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
NAME=tcl-threaded
VER=8.5.9

archive=tcl${VER}-src.tar.gz
build_dir=/tmp/$USER/${NAME}/${VER}/${SCWCOMPILER}/${SCWMPI}
install_dir=$HOME/bench/bin/${NAME}/${VER}/${SCWCOMPILER}/${SCWMPI}
source_dir=$HOME/bench/SOURCES/tcl

echo Building NAMD in `hostname`
echo Tarball is $archive
echo Install dir is $install_dir
echo Build dir is $build_dir
echo Source dir is $source_dir

#############################################################################
# Configure and build tcl
# tcl is downloaded from its website: http://www.tcl.tk/software/tcltk/download.html
echo -------------------------
echo building ${NAME} ${VER}
echo -------------------------

rm -rf ${build_dir}
mkdir -p ${build_dir}
cd ${build_dir}

tar -xzvf ${source_dir}/${archive} --strip-components=1

# build and install tcl with threads
cd unix
./configure \
    --prefix=${install_dir} \
    --enable-threads

make
make test
make install
