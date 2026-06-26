nfort -static  -traceback=verbose -mwork-vector-kind=none -fno-loop-interchange -minit-stack=zero  \
       	-o cg_exe  \
	eigsystm.F90 cg_main_gga_df_omp_YY_allct.f dosgen.f newfft.f orbanly_part_f.f \
        cg_inputs.f \
        rarr4.f \
        potextr.f pack.f smatchk2.f  gga_lib_3_PBE.f
####   omp_clock.f  ! without using nfort or nmpifort
