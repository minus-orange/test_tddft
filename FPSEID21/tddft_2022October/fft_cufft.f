      SUBROUTINE PREFFT_fftwASL(NRX,NRY,NRZ,rhog,plancfp,plancbp)
C***********************************************************
C     cuFFT-backed replacement for the FFTW-compatible wrapper.
C     Host arrays are copied to/from the GPU inside each FFT call.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 rhog(*)
      integer*8 plancfp,plancbp
      integer ierr
C
      call fpseid_cufft_plan(plancfp,plancbp,NRX,NRY,NRZ,ierr)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: fpseid_cufft_plan failed, ierr=',ierr
        stop
      endif
C
      END

C***********************************************************
      SUBROUTINE FPSEID_ACC_BACKEND(IACC)
C     cuFFT identifies the validated OpenACC device execution backend.
      INTEGER IACC
      IACC=1
      RETURN
      END
c
      SUBROUTINE ENDFFT_fftwASL(NRX,NRY,NRZ)
      use mod_timer, only: print_timer
      IMPLICIT REAL*8 (A-H,O-Z)
      integer ierr
C
      call print_timer()
      call fpseid_cufft_destroy(ierr)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: fpseid_cufft_destroy failed, ierr=',ierr
        stop
      endif
C
      END
c
      SUBROUTINE FFT3BX_fftwASL(NRX,NRY,NRZ,NG,RHOG,WORK
     &  ,plancfp,plancbp)
      use mod_timer, only: start_timer, stop_timer
C***********************************************************
C     R-space -> G-space, matching the previous FFTW backward call.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 WORK(NG)
      complex*16 RHOG(NG)
      integer*8 plancfp,plancbp
      integer ierr
C
      call prof_start(14)
      call start_timer('cufft_fft3bx')
      call fpseid_cufft_exec(plancbp,RHOG,NG,1,ierr)
      call stop_timer('cufft_fft3bx')
      call prof_stop(14)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: fpseid_cufft_exec backward failed, ierr=',
     &             ierr
        stop
      endif
C
      END

C***********************************************************
      SUBROUTINE FFT3BX_fftwASL_ACC(NRX,NRY,NRZ,NG,RHOG,WORK
     &  ,plancfp,plancbp)
      use mod_timer, only: start_timer, stop_timer
C***********************************************************
C     Device-resident R-space -> G-space cuFFT path.
C     RHOG must already be present on the OpenACC device.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 WORK(NG)
      complex*16 RHOG(NG)
      integer*8 plancfp,plancbp
      integer ierr
C
      call prof_start(14)
      call start_timer('cufft_acc_fft3bx')
!$acc host_data use_device(RHOG)
      call fpseid_cufft_exec_device(plancbp,RHOG,NG,1,ierr)
!$acc end host_data
      call stop_timer('cufft_acc_fft3bx')
      call prof_stop(14)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: fpseid_cufft_exec_device backward failed,',
     &             ' ierr=',ierr
        stop
      endif
C
      END

C***********************************************************
      SUBROUTINE FFT3BX_fftwASL_ACC_BATCH(NRX,NRY,NRZ,NG,
     & NBATCH,RHOG,WORK,plancfp,plancbp)
      use mod_timer, only: start_timer, stop_timer
C***********************************************************
C     Batched device-resident R-space -> G-space cuFFT path.
C     All local bands must be contiguous and present on the device.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 WORK(NG,NBATCH)
      complex*16 RHOG(NG,NBATCH)
      integer*8 plancfp,plancbp
      integer ierr
C
      call prof_start(14)
      call start_timer('cufft_acc_fft3bx_batch')
!$acc host_data use_device(RHOG)
      call fpseid_cufft_exec_device_batch(RHOG,NG,NBATCH,1,ierr)
!$acc end host_data
      call stop_timer('cufft_acc_fft3bx_batch')
      call prof_stop(14)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: batched device backward FFT failed,',
     &             ' ierr=',ierr
        stop
      endif
C
      END

C***********************************************************
      SUBROUTINE FFT3FX_fftwASL_ACC(NRX,NRY,NRZ,NG,RHOG,WORK
     & ,plancfp,plancbp)
      use mod_timer, only: start_timer, stop_timer
C***********************************************************
C     Device-resident G-space -> R-space cuFFT path.
C     RHOG must already be present on the OpenACC device.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 WORK(NG)
      complex*16 RHOG(NG)
      integer*8 plancfp,plancbp
      integer ierr
C
      call prof_start(14)
      call start_timer('cufft_acc_fft3fx')
!$acc host_data use_device(RHOG)
      call fpseid_cufft_exec_device(plancfp,RHOG,NG,-1,ierr)
!$acc end host_data
      call stop_timer('cufft_acc_fft3fx')
      call prof_stop(14)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: fpseid_cufft_exec_device forward failed,',
     &             ' ierr=',ierr
        stop
      endif
C
      FAC=1.0D0/DBLE(NG)
!$acc parallel loop present(RHOG(1:NG))
      DO I=1,NG
        RHOG(I)= RHOG(I)*FAC
      ENDDO
C
      END

C***********************************************************
      SUBROUTINE FFT3FX_fftwASL_ACC_BATCH(NRX,NRY,NRZ,NG,
     & NBATCH,RHOG,WORK,plancfp,plancbp)
      use mod_timer, only: start_timer, stop_timer
C***********************************************************
C     Batched device-resident G-space -> R-space cuFFT path.
C     All local bands must be contiguous and present on the device.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 WORK(NG,NBATCH)
      complex*16 RHOG(NG,NBATCH)
      integer*8 plancfp,plancbp
      integer ierr
C
      call prof_start(14)
      call start_timer('cufft_acc_fft3fx_batch')
!$acc host_data use_device(RHOG)
      call fpseid_cufft_exec_device_batch(RHOG,NG,NBATCH,-1,ierr)
!$acc end host_data
      call stop_timer('cufft_acc_fft3fx_batch')
      call prof_stop(14)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: batched device forward FFT failed,',
     &             ' ierr=',ierr
        stop
      endif
C
      FAC=1.0D0/DBLE(NG)
!$acc parallel loop collapse(2) present(RHOG(1:NG,1:NBATCH))
      DO IB=1,NBATCH
        DO I=1,NG
          RHOG(I,IB)=RHOG(I,IB)*FAC
        ENDDO
      ENDDO
C
      END

C***********************************************************
      SUBROUTINE FFT3FX_fftwASL(NRX,NRY,NRZ,NG,RHOG,WORK
     & ,plancfp,plancbp)
      use mod_timer, only: start_timer, stop_timer
C***********************************************************
C     G-space -> R-space, matching the previous FFTW forward call.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 WORK(NG)
      complex*16 RHOG(NG)
      integer*8 plancfp,plancbp
      integer ierr
C
      call prof_start(14)
      call start_timer('cufft_fft3fx')
      call fpseid_cufft_exec(plancfp,RHOG,NG,-1,ierr)
      call stop_timer('cufft_fft3fx')
      call prof_stop(14)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: fpseid_cufft_exec forward failed, ierr=',
     &             ierr
        stop
      endif
C
      FAC=1.0D0/DBLE(NG)
!$omp parallel do default(shared) private(I)
      DO I=1,NG
        RHOG(I)= RHOG(I)*FAC
      ENDDO
C
      END
