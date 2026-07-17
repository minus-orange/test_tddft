      subroutine prof_init(rank)
      implicit real*8 (a-h,o-z)
      integer rank
      integer i
      real*8 pt,pt0
      integer pc,prank
      common /profdata/ pt(64),pt0(64),pc(64),prank
      prank=rank
      do 10 i=1,64
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
      common /profdata/ pt(64),pt0(64),pc(64),prank
      if (id.lt.1 .or. id.gt.64) return
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
      common /profdata/ pt(64),pt0(64),pc(64),prank
      if (id.lt.1 .or. id.gt.64) return
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
      common /profdata/ pt(64),pt0(64),pc(64),prank
      dimension psum(64),pmax(64),pcmax(64)
      call MPI_Reduce(pt,psum,64,MPI_DOUBLE_PRECISION,MPI_SUM,0,
     &                MPI_COMM_WORLD,ierr)
      call MPI_Reduce(pt,pmax,64,MPI_DOUBLE_PRECISION,MPI_MAX,0,
     &                MPI_COMM_WORLD,ierr)
      call MPI_Reduce(pc,pcmax,64,MPI_INTEGER,MPI_MAX,0,
     &                MPI_COMM_WORLD,ierr)
      call MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)
      if (prank.ne.0) return
      write(6,*)
      write(6,*)'FPSEID_PROFILE_BEGIN'
      write(6,*)' id label                    count',
     &          '      max_rank_sec       avg_rank_sec'
      do 20 id=1,64
        if (pcmax(id).le.0) goto 20
        call prof_name(id,name)
        write(6,100)id,name,pcmax(id),pmax(id),psum(id)/dfloat(nproc)
   20 continue
      write(6,*)'FPSEID_PROFILE_END'
      write(6,*)
  100 format(1x,i2,1x,a24,1x,i10,2(1x,f18.6))
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
      if (id.eq.45) name='electf_locpotf'
      if (id.eq.46) name='electf_nonlocf'
      if (id.eq.47) name='nonlocf_coef_kin_mpi'
      if (id.eq.48) name='nonlocf_projector_mpi'
      return
      end
