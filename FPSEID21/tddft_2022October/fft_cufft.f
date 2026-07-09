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
      SUBROUTINE FFT3_LOCALPOT_fftwASL(NRX,NRY,NRZ,NG,NBLOCK,
     & RHO1,RHO2,VG,DT,plancfp,plancbp)
C***********************************************************
C     cuFFT resident local-potential FFT pair used by TDDFT S2_.
C     RHO1/RHO2 are host arrays at the Fortran boundary, but the
C     backward FFT, local-potential multiply, forward FFT, and scaling
C     are performed on the GPU as one batch.
C
      use mod_timer, only: start_timer, stop_timer
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 RHO1(NG,NBLOCK),RHO2(NG,NBLOCK)
      dimension VG(NG)
      integer*8 plancfp,plancbp
      integer ierr
C
      call prof_start(14)
      call start_timer('cufft_localpot')
      call fpseid_cufft_localpot(plancfp,plancbp,RHO1,RHO2,VG,NG,
     &                           NBLOCK,DT,ierr)
      call stop_timer('cufft_localpot')
      call prof_stop(14)
      if (ierr.ne.0) then
        write(6,*) 'ERROR: fpseid_cufft_localpot failed, ierr=',ierr
        stop
      endif
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
