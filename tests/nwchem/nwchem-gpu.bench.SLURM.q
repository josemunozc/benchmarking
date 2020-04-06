#!/bin/bash --login
#SBATCH -o LOGS/nwchem.pentacene.Hawk.2xgpu.n160.o.%J # Job output file
#SBATCH -e LOGS/nwchem.pentacene.Hawk.2xgpu.n160.e.%J # Job error file
#SBATCH -J NWCHEM                      # Job name
#SBATCH --ntasks=160                    # number of parallel processes (tasks)
#SBATCH --ntasks-per-node=40           # tasks to run per node 
#SBATCH --gres=gpu:2                   # GPU reservation and access, GPU count per allocated node
#SBATCH -p gpu                         # selected queue
#SBATCH -v                             # increase job information
#SBATCH --time=02:00:00                # time limit
#SBATCH --exclusive                    # exclusive node acces
#SBATCH --account=scw1001              # project account code

export JOB_GPUS=2

module purge
module load mpi/intel/2017/4
module load mkl/2017/4
module load CUDA/9.0
# Load NWChem settings
# module load nwchem/6.8.1-cpu

# setting required for NWChem
ulimit -s unlimited

export ARMCI_DEFAULT_SHMMAX=8192
#export ARMCI_DEFAULT_SHMMAX=$((8192*35))

# following variable is default on Hawk
export OMP_NUM_THREADS=1
clush -w $SLURM_NODELIST "sudo /apps/slurm/gpuset"
ROOT=$SLURM_SUBMIT_DIR
BINDIR=$HOME/nwchem/gpu/nwchem-6.8.1-release/bin/LINUX64
INPUTDIR=$ROOT/input_files
#EXAMPLE=siosi7
#EXAMPLE=tce_cuda
EXAMPLE=pentacene_ccsdt
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
# set desired number of GPU devices
sed -i "s/\(^cuda \)[0-9]/\1${JOB_GPUS}/" $EXAMPLE.nw
cat $EXAMPLE.nw | grep "cuda "
TILESIZE = `cat $EXAMPLE.nw | grep "tilesize " | sed "s/tilesize //"`
echo TILESIZE $TILESIZE
env
start="$(date +%s)"
## Run NWChem
time mpirun $BINDIR/nwchem $EXAMPLE.nw > ${OUTPUTDIR}/LOGS/${EXAMPLE}.Hawk.n$NCPUS.gpusx${JOB_GPUS}.TL${TILESIZE}.out.$SLURM_JOBID

stop="$(date +%s)"
finish=$(( $stop-$start ))
echo NWChem siosi7 $SLURM_JOBID  Job-Time  $finish seconds
echo nwchem End Time is `date`
