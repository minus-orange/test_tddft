CSTART OF GGA *****C
C**************************************************************C
       SUBROUTINE G2VXC2(TPIBA,NRX,NRY,NRZ,NXYZ,NG,NGQ,G,
     & VCSR,RHO,RHOG,I2G,
c ++ for Sugino FFT
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,
     & LY1,LY2,LZ1,LZ2,
c ++ for Kokubo ASL FFT
c     & WSAVE_XYZ,IFAC_XYZ,
c ++ for Kokubo FFTW
c     & plancfp,plancbp,
     &  DRX,DRY,DRZ,DRXX,DRYY,DRZZ,DRXY,DRYZ,DRZX,VWORK  )
      IMPLICIT REAL*8(A-H,O-Z)
      REAL*8 RHO(NXYZ)
      COMPLEX*16 VCSR(NXYZ),RHOG(NXYZ)
c *** for Sugino FFT
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo ASL FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c      DIMENSION IFAC_XYZ(60)
c *** for Kokubo FFTW
c      integer*8 plancfp,plancbp
      DIMENSION I2G(NGQ),G(4,NGQ)
c      COMMON/GAS/FK,SK,GPOL,ECLOC,ECRS,ECZET
C ---  for GGA
      COMPLEX*16 DRX(NXYZ) ,DRY(NXYZ) ,DRZ(NXYZ)
      COMPLEX*16 DRXX(NXYZ),DRYY(NXYZ),DRZZ(NXYZ)
      COMPLEX*16 DRXY(NXYZ),DRYZ(NXYZ),DRZX(NXYZ)
      COMPLEX*16 VWORK(NXYZ)
C **** for check
c      call clock(t0)
c **** check end
c
      PI = 4.D0*DATAN(1.D0)
      THRD2 = 2.0D0/3.0D0
      TPIBA2 = TPIBA*TPIBA
c ***  max of RHO
c      gmax=-1000.d0 
c      do ig=1,nxyz
c      if ( rho(ig).gt.0 ) then
c       gmax=max(rho(ig),gmax)
c      endif
c      enddo
c      gdiv=gmax/100.d0
cc      GMIN=gdiv/256.d0    ! take more than 0.00390625% of max of rho.
c      GMIN=gdiv/1000.d0    ! take more than 0.00390625% of max of rho.
c      write(6,*)' GMIN = ',GMIN
c ***  min of RHO
c      GMIN=1.d+20
c      do ig=1,nxyz
c      if ( rho(ig).gt.0 ) then
c       GMIN=min(rho(ig),GMIN)
c      endif
c      enddo
c ***  
      GMIN=1.0D-15
C
c ++ temp check
c       sum=0
c       do ig=1,NXYZ
c       sum=sum+rho(ig)
c       enddo
c       write(6,*)' In sub. G2VXC2: sum = ',sum
c       miya=13
c       if (miya.eq.13 ) stop
c ** check end
C
       DO JG = 1, NXYZ
        DRX(JG)  = (0.0D0,0.0D0)
        DRY(JG)  = (0.0D0,0.0D0)
        DRZ(JG)  = (0.0D0,0.0D0)
        DRXX(JG) = (0.0D0,0.0D0)
        DRYY(JG) = (0.0D0,0.0D0)
        DRZZ(JG) = (0.0D0,0.0D0)
        DRXY(JG) = (0.0D0,0.0D0) 
        DRYZ(JG) = (0.0D0,0.0D0)
        DRZX(JG) = (0.0D0,0.0D0)
       END DO
C
       DO IG = 2, NG
        JG = I2G(IG)
        DRX(JG)  = TPIBA*(0,1)*G(1,IG)*RHOG(JG)
        DRY(JG)  = TPIBA*(0,1)*G(2,IG)*RHOG(JG)
        DRZ(JG)  = TPIBA*(0,1)*G(3,IG)*RHOG(JG)
        DRXX(JG) =  - TPIBA2*G(1,IG)*G(1,IG)*RHOG(JG)
        DRYY(JG) =  - TPIBA2*G(2,IG)*G(2,IG)*RHOG(JG)
        DRZZ(JG) =  - TPIBA2*G(3,IG)*G(3,IG)*RHOG(JG)
        DRXY(JG) =  - TPIBA2*G(1,IG)*G(2,IG)*RHOG(JG)
        DRYZ(JG) =  - TPIBA2*G(2,IG)*G(3,IG)*RHOG(JG)
        DRZX(JG) =  - TPIBA2*G(3,IG)*G(1,IG)*RHOG(JG)
       END DO
