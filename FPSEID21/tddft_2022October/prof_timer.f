      subroutine prof_init(rank)
      implicit real*8 (a-h,o-z)
      integer rank
      integer i
      real*8 pt,pt0
      integer pc,prank
      common /profdata/ pt(120),pt0(120),pc(120),prank
      prank=rank
      do 10 i=1,120
        pt(i)=0.0d0
        pt0(i)=0.0d0
        pc(i)=0
   10 continue
      return
      end

      subroutine prof_start(id)
      implicit real*8 (a-h,o-z)
      include 'mpif.h'
      integer id
      real*8 pt,pt0
      integer pc,prank
      common /profdata/ pt(120),pt0(120),pc(120),prank
      if (id.lt.1 .or. id.gt.120) return
      pt0(id)=MPI_Wtime()
      call fpseid_mod_timer_start(id)
      return
      end

      subroutine prof_stop(id)
      implicit real*8 (a-h,o-z)
      include 'mpif.h'
      integer id
      real*8 pt,pt0
      integer pc,prank
      common /profdata/ pt(120),pt0(120),pc(120),prank
      if (id.lt.1 .or. id.gt.120) return
      pt(id)=pt(id)+MPI_Wtime()-pt0(id)
      pc(id)=pc(id)+1
      call fpseid_mod_timer_stop(id)
      return
      end

      subroutine prof_report()
      implicit real*8 (a-h,o-z)
      include 'mpif.h'
      real*8 pt,pt0,psum,pmax
      integer pc,pcmax,prank
      character*24 name
      common /profdata/ pt(120),pt0(120),pc(120),prank
      dimension psum(120),pmax(120),pcmax(120)
      call MPI_Reduce(pt,psum,120,MPI_DOUBLE_PRECISION,MPI_SUM,0,
     &                MPI_COMM_WORLD,ierr)
      call MPI_Reduce(pt,pmax,120,MPI_DOUBLE_PRECISION,MPI_MAX,0,
     &                MPI_COMM_WORLD,ierr)
      call MPI_Reduce(pc,pcmax,120,MPI_INTEGER,MPI_MAX,0,
     &                MPI_COMM_WORLD,ierr)
      call MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)
      if (prank.ne.0) return
      write(6,*)
      write(6,*)'FPSEID_PROFILE_BEGIN'
      write(6,*)' id label                    count',
     &          '      max_rank_sec       avg_rank_sec'
      do 20 id=1,120
        if (pcmax(id).le.0) goto 20
        call prof_name(id,name)
        write(6,100)id,name,pcmax(id),pmax(id),psum(id)/dfloat(nproc)
   20 continue
      write(6,*)'FPSEID_PROFILE_END'
      write(6,*)
  100 format(1x,i3,1x,a24,1x,i10,2(1x,f18.6))
      return
      end

      subroutine prof_name(id,name)
      integer id
      character*24 name
      name='unknown'
      if (id.eq.1)  name='time_step_total'
      if (id.eq.2)  name='g_vector_update'
      if (id.eq.3)  name='ion_md'
      if (id.eq.4)  name='frprmn'
      if (id.eq.5)  name='electf_force'
      if (id.eq.6)  name='force_energy_update'
      if (id.eq.7)  name='prenon'
      if (id.eq.8)  name='tmevl_total'
      if (id.eq.9)  name='tmevl_exkin'
      if (id.eq.10) name='tmevl_s2'
      if (id.eq.11) name='s2_nonlocal'
      if (id.eq.12) name='s2_fft_local'
      if (id.eq.13) name='tmevl_expectation'
      if (id.eq.14) name='fft_wrapper'
      if (id.eq.15) name='startup_before_steps'
      if (id.eq.16) name='fft_plan_init'
      if (id.eq.17) name='s2_acc_update'
      if (id.eq.18) name='s2_acc_kernel'
      if (id.eq.19) name='s2_zero_rho2'
      if (id.eq.20) name='s2_scatter_p'
      if (id.eq.21) name='s2_vg_build'
      if (id.eq.22) name='s2_local_multiply'
      if (id.eq.23) name='s2_gather_p'
      if (id.eq.24) name='s2_copyout_p'
      if (id.eq.25) name='s2_nonlocal_make'
      if (id.eq.26) name='s2_nonlocal_gemm'
      if (id.eq.27) name='exnlp_gemm_data'
      if (id.eq.28) name='exnlp_gemm_dot'
      if (id.eq.29) name='exnlp_gemm_update'
      if (id.eq.30) name='exnlp_gemm_enter'
      if (id.eq.31) name='exnlp_gemm_zero'
      if (id.eq.32) name='exnlp_gemm_exit'
      if (id.eq.33) name='s2_p_enter'
      if (id.eq.34) name='s2_p_exit'
      if (id.eq.35) name='tmevl_p_enter'
      if (id.eq.36) name='tmevl_p_exit'
      if (id.eq.37) name='exkin_acc_kernel'
      if (id.eq.38) name='exnlp_work1_enter'
      if (id.eq.39) name='exnlp_meta_enter'
      if (id.eq.40) name='exnlp_ct1_create'
      if (id.eq.41) name='frprmn_rhoofk'
      if (id.eq.42) name='frprmn_sumchr'
      if (id.eq.43) name='frprmn_rhoget'
      if (id.eq.44) name='frprmn_coef_sync'
      if (id.eq.45) name='frprmn_coef_setup'
      if (id.eq.46) name='frprmn_gdump_prepare'
      if (id.eq.47) name='frprmn_part1to5'
      if (id.eq.48) name='frprmn_extau_prepare'
      if (id.eq.49) name='part1to5_getylm'
      if (id.eq.50) name='vpjgen_cpu_integral'
      if (id.eq.51) name='vpjgen_mpi_allreduce'
      if (id.eq.52) name='vpjgen_postreduce'
      if (id.eq.53) name='frprmn_vloc_prepare'
      if (id.eq.54) name='frprmn_vrho_mix'
      if (id.eq.55) name='frprmn_energy_diag'
      if (id.eq.56) name='frprmn_initial_density'
      if (id.eq.57) name='frprmn_iter_init'
      if (id.eq.58) name='frprmn_pre_tmevl'
      if (id.eq.59) name='frprmn_post_tmevl'
      if (id.eq.60) name='frprmn_density_init'
      if (id.eq.61) name='frprmn_exit_cleanup'
      if (id.eq.62) name='frprmn_vrho_vofrho'
      if (id.eq.63) name='frprmn_vrho_smooth_fft'
      if (id.eq.64) name='frprmn_vrho_mix_control'
      if (id.eq.65) name='frprmn_vloc_locpot'
      if (id.eq.66) name='frprmn_vloc_smooth_fft'
      if (id.eq.67) name='frprmn_vrho_seed_ctrl'
      if (id.eq.68) name='frprmn_vrho_predict_ctrl'
      if (id.eq.69) name='frprmn_vrho_correct_ctrl'
      if (id.eq.70) name='frprmn_vrho_interp'
      if (id.eq.71) name='frprmn_vrho_converge'
      if (id.eq.72) name='frprmn_vrho_coef_restore'
      if (id.eq.73) name='vpjgen_host_zero'
      if (id.eq.74) name='vpjgen_vpp2_zero'
      if (id.eq.75) name='vpjgen_acc_kernel_d2h'
      if (id.eq.76) name='vpjgen_acc_kernel_wait'
      if (id.eq.77) name='vpjgen_acc_d2h'
      if (id.eq.78) name='frprmn_energy_vg_build'
      if (id.eq.79) name='frprmn_energy_efield'
      if (id.eq.80) name='frprmn_energy_expect'
      if (id.eq.81) name='energy_diag_hlocal'
      if (id.eq.82) name='energy_diag_nonloc'
      if (id.eq.83) name='energy_diag_dot'
      if (id.eq.84) name='energy_diag_ee_comm'
      if (id.eq.85) name='energy_offdiag_total'
      if (id.eq.86) name='offdiag_hlocal'
      if (id.eq.87) name='offdiag_nonloc'
      if (id.eq.88) name='offdiag_dot'
      if (id.eq.89) name='offdiag_comm_copy'
      if (id.eq.90) name='offdiag_gather_output'
      if (id.eq.91) name='vofrho_xc'
      if (id.eq.92) name='vofrho_fft'
      if (id.eq.93) name='vofrho_hartree_zero'
      if (id.eq.94) name='vofrho_hartree_build'
      if (id.eq.95) name='vofrho_hartree_add'
      if (id.eq.96) name='g2vxc_derivative_setup'
      if (id.eq.97) name='g2vxc_derivative_fft'
      if (id.eq.98) name='g2vxc_exchange'
      if (id.eq.99) name='g2vxc_correlation'
      if (id.eq.100)name='g2vxc_assemble'
      if (id.eq.101)name='hlocal_zero'
      if (id.eq.102)name='hlocal_scatter'
      if (id.eq.103)name='hlocal_inverse_fft'
      if (id.eq.104)name='hlocal_vg_multiply'
      if (id.eq.105)name='hlocal_forward_fft'
      if (id.eq.106)name='hlocal_gather'
      if (id.eq.107)name='hlocal_acc_total'
      if (id.eq.108)name='nonloc_kinetic'
      if (id.eq.109)name='nonloc_ylm'
      if (id.eq.110)name='nonloc_seppot'
      if (id.eq.111)name='seppot_extau'
      if (id.eq.112)name='seppot_s'
      if (id.eq.113)name='seppot_p'
      if (id.eq.114)name='seppot_d'
      if (id.eq.115)name='seppot_f'
      return
      end
