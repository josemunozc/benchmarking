#!/bin/bash
#SBATCH --ntasks-per-node=64
#SBATCH --ntasks=640
#SBATCH --threads-per-core=1
#SBATCH -J namd.alltests
#SBATCH -o %x.o.%J
#SBATCH -e %x.e.%J
#SBATCH -p compute_amd
#SBATCH --time=00:20:00
#SBATCH --exclusive
#SBATCH --account=scw1001
#
module purge
#module load compiler/aocc/2.1.0
#module load mpi/openmpi/1.10.6
module load compiler/intel/2018/3
module load mpi/intel/2018/3
module load mkl/2018/3
module list

INTELPATH=/apps/compilers/intel/2018.3/compilers_and_libraries_2018/linux
source ${INTELPATH}/bin/compilervars.sh intel64
source ${INTELPATH}/mpi/bin64/mpivars.sh intel64
source ${INTELPATH}/mkl/bin/mklvars.sh intel64

NAME=namd-verbs
VER=2.13.20200310

# Settings & directory locations
root=$HOME/bench
export top_dir=$root/tests/namd
export input_dir=${top_dir}/inputFiles
export MYLOGS=${top_dir}/logs_${SCWCOMPILER}_${SCWMPI}
export WDPATH=/scratch/$USER/NAMD.$SLURM_JOBID
export BINDIR=${root}/bin/${NAME}/${VER}/${SCWCOMPILER}/${SCWMPI}
export PATH=${BINDIR}:${PATH}

mkdir -p ${MYLOGS}

HOST=$SLURM_JOB_NUM_NODES
PPN=$SLURM_NTASKS_PER_NODE
NP=$SLURM_NPROCS
SKU=`cat /proc/cpuinfo | grep "model name" | uniq | cut -d' ' -f6`

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

export LD_LIBRARY_PATH=/apps/compilers/intel/2018.3/compilers_and_libraries_2018.3.222/linux/compiler/lib/intel64_lin:${LD_LIBRARY_PATH}

TESTS="apoa1 f1atpase stmv"
REPEAT="0 1"
for TEST in $TESTS; do
    LOG=namd.$TEST.`hostname`.$PPN.n${NP}.$SLURM_JOBID.log
    for rep in $REPEAT; do
    	rm -r -f ${WDPATH}/$rep
    	mkdir -p ${WDPATH}/$rep
    	cd ${WDPATH}/$rep
    	#set namd nodefile and number of processes
    	NODELIST=`nodeset -S , -e $SLURM_JOB_NODELIST | sed 's/,/\n/g'`
    	echo $NODELIST 
    	NODEFILE=nodelist.$SLURM_JOBID
    	echo group main > $NODEFILE
    	for node in $NODELIST; do
    	    echo host $node >> $NODEFILE
    	done
    	start="$(date +%s)"
    	# Copy input files to $WDPATH
    	cp $input_dir/${TEST}/* .
    	echo running TEST=$TEST NCPUs=$NP PPN=$PPN REPEAT=$rep
    	CMD="charmrun +p $NP ${BINDIR}/namd2 ++nodelist $NODEFILE +setcpuaffinity $TEST.namd"
    	#CMD="charmrun +p $NP namd2 +setcpuaffinity $TEST.namd"
    	echo ${CMD}
    	time  ${CMD} > $MYLOGS/$LOG.${rep}
    	echo ${CMD} >> $MYLOGS/$LOG.${rep}
    	# Record Total time for the job
    	stop="$(date +%s)"
    	finish=$(( $stop-$start ))
    	echo NAMD TEST=$TEST SKU=$SKU rep=$rep Job-Time  $finish seconds
    done
done