C
C --- TRANSFORM TO R-SPACE ----
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRX, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRX, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRX,plancfp,plancbp)
C
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRY, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRY, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRY,plancfp,plancbp)
C
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRZ, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRZ, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRZ,plancfp,plancbp)
C
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRXX, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRXX, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRXX,plancfp,plancbp)
C
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRYY, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRYY, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRYY,plancfp,plancbp)
C
c **** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRZZ, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c **** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRZZ, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRZZ,plancfp,plancbp)
C
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRXY, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRXY, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRXY,plancfp,plancbp)
C
c **** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRYZ, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c **** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRYZ, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRYZ,plancfp,plancbp)
C
c **** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRZX, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c **** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRZX, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,DRZX,plancfp,plancbp)
C
      DO 100 IG = 1, NXYZ
       VX    = 0.0D0
       VCLOC = 0.0D0
       VCGGA = 0.0D0
       VCSR(IG) = (0.0D0,0.0D0)
       DEN   = RHO(IG)
      IF(DEN.GT.0) THEN
       DX    = DBLE(DRX(IG))
       DY    = DBLE(DRY(IG))
       DZ    = DBLE(DRZ(IG))
       ABSD  = SQRT(DX*DX+DY*DY+DZ*DZ)
      IF(DEN.LT.GMIN.OR.ABSD.LT.GMIN) GO TO 200
c      IF(DEN.LT.GMIN) GO TO 200
       DXX   = DBLE(DRXX(IG))
       DYY   = DBLE(DRYY(IG))
       DZZ   = DBLE(DRZZ(IG))
       DXY   = DBLE(DRXY(IG))
       DYZ   = DBLE(DRYZ(IG))
       DZX   = DBLE(DRZX(IG))
       U0    = ( DX*(DX*DXX+DY*DXY+DZ*DZX)
     &       +   DY*(DX*DXY+DY*DYY+DZ*DYZ)
     &       +   DZ*(DX*DZX+DY*DYZ+DZ*DZZ))/ABSD
       V0    =  DXX + DYY + DZZ
       DRXX(IG)=DCMPLX(U0,V0)
C ---  GGA EXCHANGE ---
       RS =  (3.0D0/(4.0D0*PI*RHO(IG)))**(1.0D0/3.0D0)
       FK = 1.91915829D0/RS
       S  = ABSD / (2.0D0*FK*DEN)
       U1 = U0 /((2.0D0*FK)**3*DEN**2)
       V1 = V0 /((2.0D0*FK)**2*DEN)
       DRYY(IG)=DCMPLX(U1,V1)
       VWORK(IG)=DCMPLX( ABSD,S)
 200  CONTINUE  
      END IF
 100  CONTINUE
c
c       CALL EXCHPBE(DEN,S,U1,V1,1,1,EX,VX)
       CALL EXCHPBE(RHO,VWORK,DRYY,1,1,DRZZ,NXYZ,GMIN)
C --- LDA CORRELATION ---
c       CALL CORLSD(RS,0,ECLOC,VCLOC,VCDN,ECRS,ECZET,ALFC)
c       zzero=0
c       CALL CORLSD(RHO,VWORK,zzero,DRXY,DRYZ,DRZX,NXYZ,GMIN)
C --- GGA CORRELATION ---
       ZET = 0
       GPOL = ((1.D0+ZET)**THRD2+(1.D0-ZET)**THRD2)/2.D0
       DO 300 IG=1,NXYZ
       DEN   = RHO(IG)
       IF ( DEN.GT. 0 ) THEN
       ABSD=real( VWORK(IG) )
       IF ( DEN.LT.GMIN .OR. ABSD.LT.GMIN ) GOTO 400
c       IF ( DEN.LT.GMIN  ) GOTO 400
       RS =  (3.0D0/(4.0D0*PI*RHO(IG)))**(1.0D0/3.0D0)
       FK = 1.91915829D0/RS
       SK = DSQRT(4.D0*FK/PI)
c       GPOL = ((1.D0+ZET)**THRD2+(1.D0-ZET)**THRD2)/2.D0
c       T  =  ABSD/(2.0D0*SK*DEN*GPOL)
       U0=real( DRXX(IG) )
       V0=imag( DRXX(IG) )
       U2 =  U0 /(DEN**2 * (2.0D0*SK*GPOL)**3)
       V2 =  V0 /(DEN * (2.0D0*SK*GPOL)**2)
       DRYY(IG)=DCMPLX(U2,V2)
  400  CONTINUE
       ENDIF
  300  CONTINUE
