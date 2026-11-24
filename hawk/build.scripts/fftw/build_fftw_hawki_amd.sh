#!/bin/bash
#set -eu
exec > >(tee -i logfile-`date '+%Y%m%d-%H%M%S'`.txt)
exec 2>&1

module purge
module load compiler/aocc/2.1.0
module load mpi/openmpi/1.10.6
module load mkl/2018/3
module list

INTELPATH=/apps/compilers/intel/2018.3/compilers_and_libraries_2018/linux
source ${INTELPATH}/mkl/bin/mklvars.sh intel64

# Build settings
FFTW_VER=3.3.8

work_dir=$PWD
archive_fftw=fftw-3.3.8.tar.gz
build_dir=/tmp/$USER/fftw
install_dir=$HOME/bench/bin/fftw/${FFTW_VER}/${SCWCOMPILER}/${SCWMPI}
source_dir=$HOME/bench/SOURCES/fftw

echo Building NAMD in `hostname`
echo Tarball is $archive_fftw
echo Work dir is $work_dir
echo Install dir is $install_dir
echo Build dir is $build_dir
echo Source dir is $source_dir

#############################################################################
# Configure and build fftw
# fftw is downloaded from its website: http://www.fftw.org/download.html
# latest version 3.3.8 as of 30/Jan/2019
echo -------------------------
echo building fftw ${FFTW_VER}
echo -------------------------

rm -rf ${build_dir}
mkdir -p ${build_dir}
cd ${build_dir}

tar -xzvf ${source_dir}/${archive_fftw} --strip-components=1
./configure \
    --prefix=$install_dir \
    --enable-type-prefix \
    --enable-float
make
make install
