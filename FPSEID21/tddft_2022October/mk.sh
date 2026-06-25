mpinfort -O3 -report-format -static  -traceback=verbose -mwork-vector-kind=none \
       	-fno-loop-interchange -minit-stack=zero \
  -o tddft_exe  \
cpu_block.f  prof_timer.f lib4_ASL_2_check_Vext_SXACE.f \
rarr3.f tm_inputs.f  \
  rexgenDummy.f  dipole.f  orbanly_part_f.f  smatchk2.f  \
frprmn_tm12_check_Vext_Avec_v4.f pack.f tdep.f vpj_gen.f \
electf4_Vext_Avec.f  gga_lib_3_PBE.f pspw_tm11_Vext_Avec_v4_alloc.f tmevl10_Avec_v4.f bannerTDDFT.f \
 FFT_ASL_new.f -lasl_sequential
###omp_clock.f  \
###mpinfort -O3 -report-format -static -mno-vector-fma -traceback=verbose -mwork-vector-kind=none \