c
c       CALL  CORPBE(RS,0,T,U2,V2,0,1,1,EC,VCUP,VCDN
c     &     ,H,DVCUP,DVCDN)
       zzero=0
       zzero2=0
c  *** note FK and SH should be rebuild in CORPBE !!!
       CALL CORPBE(RHO,VWORK,zzero,DRYY,zzero2,1,1,DRX,DRY,DRZ
     &     ,DRXY,DRYZ,DRZX,NXYZ,GMIN)
c
      DO 500 IG=1,NXYZ
      DEN= RHO(IG)
      IF ( DEN.GT.0 ) THEN
      ABSD=real( VWORK(IG) )
      IF ( DEN.LT.GMIN .OR. ABSD.LT.GMIN ) GOTO 600
c      IF ( DEN.LT.GMIN ) GOTO 600
c       VCSR(IG) = VX + VCLOC + VCGGA
c                    Vx          +VcLSD          +VcPBEcorrection
      VCSR(IG)=aimag( DRZZ(IG) )+dreal( DRY(IG) )+dreal( DRYZ(IG) )
  600 CONTINUE
      ENDIF
  500 CONTINUE
c *** for check
c      call clock(t1)
c      write(6,*)' G2VXC2 took ',t1-t0,'seconds'
c *** check end
      RETURN
      END
C
       SUBROUTINE G2XC2(TPIBA, NRX,NRY,NRZ,NXYZ,NG,NGQ,G,
     & RHO,RHOG,I2G,
c *** for Sugino FFT
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,
     & LZ1,LZ2,EXC,VCSR,DRX,DRY,DRZ,DRXX,DRYY,DRZZ,
c *** for Kokubo ASL FFT
c     & WSAVE_XYZ,IFAC_XYZ,EXC,VCSR,DRX,DRY,DRZ,DRXX,DRYY,DRZZ,
c *** for Kokubo ASL FFT
c     & plancfp,plancbp,EXC,VCSR,DRX,DRY,DRZ,DRXX,DRYY,DRZZ,
     &                              DRXY,DRYZ,DRZX,VWORK)
      IMPLICIT REAL*8(A-H,O-Z)
      REAL*8 RHO(NXYZ)
c       REAL*8 VCSR(NXYZ), RHO(NXYZ)
      COMPLEX*16 VCSR(NXYZ), RHOG(NXYZ)
c      COMPLEX*16 RHOG(NXYZ)
c *** for Sugino FFT
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo ASK FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c      DIMENSION IFAC_XYZ(60)
c *** for Kokubo FFTW
c      integer*8 plancfp,plancbp
      DIMENSION I2G(NGQ),G(4,NGQ)
c      COMMON/GAS/FK,SK,GPOL,ECLOC,ECRS,ECZET
C --- for GGA  
      COMPLEX*16 DRX(NXYZ),DRY(NXYZ),DRZ(NXYZ)
     &         ,DRXX(NXYZ),DRYY(NXYZ),DRZZ(NXYZ)
     &         ,DRXY(NXYZ),DRYZ(NXYZ),DRZX(NXYZ)
      COMPLEX*16 VWORK(NXYZ)
C
      PI = 4.D0*DATAN(1.D0)
      THRD2 = 2.0D0/3.0D0
c ***  max of RHO
c      gmax=-1000.d0
c      do ig=1,nxyz
c      if ( rho(ig).gt.0 ) then
c       gmax=max(rho(ig),gmax)
c      endif
c      enddo
c      gdiv=gmax/100.d0
cc      GMIN=gdiv/256.d0    ! take more than 0.00390625% of max of rho.
c      GMIN=gdiv/1000.d0    ! take more than 0.00390625% of max of rho.
c ***  min of RHO
c      GMIN=1.d+20
c      do ig=1,nxyz
c      if ( rho(ig).gt.0 ) then
c       GMIN=min(rho(ig),GMIN)
c      endif
c      enddo
c ***
c ***
      GMIN=1.0D-15
C
C
       DO JG = 1, NXYZ
        DRX(JG)  = (0.0D0,0.0D0)
        DRY(JG)  = (0.0D0,0.0D0)
        DRZ(JG)  = (0.0D0,0.0D0)
       END DO
