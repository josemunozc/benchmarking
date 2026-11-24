#!/bin/bash
#SBATCH --ntasks-per-node=40
#SBATCH --ntasks=400
#SBATCH --threads-per-core=1
#SBATCH -J namd.alltests
#SBATCH -o %x.o.%J
#SBATCH -e %x.e.%J
#SBATCH -p compute
#SBATCH --time=00:20:00
#SBATCH --exclusive
#SBATCH --account=scw1001
#
module purge
module load namd/2.13.20200310
module list

# Settings & directory locations
root=$HOME/bench
export top_dir=$root/tests/namd
export input_dir=${top_dir}/inputFiles
export MYLOGS=${top_dir}/logs_verbs_${SCWCOMPILER}_${SCWMPI}
export WDPATH=/scratch/$USER/NAMD.$SLURM_JOBID

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
    	CMD="charmrun +p $NP ${NAMD_BINDIR}/namd2 ++nodelist $NODEFILE +setcpuaffinity $TEST.namd"
    	#CMD="charmrun +p $NP namd2 +setcpuaffinity $TEST.namd"
    	echo ${CMD}
    	time ${CMD} > $MYLOGS/$LOG.${rep}
    	echo ${CMD} >> $MYLOGS/$LOG.${rep}
    	# Record Total time for the job
    	stop="$(date +%s)"
    	finish=$(( $stop-$start ))
    	echo NAMD TEST=$TEST SKU=$SKU rep=$rep Job-Time  $finish seconds
    done
done
