#!/bin/bash
#module load compiler/aocc/2.1.0
#module load mpi/openmpi/1.10.6
module load compiler/intel/2018/3
module load mpi/intel/2018/3
module load mkl/2018/3

HOST=$2
HOST_OPT="ccs|cca"
TEST_CASE=$1
TEST_OPT="apoa1|f1atpase|stmv"
if ! [[ "${TEST_CASE}" =~ ^($TEST_OPT)$ ]];
then
    echo "test option not in list"
    echo ${TEST_OPT}
    exit 1;
fi  

if ! [[ "${HOST}" =~ ^($HOST_OPT)$ ]];
then
    echo "host option not in list"
    echo ${HOST_OPT}
    exit 1;
fi  

echo "TEST: ${TEST_CASE} COMPILER: ${SCWCOMPILER} MPI: ${SCWMPI}"
echo -e "CPUS\tDAYSPERNS\tAVG\tREP\tJOBID"

for f in logs_verbs_${SCWCOMPILER}_${SCWMPI}/namd.${TEST_CASE}.${HOST}*log.*; 
do 
    CPUS=`echo $f | cut -d'/' -f2 | cut -d'.' -f5 | sed s/n//`;
    REP=`echo $f | cut -d'/' -f2 | cut -d'.' -f8`;
    JOBID=`echo $f | cut -d'/' -f2 | cut -d'.' -f6`;
    DAYSPERNS=`cat $f | grep Benchmark | cut -d' ' -f8 | cut -d' ' -f2` 
    AVG=`echo $DAYSPERNS | sed 's/ /*0.5+0.5*/' | bc`
    #echo $VAR $DAYSPERNS $AVG $REP;
    #echo -e $CPUS"\t"$DAYSPERNS"\t"$AVG"\t"$REP"\t"$JOBID
    DAYSPERNS1=`echo $DAYSPERNS | cut -d' ' -f1`
    DAYSPERNS2=`echo $DAYSPERNS | cut -d' ' -f2`
    printf "%03d\t%f\t%f\t%f\t%d\t%d\n" $CPUS $DAYSPERNS1 $DAYSPERNS2 $AVG $REP $JOBID
    #echo $f
done