C
       DO IG = 2, NG
        JG = I2G(IG)
        DRX(JG)  = TPIBA*(0,1)*G(1,IG)*RHOG(JG)
        DRY(JG)  = TPIBA*(0,1)*G(2,IG)*RHOG(JG)
        DRZ(JG)  = TPIBA*(0,1)*G(3,IG)*RHOG(JG)
       END DO
C
C --- TRANSFORM TO R-SPACE ----
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRX, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRX, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c        call FFT3BX_fftw(NXYZ,DRX,plancfp,plancbp)
C
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRY, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRY, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c        call FFT3BX_fftw(NXYZ,DRY,plancfp,plancbp)
c *** for Sugino FFT
        CALL FFT3BX( NRX, NRY, NRZ, NXYZ, DRZ, VWORK,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c        CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, DRZ, VWORK,
c     &              WSAVE_XYZ, IFAC_XYZ                 )
c *** for Kokubo FFTW
c        call FFT3BX_fftw(NXYZ,DRZ,plancfp,plancbp)
c
      DO 100 IG = 1, NXYZ
       EX    = 0.0D0
       ECLOC = 0.0D0
       H     = 0.0D0
       VCSR(IG) = 0.0D0
       DEN   = RHO(IG)
      IF(DEN.GT.0.0D0) THEN
       DX    = DBLE(DRX(IG))
       DY    = DBLE(DRY(IG))
       DZ    = DBLE(DRZ(IG))
       ABSD  = SQRT(DX*DX+DY*DY+DZ*DZ)
      IF(DEN.LT.GMIN.OR.ABSD.LT.GMIN) GO TO 200
c      IF(DEN.LT.GMIN) GO TO 200
C ---  GGA EXCHANGE ---
       RS =  (3.0D0/(4.0D0*PI*RHO(IG)))**(1.0D0/3.0D0)
       FK = 1.91915829D0/RS
       S  = ABSD / (2.0D0*FK*DEN)
       U1 = 0.0D0
       V1 = 0.0D0
      DRYY(IG)=DCMPLX(U1,V1)
      VWORK(IG)=DCMPLX(ABSD,S)
 200  CONTINUE
      END IF
 100  CONTINUE
C
c       CALL  EXCHPBE(DEN,S,U1,V1,EX,VX)
       CALL  EXCHPBE(RHO,VWORK,DRYY,1,0,DRZZ,NXYZ,GMIN)
C --- LDA CORRELATION ---
c       CALL CORLSD(RS,0,ECLOC,VCLOC,VCDN,ECRS,ECZET,ALFC)
c       zzero=0
c       CALL CORLSD(RHO,VWORK,zzero,DRXY,DRYZ,DRZX,NXYZ,GMIN)
c
C --- GGA CORRELATION ---
       ZET = 0
       GPOL = ((1.D0+ZET)**THRD2+(1.D0-ZET)**THRD2)/2.D0
       DO 300 IG=1,NXYZ
       DRYY(IG)=dcmplx(0.d0,0.d0)
  300  CONTINUE
c
c       CALL  CORPBE(RS,0,T,U2,V2,0,1,1,EC,VCUP,VCDN
c     &     ,H,DVCUP,DVCDN)
       zzero=0
       zzero2=0
c  *** note FK and SH should be rebuild in CORPBE !!!
       CALL CORPBE(RHO,VWORK,zzero,DRYY,zzero2,1,0,DRX,DRY,DRZ
     &     ,DRXY,DRYZ,DRZX,NXYZ,GMIN)
c
      DO IG=1,NXYZ
c *****            Ex      +  EcLSD   +  H (EcPBEcorrection)   
       VCSR(IG)=( dreal(DRZZ(IG) )+dreal(DRX(IG) )
     &           +dreal(DRXY(IG) ) )*RHO(IG)
      ENDDO
c     
        EXC = 0.0D0
      DO IG = 1, NXYZ
        EXC = EXC + DBLE(VCSR(IG))
      END DO
      RETURN
      END
c----------------------------------------------------------------------
c######################################################################
c----------------------------------------------------------------------
c      SUBROUTINE EXCHPBE(rho,S,U,V,lgga,lpot,EX,VX)
      SUBROUTINE EXCHPBE(rho,VWORK,DRYY,lgga,lpot,DRZZ,NXYZ,GMIN)
