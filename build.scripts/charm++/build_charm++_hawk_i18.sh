#!/bin/bash
#set -eu
exec > >(tee -i logfile-`date '+%Y%m%d-%H%M%S'`.txt)
exec 2>&1

module purge
module load compiler/intel/2018/3
module load mpi/intel/2018/3
module load mkl/2018/3
module list

INTELPATH=/apps/compilers/intel/2018.3/compilers_and_libraries_2018/linux
source ${INTELPATH}/bin/compilervars.sh intel64
source ${INTELPATH}/mpi/bin64/mpivars.sh intel64
source ${INTELPATH}/mkl/bin/mklvars.sh intel64

# Build settings
NAME=charm++
VER=6.10.1
archive=charm-6.10.1.tar

build_dir=${HOME}/bench/bin/${NAME}/${VER}/${SCWCOMPILER}/${SCWMPI}
install_dir=${HOME}/bench/bin/${NAME}/${VER}/${SCWCOMPILER}/${SCWMPI}
source_dir=$HOME/bench/SOURCES/${NAME}

echo Building ${NAME} in `hostname`
echo Tarball is $archive
echo Install dir is $install_dir
echo Build dir is $build_dir
echo Source dir is $source_dir

#############################################################################
# Configure and build Charm++
# Charm++ comes bundled with Namd
echo -------------------------
echo building ${NAME} ${VER}
echo -------------------------

#rm -rf ${build_dir}
mkdir -p ${build_dir}
cd ${build_dir}

#tar -xvf ${source_dir}/${archive} --strip-components=1

#CHARM_ARCH=multicore-linux-x86_64
CHARM_ARCH=verbs-linux-x86_64
# compile Charm++ core only
./build \
    charm++ \
    ${CHARM_ARCH} \
    iccstatic \
    --no-build-shared \
    --with-production
