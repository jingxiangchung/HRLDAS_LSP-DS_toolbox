#!/bin/bash
#Written by Jing Xiang CHUNG on 19/9/2024
#A script to compile all libraries needed by WRF, WPS and HRLDAS, since they do not work well with new JASPER and don't like new JASPER is in the same directory as other needed libraries.

#Getting everything ready------------------------
INSTALL_DIR=`pwd`
PATH_to_SRC='/mnt/d/Research/MySrc'

echo "Install in ${INSTALL_DIR}..."

#export CC=icx
#export CXX=icpx
#export FC=ifx
#export F77=ifx
#export F90=ifx
#export MPIFC="mpiifort -fc=ifx"
#export MPIF77="mpiifort -fc=ifx"
#export MPIF90="mpiifort -fc=ifx"
#export MPICC="mpiicc -cc=icx"
#export MPICXX="mpiicpc -cxx=icpx"

export LD_LIBRARY_PATH=${INSTALL_DIR}/lib:${LD_LIBRARY_PATH}
export LDFLAGS="$LDFLAGS -L${INSTALL_DIR}/lib"
export CPPFLAGS="${CPPFLAGS} -I${INSTALL_DIR}/include"
export CFLAGS="-fPIC -fPIE -O3"
export PATH=${INSTALL_DIR}/bin:${PATH}

sudo apt-get install build-essential libevent-dev m4 csh

#0.OpenMPI---------------------------------------
#openmpi: https://www.open-mpi.org/software/ompi/v5.0/
echo "...compiling openMPI..."
tar -xzf ${PATH_to_SRC}/openmpi-5.0.5.tar.gz;cd openmpi-5.0.5;./configure --prefix=${INSTALL_DIR};make;make install;cd ..

#1. zlib-----------------------------------------
#zlib-1.3.1: https://github.com/madler/zlib/releases
echo "...compiling zlib and szip..."
tar -xzf ${PATH_to_SRC}/zlib-1.3.1.tar.gz; cd zlib-1.3.1;./configure --prefix=${INSTALL_DIR};make;make install;cd ..

#szip: https://docs.hdfgroup.org/archive/support/ftp/lib-external/szip/2.1.1/src/szip-2.1.1.tar.gz
tar -xzf ${PATH_to_SRC}/szip-2.1.1.tar.gz; cd szip-2.1.1; ./configure --prefix=${INSTALL_DIR};make;make install;cd ..

#2. PNG---------------------------------------
#libpng-1.6.43: http://www.libpng.org/pub/png/libpng.html
echo "...compiling libpng..."
tar -xzf ${PATH_to_SRC}/libpng-1.6.43.tar.gz; cd libpng-1.6.43;./configure --prefix=${INSTALL_DIR};make;make install;cd ..

#3. HDF5-----------------------------------------
#hdf5-1.14.4-3: https://github.com/HDFGroup/hdf5/releases
#Threadsafe+Unsupported to ensure cdo can chain nc4 data and high level libraries can be built, remove them if HDF5 breaks
echo "...compiling hdf5..."
tar -xzf ${PATH_to_SRC}/hdf5-1.14.4-3.tar.gz; cd hdf5-1.14.4-3;./configure --prefix=${INSTALL_DIR} --enable-hl --enable-build-mode=production --with-pic --with-szlib=${INSTALL_DIR} ;make;make install;cd ..

#4. NetCDF4(need HDF5)---------------------------
#netcdf-4.9.2: https://downloads.unidata.ucar.edu/netcdf/
echo "...compiling netcdf-c..."
tar -xzf ${PATH_to_SRC}/netcdf-c-4.9.2.tar.gz; cd netcdf-c-4.9.2;./configure --prefix=${INSTALL_DIR} --enable-shared --enable-netcdf-4 --disable-byterange;make;make install;cd ..

#*NetCDF4(extra)---------------
#netcdf-cxx4-4.3.1
echo "...compiling netcdf-cxx..."
tar -xzf ${PATH_to_SRC}/netcdf-cxx4-4.3.1.tar.gz; cd netcdf-cxx4-4.3.1;./configure --prefix=${INSTALL_DIR} --enable-shared;make;make install;cd ..

#netcdf-fortran-4.6.1
echo "...compiling netcdf-fortran..."
tar -xzf ${PATH_to_SRC}/netcdf-fortran-4.6.1.tar.gz; cd netcdf-fortran-4.6.1;./configure --prefix=${INSTALL_DIR} --enable-shared;make;make install;cd ..

#5. JPEG-------------------------------------
#jpeg: https://ijg.org/files/
echo "...compiling JPEG..."
tar -xzf ${PATH_to_SRC}/jpegsrc.v9f.tar.gz; cd jpeg-9f; ./configure --prefix=${INSTALL_DIR};make; make install; cd ..

#6. Jasper------------------------------------
#jasper-1.900.29: https://repository.timesys.com/buildsources/j/jasper/jasper-1.900.29/jasper-1.900.29.tar.gz
echo "...compiling jasper..."
tar -xzf ${PATH_to_SRC}/jasper-1.900.29.tar.gz; cd jasper-1.900.29; ./configure --prefix=${INSTALL_DIR};make; make install; cd ..

echo "...please run "export PATH=${INSTALL_DIR}/bin:${PATH}" when you want to compile WRF..."
echo "Job completed!"
