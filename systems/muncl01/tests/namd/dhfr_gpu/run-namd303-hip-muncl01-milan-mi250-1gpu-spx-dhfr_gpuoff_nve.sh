#!/bin/bash
#SBATCH -J namd303-hip-muncl01-milan-mi250-1gpu-dhfr_gpuoff_nve
#SBATCH -o o.%x.%j 
#SBATCH -e e.%x.%j 
#SBATCH --partition=MI250
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:2
#SBATCH --time=00:20:00
#SBATCH -d singleton
#SBATCH -w electra018

set -euo pipefail

arch=milan
gpu_model=mi250
cluster=muncl01
# gfx950 -- MI350p
# gfx942 -- MI300X
# gfx90a -- MI210, MI250
GPU_TARGET=$(rocminfo | awk '/Name:[[:space:]]*gfx/{print $2}' | sort -u | head -1)
if [[ ${GPU_TARGET} == "gfx942" ]] || [[ ${GPU_TARGET} == "gfx90a" ]] || [[ ${GPU_TARGET} == "gfx950" ]]; then
  echo "GPU_TARGET=$GPU_TARGET"
else
  echo "Error unrecognised GPU_TARGET: $GPU_TARGET"
  exit 1
fi

# point to EB toolchain
export MODULEPATH=/home/application/cardiff_arcca/easybuild/x86_64/amd/$arch/modules/all
module load foss/2026.1
module list
export LD_LIBRARY_PATH=/opt/rocm/lib:$LD_LIBRARY_PATH

NAMD=/home/application/cardiff_arcca/bin/namd-hip-${cluster}-${arch}-${gpu_model}/bin/namd3 # install prefix of NAMD
MODE=SPX                         # GPU slicing, SPX: single slice (only this works in this script), DPX: two slices, QPX: four slices (not supported on MI350p), CPX: max slices (4 on MI350p)
POWER=560                        # GPU power setting (W)
NREP=1                           # 1 replica in SPX mode
TPR=${SLURM_CPUS_PER_TASK:-1}    # worker threads per replica

if [ -z ${ROCR_VISIBLE_DEVICES+x} ]; then
    echo "ROCR_VISIBLE_DEVICES is unset"
else
    echo "ROCR_VISIBLE_DEVICES is set to '$ROCR_VISIBLE_DEVICES'"
    NGPUS=`echo $ROCR_VISIBLE_DEVICES | rev | cut -d, -f1`
    NGPUS=`echo $((NGPUS+1))`
fi

#-----------------------------------------------------------------  Benchmark settings
STEPS=500000
BENCHTIME=1800
BENCH="dhfr_gpuoff_nve"
MYDATA=${HOME}/benchmarking/input/namd/dhfr_gpu
WORK=${HOME}/scratch/parallel_benchmarks/namd-${MODE}-${BENCH}-${SLURM_JOBID}
LOGDIR=${SLURM_SUBMIT_DIR}/logs-${SLURM_JOB_NAME}

[ -x ${NAMD} ] || { echo "no namd3 at ${NAMD}" ; exit 1 ; }

# ---------------------------------------------------------------- configure the input
# We modify the original benchmark files from NAMD website to set:
#set benchtime    $STEPS;
#set num_steps_run   $BENCHTIME;

mkdir -p ${LOGDIR}
mkdir -p ${WORK}
cd ${WORK}

cp -r ${MYDATA}/ stage
INPUT=${BENCH}.namd

sed -e "s/^set num_steps_run .*/set num_steps_run ${STEPS}/" \
-e "s/^\(set[[:space:]]\+benchtime[[:space:]]\+\)[0-9]\+/\1${BENCHTIME}/" \
-i stage/${INPUT}
grep -iE "num_steps_run|benchtime" stage/${INPUT} || true

# ---------------------------------------------------------------- GPU slicing and power settings
# This needs to be adapted to the host cluster
# sudo /home/tools/gpu-manager.sh set -c ${MODE} # not working on MI210
# sudo /home/tools/gpu-manager.sh set -o ${POWER} # breaks on two GPUs on MI250, as they are 'logical' devices and only one can be changed
trap 'sudo /home/tools/gpu-manager.sh reverse-power' EXIT  # (restore default)
sleep 5

# print some GPU details 
amd-smi
# probably also good idea to check the 'logical' GPUs we got are in the same physical GPU
# command should show communication 50000-200000 between devices
amd-smi topology -w -b


# ---------------------------------------------------------------- cores assigned to this job
taskset -cp $$
grep Cpus_allowed_list /proc/self/status
PEMAP=$(taskset -cp $$ | sed 's/.*: //')

ALLOWED_CPUS=$(python3 -c '
import os
cpus = os.sched_getaffinity(0)
print(",".join(map(str, cpus)))
')
echo ALLOWED_CPUS=${ALLOWED_CPUS}
echo PEMAP=${PEMAP}

# ---------------------------------------------------------------- Run NAMD (one replica per partition)
for i in $(seq 0 $(( NREP - 1 ))) ; do
    mkdir -p r${i}
    for f in stage/*.namd stage/*.psf stage/*.pdb stage/*.tcl stage/*.inp; do
        [ -e "${f}" ] && ln -sf ${WORK}/${f} r${i}/
    done
    ( cd r${i} && ${NAMD} +p${TPR} +setcpuaffinity \
    +pemap ${ALLOWED_CPUS} \
    +devices ${ROCR_VISIBLE_DEVICES} ${INPUT} | tee rep.log 2>&1 ) &
done
wait
# ---------------------------------------------------------------- figure of merit
# ns/day = dt[fs] / mean(wall s/step of the TIMING: lines) * 86400 * 1e-6
TOTAL=0
for i in $(seq 0 $(( NREP - 1 ))) ; do
    RATE=$(awk 'BEGIN { dt = 1.0 }
        $2 == "TIMESTEP" { dt = $3 }
        $1 == "TIMING:" { split($8, w, "/") ; s += w[1] ; c += 1 }
        END { if (c > 0) printf "%.4f", dt / (s / c) * 86400 * 1e-6
        else printf "0" }' r${i}/rep.log)

    STATS=$(awk 'BEGIN { OFS = ","; max=0; min=1000; }
        $1 == "PERFORMANCE:" { sum+=$4; n++; if ($4<0+min) min=$4; if ($4>0+max) max=$4 }
        END { if (n > 0) print "avg="sum / n",sum="sum",min="min",max="max }' r${i}/rep.log)

    grep -q "WallClock:" r${i}/rep.log || echo "WARNING: replica ${i} did not terminate normally"
    echo "replica ${i} (device ${ROCR_VISIBLE_DEVICES}): ${STATS} ns/day"
    echo "replica ${i} (device ${ROCR_VISIBLE_DEVICES}): ${RATE} ns/day"
    TOTAL=$(awk -v a=${TOTAL} -v b=${RATE} 'BEGIN { printf "%.4f", a + b }')
    cp r${i}/rep.log ${LOGDIR}/namd-hip-${cluster}-${arch}-${gpu_model}-${BENCH}-n${SLURM_NTASKS}-c${SLURM_CPUS_PER_TASK}-g${NGPUS}-id${SLURM_JOBID}-log-rep${i}
done
echo "${BENCH} ${MODE} aggregate: ${TOTAL} ns/day"

