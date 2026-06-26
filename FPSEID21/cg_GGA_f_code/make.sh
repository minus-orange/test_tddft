ifort -O3 -mcmodel=medium -qopenmp -traceback \
        -o cg_exe  \
        eigsystm.F90 cg_main_gga_df_omp_YY_allct.f dosgen.f newfft.f orbanly_part_f.f \
        cg_inputs3.f \
        rarr4.f \
        potextr.f pack.f smatchk2.f  gga_lib_3_PBE.f omp_clock.f bannerCG.f
