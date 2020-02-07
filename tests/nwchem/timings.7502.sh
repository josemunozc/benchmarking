#!/bin/bash

TESTS="aump2 siosi7 c240_pbe0"

for test in $TESTS
do
    for file in `ls logs.7502/nwchem.${test}*`
    do
        CPUTIME=`cat $file | grep "Total times" | cut -d':' -f3 | sed -e 's/s//' | tr -d ' '`
        WALLTIME=`cat $file | grep "Total times" | cut -d':' -f2 | sed -e 's/wall//' -e 's/s//' | tr -d ' '`
        CPUS=`echo $file | cut -d'.' -f7 | sed 's/n//'`
        echo -e "${test}\t${CPUS}\t${CPUTIME}\t${WALLTIME}"
    done
done


#PROGNAME="nwchem.siosi7.SLURM.q"
##JOBS="0 1 2"
#NTASKS="40 60 80 100 120"
#
#for N in $NTASKS; do 
#    sed -i -e "s/\(^#SBATCH.*.n\)[0-9]\+\(.*\)/\1$N\2/" \
#	-e "s/\(^#SBATCH --ntasks=\)[0-9]\+\(.*\)/\1$N\2/" $PROGNAME
#    sbatch $PROGNAME
#    sleep 2
#done
