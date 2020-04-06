#!/bin/bash --login
#SBATCH -o LOGS/nwchem.Hawk.n2.n40.o.%J # Job output file
#SBATCH -e LOGS/nwchem.Hawk.n2.n40.e.%J # Job error file
#SBATCH -J NWCHEM                      # Job name
#SBATCH --ntasks=40                    # number of parallel processes (tasks)
#SBATCH --ntasks-per-node=40           # tasks to run per node 
#SBATCH -p dev                     # selected queue
#SBATCH -v                             # increase job information
#SBATCH --time=00:30:00                # time limit
#SBATCH --exclusive                    # exclusive node acces
#SBATCH --account=scw1001              # project account code

module purge
#module load mpi/intel/2017/4
#module load mkl/2017/4
# Load NWChem settings
module load nwchem/6.8.1-cpu

# setting required for NWChem
ulimit -s unlimited

export ARMCI_DEFAULT_SHMMAX=8192

# following variable is default on Hawk
export OMP_NUM_THREADS=1
# submit job from example nwchem directory - change for your system
ROOT=$SLURM_SUBMIT_DIR
# Where the example file can be found
#BINDIR=$HOME/nwchem/nwchem-6.8.1-release/bin/LINUX64
INPUTDIR=$ROOT/input_files
## Input file
EXAMPLE=n2

# Where the output files can be found
OUTPUTDIR=$ROOT

NNODES=$SLURM_NNODES
NCPUS=$SLURM_NTASKS
PPN=$SLURM_NTASKS_PER_NODE

###################################
#           WORKDIR               #
###################################
# directory to run the job using /scratch/$USER
WDPATH=/scratch/$USER/nwchem.$SLURM_JOBID
# create directory where the job will be run
rm -rf ${WDPATH}
mkdir ${WDPATH}

echo Running on host `hostname`
echo Time is `date`
echo Directory is `pwd`
echo SLURM job ID is $SLURM_JOBID
echo This jobs runs on the following machine: `echo $SLURM_JOB_NODELIST | uniq`

echo Number of Processing Elements is $NCPUS
echo Number of mpiprocs per node is $PPN

# change to work directory and copy input files
cd ${WDPATH}
cp $INPUTDIR/$EXAMPLE.nw .
env
start="$(date +%s)"
## Run NWChem
#time mpirun $BINDIR/nwchem $EXAMPLE.nw > ${OUTPUTDIR}/LOGS/${EXAMPLE}.Hawk.n$NCPUS.out.$SLURM_JOBID
time mpirun nwchem $EXAMPLE.nw > ${OUTPUTDIR}/LOGS/${EXAMPLE}.Hawk.n$NCPUS.out.$SLURM_JOBID
stop="$(date +%s)"
finish=$(( $stop-$start ))
echo NWChem $EXAMPLE $SLURM_JOBID  Job-Time  $finish seconds
echo nwchem End Time is `date`
