#!/bin/bash --login
#SBATCH --ntasks-per-node=64
#SBATCH --ntasks=64
#SBATCH --threads-per-core=1
#SBATCH -J alltests.nwchem
#SBATCH -o %x.o.%J
#SBATCH -e %x.e.%J
#SBATCH -p compute_amd
#SBATCH --time=02:00:00
#SBATCH --exclusive
#SBATCH --account=scw1001

module purge
module load nwchem/6.8.1-cpu
#module load compiler/intel/2018/4
#module load mpi/intel/2018/4
module list

#INTELPATH=/apps/compilers/intel/2018.4/compilers_and_libraries_2018/linux
#source ${INTELPATH}/bin/compilervars.sh intel64
#source ${INTELPATH}/mpi/bin64/mpivars.sh intel64
#source ${INTELPATH}/mkl/bin/mklvars.sh intel64

ulimit -s unlimited
export NWCHEM_TARGET=LINUX64
export ARMCI_NETWORK=OPENIB
export ARMCI_DEFAULT_SHMMAX=8192
unset MA_USE_ARMCI_MEM

# Settings & directory locations
root=$HOME
SKU=`cat /proc/cpuinfo | grep "model name" | uniq | cut -d' ' -f5`
export top_dir=$root/bench/tests/nwchem
export input_dir=${top_dir}/input_files
export MYLOGS=${top_dir}/logs.${SKU}
export WDPATH=/scratch/$USER/NWCHEM.$SLURM_JOBID
#CODE=${root}/bench/tests/nwchem
#BINDIR=${root}/bench/bin/nwchem/6.8.1/i2018.4/base-amd/7502/bin
#export PATH=$BINDIR:$PATH
#export NWCHEM_BASIS_LIBRARY=${root}/bench/bin/nwchem/6.8.1/i2018.4/base-amd/7502/data/libraries/

mkdir -p ${MYLOGS}

HOST=$SLURM_JOB_NUM_NODES
PPN=$SLURM_NTASKS_PER_NODE
NP=$SLURM_NPROCS

echo '----------------------------------------------------'
echo ' NODE USED = '$SLURM_NODELIST
echo ' SLURM_JOBID = '$SLURM_JOBID
echo ' OMP_NUM_THREADS = '$OMP_NUM_THREADS
echo ' ncores = '$NP
echo ' PPN = ' $PPN
echo '----------------------------------------------------'
#
echo Running on host `hostname`
echo Time is `date`
echo Directory is `pwd`
echo SLURM job ID is $SLURM_JOBID
#
echo Number of Processing Elements is $NP
echo Number of mpiprocs per node is $PPN
env

TESTS="aump2 siosi7 c240_pbe0"
REPEAT="0 1"
for TEST in $TESTS; do
    LOG=nwchem.$TEST.`hostname`.$SKU.$PPN.n${NP}.$SLURM_JOBID.log
    for rep in $REPEAT; do
	rm -r -f ${WDPATH}/$rep
	mkdir -p ${WDPATH}/$rep
	cd ${WDPATH}/$rep
	start="$(date +%s)"
	# Copy input files to $WDPATH
	cp $input_dir/$TEST.nw .
	echo running TEST=$TEST NCPUs=$NP PPN=$PPN REPEAT=$rep
	CMD="mpirun nwchem $TEST.nw"
	echo ${CMD}
	time  ${CMD} > $MYLOGS/$LOG.${rep}
	echo ${CMD} >> $MYLOGS/$LOG.${rep}
	# Record Total time for the job
	stop="$(date +%s)"
	finish=$(( $stop-$start ))
	echo NWCHEM TEST=$TEST SKU=$SKU rep=$rep Job-Time  $finish seconds
    done
done
