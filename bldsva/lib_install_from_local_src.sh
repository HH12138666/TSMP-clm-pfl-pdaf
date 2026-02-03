#!/bin/sh

# Install TSMP third-party libs using local archives in ../lib/src (no downloads).
# Usage: from bldsva/ run: bash lib_install_from_local_src.sh

echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "This script installs third-party libraries from local archives in ../lib/src."
echo "It does NOT download anything."
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

read -p "continue (y/n)? " answer
case $answer in
    y|Y ) ;;
    * ) echo "abort"; exit 1 ;;
esac

bldsva=$(pwd)
[ ! -d "../lib" ] && mkdir ../lib
cd ../lib && dlib=$(pwd)
[ ! -d "$dlib/src" ] && mkdir -p "$dlib/src"
cd "$dlib/src" && dsrc=$(pwd)

# Optional clean (keeps src)
CLEAN_LIB=${CLEAN_LIB:-0}
if [ "$CLEAN_LIB" = "1" ]; then
    echo "Cleaning $dlib (except src)"
    find "$dlib" -mindepth 1 -maxdepth 1 ! -name src -exec rm -rf {} +
fi

mkdir -p "$dlib/openmpi" "$dlib/hypre" "$dlib/silo" \
         "$dlib/netcdf" "$dlib/hdf5" "$dlib/zlib" "$dlib/curl" \
         "$dlib/pnetcdf" "$dlib/tcl"

log_file=$dlib/lib_install_local.out
err_file=$dlib/lib_install_local.err

require_cmd() {
    cmd=$1
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing command: $cmd"
        exit 1
    fi
}

require_file() {
    f=$1
    if [ ! -f "$f" ]; then
        echo "missing archive: $f"
        exit 1
    fi
}

pick_archive() {
    base=$1
    if [ -f "$base" ]; then
        echo "$base"
        return
    fi
    if [ -f "${base}?api=v2" ]; then
        echo "${base}?api=v2"
        return
    fi
    echo ""
}

require_cmd gcc
require_cmd gfortran
require_cmd g++
require_cmd ksh
require_cmd curl
require_cmd m4
require_cmd python || true
require_cmd make
require_cmd tar
require_cmd unzip

echo "Using local archives in $dsrc"

# Archives (must exist in lib/src)
OPENMPI_TGZ="openmpi-4.0.3.tar.gz"
HDF5_TGZ="hdf5-1.10.6.tar.gz"
NETCDF_C_ZIP="v4.7.4.zip"
NETCDF_F_ZIP="v4.5.3.zip"
SILO_TGZ="4.11.tar.gz"
HYPRE_ZIP="v2.20.0.zip"
TCL_TGZ="tcl8.6.10-src.tar.gz"
ZLIB_TGZ="v1.2.11.tar.gz"
CURL_TGZ="curl-7.71.1.tar.gz"
PNETCDF_TGZ="pnetcdf-1.12.1.tar.gz"

require_file "$OPENMPI_TGZ"
require_file "$HDF5_TGZ"
require_file "$NETCDF_C_ZIP"
require_file "$NETCDF_F_ZIP"
require_file "$SILO_TGZ"
require_file "$HYPRE_ZIP"
require_file "$TCL_TGZ"
require_file "$ZLIB_TGZ"
require_file "$CURL_TGZ"
require_file "$PNETCDF_TGZ"

# Extract if source dirs not present
[ -d "$dsrc/openmpi-4.0.3" ] || tar -xvf "$OPENMPI_TGZ" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/hdf5-1.10.6" ] || tar -xvf "$HDF5_TGZ" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/netcdf-c-4.7.4" ] || unzip -o "$NETCDF_C_ZIP" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/netcdf-fortran-4.5.3" ] || unzip -o "$NETCDF_F_ZIP" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/Silo-4.11" ] || tar -xvf "$SILO_TGZ" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/hypre-2.20.0" ] || unzip -o "$HYPRE_ZIP" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/tcl8.6.10" ] || tar -xvf "$TCL_TGZ" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/zlib-1.2.11" ] || tar -xvf "$ZLIB_TGZ" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/curl-7.71.1" ] || tar -xvf "$CURL_TGZ" >> "$log_file" 2>> "$err_file"
[ -d "$dsrc/pnetcdf-1.12.1" ] || tar -xzf "$PNETCDF_TGZ" >> "$log_file" 2>> "$err_file"

# Zlib
cd "$dsrc/zlib-1.2.11"
./configure --prefix="$dlib/zlib" >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$dlib/zlib/lib"
export PATH="$dlib/zlib/bin:$PATH"

# curl
cd "$dsrc/curl-7.71.1"
./configure --prefix="$dlib/curl" --with-zlib="$dlib/zlib" >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"
export PATH="$dlib/curl/bin:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$dlib/curl/lib"

