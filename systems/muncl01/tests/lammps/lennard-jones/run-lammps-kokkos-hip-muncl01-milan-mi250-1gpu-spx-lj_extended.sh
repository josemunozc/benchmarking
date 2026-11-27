#!/bin/bash
#SBATCH -J lammps-kokkos-hip-muncl01-milan-mi250-1gpu-spx-lj_extended
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

LMP_PFX=/home/application/cardiff_arcca/bin/lammps-kokkos-hip-${cluster}-${arch}-${gpu_model}/
EXE=${LMP_PFX}/bin/lmp
MODE=SPX                         # GPU slicing, SPX: single slice (only this works in this script), DPX: two slices, QPX: four slices (not supported on MI350p), CPX: max slices (4 on MI350p)
POWER=560                        # GPU power setting (W)
TPR=${SLURM_CPUS_PER_TASK:-1}    # worker threads per replica

if [ -z ${ROCR_VISIBLE_DEVICES+x} ]; then
    echo "ROCR_VISIBLE_DEVICES is unset"
else
    echo "ROCR_VISIBLE_DEVICES is set to '$ROCR_VISIBLE_DEVICES'"
    NGPUS=`echo $ROCR_VISIBLE_DEVICES | rev | cut -d, -f1`
    NGPUS=`echo $((NGPUS+1))`
fi

#-----------------------------------------------------------------  Benchmark settings
# Base lennard-jones system has 32K atoms (4 atoms per fcc cell, 8000 cells - 20x20x20)
# scale up using x,y,z variables
# x=y=z=4   -->  2048000 atoms ->  2M system
# x=y=8 z=4 -->  8192000 atoms ->  8M system
# x=y=z=8   --> 16384000 atoms -> 16M system
SIZE=${SIZE:-2M}
if [[ ${SIZE} == "2M" ]]; then
    x=4; y=4; z=4;
elif [[ ${SIZE} == "8M" ]]; then
    x=8; y=8; z=4;
elif [[ ${SIZE} == "16M" ]]; then
    x=8; y=8; z=8;
else
   echo not supported SIZE: $${SIZE}
fi

TIMESTEPS=10000
KOKKOS_ARGS="neigh full neigh/qeq full newton off comm device pair/only off"
NREP=2                  # bechmark repeats
BENCH="lj"
MYDATA=${LMP_PFX}/share/lammps/bench
WORK=${HOME}/scratch/parallel_benchmarks/lammps-${MODE}-${BENCH}-${SLURM_JOBID}
LOGDIR=${SLURM_SUBMIT_DIR}/logs-${SLURM_JOB_NAME}

[ -x ${EXE} ] || { echo "ERROR: ${EXE} not found or has wrong permissions" ; exit 1 ; }

# ---------------------------------------------------------------- configure the input
# We modify the original benchmark files from LAMMPS installation directory
#run $TIMESTEPS

mkdir -p ${LOGDIR}
mkdir -p ${WORK}
cd ${WORK}

cp -r ${MYDATA}/ stage
INPUT=in.${BENCH}

sed -e "s/^run .*/run ${TIMESTEPS}/" \
    -i stage/${INPUT}

# print changes made and full input file for reference:
echo changes made to input file:
grep -iE "^run" stage/${INPUT} || true
echo final input file used:
cat stage/${INPUT}

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
    echo Running benchmakr ${BENCH}: ${i}
    mkdir -p r${i}
    for f in stage/${INPUT} ; do
        [ -e "${f}" ] && ln -sf ${WORK}/${f} r${i}/
    done
    ( cd r${i} && mpirun -n ${SLURM_NTASKS} --bind-to core --map-by core \
     ${EXE} -k on t ${SLURM_CPUS_PER_TASK} g ${NGPUS} -sf kk -pk kokkos gpu/aware on ${KOKKOS_ARGS} \
     -v x $x -v y $y -v z $z \
     -in ${INPUT} -nocite -log rep.log 2>&1 )


    # ---------------------------------------------------------------- figure of merit
    printf "GPU NAME, GPU MODEL,    APP,         BENCH, SIZE (M), tasks, cores, NGPUS, Matom-step/s\n"  | tee -a r${i}/rep.log
    grep "^Performance:" r${i}/rep.log
    GPU_NAME=MI250
    awk -v gpuname=${GPU_NAME} -v gpu=${GPU_TARGET} -v ngpus=${NGPUS} -v tasks=${SLURM_NTASKS} -v cores=${SLURM_CPUS_PER_TASK} -v size=${SIZE} \
    '/^Performance:/ { for (i = 2 ; i <= NF ; i++) if ($i ~ /^Matom-step/) fom = $(i-1) }
    END { printf "%s, %s, lammps, lennard-jones, %s, %s, %s, %s, %s\n", gpuname, gpu, size, tasks, cores, ngpus, fom }' r${i}/rep.log | tee -a r${i}/rep.log

    cp r${i}/rep.log ${LOGDIR}/lammps-kokkos-hip-${cluster}-${arch}-${gpu_model}-${BENCH}-${SIZE}-n${SLURM_NTASKS}-c${SLURM_CPUS_PER_TASK}-g${NGPUS}-id${SLURM_JOBID}-log-rep${i}
done
