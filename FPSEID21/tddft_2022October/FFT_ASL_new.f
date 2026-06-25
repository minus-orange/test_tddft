      SUBROUTINE PREFFT_fftwASL(NRX,NRY,NRZ,rhog,plancfp,plancbp)
C***********************************************************
C     (FFT INIT)
C                (2005-04-13) ASL by courtesy of RIST:KOKUBO
C     INPUT :NR?
C     OUTPUT:WSAVE?,IFAC?
C
      use asl_unified
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 rhog(*)
c     dummy
      integer*8 plancfp,plancbp
C
      integer fft
      common/ASLFFTNEW/fft
C
c   ! Library Initialization
      call asl_library_initialize()
c   ! DFT Preparation
      call asl_fft_create_complex_3d_d(fft, nrx, nry, nrz)
      call asl_fft_set_spatial_stride_3d(fft, 1, nrx, nrx * nry)
      call asl_fft_set_frequency_stride_3d(fft, 1, nrx, nrx * nry)
c
      END
c      
      SUBROUTINE ENDFFT_fftwASL(NRX,NRY,NRZ)
      use asl_unified
      IMPLICIT REAL*8 (A-H,O-Z)
C
      integer fft
      common/ASLFFTNEW/fft
c         ! DFT Finalization
      call asl_fft_destroy(fft)
c   ! Library Finalization
      call asl_library_finalize()
c
      END
c
      SUBROUTINE FFT3BX_fftwASL(NRX,NRY,NRZ,NG,RHOG,WORK
     &  ,plancfp,plancbp)
      use asl_unified
C***********************************************************
C     (REAL SPACE-->G-SPACE)
C                (2005-04-13) ASL by courtesy of RIST: KOKUBO
C     INPUT :RHO,NR?,NG,WSAVE?,IFAC?
C     OUTPUT:RHOG
C     WORK  :WORK
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
c     dummy plancfp,plancbp
      integer*8 plancfp,plancbp
c
      integer fft
      common/ASLFFTNEW/fft
c
      complex*16 RHOG(NG),WORK(NG)
C
c
      call prof_start(14)
      call asl_fft_execute_complex_backward_d(fft,RHOG,WORK)
      call prof_stop(14)
      do ig=1,NG
       RHOG(IG)=WORK(IG)
      enddo
C
      END

C***********************************************************
      SUBROUTINE FFT3FX_fftwASL(NRX,NRY,NRZ,NG,RHOG,WORK
     & ,plancfp,plancbp)
      use asl_unified
C***********************************************************
C     (G-SPACE -->REAL SPACE)
C                (2005-04-13) ASL by courtesy of RIST: KOKUBO
C     INPUT :RHO,NR?,NG,WSAVE?,IFAC?
C     OUTPUT:WORK
C     WORK  :NONE
C  
      IMPLICIT REAL*8 (A-H,O-Z)
C     dummy plancfp,plancbp
      integer*8 plancfp,plancbp
c
      integer fft
      common/ASLFFTNEW/fft
c
      complex*16 RHOG(NG),WORK(NG)
C
c
      call prof_start(14)
      call asl_fft_execute_complex_forward_d(fft, rhog, work)
      call prof_stop(14)
C
      FAC=1.0D0/DBLE(NG)
      DO I=1,NG
        RHOG(I)= WORK(I)*FAC
      ENDDO
C
      END
