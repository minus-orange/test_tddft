ifort -O3 -mcmodel=medium -qopenmp \
        -o sd_exe  \
        eigsystm.F90 sd_main_df_SXACE_allct.f newfft.f orbanly_part_f.f \
        sd_inputs3.f \
        rarr3.f  bannerSD.f \
        potextr.f sddiag3_f_YY.f pack.f ortho.f smatchk2.f  gga_lib_3_PBE.f omp_clock.f 
