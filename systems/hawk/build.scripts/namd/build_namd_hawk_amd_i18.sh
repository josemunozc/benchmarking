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
NAME=namd-verbs
VER=2.13.20200310
archive=NAMD_Git-2020-03-10_Source.tar.gz

build_dir=/tmp/$USER/${NAME}/${VER}/${SCWCOMPILER}/${SCWMPI}
install_dir=$HOME/bench/bin/${NAME}/${VER}/${SCWCOMPILER}/${SCWMPI}
source_dir=$HOME/bench/SOURCES/namd

echo Building NAMD in `hostname`
echo Tarball is ${archive}
echo Install dir is $install_dir
echo Build dir is $build_dir
echo Source dir is $source_dir

#############################################################################
# Configure and build Namd
# Downloaded from https://www.ks.uiuc.edu/Development/Download/download.cgi?PackageName=NAMD (nightly version)
echo -------------------------
echo building ${NAME} ${VER}
echo -------------------------

rm -rf ${build_dir}
mkdir -p ${build_dir}
cd $build_dir

tar -xzvf ${source_dir}/${archive} --strip-components=1

FFTW_VER=3.3.8
TCL_VER=8.5.9
#CHARM_ARCH=multicore-linux-x86_64
CHARM_ARCH=verbs-linux-x86_64-iccstatic
CHARM_VER=6.10.1
#NAMD_ARCH=Linux-x86_64-icc.multicore
NAMD_ARCH=Linux-x86_64-icc.verbs

cat > arch/Linux-x86_64-icc.arch << EOF
NAMD_ARCH = Linux-x86_64
CHARMARCH = ${CHARM_ARCH} 
CXX = icpc -std=c++0x 
CXXOPTS= -static-intel -O2 -ip -axAVX -qopenmp-simd
CXXNOALIASOPTS = -O2 -fno-alias -ip -axAVX -qopenmp-simd
CXXCOLVAROPTS = -O2 -ip
CC = icc
COPTS = -static-intel -O2 -ip -axAVX -qopenmp-simd
EOF

./config \
    $NAMD_ARCH \
    --charm-base $HOME/bench/bin/charm++/${CHARM_VER}/${SCWCOMPILER}/${SCWMPI} \
    --charm-arch ${CHARM_ARCH} \
    --tcl-prefix $HOME/bench/bin/tcl-threaded/${TCL_VER}/${SCWCOMPILER}/${SCWMPI} \
    --fftw-prefix $HOME/bench/bin/fftw/${FFTW_VER}/${SCWCOMPILER}/${SCWMPI} 

cd ${NAMD_ARCH}
make -j20

mkdir -p ${install_dir}
cp charmrun ${install_dir}
cp flipbinpdb ${install_dir}
cp flipdcd ${install_dir}
cp namd2 ${install_dir}
cp psfgen ${install_dir}
cp sortreplicas ${install_dir}
