cC------------PROGRAM UNIT POTENTIAL AND CHARGE---------------------
C**************************************************************
      SUBROUTINE VOFRHO(NRX,NRY,NRZ,NXYZ,NG,NGQ,G,TPIBA,
     & VCLR,VCSR,VG,RHO,RHOG,I2G,
c *** for Sugino FFT
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2
c *** for Kokubo ASL FFT
c     & WSAVE_XYZ,IFAC_XYZ
c *** for Kokubo FFTW
     & plancfp,plancbp
     & ,DX,DY,DZ,DXX,DYY,DZZ,DXY,DYZ,DZX,VWORK)
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 RHO(NXYZ)
      COMPLEX*16 VCLR(NXYZ),VCSR(NXYZ),VG(NXYZ),RHOG(NXYZ)
c *** for Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c *** for Kokubo ASL FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c *** for Kokubo FFTW
      integer*8 plancfp,plancbp
c ****  for GGA ***
      COMPLEX*16 DX(NXYZ),DY(NXYZ),DZ(NXYZ),
     &   DXX(NXYZ),DYY(NXYZ),DZZ(NXYZ)
     &  ,DXY(NXYZ),DYZ(NXYZ),DZX(NXYZ),VWORK(NXYZ)
c *** for Sugino FFT
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo ASL FFT
c      DIMENSION IFAC_XYZ(60)
c *** for Kokubo FFTW -- nothing for IFAC 
c
      DIMENSION I2G(NGQ),G(4,NGQ)
      COMMON/SMOOTH/ADUMP
      COMMON/COMOPT/IOPT(10,5)
C
C     CALCULATE HARTREE AND EXCHANGE-CORRELATION POTENTIAL
C
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      TPIBA2=TPIBA**2
      IGGA = IOPT(8,2)
CC      CALL CLOCK(TIM0)
C
C     EXCHANGE CORRELATION CONTRIBUTION TO THE ONE-ELECTRON POTENTIAL
C
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(91)
#endif
      IF(IGGA.EQ.1) THEN
       CALL G2VXC2(TPIBA,NRX,NRY,NRZ,NXYZ,NG,NGQ,G,
     & VG,RHO,RHOG,I2G,
c *** for Sugino FFT
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,
c     & LY1,LY2,LZ1,LZ2
c *** for Kokubo ASL FFT
c     & WSAVE_XYZ,IFAC_XYZ
c *** for Kokubo FFTW
     & plancfp,plancbp
     & , DX,DY,DZ,DXX,DYY,DZZ,DXY,DYZ,DZX,VWORK )
      ELSE
      CALL S2VXC2(NXYZ,RHO,VG)
      ENDIF
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(91)
      call prof_start(92)
#endif
c ** for Sugino FFT
c      CALL FFT3FX(NRX,NRY,NRZ,NXYZ,VG,VCLR,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c ** for Kokubo ASL FFT
c      CALL FFT3FX_ASL(NRX,NRY,NRZ,NXYZ,VG,VCLR,WSAVE_XYZ,IFAC_XYZ)
c ** for Kokubo FFTW
c      call FFT3FX_fftw(NXYZ,VG,plancfp,plancbp)
c ** for Kokubo fftw ASL compatible
      CALL FFT3FX_fftwASL(NRX,NRY,NRZ,NXYZ,VG,VCLR,plancfp,plancbp)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(92)
      call prof_start(93)
#endif
C
C        HARTREE POTENTIAL
C
      DO 47 IG=1,NXYZ
   47 VCSR(IG)=(0.D0,0.D0)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(93)
      call prof_start(94)
#endif
C
*VDIR NODEP(VCSR,RHOG)
!ocl norecurrence(VCSR,RHOG)
      DO 49 IG=2,NG
      JG=I2G(IG)
   49 VCSR(JG)=0.5D0*FPI*RHOG(JG)/(TPIBA2*G(4,IG))
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(94)
      call prof_start(95)
#endif
      DO 48 IG=1,NXYZ
   48 VG(IG)=VG(IG)+VCSR(IG)*2.D0
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(95)
#endif
C
c *** Smoothing of potential
c      adump4=4*adump
c      do ig=2,nxyz
c      jg=i2g(ig)
c      vg(jg)=vg(jg)*dexp(-g(4,ig)/adump4)
c      enddo
c ***  temp check
c      miya=13
c      if ( miya.eq.13 ) then
c
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,VG,VCLR,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c      write(6,*)' After FFT3BX : VG in real space '
c      write(6,*)( vg(i),i=1,1500,100 )
c      stop
c      endif
c ***  temp check : end
CC      CALL CLOCK(TIM1)
C     WRITE(6,*) ' VOFRHO: CPTIME=',TIM1-TIM0
      RETURN
      END
C**************************************************
      SUBROUTINE S2VXC2(NXYZ,RHO,VCSR)
      IMPLICIT REAL*8(A-H,O-Z)
      COMPLEX*16 VCSR(NXYZ)
      DIMENSION RHO(NXYZ)
      DATA A0,A1,A2,A3,A4/0.4582D0,0.048D0,0.0311D0,0.0116D0,0.002D0/
      DATA B1,B2,B3/0.1423D0,1.0529D0,0.3334D0/
      DATA XB1,XALPHA/0.6108870577D0,0.7D0/
      PAI=4.D0*DATAN(1.D0)
      FPT=3.D0/(4.D0*PAI)
      DO 10 IG=1,NXYZ
      VCSR(IG)=0.D0
      IF(RHO(IG).GT.0.D0) THEN
      IF(RHO(IG).LE.FPT) THEN
         RS=(3.D0/(4.D0*PAI*RHO(IG)))**(1.D0/3.D0)
c         RS=DCBRT( 3.D0/(4.D0*PAI*RHO(IG)) )
         EC=-B1/(1.D0+B2*DSQRT(RS)+B3*RS)
         VX=-4.D0*A0/(3.D0*RS)
         CC=-B1/(1.D0+B2*DSQRT(RS)+B3*RS)
         VC= (CC*CC/(3.D0*B1))*(B2*DSQRT(RS)/2.D0+B3*RS)
         VXC2=VX+EC-VC
         VCSR(IG)=VXC2
      ELSE
         RS=(3.D0/(4.D0*PAI*RHO(IG)))**(1.D0/3.D0)
c         RS=DCBRT( 3.D0/(4.D0*PAI*RHO(IG)) )
         EC=-A1+A2*DLOG(RS)-A3*RS+A4*RS*DLOG(RS)
         VX=-4.D0*A0/(3.D0*RS)
         VC=A2/3.D0-A3*RS/3.D0+A4*(RS*DLOG(RS)+RS)/3.D0
         VXC2=VX+EC-VC
         VCSR(IG)=VXC2
      ENDIF
      ENDIF
   10 CONTINUE
      RETURN
      END
C************************************************************
      SUBROUTINE S2XC2(NXYZ,RHO,EXC,VCSR)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION RHO(NXYZ),VCSR(NXYZ)
      DATA A0,A1,A2,A3,A4/0.4582D0,0.048D0,0.0311D0,0.0116D0,0.002D0/
      DATA B1,B2,B3/0.1423D0,1.0529D0,0.3334D0/
      DATA XA1,XALPHA/0.4581652933D0,0.7D0/
C
      PAI=4.D0*DATAN(1.D0)
      FPT=3.D0/(4.D0*PAI)
      EXC=0.D0
      DO 10 IG=1,NXYZ
      VCSR(IG)=0.D0
      IF(RHO(IG).GT.0.D0) THEN
      IF(RHO(IG).LE.FPT) THEN
         RS=(3.D0/(4.D0*PAI*RHO(IG)))**(1.D0/3.D0)
c         RS=DCBRT( 3.D0/(4.D0*PAI*RHO(IG)) )
         EX=-A0/RS
         EC=-B1/(1.D0+B2*DSQRT(RS)+B3*RS)
         XC2=EC+EX
         VCSR(IG)=XC2*RHO(IG)
      ELSE
         RS=(3.D0/(4.D0*PAI*RHO(IG)))**(1.D0/3.D0)
c         RS=DCBRT( 3.D0/(4.D0*PAI*RHO(IG)) )
         EX=-A0/RS
         EC=-A1+A2*DLOG(RS)-A3*RS+A4*RS*DLOG(RS)
         XC2=EC+EX
         VCSR(IG)=XC2*RHO(IG)
      ENDIF
      ENDIF
   10 CONTINUE
      EXC=0.D0
      DO 20 IG=1,NXYZ
   20 EXC=EXC+VCSR(IG)
C
      RETURN
      END
C*****************************************************************
      SUBROUTINE RHOGET(NRX,NRY,NRZ,NXYZ,RHO,RHO1,RHOG,NTOT,S,OMEGA,
     & ZVAL,RHO2,I2G,G,
c *** for Sugino FFT
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2
c  ***** for Kokubo FFT: LY2,LZ1,LZ2 are still necessary for ROTRA
c     & WSAVE_XYZ,IFAC_XYZ , LY2,LZ1,LZ2
c  ***** for Kokubo FFTW: LY2,LZ1,LZ2 are still necessary for ROTRA
     & plancfp,plancbp, LY2,LZ1,LZ2
     & ,FDUMP,itstep,itmod)
C
C                                   (1990-04-12) OSAMU SUGINO
C                                   (1990-08-21) OSAMU SUGINO
C     CONSTRUCTS THE FULLY-SYMMETRIZED CHARGE DENSITY.
C     OUTPUT: RHO,RHOG
C     WORK  : RHO1
C     SLAVE SUBROUTINES   RHOTRA,FFT'S
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
      REAL*8 RHO(NXYZ)
      COMPLEX*16 RHO1(NXYZ),RHOG(NXYZ)
C *** for smoothing !
      complex*16 RHO2(NXYZ)
      dimension I2G(NXYZ),G(4,NXYZ)
      INTEGER*4 S(3,3,48)
C     WORK ARRAYS FOR FOURIER TRANSFORM
c *** for Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo FFT
c  ***** LY2,LZ1,LZ2 are still necessary for ROTRA
c      DIMENSION LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c      DIMENSION IFAC_XYZ(60)
c *** for Kokubo FFTW
c  ***** LY2,LZ1,LZ2 are still necessary for ROTRA
      DIMENSION LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      integer*8 plancfp,plancbp
      dimension fdump(NXYZ)
      COMMON/SMOOTH/ADUMP
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c ** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)'my_rank=',my_rank,' just in RHOGET'
c      stop
c      endif
c ** temp check : end
C
C     #############################################
C     SYMMETRIZE THE CHARGE DENSITY (IN REAL SPACE)
C     #############################################
c ****  check by Miyamoto  9/6  '95
c      write(6,*) ' in sub. RHOGET: before calling ROTRA '
c      SUM=0.D0
c      DO 151 I=1,NXYZ
c  151 SUM=SUM+RHO(I)
c      SUM=SUM*OMEGA/DBLE(NXYZ)
c      write(6,*)' Tota charge = ',sum,' Zval = ',zval    
c ****  check end
C
      CALL ROTRA(NRX,NRY,NRZ,NXYZ,RHO,RHO1,LY2,LZ1,LZ2,S,NTOT)
C
      SUM=0.D0
      DO 51 I=1,NXYZ
   51 SUM=SUM+RHO(I)
      SUM=SUM*OMEGA/DBLE(NXYZ)
C
C ********
      CHECK = ABS( ZVAL-SUM )
c      IF( CHECK .GT. 1.D-3) THEN
      IF( CHECK .GT. 5.D-2) THEN
       if ( my_rank.eq.0 ) then
         WRITE(6,*) ' '
         WRITE(6,*) '  **** RHOGET: INTEGRATED CHARGE  SUM ZVAL = ',
     &                   SUM, ZVAL
         STOP  ' INCORRECT TOTAL CHARGE '
       endif
      ELSE IF ( CHECK .GT. 1.D-7 .and. mod(itstep,itmod).eq.0 ) THEN
       if ( my_rank.eq.0 ) then
         WRITE(6,*) ' '
         WRITE(6,*) '  **** RHOGET: INTEGRATED CHARGE  SUM ZVAL = ',
     &                   SUM, ZVAL
         WRITE(6,*) ' '
       endif
      END IF
