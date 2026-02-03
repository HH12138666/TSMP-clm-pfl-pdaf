#! /bin/ksh

always_pfl(){
route "${cyellow}>> always_pfl${cnormal}"
route "${cyellow}<< always_pfl${cnormal}"
}

configure_pfl(){
route "${cyellow}>> configure_pfl${cnormal}"
    # ParFlow 安装目录与构建目录
    export PARFLOW_INS="$pfldir/bin"
    export PARFLOW_BLD="$pfldir/build"
#    export PFV="oas-gpu"
    # GPU 情况下 RMM 目录
    export RMM_ROOT=$pfldir/rmm
#
    # C 编译参数与 CMake 选项集合
    C_FLAGS="-fopenmp"
    if [[ $compiler == "Gnu" ]]; then
      C_FLAGS+=" -fcommon"
    fi
    flagsSim="  -DMPIEXEC_EXECUTABLE=$(which srun)"
    # 根据耦合情况选择 AMPS 通信层
    if [[ $withOAS == "true" ]]; then
        flagsSim+=" -DPARFLOW_AMPS_LAYER=oas3"
    else
      if [[ $withPDAF == "true" ]] ; then
        flagsSim+=" -DPARFLOW_AMPS_LAYER=da"
      else
        flagsSim+=" -DPARFLOW_AMPS_LAYER=mpi1"
      fi
    fi
    # 依赖库与构建设置
    flagsSim+=" -DOAS3_ROOT=$oasdir/$platform"
    flagsSim+=" -DSILO_ROOT=$siloPath"
    flagsSim+=" -DHYPRE_ROOT=$hyprePath"
    flagsSim+=" -DCMAKE_BUILD_TYPE=Release"
    flagsSim+=" -DPARFLOW_ENABLE_TIMING=TRUE"
    flagsSim+=" -DCMAKE_INSTALL_PREFIX=$PARFLOW_INS"
    flagsSim+=" -DCMAKE_EXE_LINKER_FLAGS=-Wl,--no-as-needed"
    flagsSim+=" -DCMAKE_SHARED_LINKER_FLAGS=-Wl,--no-as-needed"
    flagsSim+=" -DCMAKE_C_STANDARD_LIBRARIES=-lstdc++"

    # NetCDF C/Fortran 路径
    flagsSim+=" -DCMAKE_PREFIX_PATH=$ncdfPath"
    flagsSim+=" -DCMAKE_LIBRARY_PATH=$ncdfPath/lib"
    flagsSim+=" -DCMAKE_INCLUDE_PATH=$ncdfPath/include"
    flagsSim+=" -DNETCDF_DIR=$ncdfPath"
    flagsSim+=" -DNETCDF_Fortran_ROOT=$ncdfPath"
    flagsSim+=" -DNETCDF_INCLUDE_DIR=$ncdfPath/include"
    flagsSim+=" -DNETCDF_LIBRARY=$ncdfPath/lib/libnetcdf.so"
    flagsSim+=" -DNETCDF_Fortran_INCLUDE_DIR=$ncdfPath/include"
    flagsSim+=" -DNETCDF_Fortran_LIBRARY=$ncdfPath/lib/libnetcdff.so"
    # Tcl 与 AMPS I/O 模式
    flagsSim+=" -DTCL_TCLSH=$tclPath/bin/tclsh8.6"
    flagsSim+=" -DPARFLOW_AMPS_SEQUENTIAL_IO=on"
    # Fortran include/兼容参数
    pfl_fflags="-I$ncdfPath/include"
    if [[ $compiler == "Gnu" ]]; then
      pfl_fflags+=" -fallow-argument-mismatch"
    fi
    # PDAF 模式关闭 SLURM hooks
    if [[ $withPDAF == "true" ]] ; then
      # PDAF:
      # Turn off SLURM for PDAF due to error
      # Only used for finishing job close to SLURM time limit
      # Could be added in future effort
      flagsSim+=" -DPARFLOW_ENABLE_SLURM=FALSE"
    else
      flagsSim+=" -DPARFLOW_ENABLE_SLURM=TRUE"
    fi
	# 选择编译器（可选 Scalasca 包装）
    if [[ $profiling == "scalasca" ]]; then
      pcc="scorep-mpicc"
      pfc="scorep-mpif90"
      pf77="scorep-mpif77"
      pcxx="scorep-mpicxx"
      flagsTools+="CC=scorep-mpicc FC=scorep-mpif90 F77=scorep-mpif77 "
    else
	  pcc="$mpiPath/bin/mpicc"
      pfc="$mpiPath/bin/mpif90"
      pf77="$mpiPath/bin/mpif77"
      pcxx="$mpiPath/bin/mpic++"
    fi
#
    # 创建安装/构建目录
    comment "    add parflow paths $PARFLOW_INS, $PARFLOW_BLD "
     mkdir -p $PARFLOW_INS
     mkdir -p $PARFLOW_BLD
    check

    comment " parflow is configured for $processor "
    check
    # GPU/加速器构建分支
    if [[ $processor == "GPU"|| $processor == "MSA" ]]; then
       cd $pfldir
       comment "module load CUDA  mpi-settings/CUDA "
        module load CUDA  $gpuMpiSettings >> $log_file 2>> $err_file
       check
       comment "    additional configuration options for GPU are set "
        flagsSim+=" -DPARFLOW_ACCELERATOR_BACKEND=cuda"
        flagsSim+=" -DRMM_ROOT=$RMM_ROOT"
        flagsSim+=" -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared"
       check
       comment "    git clone  RAPIDS Memory Manager "
       if [ -d $RMM_ROOT ] ; then 
        comment "  remove $RMM_ROOT "
        rm -rf $RMM_ROOT >> $log_file 2>> $err_file
        check
       fi
       git clone -b branch-0.10 --single-branch --recurse-submodules https://github.com/hokkanen/rmm.git >> $log_file 2>> $err_file
       check
        mkdir -p $RMM_ROOT/build
        cd $RMM_ROOT/build
       comment "    configure RMM: RAPIDS Memory Manager "
        cmake ../ -DCMAKE_INSTALL_PREFIX=$RMM_ROOT ${cuda_architectures} >> $log_file 2>> $err_file
       check
       comment "    make RMM "
        make -j  >> $log_file 2>> $err_file
       check
       comment "    make install RMM "
        make install >> $log_file 2>> $err_file
       check
    fi

    # 执行通用配置（CMake）
    c_configure_pfl

route "${cyellow}<< configure_pfl${cnormal}"
}

make_pfl(){
route "${cyellow}>> make_pfl${cnormal}"
  # 执行通用编译/安装
  c_make_pfl
route "${cyellow}<< make_pfl${cnormal}"
}


substitutions_pfl(){
route "${cyellow}>> substitutions_pfl${cnormal}"

  # 执行通用补丁/替换逻辑
  c_substitutions_pfl

route "${cyellow}<< substitutions_pfl${cnormal}"
}