# MPI
USE_SYSTEM_MPI=${USE_SYSTEM_MPI:-1}
if [ "$USE_SYSTEM_MPI" = "1" ]; then
    echo "Using system MPI (mpicc/mpif90/mpif77)"
    export CC=$(command -v mpicc)
    export FC=$(command -v mpif90)
    export F77=$(command -v mpif77)
    if [ -z "$CC" ] || [ -z "$FC" ]; then
        echo "System MPI compilers not found in PATH (mpicc/mpif90)."
        exit 1
    fi
else
    cd "$dsrc/openmpi-4.0.3"
    ./configure --prefix="$dlib/openmpi" --with-pmix=internal >> "$log_file" 2>> "$err_file"
    make -j 4 >> "$log_file" 2>> "$err_file"
    make install >> "$log_file" 2>> "$err_file"
    export PATH="$dlib/openmpi/bin:$PATH"
    export CC="$dlib/openmpi/bin/mpicc"
    export FC="$dlib/openmpi/bin/mpif90"
    export F77="$dlib/openmpi/bin/mpif77"
fi

# HDF5
cd "$dsrc/hdf5-1.10.6"
./configure --prefix="$dlib/hdf5" --enable-build-mode=production --enable-hl --enable-fortran \
  --enable-parallel --enable-shared --enable-static >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$dlib/hdf5/lib"

# netcdf-c
export CFLAGS="-I$dlib/hdf5/include -I$dlib/curl/include"
export LDFLAGS="-L$dlib/hdf5/lib -L$dlib/curl/lib -L$dlib/zlib/lib"
export LIBS="-lhdf5 -lhdf5_hl -lcurl -lz"
cd "$dsrc/netcdf-c-4.7.4"
./configure --prefix="$dlib/netcdf" >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$dlib/netcdf/lib"

# netcdf-fortran
export CFLAGS="-I$dlib/netcdf/include -I$dlib/hdf5/include -I$dlib/curl/include"
export FCFLAGS="-I$dlib/hdf5/include -I$dlib/curl/include -I$dlib/netcdf/include"
export CPPFLAGS="-I$dlib/netcdf/include -I$dlib/hdf5/include -I$dlib/curl/include"
export LDFLAGS="-L$dlib/hdf5/lib -L$dlib/netcdf/lib -L$dlib/curl/lib -L$dlib/zlib/lib"
export LIBS="-lnetcdf -lhdf5_hl -lhdf5 -lz -lcurl"
cd "$dsrc/netcdf-fortran-4.5.3"
./configure --prefix="$dlib/netcdf" >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"

# Silo
export FCFLAGS="-g -O2 -I$dlib/netcdf/include -I$dlib/hdf5/include -L$dlib/hdf5/lib -lhdf5_fortran -lhdf5"
cd "$dsrc/Silo-4.11"
./configure --prefix="$dlib/silo" --with-hdf5="$dlib/hdf5/include,$dlib/hdf5/lib" --enable-fortran --enable-shared \
  >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"

# hypre
cd "$dsrc/hypre-2.20.0/src"
./configure --prefix="$dlib/hypre" --with-MPI --enable-fortran --enable-shared >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"

# Tcl
export LDFLAGS=""
export LIBS=""
export CFLAGS=""
export FCFLAGS=""
export CPPFLAGS=""
cd "$dsrc/tcl8.6.10/unix"
./configure --prefix="$dlib/tcl" --enable-shared >> "$log_file" 2>> "$err_file"
make -j 4 >> "$log_file" 2>> "$err_file"
make install >> "$log_file" 2>> "$err_file"
ln -sf "$dlib/tcl/bin/tclsh8.6" "$dlib/tcl/bin/tclsh" >> "$log_file" 2>> "$err_file"

# PnetCDF
cd "$dsrc/pnetcdf-1.12.1"
export FCFLAGS="-fallow-argument-mismatch"
export FFLAGS="-fallow-argument-mismatch"
./configure --prefix="$dlib/pnetcdf"
make -j 4
make install

cat > "$bldsva/machines/loadenv_x86" << 'end_loadenv'
# Resolve TSMP root relative to this file location.
_TSMP_THIS="${BASH_SOURCE[0]}"
if [ -z "$_TSMP_THIS" ]; then
  # ksh
  _TSMP_THIS="${.sh.file}"
fi
if [ -z "$_TSMP_THIS" ]; then
  _TSMP_THIS="$0"
fi
TSMP_ROOT="$(cd "$(dirname "$_TSMP_THIS")/.." && pwd)"

export PATH="$TSMP_ROOT/lib/openmpi/bin:$PATH"
export PATH="$TSMP_ROOT/lib/tcl/bin:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$TSMP_ROOT/lib/hdf5/lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$TSMP_ROOT/lib/netcdf/lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$TSMP_ROOT/lib/hypre/lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$TSMP_ROOT/lib/silo/lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$TSMP_ROOT/lib/tcl/lib"
#export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$TSMP_ROOT/lib/pnetcdf/lib"

#export CC=$TSMP_ROOT/lib/openmpi/bin/mpicc
#export FC=$TSMP_ROOT/lib/openmpi/bin/mpif90
#export F77=$TSMP_ROOT/lib/openmpi/bin/mpif77
end_loadenv

echo "installation finished (local archives)."
