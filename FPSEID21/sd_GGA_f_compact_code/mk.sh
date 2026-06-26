nfort -static  -traceback=verbose -mwork-vector-kind=none -fno-loop-interchange -minit-stack=zero  \
       	-o sd_exe  \
	eigsystm.F90 sd_main_df_SXACE_allct.f newfft.f orbanly_part_f.f \
        sd_inputs.f \
        rarr3.f \
        potextr.f sddiag3_f_YY.f pack.f ortho.f smatchk2.f  gga_lib_3_PBE.f
####   omp_clock.f  ! without using nfort or nmpifort
