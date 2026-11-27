#!/bin/bash --login
#SBATCH -J namd303-cuda-falcon-i6530-h100-1gpu-stmv_gpures_nve
#SBATCH -o o.%x.%j 
#SBATCH -e e.%x.%j 
#SBATCH --partition=gpu_h100
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:1
#SBATCH --time=00:20:00
#SBATCH -d singleton
#SBATCH --reservation=benchmarking

set -euo pipefail

arch=i6530
gpu_model=h100
cluster=falcon

# point to EB toolchain
module load NAMD/3.0.3-foss-2025a-CUDA-12.8.0
module list

NAMD=`which namd3`               # install prefix of NAMD
MODE=SPX                         # GPU slicing, SPX: single slice (only this works in this script), DPX: two slices, QPX: four slices (not supported on MI350p), CPX: max slices (4 on MI350p)
#POWER=760                        # GPU power setting (W)
NREP=1                           # 1 replica in SPX mode
TPR=${SLURM_CPUS_PER_TASK:-1}    # worker threads per replica

if [ -z ${CUDA_VISIBLE_DEVICES+x} ]; then
    echo "CUDA_VISIBLE_DEVICES is unset"
else
    echo "CUDA_VISIBLE_DEVICES is set to '$CUDA_VISIBLE_DEVICES'"
    NGPUS=`echo $CUDA_VISIBLE_DEVICES | rev | cut -d, -f1`
    NGPUS=`echo $((NGPUS+1))`
fi

#-----------------------------------------------------------------  Benchmark settings
STEPS=25000
BENCHTIME=3600
BENCH="stmv_gpures_nve"
MYDATA=${HOME}/benchmarking/input/namd/stmv_gpu
WORK=/scratch/SCWF00004/${USER}/parallel_benchmarks/namd-${MODE}-${BENCH}-${SLURM_JOBID}
LOGDIR=${SLURM_SUBMIT_DIR}/logs-${SLURM_JOB_NAME}

[ -x ${NAMD} ] || { echo "no namd3 at ${NAMD}" ; exit 1 ; }

# ---------------------------------------------------------------- configure the input
# We modify the original benchmark files from NAMD website to set:
#set benchtime    3600;
#set num_steps_run   25000;

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
## This needs to be adapted to the host cluster
#sudo /home/tools/gpu-manager.sh set -c ${MODE}
#sudo /home/tools/gpu-manager.sh set -o ${POWER}
#trap 'sudo /home/tools/gpu-manager.sh reverse-power' EXIT  # (restore default)
#sleep 5

# print some GPU details 
nvidia-smi
# probably also good idea to check the 'logical' GPUs we got are in the same physical GPU
# command should show communication 50000-200000 between devices
nvidia-smi topo --matrix


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
    for f in stage/*.namd stage/*.psf stage/*.pdb stage/*.inp stage/out_stmv.* ; do
        [ -e "${f}" ] && ln -sf ${WORK}/${f} r${i}/
    done
    ( cd r${i} && ${NAMD} +p${TPR} +setcpuaffinity \
    +pemap ${ALLOWED_CPUS} \
    +devices ${CUDA_VISIBLE_DEVICES} ${INPUT} | tee rep.log 2>&1 ) &
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
    echo "replica ${i} (device ${CUDA_VISIBLE_DEVICES}): ${STATS} ns/day"
    echo "replica ${i} (device ${CUDA_VISIBLE_DEVICES}): ${RATE} ns/day"
    TOTAL=$(awk -v a=${TOTAL} -v b=${RATE} 'BEGIN { printf "%.4f", a + b }')
    cp r${i}/rep.log ${LOGDIR}/namd-cuda-${cluster}-${arch}-${gpu_model}-${BENCH}-n${SLURM_NTASKS}-c${SLURM_CPUS_PER_TASK}-g${NGPUS}-id${SLURM_JOBID}-log-rep${i}
done
echo "${BENCH} ${MODE} aggregate: ${TOTAL} ns/day"

