#!/bin/bash
#set -eu
exec > >(tee -i logfile-`date '+%Y%m%d-%H%M%S'`.txt)
exec 2>&1

#module purge
module load compiler/intel/2018/3
module load mpi/intel/2018/3
module load mkl/2018/3
module list

INTELPATH=/apps/compilers/intel/2018.3/compilers_and_libraries_2018/linux
source ${INTELPATH}/bin/compilervars.sh intel64
source ${INTELPATH}/mpi/bin64/mpivars.sh intel64
source ${INTELPATH}/mkl/bin/mklvars.sh intel64

# Build settings
FFTW_VER=3.3.8
CHARM_ARCH=mpi-linux-x86_64
CHARM_VER=6.10.0
NAMD_ARCH=Linux-x86_64-icc
NAMD_ARCH=Linux-x86_64-icc.mpi

work_dir=$PWD
archive_namd=NAMD_Git-2020-01-16_Source.tar.gz
archive_charm=charm-6.10.0-pre.tar
archive_fftw=fftw-linux-x86_64.tar.gz
archive_tcl=tcl8.5.9-linux-x86_64.tar.gz
archive_tcl_threaded=tcl8.5.9-linux-x86_64-threaded.tar.gz
build_dir=/tmp/$USER/namd
#install_dir=/scratch/$USER/namd
source_dir=$HOME/bench/SOURCES/namd

echo Building NAMD in `hostname`
echo Tarball is $archive_namd
echo Tarball is $archive_charm
echo Tarball is $archive_fftw
echo Tarball is $archive_tcl
echo Tarball is $archive_tcl_threaded
echo Work dir is $work_dir
#echo Install dir is $install_dir
echo Build dir is $build_dir
echo Source dir is $source_dir

#############################################################################
rm -rf ${build_dir}
mkdir -p ${build_dir}
cd $build_dir
tar -xzvf ${source_dir}/${archive_namd} --strip-components=1

# Configure and build Charm
echo -------------------------
echo building Charm-${CHARM_VER}
echo -------------------------
mkdir charm
cd charm
tar -xvf ${source_dir}/${archive_charm} --strip-components=1

# compile Charm++ core only
./build \
    charm++ \
    $CHARM_ARCH \
    icc \
    --no-build-shared \
    --with-production \
    "-O3 -march=core-avx2 -fma -ftz -fomit-frame-pointer" \
    -DCMK_OPTIMIZE

cd ${build_dir}

# Configure and build fftw
# fftw is downloaded from its website: http://www.fftw.org/download.html
# latest version 3.3.8 as of 30/Jan/2019
echo -------------------------
echo building fftw ${FFTW_VER}
echo -------------------------

mkdir fftw
cd fftw
tar -xzvf ${source_dir}/${archive_fftw} --strip-components=1

cd ..
mkdir tcl-threaded
cd tcl-threaded
tar -xzvf ${source_dir}/${archive_tcl_threaded} --strip-components=1

cd ..
mkdir tcl
cd tcl
tar -xzvf ${source_dir}/${archive_tcl} --strip-components=1

cd ..

# Configure and build namd
echo -------------------------
echo building Namd ...........
echo -------------------------

sed -i \
    -e 's/^\(FLOATOPTS =\).*/\1 -O3 -march=core-avx2 -fma -ftz -fomit-frame-pointer -ip -pthread/' \
    -e 's/CXXNOALIASOPTS = -O2/CXXNOALIASOPTS = -O3/' \
    arch/Linux-x86_64-icc.arch

./config \
    $NAMD_ARCH \
    --charm-arch $CHARM_ARCH-icc

cd $NAMD_ARCH

make -j20