c----------------------------------------------------------------------
C  PBE EXCHANGE FOR A SPIN-UNPOLARIZED ELECTRONIC SYSTEM
c  K Burke's modification of PW91 codes, May 14, 1996
c  Modified again by K. Burke, June 29, 1996, with simpler Fx(s)
c----------------------------------------------------------------------
c----------------------------------------------------------------------
C  INPUT rho : DENSITY
C  INPUT S:  ABS(GRAD rho)/(2*KF*rho), where kf=(3 pi^2 rho)^(1/3)
C  INPUT U:  (GRAD rho)*GRAD(ABS(GRAD rho))/(rho**2 * (2*KF)**3)
C  INPUT V: (LAPLACIAN rho)/(rho*(2*KF)**2)
c   (for U,V, see PW86(24))
c  input lgga:  (=0=>don't put in gradient corrections, just LDA)
c  input lpot:  (=0=>don't get potential and don't need U and V)
C  OUTPUT:  EXCHANGE ENERGY PER ELECTRON (EX) AND POTENTIAL (VX)
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c References:
c [a]J.P.~Perdew, K.~Burke, and M.~Ernzerhof, submiited to PRL, May96
c [b]J.P. Perdew and Y. Wang, Phys. Rev.  B {\bf 33},  8800  (1986);
c     {\bf 40},  3399  (1989) (E).
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c Formulas:
c   	e_x[unif]=ax*rho^(4/3)  [LDA]
c ax = -0.75*(3/pi)^(1/3)
c	e_x[PBE]=e_x[unif]*FxPBE(s)
c	FxPBE(s)=1+uk-uk/(1+ul*s*s)                 [a](13)
c uk, ul defined after [a](13) 
c----------------------------------------------------------------------
c----------------------------------------------------------------------
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION RHO(NXYZ)
      COMPLEX*16 VWORK(NXYZ),DRYY(NXYZ),DRZZ(NXYZ)
      parameter(thrd=1.d0/3.d0,thrd4=4.d0/3.d0)
      parameter(pi=3.14159265358979323846264338327950d0)
      parameter(ax=-0.738558766382022405884230032680836d0)
      parameter(um=0.2195149727645171d0,uk=0.8040d0,ul=um/uk)
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c construct LDA exchange energy density
ccc      exunif = AX*rho**THRD
      if(lgga.eq.0)then
      do ig=1,nxyz
      exunif = AX*rho(ig)**THRD
	ex=exunif
        vx=ex*thrd4
      DRZZ(IG)=DCMPLX(EX,VX)
      enddo
	return
      endif
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c construct PBE enhancement factor
c      
      if(lpot.eq.0) then
      do ig=1,NXYZ
      exunif = AX*rho(ig)**THRD
      S=aimag(VWORK(IG))
      U=dreal(DRYY(IG) )
      V=aimag(DRYY(IG) )
      S2 = S*S
      P0=1.d0+ul*S2
      FxPBE = 1d0+uk-uk/P0
      EX = exunif*FxPBE
      DRZZ(IG)=DCMPLX(EX,0.d0)
      enddo
      endif      
      if(lpot.eq.0)return
c----------------------------------------------------------------------
c----------------------------------------------------------------------
C  ENERGY DONE. NOW THE POTENTIAL:
c  find first and second derivatives of Fx w.r.t s.
c  Fs=(1/s)*d FxPBE/ ds
c  Fss=d Fs/ds
c      Fs=2.d0*uk*ul/(P0*P0)   ! moved into do loop (P0 depends on S)
c      Fss=-4.d0*ul*S*Fs/P0    ! moved into do loop
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c calculate potential from [b](24) 
      do ig=1,NXYZ
      exunif = AX*rho(ig)**THRD
      S=aimag(VWORK(IG))
      U=dreal(DRYY(IG) )
      V=aimag(DRYY(IG) )
      S2 = S*S
      P0=1.d0+ul*S2
      FxPBE = 1d0+uk-uk/P0
      EX = exunif*FxPBE
      Fs=2.d0*uk*ul/(P0*P0)
      Fss=-4.d0*ul*S*Fs/P0
      VX = exunif*(THRD4*FxPBE-(U-THRD4*S2*s)*FSS-V*FS)
      DRZZ(IG)=DCMPLX(EX,VX)
      enddo
      RETURN
      END
c----------------------------------------------------------------------
c######################################################################
c----------------------------------------------------------------------
c      SUBROUTINE CORPBE(RS,ZET,T,UU,VV,WW,lgga,lpot,ec,vcup,vcdn,
c     1                  H,DVCUP,DVCDN)
      SUBROUTINE CORPBE(RHO,VWORK,ZET,DRYY,WW,lgga,lpot,DRX,DRY,DRZ,
     1                  DRXY,DRYZ,DRZX,NXYZ,GMIN)
c----------------------------------------------------------------------
c  Official PBE correlation code. K. Burke, May 14, 1996.
C  INPUT: RS=SEITZ RADIUS=(3/4pi rho)^(1/3)
C       : ZET=RELATIVE SPIN POLARIZATION = (rhoup-rhodn)/rho
C       : t=ABS(GRAD rho)/(rho*2.*KS*G)  -- only needed for PBE and made
C       :                                   from RS 
C       : UU=(GRAD rho)*GRAD(ABS(GRAD rho))/(rho**2 * (2*KS*G)**3)
C       : VV=(LAPLACIAN rho)/(rho * (2*KS*G)**2)
C       : WW=(GRAD rho)*(GRAD ZET)/(rho * (2*KS*G)**2
c       :  UU,VV,WW, only needed for PBE potential
c       : lgga=flag to do gga (0=>LSD only)
c       : lpot=flag to do potential (0=>energy only)
c  output: ec=lsd correlation energy from [a]
c        : vcup=lsd up correlation potential
c        : vcdn=lsd dn correlation potential
c        : h=NONLOCAL PART OF CORRELATION ENERGY PER ELECTRON
c        : dvcup=nonlocal correction to vcup
c        : dvcdn=nonlocal correction to vcdn
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c References:
c [a] J.P.~Perdew, K.~Burke, and M.~Ernzerhof, 
c     {\sl Generalized gradient approximation made simple}, sub.
c     to Phys. Rev.Lett. May 1996.
c [b] J. P. Perdew, K. Burke, and Y. Wang, {\sl Real-space cutoff
c     construction of a generalized gradient approximation:  The PW91
c     density functional}, submitted to Phys. Rev. B, Feb. 1996.
c [c] J. P. Perdew and Y. Wang, Phys. Rev. B {\bf 45}, 13244 (1992).
c----------------------------------------------------------------------
c----------------------------------------------------------------------
      IMPLICIT REAL*8 (A-H,O-Z)
c thrd*=various multiples of 1/3
c numbers for use in LSD energy spin-interpolation formula, [c](9).
c      GAM= 2^(4/3)-2
c      FZZ=f''(0)= 8/(9*GAM)
c numbers for construction of PBE
c      gamma=(1-log(2))/pi^2
c      bet=coefficient in gradient expansion for correlation, [a](4).
c      eta=small number to stop d phi/ dzeta from blowing up at 
c          |zeta|=1.
      parameter(thrd=1.d0/3.d0,thrdm=-thrd,thrd2=2.d0*thrd)
      parameter(sixthm=thrdm/2.d0)
      parameter(thrd4=4.d0*thrd)
      parameter(GAM=0.5198420997897463295344212145565d0)
      parameter(fzz=8.d0/(9.d0*GAM))
      parameter(gamma=0.03109069086965489503494086371273d0)
      parameter(bet=0.06672455060314922d0,delt=bet/gamma)
      parameter(eta=1.d-12)
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c find LSD energy contributions, using [c](10) and Table I[c].
c EU=unpolarized LSD correlation energy
c EURS=dEU/drs
c EP=fully polarized LSD correlation energy
c EPRS=dEP/drs
c ALFM=-spin stiffness, [c](3).
c ALFRSM=-dalpha/drs
c F=spin-scaling factor from [c](9).
c construct ec, using [c](8)
      DIMENSION RHO(NXYZ)
      COMPLEX*16 VWORK(NXYZ)
      COMPLEX*16 DRX(NXYZ),DRY(NXYZ),DRZ(NXYZ),DRYY(NXYZ)
      COMPLEX*16 DRXY(NXYZ),DRYZ(NXYZ),DRZX(NXYZ)
      pi=dacos(-1.d0)
      DO IG=1,NXYZ
      DEN   = RHO(IG)
ccc      IF ( DEN.LE. 0 ) GOTO 400
      ABSD=real( VWORK(IG) )
      IF ( DEN.LT.GMIN .OR. ABSD.LT.GMIN ) GOTO 400
c      IF ( DEN.LT.GMIN  ) GOTO 400
      RS =  (3.0D0/(4.0D0*PI*RHO(IG)))**(1.0D0/3.0D0)
      FK = 1.91915829D0/RS
      SK = DSQRT(4.D0*FK/PI)
      GPOL = ((1.D0+ZET)**THRD2+(1.D0-ZET)**THRD2)/2.D0
      T  =  ABSD/(2.0D0*SK*DEN*GPOL)
      rtrs=dsqrt(rs)
      UU=dreal(DRYY(IG))
      VV=aimag(DRYY(IG))
c *****  SUBROUTINE GCOR2(A,A1,B1,B2,B3,B4,rtrs,GG,GGRS)
c      CALL gcor2(0.0310907D0,0.21370D0,7.5957D0,3.5876D0,1.6382D0,
c     1    0.49294D0,rtrs,EU,EURS)
      A= 0.0310907D0
      A1=0.21370D0
      B1=7.5957D0
      B2=3.5876D0
      B3=1.6382D0
      B4=0.49294D0
      Q0 = -2.D0*A*(1.D0+A1*rtrs*rtrs)
      Q1 = 2.D0*A*rtrs*(B1+rtrs*(B2+rtrs*(B3+B4*rtrs)))
      Q2 = DLOG(1.D0+1.D0/Q1)
      EU = Q0*Q2
      Q3 = A*(B1/rtrs+2.D0*B2+rtrs*(3.D0*B3+4.D0*B4*rtrs))
      EURS = -2.D0*A*A1*Q2-Q0*Q3/(Q1*(1.d0+Q1))
c      CALL gcor2(0.01554535D0,0.20548D0,14.1189D0,6.1977D0,3.3662D0,
c     1    0.62517D0,rtRS,EP,EPRS)
      A= 0.01554535D0
      A1=0.20548D0
      B1=14.1189D0
      B2=6.1977D0
      B3=3.3662D0
      B4=0.62517D0
      Q0 = -2.D0*A*(1.D0+A1*rtrs*rtrs)
      Q1 = 2.D0*A*rtrs*(B1+rtrs*(B2+rtrs*(B3+B4*rtrs)))
      Q2 = DLOG(1.D0+1.D0/Q1)
      EP = Q0*Q2
      Q3 = A*(B1/rtrs+2.D0*B2+rtrs*(3.D0*B3+4.D0*B4*rtrs))
      EPRS = -2.D0*A*A1*Q2-Q0*Q3/(Q1*(1.d0+Q1))
c      CALL gcor2(0.0168869D0,0.11125D0,10.357D0,3.6231D0,0.88026D0,
c     1    0.49671D0,rtRS,ALFM,ALFRSM)
      A= 0.0168869D0
      A1=0.11125D0
      B1=10.357D0
      B2=3.6231D0
      B3=0.88026D0
      B4=0.49671D0
      Q0 = -2.D0*A*(1.D0+A1*rtrs*rtrs)
      Q1 = 2.D0*A*rtrs*(B1+rtrs*(B2+rtrs*(B3+B4*rtrs)))
      Q2 = DLOG(1.D0+1.D0/Q1)
      ALFM = Q0*Q2
      Q3 = A*(B1/rtrs+2.D0*B2+rtrs*(3.D0*B3+4.D0*B4*rtrs))
      ALFRSM = -2.D0*A*A1*Q2-Q0*Q3/(Q1*(1.d0+Q1))
      ALFC = -ALFM
      Z4 = ZET**4
      F=((1.D0+ZET)**THRD4+(1.D0-ZET)**THRD4-2.D0)/GAM
      EC = EU*(1.D0-F*Z4)+EP*F*Z4-ALFM*F*(1.D0-Z4)/FZZ
      DRX(IG)=DCMPLX(EC,0)   ! correlation by LSD part
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c LSD potential from [c](A1)
c ECRS = dEc/drs [c](A2)
c ECZET=dEc/dzeta [c](A3)
c FZ = dF/dzeta [c](A4)
      ECRS = EURS*(1.D0-F*Z4)+EPRS*F*Z4-ALFRSM*F*(1.D0-Z4)/FZZ
      FZ = THRD4*((1.D0+ZET)**THRD-(1.D0-ZET)**THRD)/GAM
      ECZET = 4.D0*(ZET**3)*F*(EP-EU+ALFM/FZZ)+FZ*(Z4*EP-Z4*EU
     1        -(1.D0-Z4)*ALFM/FZZ)
      COMM = EC -RS*ECRS/3.D0-ZET*ECZET
      VCUP = COMM + ECZET
      VCDN = COMM - ECZET
      DRY(IG)=DCMPLX(VCUP,0)
      DRZ(IG)=DCMPLX(VCDN,0)
ccc      if(lgga.eq.0)return
      if(lgga.eq.0) GOTO 400
c----------------------------------------------------------------------
c----------------------------------------------------------------------
c PBE correlation energy
c G=phi(zeta), given after [a](3)
c DELT=bet/gamma
c B=A of [a](8)
      G=((1.d0+ZET)**thrd2+(1.d0-ZET)**thrd2)/2.d0
      G3 = G**3
      PON=-EC/(G3*gamma)
      B = DELT/(DEXP(PON)-1.D0)
      B2 = B*B
      T2 = T*T
      T4 = T2*T2
      RS2 = RS*RS
      RS3 = RS2*RS
      Q4 = 1.D0+B*T2
      Q5 = 1.D0+B*T2+B2*T4
      H = G3*(BET/DELT)*DLOG(1.D0+DELT*Q4*T2/Q5)
      DRXY(IG)=DCMPLX(H,0)
c      if(lpot.eq.0)return
      if(lpot.eq.0) GOTO 400
c----------------------------------------------------------------------
c----------------------------------------------------------------------
C ENERGY DONE. NOW THE POTENTIAL, using appendix E of [b].
      G4 = G3*G
      T6 = T4*T2
      RSTHRD = RS/3.D0
      GZ=(((1.d0+zet)**2+eta)**sixthm-
     1((1.d0-zet)**2+eta)**sixthm)/3.d0
      FAC = DELT/B+1.D0
      BG = -3.D0*B2*EC*FAC/(BET*G4)
      BEC = B2*FAC/(BET*G3)
      Q8 = Q5*Q5+DELT*Q4*Q5*T2
      Q9 = 1.D0+2.D0*B*T2
      hB = -BET*G3*B*T6*(2.D0+B*T2)/Q8
      hRS = -RSTHRD*hB*BEC*ECRS
      FACT0 = 2.D0*DELT-6.D0*B
      FACT1 = Q5*Q9+Q4*Q9*Q9
      hBT = 2.D0*BET*G3*T4*((Q4*Q5*FACT0-DELT*FACT1)/Q8)/Q8
      hRST = RSTHRD*T2*hBT*BEC*ECRS
      hZ = 3.D0*GZ*h/G + hB*(BG*GZ+BEC*ECZET)
      hT = 2.d0*BET*G3*Q9/Q8
      hZT = 3.D0*GZ*hT/G+hBT*(BG*GZ+BEC*ECZET)
      FACT2 = Q4*Q5+B*T2*(Q4*Q9+Q5)
      FACT3 = 2.D0*B*Q5*Q9+DELT*FACT2
      hTT = 4.D0*BET*G3*T*(2.D0*B/Q8-(Q9*FACT3/Q8)/Q8)
      COMM = H+HRS+HRST+T2*HT/6.D0+7.D0*T2*T*HTT/6.D0
      PREF = HZ-GZ*T2*HT/G
      FACT5 = GZ*(2.D0*HT+T*HTT)/G
      COMM = COMM-PREF*ZET-UU*HTT-VV*HT-WW*(HZT-FACT5)
      DVCUP = COMM + PREF
      DVCDN = COMM - PREF
c      DRYZ(IG)=DCMPLX(DCUP,0)
c      DRZX(IG)=DCMPLX(DCDN,0)
      DRYZ(IG)=DCMPLX(DVCUP,0)
      DRZX(IG)=DCMPLX(DVCDN,0)
  400 CONTINUE
      ENDDO
      RETURN
      END
c----------------------------------------------------------------------
c######################################################################
c----------------------------------------------------------------------
      SUBROUTINE GCOR2(A,A1,B1,B2,B3,B4,rtrs,GG,GGRS)
c slimmed down version of GCOR used in PW91 routines, to interpolate
c LSD correlation energy, as given by (10) of
c J. P. Perdew and Y. Wang, Phys. Rev. B {\bf 45}, 13244 (1992).
c K. Burke, May 11, 1996.
      IMPLICIT REAL*8 (A-H,O-Z)
      Q0 = -2.D0*A*(1.D0+A1*rtrs*rtrs)
      Q1 = 2.D0*A*rtrs*(B1+rtrs*(B2+rtrs*(B3+B4*rtrs)))
      Q2 = DLOG(1.D0+1.D0/Q1)
      GG = Q0*Q2
      Q3 = A*(B1/rtrs+2.D0*B2+rtrs*(3.D0*B3+4.D0*B4*rtrs))
      GGRS = -2.D0*A*A1*Q2-Q0*Q3/(Q1*(1.d0+Q1))
      RETURN
      END