C
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)'my_rank=',my_rank,' finish to compute total RHO!' 
c      stop
c      endif
c *** temp check ; end
C *******
C
C     MAKE LIST VECTORS FOR FFT
C
c      if ( itstep.eq.0 ) then
c ** for Sugino FFT
c      CALL PREFFT(NRX,NRY,NRZ,NXYZ,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c ** for Kokubo ASL FFT
c      CALL PREFFT_ASL(NRX,NRY,NRZ,WSAVE_XYZ,IFAC_XYZ)
c ** for Kokubo FFTW
c      call PREFFT_fftw(NRX,NRY,NRZ,RHOG,plancfp,plancbp)
c ** for Kokubo fftw ASL compatible
c      CALL PREFFT_fftwASL(NRX,NRY,NRZ,RHOG,plancfp,plancbp)
c      endif
C
C        RHO IN K SPACE
C
      DO 551 IG=1,NXYZ
  551 RHOG(IG)=DCMPLX(RHO(IG),0.D0)
c *** for Sugino FFT
c      CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHOG,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo FFT
c      CALL FFT3FX_ASL(NRX,NRY,NRZ,NXYZ,RHOG,RHO1,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3FX_fftw(NXYZ,RHOG,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      CALL FFT3FX_fftwASL(NRX,NRY,NRZ,NXYZ,RHOG,RHO1,plancfp,plancbp)
c *** Smoothing !!
         adump4=4*adump
*VDIR NODEP(RHOG)
!ocl norecurrence(RHOG)
         do ig=1,nxyz
         jg=i2g(ig)
         rhog(jg)=rhog(jg)*fdump(ig)
         enddo
         DO IG=1,NXYZ
         RHO2(IG)=RHOG(IG)
         ENDDO
c *** for Sugino FFT
c         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
c     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
c *** for Kokubo ASL FFT
c         CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
c     &                WSAVE_XYZ, IFAC_XYZ               )
c *** for Kokubo FFTW
c         call FFT3BX_fftw(NXYZ,RHO2,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
         CALL FFT3BX_fftwASL( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
     &                plancfp,plancbp             )
         DO IG=1,NXYZ
         RHO(IG)=DBLE(RHO2(IG))
         ENDDO
c *** Smoothing !! : END 
c **** smear negative rho: for SXACE!!
      rhomin=1.d-12
      do ir=1,nxyz
       if (rho(ir).lt.rhomin ) rho(ir)=rhomin
      enddo
C
C
c   ****  temp check !1
c      SUM=0.D0
c      DO I=1,NXYZ
c      SUM=SUM+RHO(I)
c      ENDDO
c      SUM=SUM*OMEGA/DBLE(NXYZ)
C
C ********
c      CHECK = ABS( ZVAL-SUM )
c      IF( CHECK .GT. 1.D-3) THEN
c         WRITE(6,*) ' '
c         WRITE(6,*) '  **** RHOGET: INTEGRATED CHARGE  SUM ZVAL = ',
c     &                   SUM, ZVAL
c         STOP  ' INCORRECT TOTAL CHARGE '
c      ELSE IF ( CHECK .GT. 1.D-7) THEN
c         WRITE(6,*) ' '
c         WRITE(6,*) '  **** RHOGET: INTEGRATED CHARGE  SUM ZVAL = ',
c     &                   SUM, ZVAL
c         WRITE(6,*) ' '
c      END IF
C     WRITE(6,*) ' RHOG AND SUM',RHOG(1),SUM
C
      RETURN
      END
C***********************************************************
      SUBROUTINE ROTRA(NRX,NRY,NRZ,NXYZ,RHO,RHO1,LX,LY,LZ,S,NTOT)
C***********************************************************
C
C                                   (1990-04-12) OSAMU SUGINO
C
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 RHO(NXYZ),RHO1(NXYZ)
      INTEGER*4 S(3,3,48),LX(NXYZ),LY(NXYZ),LZ(NXYZ)
      IF(NTOT.EQ.1) THEN
         DO 52 I=1,NXYZ
   52    RHO(I)=RHO(I)
      ELSE
C
C
C        MAKE LIST VECTOR
C
         DO 100 II=1,NXYZ
         K=1+(II-1)/(NRX*NRY)
         I=II-(K-1)*NRX*NRY
         J=1+(I-1)/NRX
         I=I-(J-1)*NRX
         LX(II)=I-1
         LY(II)=J-1
         LZ(II)=K-1
         RHO1(II)=0.D0
  100    CONTINUE
C
         DO 10 IROT=1,NTOT
         DO 10 I=1,NXYZ
         IR1=S(1,1,IROT)*LX(I)*NRX/NRX
     &      +S(2,1,IROT)*LY(I)*NRX/NRY
     &      +S(3,1,IROT)*LZ(I)*NRX/NRZ
         IR2=S(1,2,IROT)*LX(I)*NRY/NRX
     &      +S(2,2,IROT)*LY(I)*NRY/NRY
     &      +S(3,2,IROT)*LZ(I)*NRY/NRZ
         IR3=S(1,3,IROT)*LX(I)*NRZ/NRX
     &      +S(2,3,IROT)*LY(I)*NRZ/NRY
     &      +S(3,3,IROT)*LZ(I)*NRZ/NRZ
         IC1=MOD(IR1,NRX)
         IF(IC1.GE.0) IC1=IC1+1
         IF(IC1.LT.0) IC1=IC1+1+NRX
         IC2=MOD(IR2,NRY)
         IF(IC2.GE.0) IC2=IC2+1
         IF(IC2.LT.0) IC2=IC2+1+NRY
         IC3=MOD(IR3,NRZ)
         IF(IC3.GE.0) IC3=IC3+1
         IF(IC3.LT.0) IC3=IC3+1+NRZ
         II=IC1+(IC2-1+(IC3-1)*NRY)*NRX
   10    RHO1(I)=RHO1(I)+RHO(II)
C
         FACTOR=1.D0/DBLE(NTOT)
         DO 51 I=1,NXYZ
   51    RHO(I)=RHO1(I)*FACTOR
      ENDIF
      RETURN
      END
C
C*****************************************************************
      SUBROUTINE LOCPOT(NXYZ,NG,NGQ,G,TPIBA,VG,EIGT,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,itstep
c
     & ,nbegint,nendt,ncpuq,ncpu )
C***********************************************************
C
C     CONSTRUCT LOCAL ONE-ELECTRON POTENTITL
C                                   (1990-08-21) OSAMU SUGINO
C               NUMERICAL POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
      REAL*8 G(4,NGQ)
      COMPLEX*16 VG(NXYZ),EIGT(NXYZ)
c      DIMENSION I2G(NGQ),VGA(NGQ)
      DIMENSION I2G(NGQ),VGA(NGQ,NTYQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
      DIMENSION ZV(NTYQ),RC0(NCRQ,NTYQ),COR(NCRQ,NTYQ),NUMC(NTYQ)
c      common/cputask2/nbegint(0:ncpuq),nendt(0:ncpuq),ncpu
      dimension nbegint(0:ncpuq),nendt(0:ncpuq)
      COMPLEX*16 VG_(NGQ),EIGTMP,VGVAL
CC      CALL CLOCK(TIM0)
! ==============================================================================
!     call ftrace_region_begin("reg001")
! ==============================================================================
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
      FPI=4.D0*PI
      REWIND 81
! ==============================================================================
!     call ftrace_region_end("reg001")
! ==============================================================================
C
! ==============================================================================
!     call ftrace_region_begin("reg002")
! ==============================================================================
      DO 81 IG=1,NXYZ
   81 VG(IG)=(0.D0,0.D0)
! ==============================================================================
!     call ftrace_region_end("reg002")
! ==============================================================================
C
      if ( my_rank.eq.0 .and. itstep.eq.0 ) then
       call clock (t0)
      endif
C
c *** temp check
c      if ( my_rank.eq.0 ) then
c        write(6,*)' in LOCPOT itstep=',itstep
c        do ITY=1,NTYPE
c        write(6,*)' VGA  ITY =',ITY 
c        write(6,'(4F22.16)')(VGA(IG,ITY),IG=1,NGQ,1000)
c        enddo
c      endif
c *** temp check: end
! ==============================================================================
!     call ftrace_region_begin("reg003")
! ==============================================================================
      DO IG=1,NGQ
      VG_(IG)=(0.D0,0.D0)
      ENDDO
#ifdef _OPENACC
c *** Preserve the original ITY/K order for the G=0 contribution.
      DO ITY=1,NTYPE
        NUM=ABS(NUMTY(ITY))
        DO K=1,NUM
          ITAU=NIDN(K,ITY)
          if ( ITAU.ge.nbegint(my_rank). and.
     &         ITAU.le.nendt(my_rank) ) then
            if ( K.eq.1 ) then
              VG(1)=VG(1)+NUM*VGA(1,ITY)
              VG_(1)=VG_(1)+NUM*VGA(1,ITY)
            endif
          endif
        ENDDO
      ENDDO
c *** One GPU thread owns one G vector.  Its ITY/K/IA accumulation order
c *** is identical to the original host loop; MPI remains on the host.
!$acc parallel loop gang vector
!$acc& copyin(G(1:4,1:NG),VGA(1:NG,1:NTYQ),
!$acc& TAU(1:3,1:NTAUQ),NUMTY(1:NTYQ),
!$acc& NIDN(1:NTAUQ,1:NTYQ),nbegint(0:ncpuq),
!$acc& nendt(0:ncpuq),ZV(1:NTYQ),RC0(1:NCRQ,1:NTYQ),
!$acc& COR(1:NCRQ,1:NTYQ),NUMC(1:NTYQ))
!$acc& copyout(VG_(2:NG))
!$acc& private(ITY,NUM,K,ITAU,IA,R02,Q,SUM,EIGTMP,VGVAL)
      DO IG=2,NG
        VGVAL=(0.D0,0.D0)
        DO ITY=1,NTYPE
          NUM=ABS(NUMTY(ITY))
          DO K=1,NUM
            ITAU=NIDN(K,ITY)
            if ( ITAU.ge.nbegint(my_rank). and.
     &           ITAU.le.nendt(my_rank) ) then
              Q=TPIBA2*G(4,IG)
              SUM=  G(1,IG)*TAU(1,ITAU)
     &             +G(2,IG)*TAU(2,ITAU)
     &             +G(3,IG)*TAU(3,ITAU)
              SUM=SUM*TPIBA
              EIGTMP=DCMPLX(COS(SUM),-SIN(SUM))
              VGVAL=VGVAL+EIGTMP*VGA(IG,ITY)
              DO IA=1,NUMC(ITY)
                R02=RC0(IA,ITY)**2
                VGVAL=VGVAL+ZV(ITY)*COR(IA,ITY)*FPI/Q
     &                       *EIGTMP*EXP(-0.25D0*Q*R02)
              ENDDO
            endif
          ENDDO
        ENDDO
        VG_(IG)=VGVAL
      ENDDO
#else
      DO 20 ITY=1,NTYPE
c      READ(81)  VGA
        NUM=ABS(NUMTY(ITY))
c        VG(1)=VG(1)+NUM*VGA(1)
c        VG(1)=VG(1)+NUM*VGA(1,ITY)
        DO 22 K=1,NUM
          ITAU=NIDN(K,ITY)
        if ( ITAU.ge.nbegint(my_rank). and.
     &       ITAU.le.nendt(my_rank) ) then
        if ( K.eq.1 ) then
        VG(1)=VG(1)+NUM*VGA(1,ITY)
        VG_(1)=VG_(1)+NUM*VGA(1,ITY)
        endif
c *** temp check
c         write(6,*)' my_rank=',my_rank,' ITAU=',ITAU
c *** temp check : end
*VDIR NODEP(VG)
!ocl norecurrence(VG)
          DO 80 IG=2,NG
!         JG=I2G(IG)
          Q=TPIBA2*G(4,IG)
          SUM=  G(1,IG)*TAU(1,ITAU) + G(2,IG)*TAU(2,ITAU)
     &        + G(3,IG)*TAU(3,ITAU)
          SUM=SUM*TPIBA
          EIGT(IG)=DCMPLX(COS(SUM),-SIN(SUM))
cc          VG(JG)=VG(JG)+EIGT(IG)*VGA(IG)
!         VG(JG)=VG(JG)+EIGT(IG)*VGA(IG,ITY)
          VG_(IG)=VG_(IG)+EIGT(IG)*VGA(IG,ITY)
C     IF(IG.EQ.2) WRITE(6,*) 'VGA(2)',VGA(2),EIGT(IG)
   80     CONTINUE
C
C
      DO 52 IA=1,NUMC(ITY)
      R02=RC0(IA,ITY)**2
*VDIR NODEP(VG)
!ocl norecurrence(VG)
      DO 82 IG=2,NG
!     JG=I2G(IG)
      Q=TPIBA2*G(4,IG)
!     VG(JG)=VG(JG)+ZV(ITY)*COR(IA,ITY)*FPI/Q
      VG_(IG)=VG_(IG)+ZV(ITY)*COR(IA,ITY)*FPI/Q
     &                 *EIGT(IG)*EXP(-0.25D0*Q*R02)
   82 CONTINUE
   52 CONTINUE
      endif  ! if ITAU is wihtin nbegint - nendt loop: end
   22   CONTINUE
   20 CONTINUE
#endif
      DO IG=2,NG
        JG=I2G(IG)
        VG(JG)=VG_(IG)
      ENDDO
! ==============================================================================
!     call ftrace_region_end("reg003")
! ==============================================================================
c
      if ( my_rank.eq.0 .and. itstep.eq.0 ) then
       call clock (t1)
       write(6,*)' in sub. LOCPOT:
     &       VG calculation took ',t1-t0,' sec '
      endif
c
c *** temp check
c         write(6,*)' my_rank=',my_rank,' VG sum end'
c *** temp check : end
C
c ***
      if ( itstep.eq.0 .and. my_rank.eq.0 ) call clock(t00)
c   *** Use EIGT as work area!
! ==============================================================================
!     call ftrace_region_begin("reg004")
! ==============================================================================
      do ig=1,nxyz
       EIGT(ig)=0.0d0
      enddo
! ==============================================================================
!     call ftrace_region_end("reg004")
! ==============================================================================
C
      miya=13
      if ( miya.eq.13 ) goto 1313 ! skip reduce and Bcast but do ALLReduce
c
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_begin("reg005")
! ==============================================================================
        call MPI_Reduce(VG,EIGT,nxyz,MPI_DOUBLE_COMPLEX
     &    ,MPI_SUM, 0,MPI_COMM_WORLD,ierr)
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_end("reg005")
! ==============================================================================
C
      if ( my_rank.eq.0 ) then
! ==============================================================================
!     call ftrace_region_begin("reg006")
! ==============================================================================
      DO 70 IG=1,NXYZ
c   70 VG(IG)=VG(IG)/OMEGA
   70 VG(IG)=EIGT(IG)/OMEGA
! ==============================================================================
!     call ftrace_region_end("reg006")
! ==============================================================================
      endif
C
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_begin("reg007")
! ==============================================================================
      call MPI_Bcast(VG ,nxyz,MPI_DOUBLE_COMPLEX,0,
     &        MPI_COMM_WORLD,ierr)
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_end("reg007")
! ==============================================================================
 1313 continue
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_begin("reg008")
! ==============================================================================
        call MPI_ALLReduce(VG,EIGT,nxyz,MPI_DOUBLE_COMPLEX
     &    ,MPI_SUM, MPI_COMM_WORLD,ierr)
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_end("reg008")
! ==============================================================================
C
! ==============================================================================
!     call ftrace_region_begin("reg009")
! ==============================================================================
      DO 71 IG=1,NXYZ
c   70 VG(IG)=VG(IG)/OMEGA
   71 VG(IG)=EIGT(IG)/OMEGA
! ==============================================================================
!     call ftrace_region_end("reg009")
! ==============================================================================
C
c ***
      if ( itstep.eq.0 .and. my_rank.eq.0 ) then
       call clock(t01)
       write(6,*)' in sub. LOCPOT:
     &      Reduce-Bcast took ',t01-t00,' sec'
      endif 
c *** temp check
c      if ( my_rank.eq.0 ) then
c      write(6,*)' VG check !!! '
c      write(6,1515)( VG(ig),ig=1,nxyz,100 )
c 1515 format(4f19.13)
c      endif
c *** temp check : end
CC      CALL CLOCK(TIM1)
C     WRITE(6,*) '  LOCPOT CPTIME:',TIM1-TIM0
      RETURN
      END
C------------PROGRAM UNIT FORCE-------------------------
C*
C**************************************************************
      SUBROUTINE EWALDY(TPIBA,OMEGA,EWA,NGQ,NG,G,EXPG,
     & FORCE,LATQ,EWVEC,NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,ZV,ZZ,
     & A1,A2,A3,B1,B2,B3,itstep
c
     &  ,nbegint,nendt,ncpuq,ncpu  ) ! note nbegintt nendtt in upper routine
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
      REAL*8 FORCE(3,NTAUQ),ZZ(NTAUQ)
      DIMENSION EWVEC(4,LATQ)
      DIMENSION G(4,NGQ),EXPG(NGQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     & ZV(NTYQ)
      REAL*8 A1(3),A2(3),A3(3),B1(3),B2(3),B3(3)
      REAL*8 FSUB(3),RP(3)
      integer status(MPI_STATUS_SIZE),tag
      common/tmod/itmod
c      common/cputask3/nbegint(0:ncpuq),nendt(0:ncpuq),ncpu
      dimension nbegint(0:ncpuq),nendt(0:ncpuq)
      data tag/21/
C
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
C
CC      CALL CLOCK(TIM0)
C
C     COMPUTE VARIOUS PARAMETERS
C
C *****  INPUT CARE
c             TOL=50.0D0
          TOL=140.0D0  ! for large aspect ratio
c          TOL=280.0D0  ! for large aspect ratio
C            EPS=0.0256D0*2.D0
             EPS=0.0256D0
C *****  INPUT END
      TPIBA2=TPIBA*TPIBA
      PI=4.D0*ATAN(1.D0)
      PI2=2.D0*PI
      SEPS=SQRT(EPS)
      SEPI=2.D0*SEPS/SQRT(PI)
      RMAX=SQRT(TOL/EPS)
      B11=0.D0
      B22=0.D0
      B33=0.D0
      DO 1500 I=1,3
        B11=B11+B1(I)*B1(I)
        B22=B22+B2(I)*B2(I)
        B33=B33+B3(I)*B3(I)
 1500 CONTINUE
      B11=B11*TPIBA2
      B22=B22*TPIBA2
      B33=B33*TPIBA2
      IMX=INT(RMAX*SQRT(B11)/PI2)+1
      JMX=INT(RMAX*SQRT(B22)/PI2)+1
      KMX=INT(RMAX*SQRT(B33)/PI2)+1
C
      if ( mod(itstep,itmod).eq.0 ) then
      if ( my_rank.eq.0 ) WRITE(6,6000) IMX,JMX,KMX
 6000 FORMAT(/10X,'  ** EWALDY: IMX JMX KMX = ',3I5)
      endif
C
      RMAX=RMAX*RMAX
      CALL AGEN(A1,A2,A3,IMX,JMX,KMX,NLV,LATQ,EWVEC,RMAX,itstep)
C
C     STORE DATA FOR ATOMS INTO NEW ARRAYS
C
      NATOT=0
      DO 1510 ITY=1,NTYPE
        NAT=ABS(NUMTY(ITY))
        DO 1511 ITA=1,NAT
          ITAU=NIDN(ITA,ITY)
          ZZ(ITAU)=ZV(ITY)
          NATOT=NATOT+1
 1511   CONTINUE
 1510 CONTINUE
      ESUMG=0.D0
      ESUMR=0.D0
      DO 1520 I=1,NATOT
        FORCE(1,I)=0.D0
        FORCE(2,I)=0.D0
        FORCE(3,I)=0.D0
 1520 CONTINUE
      DO 1521 I=1,NGQ
 1521 EXPG(I)=0.D0
C*****************************
C     START SUM IN G SPACE
C*****************************
C
C    DO G SUM FOR THE CASE WHERE A=B
C
      ESUM0=0.D0
      DO 1530 I=NG,2,-1
        Q=G(4,I)*TPIBA2
        EXPG(I)=EXP(-Q/(4.D0*EPS))/Q
        ESUM0=ESUM0+EXPG(I)
 1530 CONTINUE
      ESUM0=ESUM0-0.25D0/EPS
C
C     START LOOP OVER ATOMS IN CELL
C
      iseq=0
      DO 1540 I=1,NATOT
C
      iseq=iseq+1
c *****
      if ( iseq.ge.nbegint(my_rank) .and.
     &     iseq.le.nendt(my_rank) ) then
C     TERM WITH A=B
C
C     ADD TO SUMS (ENERGY)
C
        ESUMG=ESUMG+ZZ(I)*ZZ(I)*ESUM0
      endif
c *****
        IM=I-1
        IF(IM.NE.0) THEN
C
C    TERMS WITH A#B
C
          DO 1541 J=1,IM
           iseq=iseq+1
      if ( iseq.ge.nbegint(my_rank) .and.
     &     iseq.le.nendt(my_rank) ) then
C
C     R(X,Y,Z) IS THE VECTOR BETWEEN TWO ATOMS IN THE CELL
C
            RX=TAU(1,I)-TAU(1,J)
            RY=TAU(2,I)-TAU(2,J)
            RZ=TAU(3,I)-TAU(3,J)
C
C     LOOP OVER G VECTORS
C
            ESUB=0.D0
            DO 1542 K=1,3
              FSUB(K)=0.D0
 1542       CONTINUE
            DO 1543 IG=NG,2,-1
              GDT=G(1,IG)*RX+G(2,IG)*RY+G(3,IG)*RZ
              GDT=GDT*TPIBA
              EXP1=COS(GDT)*EXPG(IG)
              EXP2=SIN(GDT)*EXPG(IG)
              ESUB=ESUB+EXP1
              FSUB(1)=FSUB(1)+G(1,IG)*EXP2
              FSUB(2)=FSUB(2)+G(2,IG)*EXP2
              FSUB(3)=FSUB(3)+G(3,IG)*EXP2
 1543       CONTINUE
            ESUB=ESUB-0.25D0/EPS
C
C     ADD TO SUMS (ENERGY AND FORCE)
C
            ESUMG=ESUMG+2.D0*ZZ(I)*ZZ(J)*ESUB
            DO 1544 K=1,3
              FORCE(K,I)=FORCE(K,I)+ZZ(J)*FSUB(K)
              FORCE(K,J)=FORCE(K,J)-ZZ(I)*FSUB(K)
 1544       CONTINUE
        endif   ! iseq is within nbegint to nendt
 1541     CONTINUE
        ENDIF  ! IM.NE.0
ccc      endif  ! if i.ge.nbegint(my_rank) .and. i.le.nendt(my_rank)
 1540 CONTINUE
      ESUMG=PI2*ESUMG/OMEGA
      DO 1545 K=1,3
      DO 1545 I=1,NATOT
        FORCE(K,I)=4.D0*PI*ZZ(I)*TPIBA*FORCE(K,I)/OMEGA
 1545 CONTINUE
C
C****************************
C     END G SUM
C****************************
C
C****************************
C     START SUM IN R SPACE
C****************************
C
C     DO R SUM FOR THE CASE WHERE A=B
C
      ESUM0=0.D0
      DO 1600 I=2,NLV
        RMOD=SQRT(EWVEC(4,I))
        ARG=SEPS*RMOD
        IF(ARG.LE.25.D0) THEN
           EXP1=DERFC(ARG)/RMOD
           ESUM0=ESUM0+EXP1
        ENDIF
 1600 CONTINUE
      ESUM0=ESUM0-SEPI
C
C
C   START LOOP OVER ATOMS IN CELL
C
      iseq=0
      DO 1610 I=1,NATOT
      iseq=iseq+1
c ******
      if ( iseq.ge.nbegint(my_rank) .and.
     &     iseq.le.nendt(my_rank) ) then
C
C     TERM WITH A=B
C
        ESUMR=ESUMR+ZZ(I)*ZZ(I)*ESUM0
      endif
c ******
        IM=I-1
        IF(IM.NE.0) THEN
C
C     TERMS WITH A#B
C
          DO 1611 J=1,IM
          iseq=iseq+1
c ******
      if ( iseq.ge.nbegint(my_rank) .and.
     &     iseq.le.nendt(my_rank) ) then
C
C     LOOP OVER LATTICE POINTS
C
            ESUB=0.D0
            DO 1612 K=1,3
              FSUB(K)=0.D0
 1612       CONTINUE
            DO 1613 IL=1,NLV
              RP(1)=EWVEC(1,IL)-TAU(1,J)+TAU(1,I)
              RP(2)=EWVEC(2,IL)-TAU(2,J)+TAU(2,I)
              RP(3)=EWVEC(3,IL)-TAU(3,J)+TAU(3,I)
              RMOD=RP(1)*RP(1)+RP(2)*RP(2)+RP(3)*RP(3)
              RMOD=SQRT(RMOD)
              ARG=SEPS*RMOD
              IF(ARG.LE.25.D0) THEN
                EXP1=DERFC(ARG)/RMOD
                EXP2=(EXP1+SEPI*DEXP(-ARG*ARG))/(RMOD*RMOD)
                ESUB=ESUB+EXP1
                FSUB(1)=FSUB(1)+RP(1)*EXP2
                FSUB(2)=FSUB(2)+RP(2)*EXP2
                FSUB(3)=FSUB(3)+RP(3)*EXP2
              ENDIF
 1613       CONTINUE
C           ESUB=ESUB-PI/(EPS*OMEGA)
C
C     ADD TO SUMS (ENERGY AND FORCE)
C
            ESUMR=ESUMR+2.D0*ZZ(I)*ZZ(J)*ESUB
            DO 1616 K=1,3
              FORCE(K,I)=FORCE(K,I)+ZZ(I)*ZZ(J)*FSUB(K)
              FORCE(K,J)=FORCE(K,J)-ZZ(I)*ZZ(J)*FSUB(K)
C             WRITE(6,*) FORCE(K,I),FORCE(K,J)
 1616       CONTINUE
         endif  ! iseq is within nbegint to nendt
 1611     CONTINUE
        ENDIF ! IM.NE.0
c       endif  ! I is within nbegint(my_rank) and nendt(my_rank)
 1610 CONTINUE
      ESUMR=ESUMR*0.5D0
C
C*************************
C     END R SUM
C*************************
C
C     GENERATE - FORCE(;)
C
      DO 1700 K=1,3
      DO 1700 J=1,NATOT
        FORCE(K,J)=-FORCE(K,J)
 1700 CONTINUE
CC      CALL CLOCK(TIM2)
CC      WRITE(6,*) '  EWALD R ',ESUMR,TIM2-TIM1
CC        WRITE(6,*) '  EWALD R ',ESUMR
      EWA=ESUMG+ESUMR
      TEMP=0.d0
       call MPI_Reduce(EWA,TEMP,1,MPI_DOUBLE_PRECISION
     &    ,MPI_SUM, 0,MPI_COMM_WORLD,ierr)
      EWA=TEMP
      FSUB(1)=0.d0
      FSUB(2)=0.d0
      FSUB(3)=0.d0
      do it=1,natot
       call MPI_Reduce(FORCE(1,it),FSUB,3,MPI_DOUBLE_PRECISION
     &    ,MPI_SUM, 0,MPI_COMM_WORLD,ierr)
       FORCE(1,it)=FSUB(1)
       FORCE(2,it)=FSUB(2)
       FORCE(3,it)=FSUB(3)
      enddo
      call MPI_Bcast(FORCE,3*NATOT,MPI_DOUBLE_PRECISION,0,
     &        MPI_COMM_WORLD,ierr)
C     DO 17 I=1,NTAUQ
C  17 WRITE(6,*) (FORCE(J,I),J=1,3)
      RETURN
      END
C*
C*
      SUBROUTINE AGEN(B1,B2,B3,NRX,NRY,NRZ,NG,NGQ,G,GCUT,itstep)
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
      REAL*8 B1(3),B2(3),B3(3),T(4)
      DIMENSION G(4,NGQ)
      INTEGER TNRM1,TNRM2,TNRM3
      common/tmod/itmod
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c
      DO 5 J=1,4
    5 G(J,1)=0.D0
      NG=2
      IMAX=0
      JMAX=0
      KMAX=0
C *****
      TNRM1=2*NRX+1
      TNRM2=2*NRY+1
      TNRM3=2*NRZ+1
C *****
      DO 10 I1=1,TNRM1
      I=I1-NRX
      DO 10 J1=1,TNRM2
      J=J1-NRY
      DO 10 K1=1,TNRM3
      K=K1-NRZ
      G2=0.D0
      DO 15 IR=1,3
      T(IR)=DBLE(I)*B1(IR)+DBLE(J)*B2(IR)+DBLE(K)*B3(IR)
   15 G2=G2+T(IR)*T(IR)
      IF(G2.GT.GCUT) GO TO 10
      IF(G2.LT.1.D-8) GOTO 10
      IF(ABS(I).GT.IMAX) IMAX=ABS(I)
      IF(ABS(J).GT.JMAX) JMAX=ABS(J)
      IF(ABS(K).GT.KMAX) KMAX=ABS(K)
      DO 6 IR=1,3
    6 G(IR,NG)=T(IR)
      G(4,NG)=G2
      NG=NG+1
      IF(NG.GT.NGQ) GO TO 100
   10 CONTINUE
      NG=NG-1
      if ( mod(itstep,itmod).eq.0 ) then
      if ( my_rank.eq.0 ) then
      WRITE(6,130) GCUT,NG,NRX*NRY*NRZ*4.0*3.141593/3.0/8.0
  130 FORMAT(' GCUT=',F15.7,' NG=',I8,' NG EFFICIENT=',F15.7)
      WRITE(6,*) ' IMAX=',IMAX,' JMAX=',JMAX,' KMAX=',KMAX
      endif
      endif
      RETURN
  100 if ( my_rank.eq.0 ) WRITE(6,110) GCUT,NG
  110 FORMAT(' GCUT=',1PE12.4,' IS TOO BIG. STOPPING'/
     &       ' NGQ should be ',I9)
      STOP
      END
C*****************************************************************
C***********************************************************
      SUBROUTINE SYMFRC(S,NTOT,DFORCE,SFORCE,
     & NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,LATQ,RVEC, NLV )
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION H(3,3),BB(3,3),B2(3,3),RS(3,3,48)
      DIMENSION X(3),Y(3),RSINV(3,3,48),DUM1(3,3),DUM2(3,3)
      DIMENSION XX(3)
      COMMON/AVEC/A1(3),A2(3),A3(3),XB1(3),XB2(3),XB3(3),COVA,ALAT
      INTEGER*4 S(3,3,48)
      DIMENSION DFORCE(3,NTAUQ),SFORCE(3,NTAUQ),RVEC(4,LATQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
C
      IF(NTOT.EQ.1) THEN
        DO 5555 IO=1,NTAUQ
        DO 5555 JO=1,3
 5555   SFORCE(JO,IO)=DFORCE(JO,IO)
        RETURN
      ENDIF
      H(1,1)=A1(1)
      H(1,2)=A2(1)
      H(1,3)=A3(1)
      H(2,1)=A1(2)
      H(2,2)=A2(2)
      H(2,3)=A3(2)
      H(3,1)=A1(3)
      H(3,2)=A2(3)
      H(3,3)=A3(3)
C
      CALL INVMAT(H,BB)
      DO 1000 IROT=1,NTOT
        DO 1010 J=1,3
          DO 1020 K=1,3
            B2(J,K)=0.D0
            RS(J,K,IROT)=0.D0
 1020     CONTINUE
 1010   CONTINUE
C
        DO 1110 J=1,3
          DO 1120 K=1,3
            DO 1130 L=1,3
              B2(K,J)=S(L,K,IROT)*BB(L,J)+B2(K,J)
 1130       CONTINUE
 1120     CONTINUE
 1110   CONTINUE
C
        DO 1210 J=1,3
          DO 1220 K=1,3
            DO 1230 L=1,3
              RS(K,J,IROT)=RS(K,J,IROT)+H(K,L)*B2(L,J)
 1230       CONTINUE
 1220     CONTINUE
 1210   CONTINUE
C
        DO 1410 I=1,3
          DO 1420 J=1,3
            DUM1(I,J)=RS(I,J,IROT)
 1420     CONTINUE
 1410   CONTINUE
        CALL INVMAT(DUM1,DUM2)
        DO 1510 I=1,3
          DO 1520 J=1,3
            RSINV(I,J,IROT)=DUM2(I,J)
 1520     CONTINUE
 1510   CONTINUE
 1000 CONTINUE
CC
        DO 2000 I=1,NTYPE
          DO 2100 J=1,ABS(NUMTY(I))
            ITAU=NIDN(J,I)
            X(1)=TAU(1,ITAU)
            X(2)=TAU(2,ITAU)
            X(3)=TAU(3,ITAU)
            SFORCE(1,ITAU)=0.D0
            SFORCE(2,ITAU)=0.D0
            SFORCE(3,ITAU)=0.D0
            DO 2200 IROT=1,NTOT
              DO 2300 L=1,3
                XX(L)=0.D0
                DO 2400 M=1,3
                  XX(L)=XX(L)+RS(L,M,IROT)*X(M)
 2400           CONTINUE
 2300         CONTINUE
              IFLG=0
              DO 3000 I2=1,NTYPE
                DO 3100 J2=1,ABS(NUMTY(I2))
                  DO 3200 K=1, NLV
                    ITAU2=NIDN(J2,I2)
                    Y(1)=TAU(1,ITAU2)+RVEC(1,K)
                    Y(2)=TAU(2,ITAU2)+RVEC(2,K)
                    Y(3)=TAU(3,ITAU2)+RVEC(3,K)
                    ACHK=DABS(XX(1)-Y(1))+DABS(XX(2)-Y(2))
     &                   +DABS(XX(3)-Y(3))
                    IF(ACHK.LT.1.D-8)THEN
                      IFLG=1
                      DO 3600 L=1,3
                        DO 3700 M=1,3
                          SFORCE(L,ITAU)=SFORCE(L,ITAU)
     &                   +DFORCE(M,ITAU2)*RSINV(L,M,IROT)/NTOT
 3700                   CONTINUE
 3600                 CONTINUE
                    ENDIF
 3200             CONTINUE
 3100           CONTINUE
 3000         CONTINUE
              IF(IFLG.EQ.0)WRITE(6,*) ' WARNING !!! IN SYMFRC ITAU= '
     &       ,ITAU,' IROT=',IROT
 2200       CONTINUE
 2100     CONTINUE
 2000   CONTINUE
        RETURN
        END
C*******************************************************
      SUBROUTINE INVMAT(H,B)
      IMPLICIT REAL*8(A,B,D-H,O-Z)
      REAL*8 H(3,3),B(3,3)
C
      DET=H(1,1)*H(2,2)*H(3,3)+H(1,3)*H(2,1)*H(3,2)
     &   +H(1,2)*H(2,3)*H(3,1)
     &   -H(1,3)*H(2,2)*H(3,1)-H(1,2)*H(2,1)*H(3,3)
     &   -H(1,1)*H(2,3)*H(3,2)
C
      B(1,1)=       H(2,2)*H(3,3) - H(2,3)*H(3,2)
      B(2,1)=(-1)*( H(2,1)*H(3,3) - H(2,3)*H(3,1) )
      B(3,1)=       H(2,1)*H(3,2) - H(2,2)*H(3,1)
      B(1,2)=(-1)*( H(1,2)*H(3,3) - H(1,3)*H(3,2) )
      B(2,2)=       H(1,1)*H(3,3) - H(1,3)*H(3,1)
      B(3,2)=(-1)*( H(1,1)*H(3,2) - H(1,2)*H(3,1) )
      B(1,3)=       H(1,2)*H(2,3) - H(1,3)*H(2,2)
      B(2,3)=(-1)*( H(1,1)*H(2,3) - H(1,3)*H(2,1) )
      B(3,3)=       H(1,1)*H(2,2) - H(1,2)*H(2,1)
      IF(DET.EQ.0.D0) STOP ' INVMAT '
      DO 10 I=1,3
      DO 20 J=1,3
        B(I,J)=B(I,J)/DET
   20 CONTINUE
   10 CONTINUE
C
      RETURN
      END
C**************************************************************
      SUBROUTINE LOCPOTF(NXYZ,NG,NGQ,G,EXPG,EIGT,TPIBA,OMEGA,
     &  DELTA,DELTAd,VG,RHO,RHOG,I2G,FORCE,VGA,
     &  NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,ZZ, ZVAL,
     &  ESELF, EWA, ELOCAL, EXC, EH,ITSTEP
     & ,DRX,DRY,DRZ,DRXX,DRYY,DRZZ,DRXY,DRYZ,DRZX,VWORK
     & ,REXT,WEXT,ft,dft,NRX,NRY,NRZ
c *** for Sugino FFT
c     &                  ,WSAVEX,WSAVEY,WSAVEZ
c     &                  ,LX1,LX2,LY1
c     &                  ,LY2,LZ1,LZ2
c     &                  ,IFACX,IFACY,IFACZ)
c *** for Kokubo ASL FFT
c     &                  ,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
     &                  ,plancfp,plancbp
c
     &    ,nbegint,nendt,nbegintt,nendtt,ncpuq,ncpu )
C
C     CONSTRUCT LOCAL ONE-ELECTRON POTENTITL AND FORCE
C               NUMERICAL POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
c      PARAMETER(LATQ=15630, ncpuq=30)
      PARAMETER(LATQ=15630)
c      include 'ncpuq.h'
      REAL*8 G(4,NGQ),RHO(NXYZ),FORCE(3,NTAUQ),ZZ(NTAUQ)
      REAL*8 EXPG(NGQ)
      COMPLEX*16 EIGT(NXYZ),VG(NXYZ),RHOG(NXYZ),CI,CRG,CTEMP
c *** for GGA ***
      COMPLEX*16 DRX(NXYZ),DRY(NXYZ),DRZ(NXYZ)
     &          ,DRXX(NXYZ),DRYY(NXYZ),DRZZ(NXYZ)
     &          ,DRXY(NXYZ),DRYZ(NXYZ),DRZX(NXYZ),VWORK(NXYZ)
c      DIMENSION I2G(NGQ),VGA(NGQ)
      DIMENSION I2G(NGQ),VGA(NGQ,NTYQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
      COMMON/AVEC/A1(3),A2(3),A3(3),B1(3),B2(3),B3(3),COVA,ALAT
      COMMON/COMOPT/IOPT(10,5)
      DIMENSION EWVEC(4,LATQ)
      DIMENSION ZV(NTYQ),RC0(NCRQ,NTYQ),COR(NCRQ,NTYQ),NUMC(NTYQ)
C     DIMENSION AFORCE(3,16),BFORCE(3,16)
c *** for Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo ASL FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c      DIMENSION IFAC_XYZ(60)
c *** for Kokubo FFTW
      integer*8 plancfp,plancbp
c *** for extra charge
      complex*16 REXT(NXYZ),WEXT(NXYZ)
      integer tag,status(MPI_STATUS_SIZE)
c      common/cputask2/nbegint(0:ncpuq),nendt(0:ncpuq),ncpu
      dimension nbegint(0:ncpuq),nendt(0:ncpuq)
      dimension nbegintt(0:ncpuq),nendtt(0:ncpuq)
      data tag/21/
      COMPLEX*16 VG_(NGQ), WEXT_(NGQ)
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c ** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in LOCPOT '
c       write(6,*)' nbegint nendt '
c       do icpu=1,ncpuq
c        write(6,*) nbegint(icpu),nendt(icpu)
c       enddo
c       write(6,*)' nbegintt nendtt '
c       do icpu=1,ncpuq
c        write(6,*) nbegintt(icpu),nendtt(icpu)
c       enddo
c      endif
c ** temp check : end
c
      CI=(0.D0,1.D0)
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      TPIBA2=TPIBA**2
      IGGA = IOPT(8,2)
c *** temp check
c      write(6,*)' in sub. LOCPOTF   RHOG !! '
c      write(6,*)( RHOG(IG),IG=1,1500,100 )
c *** temp check : end
C
c *** temp check
c      if ( my_rank.eq.0 ) then
c       write(6,*)' In LOCPOTF itstep=',itstep
c       do ity=1,ntype
c        write(6,*)'TAU  ity = ',ity
c        NUM=ABS(NUMTY(ITY))
c        do K=1,NUM
c         ITAU=NIDN(K,ITY)
c         write(6,'(3F22.16)')(TAU(jj,itau),jj=1,3)
c        enddo
c       enddo
c      endif
c *** temp check end
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' In LOCPOTF itstep=',itstep
c       do ity=1,NTYPE
c        write(6,*)' ity =',ity
c        write(6,*)' ZV =',ZV(ity),' RC0 =',RC0(1,ity),RC0(2,ity)
c        write(6,*)' COR =',COR(1,ity),COR(2,ity)
c       enddo
c      endif
c *** temp check end
c *** temp check
c      if ( my_rank.eq.0 ) then
c        write(6,*)' in LOCPOTF itstep=',itstep
c        do ITY=1,NTYPE
c        write(6,*)' VGA  ITY =',ITY
c        write(6,'(4F22.16)')(VGA(IG,ITY),IG=1,NGQ,1000)
c        enddo
c      endif
c *** temp check: end
c *** temp check
c      if ( my_rank.eq.0 ) then
c      write(6,*)' ELOCAL= ',ELOCAL
c      write(6,*)' ELOCALd= ',ELOCALd
C        HARTREE ENERGY
C
c      EH=0.D0
c      EHd=0.D0
c*VDIR NODEP(WEXT,REXT)
c!ocl norecurrence(WEXT,REXT)
c      DO IG=2,NG
c      JG=I2G(IG)
c       EHd=EHd
c     & +FPI*DBLE(WEXT(JG)*dft*Rext(JG))/(TPIBA2*G(4,IG))
c      EH=EH+0.5D0*FPI*DBLE(DCONJG(WEXT(JG))*WEXT(JG))/(TPIBA2*G(4,IG))
c      enddo
c      write(6,*)' Before SELF ENERGY : EH=',EH
c      endif
c *** temp check ; end
C
C       SELF-ENERGY
C
      ESUM=0.D0
      ZSUM=0.D0
      DO 30 ITAU=1,NTYPE
      UM=DBLE(ABS(NUMTY(ITAU)))
      ZSUM=ZSUM+ZV(ITAU)*UM
      NN=NUMC(ITAU)
      VAL=0.D0
      DO 32 IA=1,NN
   32 VAL=VAL+COR(IA,ITAU)*RC0(IA,ITAU)**2
   30 ESUM=ESUM+VAL*UM*ZV(ITAU)
C ******     3/4/93... FIX BUG: FROM ZSUM TO - ZVAL
          ESELF = -PI*ZVAL/OMEGA*ESUM
C ******
C
      DO 1500 I=1,NTAUQ
      FORCE(1,I)=0.D0
      FORCE(2,I)=0.D0
      FORCE(3,I)=0.D0
 1500 CONTINUE
C
c *** temp check
c      if ( my_rank.eq.0 ) then
c      write(6,*)' ELOCAL= ',ELOCAL
c      write(6,*)' ELOCALd= ',ELOCALd
cC        HARTREE ENERGY
cC
c      EH=0.D0
c      EHd=0.D0
c*VDIR NODEP(WEXT,REXT)
c!ocl norecurrence(WEXT,REXT)
c      DO IG=2,NG
c      JG=I2G(IG)
c       EHd=EHd
c     & +FPI*DBLE(WEXT(JG)*dft*Rext(JG))/(TPIBA2*G(4,IG))
c      EH=EH+0.5D0*FPI*DBLE(DCONJG(WEXT(JG))*WEXT(JG))/(TPIBA2*G(4,IG))
c      enddo
c      write(6,*)' Before EWALDY : EH=',EH
c      endif
c *** temp check ; end
C
C       EWALD SUM
C
      CALL EWALDY(TPIBA,OMEGA,EWA,NGQ,NG,G,EXPG,FORCE,LATQ,EWVEC,
     &           NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,ZV,ZZ,
     &           A1,A2,A3,B1,B2,B3,itstep
c
     &          ,nbegintt,nendtt,ncpuq,ncpu )
C *****   EWALD END
C     WRITE(6,6002)
C6002 FORMAT(15X,'  ****  FORCE EWALD PARTS: NEGATIVE')
C     DO 9030 ITAU=1,NTAUQ
C9030 WRITE(6,'(23X,3F14.6)') (FORCE(I,ITAU),I=1,3)
C
c *** temp check
      if ( my_rank.eq.0.and.itstep.eq.0 ) then
      write(6,*)' ELOCAL= ',ELOCAL
      write(6,*)' ELOCALd= ',ELOCALd
C        HARTREE ENERGY
C
      EH=0.D0
      EHd=0.D0
*VDIR NODEP(WEXT,REXT)
!ocl norecurrence(WEXT,REXT)
      DO IG=2,NG
      JG=I2G(IG)
       EHd=EHd
     & +FPI*DBLE(WEXT(JG)*dft*Rext(JG))/(TPIBA2*G(4,IG))
      EH=EH+0.5D0*FPI*DBLE(DCONJG(WEXT(JG))*WEXT(JG))/(TPIBA2*G(4,IG))
      enddo
      write(6,*)' Before ELOCAL : EH=',EH
      endif
c *** temp check ; end
C
C
C LOCAL POTENTITAL
C
C
      do IG=1,NXYZ
c       WEXT(IG)=DCONJG( RHOG(IG)+REXT(IG) )
       WEXT(IG)=DCONJG( RHOG(IG)+ft*REXT(IG) )
      enddo
c
      DO 25 IG=1,NXYZ
      EIGT(IG)=(0.D0,0.D0)
   25 VG(IG)=(0.D0,0.D0)
C
      ENERGY1=0.D0
      ENERGY2=0.D0
      REWIND 81
      DO IG=1,NG
        JG=I2G(IG)
        VG_(IG)=(0.D0,0.D0)
        WEXT_(IG) = WEXT(JG)
      ENDDO
      DO 20 ITY=1,NTYPE
cc      READ(81) VGA
      NUM=ABS(NUMTY(ITY))
c      VG(1)=VG(1)+VGA(1)*NUM/OMEGA
c      VG(1)=VG(1)+VGA(1,ITY)*NUM/OMEGA
      DO 22 K=1,NUM
      ITAU=NIDN(K,ITY)
      if ( ITAU.ge.nbegint(my_rank) .and.
     &     ITAU.le.nendt(my_rank) ) then
      if (K.eq.1 ) then
      VG(1)=VG(1)+VGA(1,ITY)*NUM/OMEGA
      VG_(1)=VG_(1)+VGA(1,ITY)*NUM/OMEGA
      endif
*VDIR NODEP(VG,WEXT)
!ocl norecurrence(VG,WEXT)
      DO 80 IG=2,NG
!     JG=I2G(IG)
      Q=TPIBA2*G(4,IG)
      SUM=  G(1,IG)*TAU(1,ITAU) + G(2,IG)*TAU(2,ITAU)
     &    + G(3,IG)*TAU(3,ITAU)
      SUM=SUM*TPIBA
      EIGT(IG)=DCMPLX(COS(SUM),-SIN(SUM))
c      CTEMP=VGA(IG)*EIGT(IG)/OMEGA
      CTEMP=VGA(IG,ITY)*EIGT(IG)/OMEGA
!     VG(JG)=VG(JG)+CTEMP
      VG_(IG)=VG_(IG)+CTEMP
      C1=G(1,IG)*TPIBA*OMEGA
      C2=G(2,IG)*TPIBA*OMEGA
      C3=G(3,IG)*TPIBA*OMEGA
c      CRG=DCONJG(RHOG(JG))
!     CRG=WEXT(JG)
      CRG=WEXT_(IG)
      ENERGY1=ENERGY1+DBLE(CRG*CTEMP)
C     AFORCE(1,ITAU)=AFORCE(1,ITAU)+DBLE(-CI*CTEMP*C1*CRG)
C     AFORCE(2,ITAU)=AFORCE(2,ITAU)+DBLE(-CI*CTEMP*C2*CRG)
C     AFORCE(3,ITAU)=AFORCE(3,ITAU)+DBLE(-CI*CTEMP*C3*CRG)
      FORCE(1,ITAU)=FORCE(1,ITAU)+DBLE(-CI*CTEMP*C1*CRG)
      FORCE(2,ITAU)=FORCE(2,ITAU)+DBLE(-CI*CTEMP*C2*CRG)
      FORCE(3,ITAU)=FORCE(3,ITAU)+DBLE(-CI*CTEMP*C3*CRG)
   80 CONTINUE
c *** temp check
c      if (my_rank.eq.1 ) then
c       write(6,*)' in LOCPOTF after DO 80 ity= ',ity
c       write(6,*)' VGA '
c       write(6,'(4F22.16)')( VGA(IG,ITY),IG=1,NXYZ,1000)
c       write(6,*)' EIGT '
c       write(6,'(4F22.16)')( EIGT(IG),IG=1,NXYZ,1000)
c       write(6,*)' VG_ '
c       write(6,'(4F22.16)')( VG_(IG),IG=1,NXYZ,1000)
c      endif
c *** temp check: end
C              LONG RANGE PART
      DO 52 IA=1,NUMC(ITY)
      R02=RC0(IA,ITY)**2
*VDIR NODEP(VG,WEXT)
!ocl norecurrence(VG,WEXT)
      DO 82 IG=2,NG
!     JG=I2G(IG)
      Q=TPIBA2*G(4,IG)
      AA=ZV(ITY)*COR(IA,ITY)*FPI/Q*EXP(-0.25D0*Q*R02)/OMEGA
!     VG(JG)=VG(JG)+EIGT(IG)*AA
      VG_(IG)=VG_(IG)+EIGT(IG)*AA
      C1=AA*G(1,IG)*TPIBA*OMEGA
      C2=AA*G(2,IG)*TPIBA*OMEGA
      C3=AA*G(3,IG)*TPIBA*OMEGA
c      CRG=DCONJG(RHOG(JG))
!     CRG=WEXT(JG)
      CRG=WEXT_(IG)
      ENERGY2=ENERGY2+DBLE(EIGT(IG)*AA*CRG)
C     BFORCE(1,ITAU)=BFORCE(1,ITAU)+DBLE(-CI*EIGT(IG)*C1*CRG)
C     BFORCE(2,ITAU)=BFORCE(2,ITAU)+DBLE(-CI*EIGT(IG)*C2*CRG)
C     BFORCE(3,ITAU)=BFORCE(3,ITAU)+DBLE(-CI*EIGT(IG)*C3*CRG)
      FORCE(1,ITAU)=FORCE(1,ITAU)+DBLE(-CI*EIGT(IG)*C1*CRG)
      FORCE(2,ITAU)=FORCE(2,ITAU)+DBLE(-CI*EIGT(IG)*C2*CRG)
      FORCE(3,ITAU)=FORCE(3,ITAU)+DBLE(-CI*EIGT(IG)*C3*CRG)
   82 CONTINUE
   52 CONTINUE
c *** temp check
c      if (my_rank.eq.1 ) then
c       write(6,*)' in LOCPOTF after DO 52 ITY= ',ity
c       write(6,*)' AA = ',AA
c       write(6,*)'  EIGT '
c       write(6,'(4F22.16)')( EIGT(IG),IG=1,NXYZ,1000)
c       write(6,*)'  VG_ '
c       write(6,'(4F22.16)')( VG_(IG),IG=1,NXYZ,1000)
c      endif
c *** temp check: end
C
      endif  ! if ITAU.ge.nbegint and lt nendt loop: end
   22 CONTINUE
   20 CONTINUE
      DO IG=2,NG
        JG=I2G(IG)
        VG(JG)=VG_(IG)
      ENDDO
c *****
      do ig=1,nxyz
       EIGT(ig)=0.d0
      enddo
        call MPI_Reduce(VG,EIGT,nxyz,MPI_DOUBLE_COMPLEX
     &    ,MPI_SUM, 0,MPI_COMM_WORLD,ierr)
C
c*****************************
C
           if ( my_rank.ne.0 ) then
            ntleng=nendt(my_rank)-nbegint(my_rank)+1
            if ( ntleng.gt.0) then
            call MPI_Send(FORCE(1,nbegint(my_rank)),3*ntleng,
     &        MPI_DOUBLE_PRECISION,0,tag,MPI_COMM_WORLD,ierr)
            endif
           else
            do icpu=1,ncpu
            ntleng=nendt(icpu)-nbegint(icpu)+1
            if ( ntleng.gt.0) then
            call MPI_Recv(FORCE(1,nbegint(icpu)),3*ntleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag,MPI_COMM_WORLD,status,ierr)
            endif
            enddo
           endif ! end of if my_rank.ne.0 loop
c
C * TEMP
C     WRITE(6,6004)
C6004 FORMAT(15X,'  ****  FORCE LOCAL PARTS: NEGATIVE ')
C     DO 9031 ITAU=1,NTAUQ
C9031 WRITE(6,'(23X,3F14.6)') (FORCE(I,ITAU),I=1,3)
C
c *** temp check
      miya=13
      if ( miya.eq.13 .and.my_rank.eq.0.and.itstep.eq.0 ) then
       write(6,*)'just before do 6351 '
ccc       write(6,*)'plot EIGT!'
ccc       write(6,7979)(EIGT(IG),IG=1,NXYZ,NXYZ)
       write(6,*)'plot REXT!'
       write(6,7979)(REXT(IG),IG=1,NXYZ,NXYZ)
ccc       write(6,*)'plot WEXT!'
ccc       write(6,7979)(WEXT(IG),IG=1,NXYZ,NXYZ)
      endif
 7979 format(4f22.16)
c *** temp check : end
      ELOCAL=0.D0
      ELOCALd=0.D0
      DO 6351 IG=1,NXYZ
c 6351 ELOCAL=ELOCAL+DBLE(DCONJG(VG(IG))*RHOG(IG))
c 6351 ELOCAL=ELOCAL+DBLE(DCONJG(EIGT(IG))*RHOG(IG))
      ELOCALd=ELOCALd+DBLE(DCONJG(EIGT(IG))*dft*REXT(IG))
 6351 ELOCAL=ELOCAL+DBLE(EIGT(IG)*WEXT(IG))
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in LOCPOTF after DO 6351 '
c       write(6,*)'  EIGT '
c       write(6,'(4F22.16)')(EIGT(IG),IG=1,NXYZ,1000)
c       write(6,*)'  WEXT '
c       write(6,'(4F22.16)')(WEXT(IG),IG=1,NXYZ,1000)
c      endif
c *** temp check :end
      ELOCAL=OMEGA*ELOCAL
      ELOCALd=OMEGA*ELOCALd
C
c *** temp check
c      if ( my_rank.eq.0 ) then
c      write(6,*)' ELOCAL= ',ELOCAL
c      write(6,*)' ELOCALd= ',ELOCALd
cC        HARTREE ENERGY
cC
c      EH=0.D0
c      EHd=0.D0
c*VDIR NODEP(WEXT,REXT)
ccccc!ocl norecurrence(WEXT,REXT)
c      DO IG=2,NG
c      JG=I2G(IG)
c       EHd=EHd
c     & +FPI*DBLE(WEXT(JG)*dft*Rext(JG))/(TPIBA2*G(4,IG))
c      EH=EH+0.5D0*FPI*DBLE(DCONJG(WEXT(JG))*WEXT(JG))/(TPIBA2*G(4,IG))
c      enddo
c      write(6,*)' Before calling S2XC2 : EH=',EH 
c      endif
c *** temp check ; end
C         EXCHANGE CORRELATION PART
      IF(IGGA.EQ.1) THEN
c *** temp check
c       write(6,*)' GGA is selected!' 
c *** temp check: end
       CALL G2XC2(TPIBA, NRX,NRY,NRZ,NXYZ,NG,NGQ,G,
     & RHO,RHOG,I2G,
c *** for Sugino FFT
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,
c     & LY1,LY2,LZ1,LZ2,EXC,VG,DRX,DRY,DRZ,
c *** for Kokubo ASL FFT
c     & WSAVE_XYZ,IFAC_XYZ,EXC,VG,DRX,DRY,DRZ,
c *** for Kokubo FFTW
     & plancfp,plancbp,EXC,VG,DRX,DRY,DRZ,
     & DRXX,DRYY,DRZZ,DRXY,DRYZ,DRZX,VWORK)
      ELSE
c *** temp check
c       write(6,*)' LDA is selected!' 
c *** temp check: end
      CALL S2XC2(NXYZ,RHO,EXC,VG)
      ENDIF
      EXC = OMEGA*EXC/DBLE(NXYZ)
C
C      CALL S2VXC2(NXYZ,RHO,VG)
C      EVXC=0.D0
C      DO 651 I=1,NXYZ
C        EVXC=EVXC+VG(I)*RHO(I)
C  651 CONTINUE
C      EVXC=EVXC*OMEGA/DBLE(NXYZ)
C     WRITE(6,*) ' EVXC=',EVXC
C
C        HARTREE ENERGY
C
      EH=0.D0
      EHd=0.D0
*VDIR NODEP(WEXT,REXT)
cccc!ocl norecurrence(WEXT,REXT)
!$omp parallel default(shared)
!$omp do private(JG),reduction(+:EH),reduction(+:EHd)
      DO 652 IG=2,NG
      JG=I2G(IG)
c  652 EH=EH+0.5D0*FPI*DBLE(DCONJG(RHOG(JG))*RHOG(JG))/(TPIBA2*G(4,IG))
       EHd=EHd
     & +FPI*DBLE(WEXT(JG)*dft*Rext(JG))/(TPIBA2*G(4,IG))
  652 EH=EH+0.5D0*FPI*DBLE(DCONJG(WEXT(JG))*WEXT(JG))/(TPIBA2*G(4,IG))
!$omp enddo
!$omp end parallel
      EH=OMEGA*EH
      EHd=OMEGA*EHd
c *** temp check
      if ( my_rank.eq.0.and.itstep.eq.0 ) then
       write(6,*)' after DO 652  EH = ',EH
      endif
c *** temp check : end
C
C
      DELTAd=EHd+ELOCALd
      DELTA=EWA+EH+ELOCAL+EXC+ESELF
C
      RETURN
      END
C
C***********************************************************
C     SUBROUTINE CHKGRP(S,NTOT,
C    & NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,LATQ,RVEC, NLV)
C     IMPLICIT REAL*8 (A-H,O-Z)
C     DIMENSION H(3,3),BB(3,3),B2(3,3),RS(3,3,48)
C     DIMENSION X(3),Y(3),RSINV(3,3,48),DUM1(3,3),DUM2(3,3)
C     DIMENSION XX(3)
C     COMMON/AVEC/A1(3),A2(3),A3(3),XB1(3),XB2(3),XB3(3),COVA,ALAT
C     INTEGER*4 S(3,3,48)
C     DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),RVEC(4,LATQ)
C
C     WRITE(6,*) '   IN CHKGRP '
C     H(1,1)=A1(1)
C     H(1,2)=A2(1)
C     H(1,3)=A3(1)
C     H(2,1)=A1(2)
C     H(2,2)=A2(2)
C     H(2,3)=A3(2)
C     H(3,1)=A1(3)
C     H(3,2)=A2(3)
C     H(3,3)=A3(3)
C
C     CALL INVMAT(H,BB)
C     DO 1000 IROT=1,NTOT
C       DO 1010 K=1,3
C       DO 1010 J=1,3
C       B2(J,K)=0.D0
C1010   RS(J,K,IROT)=0.D0
C
C       DO 1110 J=1,3
C       DO 1110 K=1,3
C       DO 1110 L=1,3
C1110   B2(K,J)=S(L,K,IROT)*BB(L,J)+B2(K,J)
C
C       DO 1210 J=1,3
C       DO 1210 K=1,3
C       DO 1210 L=1,3
C1210   RS(K,J,IROT)=RS(K,J,IROT)+H(K,L)*B2(L,J)
C
C       DO 1410 I=1,3
C       DO 1410 J=1,3
C1410   DUM1(I,J)=RS(I,J,IROT)
C
C       CALL INVMAT(DUM1,DUM2)
C       DO 1510 I=1,3
C       DO 1510 J=1,3
C1510   RSINV(I,J,IROT)=DUM2(I,J)
C1000 CONTINUE
CC
C       DO 2000 I=1,NTYPE
C       DO 2000 J=1,ABS(NUMTY(I))
C       ITAU=NIDN(J,I)
C       X(1)=TAU(1,ITAU)
C       X(2)=TAU(2,ITAU)
C       X(3)=TAU(3,ITAU)
C       WRITE(6,'('' TAU1 '',3F15.7)') (X(II),II=1,3)
C       DO 2000 IROT=1,NTOT
C       WRITE(6,'(''      IROT'',I3)') IROT
C
C         DO 2300 L=1,3
C         XX(L)=0.D0
C         DO 2300 M=1,3
C2300     XX(L)=XX(L)+RS(L,M,IROT)*X(M)
C         WRITE(6,'('' XX '',3F15.7)') (XX(II),II=1,3)
C
C         DO 3000 I2=1,NTYPE
C         DO 3000 J2=1,ABS(NUMTY(I2))
C         DO 3000 K=1, NLV
C           ITAU2=NIDN(J2,I2)
C           Y(1)=TAU(1,ITAU2)+RVEC(1,K)
C           Y(2)=TAU(2,ITAU2)+RVEC(2,K)
C           Y(3)=TAU(3,ITAU2)+RVEC(3,K)
C           ACHK=ABS(XX(1)-Y(1))+ABS(XX(2)-Y(2))+ABS(XX(3)-Y(3))
C           IF(ACHK.LT.1.D-8) GOTO 3010
C3000     CONTINUE
C         WRITE(6,*) '  WARNING !!! ITAU= ',ITAU,' IROT= ', IROT
C3010     CONTINUE
C         WRITE(6,'('' TAU2 '',3F15.7)') (TAU(II,ITAU2),II=1,3)
C         WRITE(6,'('' RVEC '',3F15.7)') (RVEC(II,K),II=1,3)
C2000   CONTINUE
C       RETURN
C       END
C********************************************************
      SUBROUTINE FINDNBR(NTAU,TAU,LATQ,RVEC,NLV)
      IMPLICIT REAL*8(A-H,O-Z)
      PARAMETER (NATM=250)
      DIMENSION TAU(3,NTAU),RVEC(4,LATQ)
      DIMENSION INEIBR(NATM),RLEN(NATM),ILAT(NATM)
C
      DATA PI/3.1415926535897932D0/
      DATA RMAX/5.D0/
      DATA AU/0.5292D0/
      IFIN=NTAU
C
      DO 1000 I=1,IFIN
        X=TAU(1,I)
        Y=TAU(2,I)
        Z=TAU(3,I)
        ICONT=0
        DO 2000 J=1,NTAU
        DO 2050 M=1,NLV
          XX=TAU(1,J)+RVEC(1,M)
          YY=TAU(2,J)+RVEC(2,M)
          ZZ=TAU(3,J)+RVEC(3,M)
          XXX=XX-X
          YYY=YY-Y
          ZZZ=ZZ-Z
          R1= XXX*XXX + YYY*YYY + ZZZ*ZZZ
          IF(I.NE.J.AND.R1.LT.RMAX*RMAX)THEN
            ICONT=ICONT+1
            INEIBR(ICONT)=J
            ILAT(ICONT)=M
            RLEN(ICONT)=DSQRT(R1)
          ENDIF
          IF(ICONT.GT.NATM) STOP 'NATM.LT.ICONT'
 2050   CONTINUE
 2000   CONTINUE
        WRITE(6,2600) I,ICONT
 2600   FORMAT(1H , I5,' -TH ATOM HAS ',I5, ' NEAR ATOMS')
        DO 2500 J=1,ICONT
          K=INEIBR(J)
          XXX=TAU(1,K)-X  + RVEC(1,ILAT(J))
          YYY=TAU(2,K)-Y  + RVEC(2,ILAT(J))
          ZZZ=TAU(3,K)-Z  + RVEC(3,ILAT(J))
          R1=RLEN(J)*AU
          WRITE(6,2700) INEIBR(J),RLEN(J),R1,XXX,YYY,ZZZ
 2700     FORMAT(1H ,I5,' -ATOM:  ',2E18.8, ' ( ',3E15.5,')' )
 2500   CONTINUE
C
        DO 3000 J=1,ICONT
          DO 3100 K=J+1,ICONT
            L=INEIBR(J)
            M=INEIBR(K)
            X1=TAU(1,L)-X + RVEC(1,ILAT(J))
            Y1=TAU(2,L)-Y + RVEC(2,ILAT(J))
            Z1=TAU(3,L)-Z + RVEC(3,ILAT(J))
            X2=TAU(1,M)-X + RVEC(1,ILAT(K))
            Y2=TAU(2,M)-Y + RVEC(2,ILAT(K))
            Z2=TAU(3,M)-Z + RVEC(3,ILAT(K))
            R1=X1*X2+Y1*Y2+Z1*Z2
            ANGLE=ACOS(R1/RLEN(J)/RLEN(K))*180.D0/PI
            WRITE(6,3500) L,M,ANGLE
 3500       FORMAT(1H ,'ANGLE BETWEEN ',I5,',',I5, ':  ',F15.5)
 3100     CONTINUE
 3000   CONTINUE
 1000 CONTINUE
      RETURN
      END
C***************************************************************
c      SUBROUTINE G2VECT(NGQ,NG,NG2Q,NG2,VECK,
c     &                  G,G2,J2G,I2G,TPIBA,GCUT2)
c      IMPLICIT REAL*8 (A-H,O-Z)
c      DIMENSION G(4,NGQ),G2(4,NG2Q),I2G(NGQ),J2G(NG2Q),VECK(3)
cC
c      PI=4.D0*ATAN(1.D0)
c      TPIBA2=TPIBA*TPIBA
c      IG2=1
c      DO 1 I=1,NG
c      IF(IG2.GT.NG2Q) GOTO 100
c      G2(1,IG2)=VECK(1)+G(1,I)
c      G2(2,IG2)=VECK(2)+G(2,I)
c      G2(3,IG2)=VECK(3)+G(3,I)
c      G2(4,IG2)=G2(1,IG2)**2 + G2(2,IG2)**2 + G2(3,IG2)**2
c      GDIF= G2(4,IG2)*TPIBA2
c      IF(GDIF.GT.GCUT2) GOTO 1
cC     WRITE(6,*) ' GDIF ',I,IG2,GDIF,G(4,I)*TPIBA2
c      J2G(IG2)=I2G(I)
c      IG2=IG2+1
c    1 CONTINUE
c      IG2=IG2-1
c      WRITE(6,200) (VECK(I),I=1,3),GCUT2,IG2
c  200 FORMAT(' KVECT=',3F9.4,': GCUT2= ',F9.3,'  NG2= ',I5)
c      WRITE(6,*) ' NG=',NG
c      NG2=IG2
cC
c      DO 20 IG=1,NG2
c        DO 30 JG=IG,NG2
c          IF( G2(4,JG).GE.G2(4,IG) ) GOTO 30
c            DO 15 IR=1,4
c              Q=G2(IR,IG)
c              G2(IR,IG)=G2(IR,JG)
c              G2(IR,JG)=Q
c   15       CONTINUE
c            IR=J2G(IG)
c            J2G(IG)=J2G(JG)
c            J2G(JG)=IR
c   30   CONTINUE
c   20 CONTINUE
c      RETURN
c  100 WRITE(6,110) GCUT2
c  110 FORMAT(' GCUT2=',1PE12.4,' IS TOO BIG. STOPPING')
c      WRITE(6,*) ' TPIBA ',TPIBA,I,NG2Q
c      STOP
c      END
C****************************************************************
c      SUBROUTINE GEN(A,A1,A2,A3,B1,B2,B3,NRX,NRY,NRZ,NXYZ,
c     &                NG,NGQ,G,I2G,GCUT)
C
C   GENERATES THE RECIPROCAL LATTICE VECTORS WITH LENGTH SQUARED
C   LESS THAN GCUT, AND RETURNS THEM IN ORDER OF INCREASING LENGTH.
C      G=I*B1+J*B2+K*B3,
C   WHERE B1,B2,B3 ARE THE VECTORS DEFINING THE RECIPROCAL LATTICE,
C   THE G'S ARE IN UNITS OF 2PI/A, WHERE A IS THE LATTICE CONSTANT.
C   (I.E. TRUE G IS OBTAINED BY MULTIPLYING THE G'S WITH 2PAI/A.)
C                                   (1990-04-12) OSAMU SUGINO
C   SLAVE SUBROUTINE:RECIP
C   INPUT:A?(3), LATTICE VECTOR
C   OUTPUT:G(NG), RECIPROCAL LATTICE VECTORS
C
c      IMPLICIT REAL*8 (A-H,O-Z)
c      REAL*8 A1(3),A2(3),A3(3),B1(3),B2(3),B3(3),T(4)
c      DIMENSION I2G(NGQ),G(4,NGQ)
c      WRITE(6,3001) (A1(I),A2(I),A3(I),I=1,3)
c 3001 FORMAT(' A-VECTORS'/,3(' ',3F15.7/))
c      CALL RECIPS(A,A1,A2,A3,B1,B2,B3)
c      WRITE(6,3002) (B1(I),B2(I),B3(I),I=1,3)
c 3002 FORMAT(' B-VECTORS'/,3(' ',3F15.7/))
c      NG=1
c      IMAX=0
c      JMAX=0
c      KMAX=0
c      TNRM1=2*NRX-1
c      TNRM2=2*NRY-1
c      TNRM3=2*NRZ-1
c      DO 10 I1=1,TNRM1
c      I=I1-NRX
c      DO 10 J1=1,TNRM2
c      J=J1-NRY
c      DO 10 K1=1,TNRM3
c      K=K1-NRZ
c      G2=0.D0
c      DO 5 IR=1,3
c      T(IR)=DBLE(I)*B1(IR)+DBLE(J)*B2(IR)+DBLE(K)*B3(IR)
c    5 G2=G2+T(IR)*T(IR)
cc      IF(G2.GT.GCUT) GO TO 10
c      IF(ABS(I).GT.IMAX) IMAX=ABS(I)
c      IF(ABS(J).GT.JMAX) JMAX=ABS(J)
c      IF(ABS(K).GT.KMAX) KMAX=ABS(K)
c      DO 6 IR=1,3
c    6 G(IR,NG)=T(IR)
c      G(4,NG)=G2
c      N1=I+1
c      IF(I.LT.0) N1=N1+NRX
c      N2=J+1
c      IF(J.LT.0) N2=N2+NRY
c      N3=K+1
c      IF(K.LT.0) N3=N3+NRZ
c      I2G(NG)=N1+(N2-1)*NRX+(N3-1)*NRX*NRY
c      NG=NG+1
c      IF(NG.GT.NGQ) GO TO 100
c   10 CONTINUE
c      NG=NG-1
c      WRITE(6,130) GCUT,NG,NXYZ*4.0*3.141593/3.0/8.0
c  130 FORMAT(' GCUT=',F15.7,' NG=',I8,' NG EFFICIENT=',F15.7)
c      WRITE(6,*) ' IMAX=',IMAX,' JMAX=',JMAX,' KMAX=',KMAX
cC
cC   REORDER THE G'S IN ORDER OF INCREASING MAGNITUDE.
c      DO 20 IG=1,NG
c      DO 20 JG=IG,NG
c      IF(G(4,JG).GE.G(4,IG)) GO TO 20
c      DO 15 IR=1,4
c      Q=G(IR,IG)
c      G(IR,IG)=G(IR,JG)
c   15 G(IR,JG)=Q
c      IS=I2G(IG)
c      I2G(IG)=I2G(JG)
c      I2G(JG)=IS
c   20 CONTINUE
c      RETURN
c  100 WRITE(6,110) GCUT,NGQ
c  110 FORMAT(' GCUT=',1PE12.4,' IS TOO BIG. STOPPING',I9)
c      STOP
c      END
C****************************************************************
      SUBROUTINE GGEN(A,A1,A2,A3,B1,B2,B3,NRX,NRY,NRZ,NXYZ,
     &                NG,NGQ,G,I2G,GCUT,GG,I2GG,INDX)
C
C   GENERATES THE RECIPROCAL LATTICE VECTORS WITH LENGTH SQUARED
C   LESS THAN GCUT, AND RETURNS THEM IN ORDER OF INCREASING LENGTH.
C      G=I*B1+J*B2+K*B3,
C   WHERE B1,B2,B3 ARE THE VECTORS DEFINING THE RECIPROCAL LATTICE,
C   THE G'S ARE IN UNITS OF 2PI/A, WHERE A IS THE LATTICE CONSTANT.
C   (I.E. TRUE G IS OBTAINED BY MULTIPLYING THE G'S WITH 2PAI/A.)
C                                   (1990-04-12) OSAMU SUGINO
C   QUICK SORT VERSION              (1991-02-13) OSAMU SUGINO
C   SLAVE SUBROUTINE:RECIP
C   INPUT:A?(3), LATTICE VECTOR
C   OUTPUT:G(NG), RECIPROCAL LATTICE VECTORS
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
      REAL*8 A1(3),A2(3),A3(3),B1(3),B2(3),B3(3),T(4)
      DIMENSION I2G(NGQ),G(4,NGQ)
      DIMENSION I2GG(NGQ),GG(4,NGQ),INDX(NGQ)
      INTEGER TNRM1,TNRM2,TNRM3
cc
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
ccc
      if (my_rank.eq.0 ) WRITE(6,3001) (A1(I),A2(I),A3(I),I=1,3)
 3001 FORMAT(' A-VECTORS'/,3(' ',3F15.7/))
      CALL RECIPS(A,A1,A2,A3,B1,B2,B3)
      if (my_rank.eq.0 ) WRITE(6,3002) (B1(I),B2(I),B3(I),I=1,3)
 3002 FORMAT(' B-VECTORS'/,3(' ',3F15.7/))
      NG=1
      IG=1
      IMAX=0
      JMAX=0
      KMAX=0
c      TNRM1=2*NRX-1
c      TNRM2=2*NRY-1
c      TNRM3=2*NRZ-1
      TNRM1=NRX
      TNRM2=NRY
      TNRM3=NRZ
c ***  check FFT grids !!!
      if ( mod( nrx,2).ne.1 ) then
       write(6,*)' NRX should be odd number !! STOPPING'
       stop
      elseif ( mod(nry,2).ne.1 ) then
       write(6,*)' NRY should be odd number !! STOPPING'
       stop
      elseif ( mod(nrz,2).ne.1 ) then
       write(6,*)' NRZ should be odd number !! STOPPING'
       stop
      endif
c
      DO 10 I1=0,TNRM1-1
c      I=I1-NRX
      I=I1-NRX/2
      DO 10 J1=0,TNRM2-1
c      J=J1-NRY
      J=J1-NRY/2
      DO 10 K1=0,TNRM3-1
c      K=K1-NRZ
      K=K1-NRZ/2
      G2=0.D0
      DO 5 IR=1,3
      T(IR)=DBLE(I)*B1(IR)+DBLE(J)*B2(IR)+DBLE(K)*B3(IR)
    5 G2=G2+T(IR)*T(IR)
cccc      IF(G2.GT.GCUT) GO TO 10
      IF(ABS(I).GT.IMAX) IMAX=ABS(I)
      IF(ABS(J).GT.JMAX) JMAX=ABS(J)
      IF(ABS(K).GT.KMAX) KMAX=ABS(K)
      DO 6 IR=1,3
c    6 GG(IR,NG)=T(IR)
c      GG(4,NG)=G2
    6 GG(IR,IG)=T(IR)
      GG(4,IG)=G2
      N1=I+1
      IF(I.LT.0) N1=N1+NRX
      N2=J+1
      IF(J.LT.0) N2=N2+NRY
      N3=K+1
      IF(K.LT.0) N3=N3+NRZ
c      I2GG(NG)=N1+(N2-1)*NRX+(N3-1)*NRX*NRY
      I2GG(IG)=N1+(N2-1)*NRX+(N3-1)*NRX*NRY
c ***
c      IF ( G2.LE.GCUT ) NG=NG+1
      NG=NG+1
      IG=IG+1
      IF(NG.GT.NGQ+1) GO TO 100
   10 CONTINUE
      NG=NG-1
      IG=IG-1
      if ( my_rank.eq.0 ) then
      WRITE(6,130) GCUT,NG,NXYZ*4.0*3.141593/3.0/8.0
  130 FORMAT(' GCUT=',F15.7,' NG=',I8,' NG EFFICIENT=',F15.7)
      WRITE(6,*) ' IMAX=',IMAX,' JMAX=',JMAX,' KMAX=',KMAX
      endif
C
C   REORDER THE G'S IN ORDER OF INCREASING MAGNITUDE.
c      CALL INDEXX(NG,GG,INDX)
c      DO 20 IG=1,NG
      CALL INDEXX(NXYZ,GG,INDX)
      DO 20 IG=1,NXYZ
      G(1,IG)=GG(1,INDX(IG))
      G(2,IG)=GG(2,INDX(IG))
      G(3,IG)=GG(3,INDX(IG))
      G(4,IG)=GG(4,INDX(IG))
      I2G(IG)=I2GG(INDX(IG))
   20 CONTINUE
c ***  temp check
c      write(6,*)' GGEN ! NG = ',NG,' IG = ',ig
c      write(6,*)' 1 to NG '
c      write(6,*)( G(4,i),i=1,ng,100 )
c      write(6,*)' beyod NG '
c      write(6,*)( G(4,i),i=ng+1,ig,500 )
c ***  temp check : end
      RETURN
  100 WRITE(6,110) GCUT,NGQ
  110 FORMAT(' GCUT=',1PE12.4,' IS TOO BIG. STOPPING',I9)
      STOP
      END
      SUBROUTINE INDEXX(N,ARRIN,INDX)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION ARRIN(4,N),INDX(N)
      DO 11 J=1,N
   11 INDX(J)=J
      L=N/2+1
      IR=N
   10 CONTINUE
      IF(L.GT.1) THEN
         L=L-1
         INDXT=INDX(L)
         Q=ARRIN(4,INDXT)
      ELSE
         INDXT=INDX(IR)
         Q=ARRIN(4,INDXT)
         INDX(IR)=INDX(1)
         IR=IR-1
         IF(IR.EQ.1) THEN
            INDX(1)=INDXT
            RETURN
         ENDIF
      ENDIF
      I=L
      J=L+L
   20 IF(J.LE.IR) THEN
         IF(J.LT.IR) THEN
            IF(ARRIN(4,INDX(J)).LT.ARRIN(4,INDX(J+1))) J=J+1
         ENDIF
         IF(Q.LT.ARRIN(4,INDX(J))) THEN
            INDX(I)=INDX(J)
            I=J
            J=J+J
         ELSE
            J=IR+1
         ENDIF
         GOTO20
      ENDIF
      INDX(I)=INDXT
      GOTO 10
      END
c **** begin FFT part
c      SUBROUTINE FFT3BX(NRX,NRY,NRZ,NG,RHOG,WORK,
c     &                  WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,
c     &                  LX1,LX2,LY1,LY2,LZ1,LZ2)
cC***********************************************************
cC     (REAL SPACE-->G-SPACE)
cC                                   (1990-04-12) OSAMU SUGINO
cC     INPUT :RHO,NR?,NG,WSAVE?,IFAC?,L??
cC     OUTPUT:RHOG
cC     WORK  :WORK
cC
c      IMPLICIT REAL*8 (A-H,O-Z)
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c      DIMENSION RHOG(2,NG),WORK(2,NG)
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NG),LX2(NG),LY1(NG),LY2(NG),LZ1(NG),LZ2(NG)
cC
cC     DO 15 IG=1,NG
cC     WORK(1,IG)=RHOG(1,IG)
cC     WORK(2,IG)=RHOG(2,IG)
cC  15 CONTINUE
c      CALL FFTSV1(NG,RHOG,WORK)
c      CALL CFFT3B(NG,NRX*NRY,NRZ,WORK,RHOG,WSAVEZ,IFACZ)
cC
c      CALL FFTXYZ(NG,NRX*NRY,NRZ,WORK,RHOG,LZ1,LZ2)
c      CALL CFFT3B(NG,NRZ*NRX,NRY,RHOG,WORK,WSAVEY,IFACY)
cC
c      CALL FFTXYZ(NG,NRZ*NRX,NRY,RHOG,WORK,LY1,LY2)
c      CALL CFFT3B(NG,NRY*NRZ,NRX,WORK,RHOG,WSAVEX,IFACX)
cC
c      CALL FFTXYZ(NG,NRY*NRZ,NRX,WORK,RHOG,LX1,LX2)
c      CALL FFTSV2(NG,RHOG,WORK)
cC     FAC=1.0D0/DBLE(NG)
c      FAC=1.0D0
c      DO 40 I=1,NG
c      RHOG(1,I)= WORK(1,I)*FAC
c      RHOG(2,I)= WORK(2,I)*FAC
c   40 CONTINUE
cC
c      RETURN
c      END
cC***********************************************************
c      SUBROUTINE FFT3FX(NRX,NRY,NRZ,NG,RHOG,WORK,
c     &                  WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,
c     &                  LX1,LX2,LY1,LY2,LZ1,LZ2)
cC***********************************************************
cC     (G-SPACE -->REAL SPACE)
cC                                   (1990-04-12) OSAMU SUGINO
cC     INPUT :RHOG,NR?,NG,WSAVE?,IFAC?,L??
cC     OUTPUT:WORK
cC     WORK  :NONE
cC
c      IMPLICIT REAL*8 (A-H,O-Z)
c      DIMENSION  RHOG(2,NG),WORK(2,NG)
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NG),LX2(NG),LY1(NG),LY2(NG),LZ1(NG),LZ2(NG)
cC
c      CALL FFTSV1(NG,RHOG,WORK)
c      CALL CFFT3F(NG,NRX*NRY,NRZ,WORK,RHOG,WSAVEZ,IFACZ)
cC
c      CALL FFTXYZ(NG,NRX*NRY,NRZ,WORK,RHOG,LZ1,LZ2)
c      CALL CFFT3F(NG,NRZ*NRX,NRY,RHOG,WORK,WSAVEY,IFACY)
cC
c      CALL FFTXYZ(NG,NRZ*NRX,NRY,RHOG,WORK,LY1,LY2)
c      CALL CFFT3F(NG,NRY*NRZ,NRX,WORK,RHOG,WSAVEX,IFACX)
cC
c      CALL FFTXYZ(NG,NRY*NRZ,NRX,WORK,RHOG,LX1,LX2)
c      CALL FFTSV2(NG,RHOG,WORK)
c      FAC=1.0D0/DBLE(NG)
cC     FAC=1.0D0
c      DO 40 I=1,NG
c      RHOG(1,I)= WORK(1,I)*FAC
c      RHOG(2,I)= WORK(2,I)*FAC
c   40 CONTINUE
c      RETURN
c      END
cc *** end FFT part
C*****************************************************************
      SUBROUTINE LVGEN(A1,A2,A3,LATQ,NLV,RCUT,R,RR,NTOT)
C
C   GENERATES THE LATTICE VECTORS WITH LENGTH SQUARED
C   LESS THAN RCUT, AND RETURNS THEM IN ORDER OF INCREASING LENGTH.
C      R=I*A1+J*A2+K*A3,
C   WHERE A1,A2,A3 ARE THE VECTORS DEFINING THE DIRECT LATTICE.
C   THE R'S ARE IN ATOMIC UNITS.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
      REAL*8 A1(3),A2(3),A3(3),T(4)
      DIMENSION R(4,LATQ),RR(LATQ),NTOT(LATQ)
      INTEGER TNRM1
      DATA NR/15/
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c
      NLV=1
      TNRM1=2*NR-1
      DO 10 I1=1,TNRM1
      I=I1-NR
      DO 10 J1=1,TNRM1
      J=J1-NR
      DO 10 K1=1,TNRM1
      K=K1-NR
      R2=0.D0
      DO 5 IR=1,3
      T(IR)=DBLE(I)*A1(IR)+DBLE(J)*A2(IR)+DBLE(K)*A3(IR)
    5 R2=R2+T(IR)*T(IR)
      IF(R2.GT.RCUT) GO TO 10
      DO 6 IR=1,3
    6 R(IR,NLV)=T(IR)
      R(4,NLV)=R2
      NLV=NLV+1
      IF(NLV.GT.LATQ) GO TO 100
   10 CONTINUE
      NLV=NLV-1
C   REORDER THE R'S IN ORDER OF INCREASING MAGNITUDE.
      DO 20 IV=1,NLV
      DO 20 JV=IV,NLV
      IF(R(4,JV).GE.R(4,IV)) GO TO 20
      DO 15 IR=1,4
      Q=R(IR,IV)
      R(IR,IV)=R(IR,JV)
   15 R(IR,JV)=Q
   20 CONTINUE
C*    PRINT SHELL INFORMATION
      IND=1
      II=1
      RR(1)=R(4,1)
      DO 50 I=2,NLV
      NTOT(IND)=I-II
      IF(ABS(R(4,I)-R(4,II)).LT.0.001) GO TO 50
C
      IND=IND+1
      RR(IND)=R(4,I)
      II=I
50    CONTINUE
      NTOT(IND)=NLV+1-II
      if ( my_rank.eq.0 ) then
      DO 60 I=1,IND
   60 PRINT 200,I,RR(I),NTOT(I)
      endif
200   FORMAT(10X,'    SHELL NO.',I4,1X,' LENGTH SQUARED',1X,F9.3,2X,
     1   'NO. OF VECTS.',I4)
      RETURN
  100 if ( my_rank.eq.0 ) WRITE(6,110) RCUT, NLV, LATQ
  110 FORMAT(' RCUT=',1PE12.4,' IS TOO BIG.  NLV LATQ = ',2I5)
      STOP
      END
C*
C*
      SUBROUTINE ESORT(N,ARRIN,INDX)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION ARRIN(N),INDX(N)
      DO 11 J=1,N
   11 INDX(J)=J
      L=N/2+1
      IR=N
   10 CONTINUE
      IF(L.GT.1) THEN
         L=L-1
         INDXT=INDX(L)
         Q=ARRIN(INDXT)
      ELSE
         INDXT=INDX(IR)
         Q=ARRIN(INDXT)
         INDX(IR)=INDX(1)
         IR=IR-1
         IF(IR.EQ.1) THEN
            INDX(1)=INDXT
            RETURN
         ENDIF
      ENDIF
      I=L
      J=L+L
   20 IF(J.LE.IR) THEN
         IF(J.LT.IR) THEN
            IF(ARRIN(INDX(J)).LT.ARRIN(INDX(J+1))) J=J+1
         ENDIF
         IF(Q.LT.ARRIN(INDX(J))) THEN
            INDX(I)=INDX(J)
            I=J
            J=J+J
         ELSE
            J=IR+1
         ENDIF
         GOTO20
      ENDIF
      INDX(I)=INDXT
      GOTO 10
      END
C ******************************************************
C
C
C   LATTICE VECTOR GENERATION
C
C
C
C ******************************************************
      SUBROUTINE LVGENX(A1,A2,A3,S,NROT,RKK,KG,KZ,NNK,NKG)
      PARAMETER(LATQ=50)
      IMPLICIT REAL*8(A-H,O-Z)
      include 'mpif.h'
      DIMENSION A1(3),A2(3),A3(3),SP(3,3),KG(3,LATQ),KZ(3,LATQ,48)
     &         ,NNK(LATQ),RKK(LATQ), A3WK(3)
      INTEGER*4 S(3,3,48)
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      if ( my_rank.eq.0 ) write(6,*) ' in sub. LVGENX !!'
      if ( my_rank.eq.0 ) READ(5,*) QFR
      call MPI_BCAST(QFR,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ierr)
      if ( my_rank.eq.0 ) write(6,*) ' QFR has been BCASTed!'
CARE * TEMP:  FOR REMOVING LATTICE VECTORS IN A3 DIRECTION
          DO 1 K = 1, 3
    1     A3WK(K) =           A3(K)
CC  1     A3WK(K) = 3.0D+00 * A3(K)
C ***         NORMALLY, THE FOLLOWING A3WK SHOULD BE REPLACED BY A3.
          CALL SRPGEN(A1,A2,A3WK,SP)
C ***   TEMP END
c      CALL RARR2(SP,S,NROT,1,QFR,1.0D-12,1,RKK,KG,KZ,NNK,NKG)
      CALL RARR3(SP,S,NROT,1,QFR,1.0D-12,1,RKK,KG,KZ,NNK,NKG)
c      if ( my_rank.eq.0 ) write(6,*) ' RARR3 has been done!'
cc      write(6,*)'my_rank=',my_rank,'  RARR3 has been done!'
      RETURN
      END
      SUBROUTINE SRPGEN(A1,A2,A3,SP)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION A1(3),A2(3),A3(3),SP(3,3)
      SP(1,2)=A1(1)*A2(1)+A1(2)*A2(2)+A1(3)*A2(3)
      SP(1,3)=A1(1)*A3(1)+A1(2)*A3(2)+A1(3)*A3(3)
      SP(2,3)=A2(1)*A3(1)+A2(2)*A3(2)+A2(3)*A3(3)
      SP(1,1)=A1(1)*A1(1)+A1(2)*A1(2)+A1(3)*A1(3)
      SP(2,2)=A2(1)*A2(1)+A2(2)*A2(2)+A2(3)*A2(3)
      SP(3,3)=A3(1)*A3(1)+A3(2)*A3(2)+A3(3)*A3(3)
      SP(3,1)=SP(1,3)
      SP(2,1)=SP(1,2)
      SP(3,2)=SP(2,3)
      RETURN
      END
C ******************************************************************
      SUBROUTINE RARR2(SP,RG,NG,INV,QF,EPS,IPRINT,AKK,KG,KZ,NNK,NKG)
      IMPLICIT REAL*8(A-H,O-Z)
      PARAMETER(LATQ=50)
      DIMENSION KG(3,LATQ),AKK(LATQ),SP(3,3),NN(3)
     &         ,KZ(3,LATQ,48),NNK(LATQ)
      INTEGER*4 RG(3,3,48)
      REAL*8  AKK,SP
      EQUIVALENCE (N1,NN(1)),(N2,NN(2)),(N3,NN(3))
      IND=0
      QFF=QF*QF
      A=SP(3,3)
      B0=SP(2,2)*SP(3,3)-SP(2,3)**2
      B=B0/A
      C=(SP(1,1)*SP(2,2)*SP(3,3)+2.0*SP(2,3)*SP(3,1)*SP(1,2)
     &  -(SP(1,1)*SP(2,3)**2+SP(2,2)*SP(3,1)**2+SP(3,3)*SP(1,2)**2))/B0
      N=0
      QN1=-QF/SQRT(C)
      N1=QN1
   20 GK1=N1
      SB=-(SP(1,2)*SP(3,3)-SP(1,3)*SP(2,3))*GK1/B0
      S=C*GK1*GK1
      RS=QFF-S
      IF(RS) 65,21,21
   21 QN2=SB-SQRT(RS/B)
      N2=QN2
      IF(QN2.GT.0.0) N2=N2+1
   22 GK2=N2
      SA=-(SP(1,3)*GK1+SP(2,3)*GK2)/A
      SS=S+B*(GK2-SB)**2
      RS=QFF-SS
      IF(RS) 64,23,23
   23 QN3=SA-SQRT(RS/A)
      N3=QN3
      IF(QN3.GT.0.0) N3=N3+1
   24 GK3=N3
      SSS=SS+A*(GK3-SA)**2
      IF(QFF-SSS) 62,25,25
   25 IF(N) 46,46,26
   26 DO 28 K=1,NKG
      IF(AKK(K)-(SSS-EPS)) 28,32,32
   28 CONTINUE
      IF(N-LATQ) 30,50,50
   30 K=N+1
      GO TO 48
   32 IF(AKK(K)-(SSS+EPS)) 52,52,34
   34 IF(N-LATQ) 38,36,36
   36 IF(NKG-K) 48,48,40
   40 KM=K+1
      GO TO 42
   38 KM=K
   42 DO 44 KK=KM,NKG
      KS=NKG-KK+K
      AKK(KS+1)=AKK(KS)
      DO 41 J=1,3
   41 KG(J,KS+1)=KG(J,KS)
   44 CONTINUE
      GO TO 48
   46 K=1
   48 AKK(K)=SSS
      DO 49 I=1,3
   49 KG(I,K)=NN(I)
   50 N=N+1
      NKG=MIN0(N,LATQ)
      GO TO 60
   52 DO 54 IV=1,INV+1
      DO 54 IG=1,NG
      DO 55 I=1,3
      IS=0
      DO 56 M=1,3
   56 IS=IS+RG(M,I,IG)*KG(M,K)
      IF( IV.EQ.2) IS=-IS
      IF(IS-NN(I)) 54,55,54
   55 CONTINUE
      GO TO 60
   54 CONTINUE
      IF(K.GE.LATQ) GO TO 50
      K=K+1
      IF(K.GT.NKG) GO TO 48
      IF(AKK(K)-(SSS+EPS)) 52,52,34
   60 N3=N3+1
      GO TO 24
   62 N2=N2+1
      GO TO 22
   64 N1=N1+1
      GO TO 20
   65 CONTINUE
      IF(N.GT.NKG) IND=-1
C
      WRITE(6,6000) NKG, IND
 6000 FORMAT(/8X,
     &'  **** RARR2: NEXPND = ',I4,' IND = ',I2,' SHOULD BE 0')
C
      IF(IPRINT.NE.0) WRITE(6,100) N
  100 FORMAT(8X,
     &'              N = ',I3,'   NO  KR1 KR2 KR3    ADR ')
      IF(IPRINT) 80,88,80
   80 DO 82 KK=1,NKG
      WRITE(6,2000) KK,(KG(I,KK),I=1,3),AKK(KK)
 2000 FORMAT(31X,I3,2X,3I3,2X,D13.5)
   82 CONTINUE
CC
   88 DO 71 KK=1,NKG
      KS=1
      KZ(1,KK,1)=KG(1,KK)
      KZ(2,KK,1)=KG(2,KK)
      KZ(3,KK,1)=KG(3,KK)
      DO 72 IG=1,NG
      DO 72 IW=1,-1,-2
      KK1=RG(1,1,IG)*KG(1,KK)+RG(2,1,IG)*KG(2,KK)+RG(3,1,IG)*KG(3,KK)
      KK2=RG(1,2,IG)*KG(1,KK)+RG(2,2,IG)*KG(2,KK)+RG(3,2,IG)*KG(3,KK)
      KK3=RG(1,3,IG)*KG(1,KK)+RG(2,3,IG)*KG(2,KK)+RG(3,3,IG)*KG(3,KK)
      KK1=KK1*IW
      KK2=KK2*IW
      KK3=KK3*IW
      DO 73 KX=1,KS
      IF((KK1.EQ.KZ(1,KK,KX)).AND.(KK2.EQ.KZ(2,KK,KX)).AND.
     &   (KK3.EQ.KZ(3,KK,KX))) GO TO 72
   73 CONTINUE
      KS=KS+1
      KZ(1,KK,KS)=KK1
      KZ(2,KK,KS)=KK2
      KZ(3,KK,KS)=KK3
   72 CONTINUE
      NNK(KK)=KS
   71 CONTINUE
CCC   DO 74 KK=1,NKG
C     WRITE(6,91) KK,NNK(KK)
C     DO 75 KI=1,NNK(KK)
C     WRITE(6,92) KI,(KZ(II,KK,KI),II=1,3)
C  75 CONTINUE
C  74 CONTINUE
C  91 FORMAT(1H ,I5,I10)
CC 92 FORMAT(1H ,I3,15X,3I4)
C     WRITE(37) KG,NKG
C     WRITE(28) KZ,NNK,NKG
      RETURN
      END
C ********************************************************************
C     PARAMETERS:
C        LATQ    = # OF IRREDUCIBLE LATTICE VECTORS.
C        NAD     = 2*N+1 WHERE N GIVES FINENESS OF MESHES IN BZ.
C        NAS     = # OF K IN A IRREDUCIBLE WEDGE.
C ********************************************************************
      SUBROUTINE MESHK(RG,NG,NS,NI,KR,NRF,MM,RCO,JDR,SK,WK,NJD,CCO,
     &                 NDX, NDY, NDZ )
      IMPLICIT INTEGER(A-Z)
      include 'mpif.h'
      PARAMETER(NAS=72, LATQ=144,NARF=LATQ)
      PARAMETER(NAD=72 )
      REAL*8 SK,WK,SS,CCO,PAI,RCO
CCC   REAL*8 SS1,SS2,SS3
      DIMENSION NJD(NAS),CCO(-NAD:NAD)
      DIMENSION SK(3,NAS),WK(NAS),KR(3,NARF)
      DIMENSION MM(3,10000),RCO(NAS,NARF),JDR(48,NAS)
      INTEGER*4 RG(3,3,48)
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c
      PAI=4.D0*ATAN(1.D0)
C
CCC   REWIND 63

      if ( my_rank.eq.0 ) then
      READ(5,*) N
      endif
      call MPI_BCAST(N,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
c *** temp check
c      do icpu=0,3
c       if ( my_rank.eq.icpu ) then
c        write(6,*)' in sub MESHK my_rank=',my_rank,' N=',N
c       endif 
c      enddo
c *** temp check : end
      if ( my_rank.eq.0 ) then
      WRITE(6,6600) N
      endif
c *** temp check
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c *** temp check : end
 6600 FORMAT(/8X,
     &'  **** MESHK: N = ',I4)
c      IF(NAD .LT. 2*N-1 ) STOP ' N IS TOO BIG... OR CHANGE NAD.'
      IF(NAD .LT. 2*N-1 ) then
       if ( my_rank.eq.0 ) write(6,*)' N IS TOO BIG... OR CHANGE NAD.'
       STOP
      ENDIF
C
      DO 98 IH=-(N-1),N-1
      CCO(IH)=COS(2.0D0*PAI*DFLOAT(IH)/DFLOAT(N))
   98 CONTINUE
c *** temp check
c      if ( my_rank.ne.0 ) write(6,*)' my_rank and N ',my_rank,N
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c      miya=13
c      if ( miya.eq.13) stop
c *** temp check ; end
      CALL MESHK2(NG,RG,NS,NI,SK,WK,KR,NRF,MM,RCO,JDR,N,NJD,CCO)
c *** temp check
c      write(6,*)' my_rank=',my_rank,' MESHK2 finished ! '
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c      miya=13
c      if ( miya.eq.13) stop
c *** temp check ; end
C ****
      if ( my_rank.eq.0 ) then
      READ(5,*) NDX, NDY, NDZ
      endif
      call MPI_BCAST(NDX,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(NDY,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(NDZ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
C
      if ( my_rank.eq.0 ) then
      WRITE(6,6602) NI, NS, ( IS,( SK(I,IS),I=1,3),WK(IS), IS=1,NS )
 6602 FORMAT(8X,
     &'          TOTAL NO. OF K IN WHOLE BZ = ',I4/8X,
     &'          TOTAL NO. OF K IN WEDGE    = ',I4/8X,
     &'          NO.            COORDINATES      WK  '/
     & (18X, I3, 3F8.4, 2X, F8.4)  )
      DO 99 IS=1,NS
      WRITE(6,6604) IS, NJD(IS), ( JDR(IG,IS), IG = 1, NJD(IS) )
 6604 FORMAT(8X,
     &'          NO. ',I3,' NJD = ',I4,'  JDR(1..NJD) = :'/
     & ( 22X,15I3) )
   99 CONTINUE
      WRITE(6,6606) NDX, NDY, NDZ
 6606 FORMAT(8X,'          FOR DOS: NDX NDY NDZ = ',3I4)
c **** temp check
c      miya=13
c      if ( miya.eq.13 ) stop
c **** temp check : end
      endif  ! end of if my_rank.eq.0 loop
c
      SS=0.0
      DO 12 I=1,NS
   12 SS=SS+WK(I)
      DO 14 I=1,NS
   14 WK(I)=WK(I)/SS
CCC   WRITE(6,*) 'SS=',SS
CCC   DO 13 KS=1,NS
CCC   WRITE(6,3) (SK(I,KS),I=1,3),NRF,(RCO(KS,I),I=1,NRF),WK(KS)
CCC13 CONTINUE
CCC 3 FORMAT(3X,3F10.5,/,3X,I3,/,1X,20(2X,4F10.5))
      RETURN
      END
C**
C**
      SUBROUTINE MESHK2(NG,RG,NS,NI,SK,WK,KR,NRF,MM,RCO,JDR,N,NJD,CCO)
CCC   SUBROUTINE MESHK2(NG,RG,NS,NI,SK,WK,KR,NRF,MM,RCO,JDR,N,NJD)
      IMPLICIT INTEGER(A-Z)
      include 'mpif.h'
      PARAMETER(NAS=72, LATQ=144,NARF=LATQ)
      PARAMETER(NAD=72 )
      REAL*8 SK,WK,CCO,RCO
      DIMENSION NJD(NAS),CCO(-NAD:NAD)
C     REAL*8 SK,WK,    RCO,ADX,ADY,ADZ,P2
C     DIMENSION NJD(NAS)
      DIMENSION PP(3),QQ(3),KK(3),KR(3,NARF),RCO(NAS,NARF),JDR(48,NAS)
      DIMENSION SK(3,NAS),WK(NAS),MM(3,10000)
      INTEGER*4 RG(3,3,48)
C ****  FOR NEW VERSION 'DOS' *****
C     DATA P2/6.28318530717958648D0/
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c **** temp check
c      write(6,*)' my_rank=',my_rank,' N=',N,' in MESHK2'
      if ( n.eq.0 )then
      write(6,*) 'my_rank=',my_rank,' N=0 !!!'
      stop
      endif
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c      miya=13
c      if ( miya.eq.13 ) then
c       stop
c      endif
c **** temp check : end
c
C     ADX=P2/DFLOAT(N)
C     ADY=P2/DFLOAT(N)
C     ADZ=P2/DFLOAT(N)
C
      DO 98 II=1,NAS
      DO 98 JJ=1,NARF
      RCO(II,JJ)=0.0D0
   98 CONTINUE
C
      DO 99 II=1,NAS
      NJD(II)=0
      DO 99 JJ=1,48
  99  JDR(JJ,II)=0
C
      NI=1
      IS=1
  100 CONTINUE
C
      if ( my_rank.eq.0 ) then
      READ(5,*) M1,M2,M3
      endif
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
      call MPI_BCAST(M1,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(M2,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(M3,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
c **** temp check
c      if ( my_rank.ne.0 ) then
c      write(6,*)' my_rank=',my_rank,'M1=',M1,' in MESHK2'
c      write(6,*)' my_rank=',my_rank,'M2=',M2,' in MESHK2'
c      write(6,*)' my_rank=',my_rank,'M3=',M3,' in MESHK2'
c      endif
c **** temp check : end
      IF( M1*M1 + M2*M2 + M3*M3 .EQ.0) GO TO 101
      if ( my_rank.eq.0 ) then
      READ(5,*) MM1,MM2,MM3
      READ(5,*) J1X,J2X,J3X
      READ(5,*) J1Y,J2Y,J3Y
      READ(5,*) J1Z,J2Z,J3Z
      endif
      call MPI_BCAST(MM1,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(MM2,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(MM3,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J1X,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J2X,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J3X,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J1Y,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J2Y,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J3Y,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J1Z,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J2Z,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_BCAST(J3Z,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
c **** temp check
c      if ( my_rank.ne.0 ) then
c      write(6,*)' my_rank=',my_rank,'MM1=',MM1
c      write(6,*)' my_rank=',my_rank,'MM2=',MM2
c      write(6,*)' my_rank=',my_rank,'MM3=',MM3
c      write(6,*)' my_rank=',my_rank,'J1X=',J1X
c      write(6,*)' my_rank=',my_rank,'J2X=',J2X
c      write(6,*)' my_rank=',my_rank,'J3X=',J3X
c      write(6,*)' my_rank=',my_rank,'J1Y=',J1Y
c      write(6,*)' my_rank=',my_rank,'J2Y=',J2Y
c      write(6,*)' my_rank=',my_rank,'J3Y=',J3Y
c      write(6,*)' my_rank=',my_rank,'J1Z=',J1Z
c      write(6,*)' my_rank=',my_rank,'J2Z=',J2Z
c      write(6,*)' my_rank=',my_rank,'J3Z=',J3Z
cc      miya=13
cc      if ( miya.eq.13 ) stop
c      endif
c **** temp check : end
C
c ***** temp check
c      if ( my_rank.ne.0 ) then
c      write(6,*)' my_rank=',my_rank,' N=',N,' in sub MESHK2'
cc      miya=13
cc      if ( miya.eq.13 ) stop
c      endif
c ***** temp check : end
c
      DO 1 I1=-M1,M1,MM1
      DO 2 I2=-M2,M2,MM2
      DO 3 I3=-M3,M3,MM3
c                        IF(IS.GT.NAS) STOP ' MESHK2: N IS TOO BIG...'
                        IF(IS.GT.NAS) then 
                         if (my_rank.eq.0 )
     &                       write(6,*) ' MESHK2: N IS TOO BIG...'
                         STOP
                        ENDIF
      PP(1)=I1*J1X+I2*J1Y+I3*J1Z
      PP(2)=I1*J2X+I2*J2Y+I3*J2Z
      PP(3)=I1*J3X+I2*J3Y+I3*J3Z
      DO 11 I=1,3
      QQ(I)=PP(I)
   11 CONTINUE
C
      DO 13 I=1,3
      PP(I)=MOD(QQ(I),N)
      IF(PP(I).GT.N/2)  PP(I)=PP(I)-N
      IF(PP(I).LE.-N/2)  PP(I)=PP(I)+N
   13 CONTINUE
C
      ND=0
      IQRT=0
      IF(NI.NE.1) THEN
      DO 31 I=1,NI-1
      IF((PP(1).EQ.MM(1,I)).AND.(PP(2).EQ.MM(2,I)).AND.
     *   (PP(3).EQ.MM(3,I)))  THEN
      IQRT=1
      END IF
   31 CONTINUE
      IF(IQRT.EQ.1) GO TO 3
      END IF
      NNI=NI
      JIG=0
      DO 21 IW=1,-1,-2
      DO 21 IG=1,NG
      IQRT2=0
      IQRT3=0
      DO 23 I=1,3
      KK(I)=0
      DO 24 J=1,3
   24 KK(I)=KK(I)+RG(I,J,IG)*PP(J)*IW
   23 CONTINUE
      DO 25 I=1,3
      QQ(I)=MOD(KK(I),N)
      IF(QQ(I).GT.N/2) QQ(I)=QQ(I)-N
      IF(QQ(I).LE.-N/2) QQ(I)=QQ(I)+N
   25 CONTINUE
      IF((QQ(1).EQ.PP(1)).AND.(PP(2).EQ.QQ(2)).AND
     *   .(QQ(3).EQ.PP(3))) THEN
      ND=ND+1
      IF((IG.EQ.1).AND.(IW.EQ.1)) THEN
      JIG=JIG+1
      DO 29 I=1,3
      MM(I,NI)=QQ(I)
   29 CONTINUE
      DO 64 KA=1,NRF
      RCO(IS,KA)=RCO(IS,KA)
     &  +CCO(MOD((QQ(1)*KR(1,KA)+QQ(2)*KR(2,KA)+QQ(3)*KR(3,KA)),N))
   64 CONTINUE
      NJD(IS)=NJD(IS)+1
      JDR(JIG,IS)=IG
      ELSE
      NI=NI-1
      END IF
      ELSE
C
C
      DO 33 I=NNI,NI-1
      IF((QQ(1).EQ.MM(1,I)).AND.(QQ(2).EQ.MM(2,I)).AND.
     *   (QQ(3).EQ.MM(3,I)))  THEN
      IQRT2=1
      END IF
      IF(((QQ(1).EQ.-MM(1,I)).OR.((QQ(1).EQ.N/2).AND.(MM(1,I).EQ.N/2)))
     *   .AND.
     *   ((QQ(2).EQ.-MM(2,I)).OR.((QQ(2).EQ.N/2).AND.(MM(2,I).EQ.N/2)))
     *   .AND.
     *   ((QQ(3).EQ.-MM(3,I)).OR.((QQ(3).EQ.N/2).AND.(MM(3,I).EQ.N/2))))
     *  THEN
      IQRT3=1
      END IF
   33 CONTINUE
      IF(IQRT2.EQ.1) GO TO 21
      DO 65 KA=1,NRF
      RCO(IS,KA)=RCO(IS,KA)
     &  +CCO(MOD((QQ(1)*KR(1,KA)+QQ(2)*KR(2,KA)+QQ(3)*KR(3,KA)),N))
   65 CONTINUE
      IF(IQRT3.NE.1) THEN
      JIG=JIG+1
      NJD(IS)=NJD(IS)+1
      JDR(JIG,IS)=IG
      END IF
      DO 27 I=1,3
   27 MM(I,NI)=QQ(I)
      END IF
      NI=NI+1
   21 CONTINUE
c **** temp check
c      write(6,*)' my_rank=',my_rank,' ND=',ND
c **** temp check : end
      WK(IS)=1.0D0/DFLOAT(ND)
c **** temp check
c      write(6,*)' my_rank=',my_rank,' N=',N
c **** temp check : end
      DO 28 I=1,3
      SK(I,IS)=DFLOAT(PP(I))/DFLOAT(N)
   28 CONTINUE
      IS=IS+1
    3 CONTINUE
    2 CONTINUE
    1 CONTINUE
      GO TO 100
  101 CONTINUE
      NI=NI-1
      NS=IS-1
      RETURN
      END
C*
C
CC    SUBROUTINE DATSTR(NGQ,NG,I2G,NG2Q,NG2,J2G,NUMK,WGT)
C
C     IMPLICIT REAL*8 (A-H,O-Z)
C
C     DIMENSION I2G(NGQ),NG2(NUMK),J2G(NG2Q,NUMK)
C     DIMENSION WGT(NUMK)
C
C     REWIND 25
C     WRITE(25) NG,(I2G(IG),IG=1,NG)
C     WRITE(25) NUMK,(NG2(IK),IK=1,NUMK),(WGT(IK),IK=1,NUMK)
C     WRITE(25) ((J2G(IG,IK),IG=1,NG2(IK)),IK=1,NUMK)
C
C     RETURN
C     END
C ********************************************************************
C        CHECK OF S-MATRIX AND CONSISTENCY WITH ACTUAL COORDINATES.
C                        A. OSHIYAMA  6/22/93
C ********************************************************************
      SUBROUTINE SMATCHK( S, TAU, CTAU, B1, B2, B3, ALAT,
     &                    NTOT, NTAUQ )
      IMPLICIT REAL*8 (A-H, O-Z)
      INTEGER  S(3,3,48), IS(3,3)
      DIMENSION TAU(3,NTAUQ), CTAU(3,NTAUQ), B1(3), B2(3), B3(3)
      DATA  ONE/1.0D+00/, ZERO/0.0D+00/
C
      WRITE(6,1000)
 1000 FORMAT(/
     &'   **** SMATCHK: THIS VERSION DOES NOT RECOGNIZE ATOM TYPE.')
C
      DO 1 I = 1, NTOT
      DO 2 J = 1, NTOT
          DO 3 K1 = 1, 3
          DO 3 K2 = 1, 3
    3     IS(K1,K2) = 0
          DO 4 K1 = 1, 3
          DO 4 K2 = 1, 3
    4     IS(K1,K2) = IS(K1,K2) + S(K1,1,I) * S(1,K2,J)
     &                          + S(K1,2,I) * S(2,K2,J)
     &                          + S(K1,3,I) * S(3,K2,J)
      NUM = 0
          DO 5 JP = 1, NTOT
             DO 6 K1 = 1, 3
             DO 6 K2 = 1, 3
             IF( IS(K1,K2) .NE. S(K1,K2,JP) ) GO TO 5
    6        CONTINUE
          NUM = NUM + 1
    5     CONTINUE
C
      IF( NUM .NE. 1 ) THEN
         WRITE(6,1010) NUM, I, J,
     &    ( (S(K1,K2,I), K2=1,3), (S(K1,K2,J), K2=1,3),
     &      (IS(K1,K2), K2=1,3),  K1 = 1, 3             )
 1010    FORMAT(10X,'  SOMETHING WRONG FOR S MATRIX: ',
     &              '  NUM I J = ',3I3/
     &   (15X,3I3,3X,3I3,3X,3I3) )
         STOP
      END IF
C
    2 CONTINUE
    1 CONTINUE
C ***
C    CHECK OF CLOSED ALGEBRA FOR  MATRICES IS COMPLETED
C ***
      DO 10 IAT = 1, NTAUQ
      C1 = (  TAU(1,IAT)*B1(1) + TAU(2,IAT)*B1(2)
     &                         + TAU(3,IAT)*B1(3) ) / ALAT
      C2 = (  TAU(1,IAT)*B2(1) + TAU(2,IAT)*B2(2)
     &                         + TAU(3,IAT)*B2(3) ) / ALAT
      C3 = (  TAU(1,IAT)*B3(1) + TAU(2,IAT)*B3(2)
     &                         + TAU(3,IAT)*B3(3) ) / ALAT
                                  CTAU(1,IAT) = MOD(C1,ONE)
      IF( CTAU(1,IAT) .LT. ZERO ) CTAU(1,IAT) = CTAU(1,IAT) + ONE
                                  CTAU(2,IAT) = MOD(C2,ONE)
      IF( CTAU(2,IAT) .LT. ZERO ) CTAU(2,IAT) = CTAU(2,IAT) + ONE
                                  CTAU(3,IAT) = MOD(C3,ONE)
      IF( CTAU(3,IAT) .LT. ZERO ) CTAU(3,IAT) = CTAU(3,IAT) + ONE
   10 CONTINUE
C
      DO 12 IAT = 1, NTAUQ
      DO 14 IOP = 1, NTOT
      CP1 =  CTAU(1,IAT) * DBLE( S(1,1,IOP) )
     &     + CTAU(2,IAT) * DBLE( S(2,1,IOP) )
     &     + CTAU(3,IAT) * DBLE( S(3,1,IOP) )
      CP2 =  CTAU(1,IAT) * DBLE( S(1,2,IOP) )
     &     + CTAU(2,IAT) * DBLE( S(2,2,IOP) )
     &     + CTAU(3,IAT) * DBLE( S(3,2,IOP) )
      CP3 =  CTAU(1,IAT) * DBLE( S(1,3,IOP) )
     &     + CTAU(2,IAT) * DBLE( S(2,3,IOP) )
     &     + CTAU(3,IAT) * DBLE( S(3,3,IOP) )
                          C1 = MOD(CP1,ONE)
      IF( C1 .LT. ZERO )  C1 = C1 + ONE
                          C2 = MOD(CP2,ONE)
      IF( C2 .LT. ZERO )  C2 = C2 + ONE
                          C3 = MOD(CP3,ONE)
      IF( C3 .LT. ZERO )  C3 = C3 + ONE
C
           NUM = 0
        DO 16 JAT = 1, NTAUQ
        IF( ABS(C1-CTAU(1,JAT)) .GT. 0.1D-04 ) GO TO 16
        IF( ABS(C2-CTAU(2,JAT)) .GT. 0.1D-04 ) GO TO 16
        IF( ABS(C3-CTAU(3,JAT)) .GT. 0.1D-04 ) GO TO 16
           NUM = NUM + 1
C          WRITE(6,1020) IAT, JAT, IOP
C1020      FORMAT(10X,3X,I4,'-TH ATOM IS MAPPED ON ',I4,'-TH ATOM ',
C    &                      ' BY ',I2,'-TH OPERATION.')
   16   CONTINUE
C
      IF(NUM.EQ.0) THEN
      WRITE(6,1040) IOP, IAT, C1, C2, C3
 1040 FORMAT(10X,'   SYMMETRY OPERATION ',I3,' ON ',I4,'TH ATOM NOT',
     &           ' TRANSFORM ANOTHER ATOM.'/
     &       10X,'     C1 C2 C3 = ',3D18.10)
      STOP
      END IF
C
   14 CONTINUE
   12 CONTINUE
C
      WRITE(6,1100)
 1100 FORMAT(
     &'                 NORMAL END')
C
      RETURN
      END
C *******************************************************************
      SUBROUTINE CRDAN( IND, TAU, RTAU, NTAUQ )
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
      DIMENSION  TAU(3,NTAUQ), RTAU(3,NTAUQ)
      COMMON /AVEC/  A1(3), A2(3), A3(3), B1(3), B2(3), B3(3)
     &             , COVA, ALAT
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
C
      DO 1 I = 1, NTAUQ
      DO 1 K = 1, 3
    1 RTAU(K,I) = 0.0D+00
      DO 2 I = 1, NTAUQ
        DO 3 K = 1, 3
        RTAU(1,I) = RTAU(1,I) + B1(K) * TAU(K,I)
        RTAU(2,I) = RTAU(2,I) + B2(K) * TAU(K,I)
    3   RTAU(3,I) = RTAU(3,I) + B3(K) * TAU(K,I)
        DO 4 K = 1, 3
    4   RTAU(K,I) =  RTAU(K,I) / ALAT
    2 CONTINUE
C **
C        HEXAGONAL ALPHA QUARTZ CASE
      IF( IND .EQ. 2 ) THEN
        if ( my_rank.eq.0 ) then
        WRITE(6,1000)
 1000   FORMAT(//'     ****** CRDAN:    HEXAGONAL ALPHA QUARTZ')
        DO 100 I = 1, NTAUQ
  100   WRITE(6,1100) I, ( RTAU(K,I), K = 1, 3 )
 1100   FORMAT(12X,' ATOM ',I4,' RTAU = ',3D13.5)
        WRITE(6,*) ' '
        endif
      ELSE
        if ( my_rank.eq.0 ) then
        WRITE(6,*) ' IND .NE. 2:  NOT PROGRAMMED IND = ', IND
        endif
      END IF
C
      RETURN
      END
