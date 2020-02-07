#!/bin/bash
#set -eu
exec > >(tee -i logfile-`date +'%Y%m%d-%H%M%S'`.txt)
exec 2>&1

# following instructions from https://developer.arm.com/tools-and-software/server-and-hpc/help/porting-and-tuning/building-nwchem-with-arm-compiler

module purge
module load compiler/intel/2018/4
module load mpi/intel/2018/4
module load mkl/2018/4
module list

INTELPATH=/apps/compilers/intel/2018.3/compilers_and_libraries_2018/linux
source ${INTELPATH}/bin/compilervars.sh intel64
source ${INTELPATH}/mpi/bin64/mpivars.sh intel64
source ${INTELPATH}/mkl/bin/mklvars.sh intel64

# https://github.com/nwchemgit/nwchem/blob/master/INSTALL
name=nwchem
ver=6.8.1
compilerver=i2018.4
opts=base-amd
SKU=`cat /proc/cpuinfo | grep "model name" | uniq | cut -d' ' -f5`
archive=$HOME/bench/SOURCES/${name}/nwchem-6.8.1-release.revision-v6.8-133-ge032219-srconly.2018-06-14.tar.bz2
BINDIR=$HOME/bench/bin/${name}/${ver}/${compilerver}/${opts}/${SKU}

export NWCHEM_TOP=/tmp/$USER/${name}/${name}-${ver}-${compilerver}/${opts}
export NWCHEM_TARGET=LINUX64
export ARMCI_NETWORK=OPENIB
export NWCHEM_MODULES="all"
export USE_NOIO=T
export USE_F90_ALLOCATABLE=T
export USE_OPENMP=T

export USE_MPI=Y
export USE_MPIF=Y
export USE_MPIF4=Y
export USE_OPENMP=Y

export MKLLIB=$MKLROOT/lib/intel64
export MKLINC=$MKLROOT/include

export BLAS_SIZE=8
export BLASOPT="-mkl -qopenmp"

export LAPACK_SIZE=8
export LAPACK_LIB="-lmkl_lapack95_ilp64"

#export USE_SCALAPACK=Y
#export SCALAPACK="-mkl -qopenmp -lmkl_scalapack_ilp64 -lmkl_blacs_intelmpi_ilp64"
#export SCALAPACK_LIB="$SCALAPACK"

export FC=ifort
export CC=icc
#export COPTIMIZE="-O3 -qopt-prefetch -unroll -ip -no-prec-div -xHost -fp-model=precise"
#export FOPTIMIZE="-O3 -qopt-prefetch -unroll -ip -no-prec-div -xHost -fp-model=precise"
#export USE_OPTREPORT=Y

# There is an issue using Global Arrays 5.6.5 (the version used by
# Nwchem 6.8.1 by defult) when compiled with MKL 2018/2
# This is a known issue:
#
# http://www.nwchem-sw.org/index.php/Special:AWCforum/st/id2660/#post_9583
#
# The error messages relates to eigenvectors not converging
#
# PDSTEDC parameter number   10 had an illegal value 
# 0:0: ga_pdsyevd: eigenvectors failed to converge:: -10
# (rank:0 hostname:ccs0135 pid:349930):ARMCI DASSERT fail. ../../ga-5.6.5/armci/src/common/armci.c:ARMCI_Error():208 cond:0
#
# Developers suggest using Global Arrays 5.7 (latest as 21/06/2019) to fix the issue.
#export GA_RELEASE_NO=5.7

rm -rf $NWCHEM_TOP
mkdir -p $NWCHEM_TOP
cd $NWCHEM_TOP
tar -xjf $archive --strip-components=1

# "tweaking" compile options
#sed -i \
#    -e 's/-qopt-report-file=stderr//g' \
#    $NWCHEM_TOP/src/config/makefile.h

cd $NWCHEM_TOP/src
make nwchem_config || exit 10 
make configure_ga || exit 20
make -j20 || exit 30	

cd $NWCHEM_TOP/src/util
make version || exit 40
make || exit 50

cd $NWCHEM_TOP/src
make link || exit 60


####################
# Copy executables #
####################
mkdir -p ${BINDIR}/bin
mkdir -p ${BINDIR}/data

cp $NWCHEM_TOP/bin/${NWCHEM_TARGET}/nwchem ${BINDIR}/bin
cp $NWCHEM_TOP/bin/${NWCHEM_TARGET}/parallel ${BINDIR}/bin

cp -r $NWCHEM_TOP/src/basis/libraries ${BINDIR}/data
cp -r $NWCHEM_TOP/src/data ${BINDIR}
cp -r $NWCHEM_TOP/src/nwpw/libraryps ${BINDIR}/data

ls -lt ${BINDIR}/bin
ls -lt ${BINDIR}/data
