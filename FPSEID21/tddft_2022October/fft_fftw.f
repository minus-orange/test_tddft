      SUBROUTINE PREFFT_fftwASL(NRX,NRY,NRZ,rhog,plancfp,plancbp)
C***********************************************************
C     (FFT INIT)
C                 (2012-12-13) by courtesy of RIST:KOKUBO
C     INPUT :NR?
C     OUTPUT:plancfp,plancbp
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 rhog(*)
C
      include 'fftw3.f'
      integer CRITERIA, nfft(3),narray(3)
      integer*8 plancfp,plancbp
C
      integer nthrds,omp_get_num_threads
      integer iret
C
!$OMP PARALLEL
      nthrds=omp_get_num_threads()
!$OMP END PARALLEL
!!!! for fftw init !!!!
      call dfftw_init_threads(iret)
      if (iret.eq.0) then
        write(6,*) 'ERROR: dfftw_init_threads failed'
        stop
      endif
!     CRITERIA=FFTW_ESTIMATE
!     CRITERIA=FFTW_PATIENT
      CRITERIA=FFTW_MEASURE
      nfft(  1:3)=(/nrx,nry,nrz/)
      narray(1:3)=(/nrx,nry,nrz/)

      call dfftw_plan_with_nthreads(nthrds)
      call dfftw_plan_many_dft(plancfp,3,nfft,1,
     & rhog,narray,1,1,
     & rhog,narray,1,1,
     &                         FFTW_FORWARD,CRITERIA)
      call dfftw_plan_with_nthreads(nthrds)
      call dfftw_plan_many_dft(plancbp,3,nfft,1,
     & rhog,narray,1,1,
     & rhog,narray,1,1,
     &                         FFTW_BACKWARD,CRITERIA)
!!!! for fftw !!!!
C
      END
c
c    subroutine ENDFFT is dummy !!!
      SUBROUTINE ENDFFT_fftwASL(NRX,NRY,NRZ)
      IMPLICIT REAL*8 (A-H,O-Z)
C
c      integer fft
c      common/ASLFFTNEW/fft
c
      NXYZ=NRX*NRY*NRZ
c
      END
c
      SUBROUTINE FFT3BX_fftwASL(NRX,NRY,NRZ,NG,RHOG,WORK
     &  ,plancfp,plancbp)
C***********************************************************
C     (REAL SPACE-->G-SPACE)
C                 (2012-12-13) by courtesy of  RIST:KOKUBO
C     INPUT :RHO,NG,plancfp,plancbp
C     OUTPUT:RHOG
C
      IMPLICIT REAL*8 (A-H,O-Z)
c     dummy: WORK NRX, NRY, NRZ
      complex*16 WORK(NG)
c
      complex*16 RHOG(NG)
      integer*8 plancfp,plancbp
C
      call prof_start(14)
      call dfftw_execute_dft(plancbp,rhog,rhog)
      call prof_stop(14)
C
      END

C***********************************************************
      SUBROUTINE FFT3_LOCALPOT_fftwASL(NRX,NRY,NRZ,NG,NBLOCK,
     & RHO1,RHO2,VG,DT,plancfp,plancbp)
C***********************************************************
C     Local-potential FFT pair used by TDDFT S2_.
C     CPU/FFTW implementation preserves the previous per-band operation.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      complex*16 RHO1(NG,NBLOCK),RHO2(NG,NBLOCK)
      dimension VG(NG)
      integer*8 plancfp,plancbp
C
      DO IB=1,NBLOCK
        CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NG,RHO1(1,IB),RHO2(1,IB),
     &                      plancfp,plancbp)
      ENDDO
C
      DO IB=1,NBLOCK
!$omp parallel do default(shared) private(I,FAC)
        DO I=1,NG
          FAC=DT*DREAL(VG(I))
          RHO2(I,IB)=DCMPLX(DCOS(FAC),-DSIN(FAC))*RHO1(I,IB)
        ENDDO
      ENDDO
C
      DO IB=1,NBLOCK
        CALL FFT3FX_fftwASL(NRX,NRY,NRZ,NG,RHO2(1,IB),RHO1(1,IB),
     &                      plancfp,plancbp)
      ENDDO
C
      END

C***********************************************************
      SUBROUTINE FFT3FX_fftwASL(NRX,NRY,NRZ,NG,RHOG,WORK
     & ,plancfp,plancbp)
C***********************************************************
C     (G-SPACE -->REAL SPACE)
C                 (2012-12-13) by courtesy of  RIST:KOKUBO
C     INPUT :RHO,NG,plancfp,plancbp
C     OUTPUT:RHOG
C
      IMPLICIT REAL*8 (A-H,O-Z)
c     dummy : WORK NRX NRY NRZ
      complex*16 WORK(NG)
c
      complex*16 RHOG(NG)
      integer*8 plancfp,plancbp
C
      call prof_start(14)
      call dfftw_execute_dft(plancfp,rhog,rhog)
      call prof_stop(14)
C
      FAC=1.0D0/DBLE(NG)
!$omp parallel do default(shared) private(I)
      DO I=1,NG
        RHOG(I)= RHOG(I)*FAC
      ENDDO
C
      END
