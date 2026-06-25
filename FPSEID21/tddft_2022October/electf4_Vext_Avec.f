C------------PROGRAM UNIT FORCE-------------------------
C******************************************************
C FORCE
C                               1990-11-25 OSAMU SUGINO
C    ELECTF---LOCPOTF---S2XC2
C          !
C          ---NONLOCF---NONLF
C          !        !
C          !        ---SEPPOTF
C          !
C          ---SYMFRC
C
C*****************************************************
c      SUBROUTINE ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
      SUBROUTINE ELECTF(MXBND,MXBND0,MBLK,NXYZ,NG,NGQ,NG2, NG2Q,
     &     NBNDQ, NBND, NUMK, NUMKQ, NBSEQ,COEF, DCOEF,
     &                   YLM, G, EXPG, G2, RHO, RHO4, RHO1, RHO2,RHOG,
     &                   RHOAX,RHOAY,RHOAZ,
     &                   TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ,
     &                   VPP, IOWF, IOVP, OMEGA, FORCE, DFORCE,
     &                   SFORCE,
     &                   NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &                   NKMESH, NEXPND, NFL, EE,PX,PY,PZ
     &                             EENL, RCOSIN, WK,
     &                   VINT, NSY, FXNL, FYNL, FZNL,
     &                   TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &      ZZ, ZVAL, NPFL, MXOFL, OCC,itstep,VGA,GDUMP,NGNL
     &                  ,NRX,NRY,NRZ
c +++ for A-vector +++ (Ework work by A-vector)) Y. Miyamoto 2020
     &     ,GDUMPd,EEd,EKINEd
c *** for Sugino FFT
c     &                  ,WSAVEX,WSAVEY,WSAVEZ
c     &                  ,LX1,LX2,LY1
c     &                  ,LY2,LZ1,LZ2
c     &     ,IFACX,IFACY,IFACZ,REXT,WEXT,ft,dft,DELTAd,CWORK)
c *** for Kokubo ASL FFT
c     &      ,WSAVE_XYZ,IFAC_XYZ,REXT,WEXT,ft,dft,DELTAd,CWORK)
c *** for Kokubo FFTW
     &                  ,plancfp,plancbp,REXT,WEXT,ft,dft,DELTAd,CWORK
c
     &     ,NGcont
c
     &   ,nbegin,nend,nbegint,nendt,nbegintt,nendtt,ncpuq,ncpu)
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
c      REAL*8 YLM(NG2Q,4),RHO(NXYZ)
c      REAL*8 YLM(NG2Q,9),RHO(NXYZ)
      REAL*8 YLM(NGcont,16),RHO(NXYZ)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHOG(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3),RHO4(NXYZ)
c     &           VG(NXYZ),WORK2(NG2Q,5),RHO4(NXYZ)
     &           VG(NXYZ),WORK2(NG2Q,7),RHO4(NXYZ)
      DIMENSION I2G(NGQ),NG2(NUMKQ)
      dimension NGNL(NTYQ,NUMKQ)
      DIMENSION G(4,NGQ),EXPG(NGQ),G2(4,NG2Q,NUMKQ),GDUMP(NG2Q,NUMKQ)
c +++ for A-vec
      DIMENSION GDUMPd(NG2Q,NUMKQ),EEd(MXBND,NUMKQ)
      dimension VGA(NGQ,NTYQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     &          ZV(NTYQ),RC0(NCRQ,NTYQ),
     &          COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ)
c      COMPLEX*16 COEF(NG2Q,MXBND),DCOEF(NG2Q,MXBND)
c      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,MXBND)
c      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,10)
c      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,15)
      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,21)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ)
     &         ,IOWF(MBLK,NUMKQ)
     &         ,IOVP(2,NTYQ,NUMKQ)
      INTEGER*4 S(3,3,48)
      DIMENSION FORCE(3,NTAUQ),DFORCE(3,NTAUQ),SFORCE(3,NTAUQ),
     &  ZZ(NTAUQ)
      DIMENSION RVEC(4,LATQ)
c *** for external charge
      complex*16 REXT(NXYZ),WEXT(NXYZ)
c +++++++++++
      COMPLEX*16 CWORK(NXYZ,10)
c +++++++++++
      COMMON/COMFIX/FATM(3,101),NFIX,IFATM(101)
      COMMON/COMOPT/IOPT(10,5)
      common/tmod/itmod
c      parameter ( ncpuq=30 )
cc      include 'ncpuq.h'
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      dimension nbegint(0:ncpuq),nendt(0:ncpuq)
      dimension nbegintt(0:ncpuq),nendtt(0:ncpuq)
C
      PARAMETER (IRLATQ=144,NAS=72)
      DIMENSION EE(NBNDQ,NUMKQ),EENL(NBNDQ,NUMKQ),RCOSIN(NAS,IRLATQ),
     & WK(NUMKQ),VINT(NBNDQ,IRLATQ),NSY(IRLATQ), OCC(NBNDQ,NUMKQ)
      DIMENSION FXNL(NTAUQ,NBNDQ,NUMKQ),FYNL(NTAUQ,NBNDQ,NUMKQ),
     & FZNL(NTAUQ,NBNDQ,NUMKQ)
c *** for Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c      DIMENSION IFAC_XYZ(60)
c *** for Kokubo FFTW
      integer*8 plancfp,plancbp
c ***  attnesion
      dimension NBSEQ(NUMKQ)
c *** for macroscopic current
      dimension RHOAX(NXYZ),RHOAY(NXYZ),RHOAZ(NXYZ)
      dimension PX(NBNDQ,NUMKQ),PY(NBNDQ,NUMKQ),PZ(NBNDQ,NUMKQ)
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c **** temp check
c      DELTAd=0.d0
c **** temp check : end
c ** temp check
c      if (my_rank.le.1 ) then
c       write(6,*)' just in ELECTF(my_rank=',my_rank,')' 
c       do ity=1,ntype
c        write(6,*)' VGA ity =',ity
c        write(6,'(4F22.16)')(VGA(ig,ity),ig=1,NXYZ,1000)
c       enddo
c      endif
c ** temp check : end
C
C     CONSTRUCTS THE ONE-ELECTRON POTENTIAL RHO3
C
c *****  temp check
c      if ( my_rank.eq.0 ) then
c       write(6,*)' in sub. electf2:  RHOG !! '
c       write(6,*) ( RHOG(ig),ig=1,1500,100 )
c
c        HARTREE ENERGY
c
c      EH=0.D0
c      TPIBA2=TPIBA**2
c      FPI=4.d0*DACOS(-1.d0)
c      DO IG=2,NG
c      JG=I2G(IG)
c      EH=EH+0.5D0*FPI*DBLE(DCONJG(RHOG(JG))*RHOG(JG))/(TPIBA2*G(4,IG))
c      ENDDO
c      EH=OMEGA*EH
c      write(6,*)' EH = ',EH
c      endif
c *****  temp check ; end
c +++ temp check
c       do ii=1,15
c         do ig=1,nxyz
c          DCOEF(ig,ii)=DCMPLX(0.d0,0.d0)
c         enddo
c       enddo
c +++ temp check; end
      CALL LOCPOTF(NXYZ,NG,NGQ,G,EXPG,RHO1,TPIBA,OMEGA,
cc     &             DELTA,VG,RHO,RHOG,I2G,FORCE,RHO2,
     &             DELTA,DELTAd,VG,RHO,RHOG,I2G,FORCE,VGA,
     &             NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,
     &             NCRQ,ZV,RC0,COR,NUMC,ZZ, ZVAL,
     &             ESELF, EWA, ELOCAL, EXC, EH,itstep
c     & ,DCOEF(1,1),DCOEF(1,2),DCOEF(1,3),DCOEF(1,4),DCOEF(1,5)
c     & ,DCOEF(1,6),DCOEF(1,7),DCOEF(1,8),DCOEF(1,9),DCOEF(1,10)
     &   ,CWORK(1,1),CWORK(1,2),CWORK(1,3),CWORK(1,4),CWORK(1,5)
     &   ,CWORK(1,6),CWORK(1,7),CWORK(1,8),CWORK(1,9),CWORK(1,10)
     &                  ,REXT,WEXT,ft,dft
     &                  ,NRX,NRY,NRZ
c *** for Sugino FFT
c     &                  ,WSAVEX,WSAVEY,WSAVEZ
c     &                  ,LX1,LX2,LY1
c     &                  ,LY2,LZ1,LZ2
c     &                  ,IFACX,IFACY,IFACZ)
c *** for Kokubo ASL FFT
c     &                  ,WSAVE_XYZ
c     &                  ,IFAC_XYZ)
c *** for Kokubo FFTW
     &                  ,plancfp,plancbp
c
     &   ,nbegint,nendt,nbegintt,nendtt,ncpuq,ncpu )
C
C     CALCULATE NON-LOCAL POTENTIAL CONTRIBUTION
c **** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)'my_rank=',my_rank,'LOCPOTF end'
c      stop
c      endif
c **** temp check
C
      CALL NONLOCF( MXBND, MBLK, NXYZ, NG2, NG2Q,NBNDQ,NBND,
     &              NUMK, NUMKQ, NBSEQ,IOVP,
     &              RHO4, COEF, DCOEF, YLM, G2, RHO2, TPIBA,
     &              DELTA, ETOT, WORK2, VPJ, VPP, IOWF, S, NTOT,
     &              FORCE, DFORCE, SFORCE, LATQ, RVEC, NLV,
     &              OMEGA, NTAUQ, NTYQ, NTYPE, LREQ,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK, VINT,
c +++ A-vec Y. Miyamoto
     &              GDUMPd,EEd,EKINEd,
     &              NSY, FXNL, FYNL, FZNL,
     &  TAU, NUMTY,NIDN,EKINE,ENL,NPFL,MXOFL,OCC,itstep,GDUMP,NGNL
     &  ,NGcont
c +++ for macroscopic current
     &   ,RHOAX,RHOAY,RHOAZ,PX,PY,PZ,PXTOT,PYTOT,PZTOT
c
     &  ,nbegin,nend,ncpuq,ncpu  )
C
      if ( mod(itstep,itmod).eq.0 .and. my_rank.eq.0 ) then
      CALL CLOCK(TIM)
c      CALL cpu_time(TIM)
      WRITE(6,6000) TIM
 6000 FORMAT(23X,'****  ELECTF: AFTER       ',F15.7,' SEC')
C
c *** temp check
c      write(6,*)' EKINEd again =',EKINEd
c *** temp check : end
C
      WRITE(6,6002)  ETOT, 2.0D+00*ETOT,
     &               ESELF, EWA, ELOCAL, EXC, EH, EKINE, ENL
 6002 FORMAT(//
     & '  ****** TOTAL ENERGY: ETOT   = ', D20.10,'  HR'/
     & '                                ', D20.10,'  RYD'//
     & '  ******                ESELF = ', D20.10,'  HR'/
     & '  ******                 EWA  = ', D20.10,'  HR'/
     & '  ******               ELOCAL = ', D20.10,'  HR'/
     & '  ******                 EXC  = ', D20.10,'  HR'/
     & '  ******                 EH   = ', D20.10,'  HR'/
     & '  ******                EKINE = ', D20.10,'  HR'/
     & '  ******                 ENL  = ', D20.10,'  HR'//)
c  *** write macroscopic current
      write(6,6011)PXTOT,PYTOT,PZTOT
 6011 format(' current J(a.u.) =',3f24.16)
c
      WRITE(6,6004)
 6004 FORMAT(/
     & '  ******  TOTAL FORCE: NEGATIVE  (HARTREE/AU):')
      DO 10 I=1,NTAUQ
   10 WRITE(6,11) I, (FORCE(J,I),J=1,3)
   11 FORMAT(14X,I4,3F15.7)
      WRITE(6,*) ' '
c
      endif
C
      DO 20 I=1,NFIX
         IATM=IFATM(I)
         IF(IATM.LT.0) THEN
            IATM=-IATM
            DO 22 J=1,3
   22       FORCE(J,IATM)=0.D0
C
CTEMP       WRITE(6,6006) IATM,  ( FORCE(J,IATM), J=1,3 )
C6006       FORMAT('          FORCE MODIFIED: ATM = ',I4,3F12.4 )
C
         ELSE
            SUM=0.D0
            DO 24 J=1,3
   24       SUM=SUM+FATM(J,I)*FORCE(J,IATM)
            DO 23 J=1,3
   23       FORCE(J,IATM)=FORCE(J,IATM)-SUM*FATM(J,I)
C
C TEMP      WRITE(6,6006) IATM,  ( FORCE(J,IATM), J=1,3 )
C
C            SUM2=0.D0
C            DO 25 J=1,3
C   25       SUM2=SUM2+FATM(J,I)*TAU(J,IATM)
C            WRITE(6,*) ' MENSEIBUN ',SUM2,SUM
      ENDIF
   20 CONTINUE
C CARE TEMP   DB REACTION FROM VAPOR
CC        FFF = 0.5D+00 * ( FORCE(3,5) + FORCE(3,6) )
CC        FORCE(3,5) = FORCE(3,5) - FFF
CC        FORCE(3,6) = FORCE(3,6) - FFF
C CARE TEMP   DB REACTION FROM TERRACE
C         FFF = 0.25D+00 * ( FORCE(1,11) + FORCE(2,11)
C    &                     + FORCE(1,12) + FORCE(2,12) )
C         FORCE(1,11) = FORCE(1,11) - FFF
C         FORCE(2,11) = FORCE(2,11) - FFF
C         FORCE(1,12) = FORCE(1,12) - FFF
C         FORCE(2,12) = FORCE(2,12) - FFF
C CARE TEMP   DB REACTION FROM TERRACE
C         FFF = 0.5D+00 * ( FORCE(1,5) + FORCE(2,5) )
C         FORCE(1,5) = FORCE(1,5) - FFF
C         FORCE(2,5) = FORCE(2,5) - FFF
C CARE TEMP END
      RETURN
      END
C*****************************************************************
      SUBROUTINE NONLOCF( MXBND, MBLK, NXYZ, NG2, NG2Q, NBNDQ,NBND,
     &                    NUMK, NUMKQ, NBSEQ,IOVP,
     &                    RHOA, COEF, DCOEF, YLM, G2, RHO2,
     &                    TPIBA, DELTA, ETOT, WORK2, VPJ, VPP, IOWF,
     &                    S, NTOT,
     &                    FORCE, DFORCE, SFORCE, LATQ, RVEC,NLV,
     &                    OMEGA, NTAUQ, NTYQ, NTYPE, LREQ,
     &                    NKMESH, NEXPND, NFL, EE, EENL,RCOSIN,WK,VINT,
c +++ for A-vector Y. Miyamoto 2020
     &                    GDUMPd,EEd,EKINEd,
     &                    NSY, FXNL, FYNL, FZNL,
     &                    TAU, NUMTY, NIDN, EKINE, ENL, NPFL, MXOFL, 
     &                    OCC,itstep,GDUMP,NGNL,NGcont
c +++ for macroscopic current
     &        ,RHOAX,RHOAY,RHOAZ,PX,PY,PZ,PXTOT,PYTOT,PZTOT
c
     &       ,nbegin,nend,ncpuq,ncpu        )
C
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,4)
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,9)
      REAL*8 RHOA(NXYZ),YLM(NGcont,16)
ccc      COMPLEX*16 RHOA(NXYZ)
ccc      REAL*8 YLM(NG2Q,4)
      COMPLEX*16 RHO2(NXYZ),
c     &           COEF(NG2Q,MXBND),DCOEF(NG2Q,MXBND),WORK2(NG2Q,3)
c     &  COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,MXBND),WORK2(NG2Q,3)
c     &  COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,10),WORK2(NG2Q,3)
c     &  COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,15),WORK2(NG2Q,5)
     &  COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,21),WORK2(NG2Q,7)
      DIMENSION NG2(NUMKQ),RVEC(4,LATQ)
      dimension NGNL(NTYQ,NUMKQ)
      DIMENSION G2(4,NG2Q,NUMKQ), GDUMP(NG2Q,NUMKQ),
     &          FORCE(3,NTAUQ),DFORCE(3,NTAUQ),SFORCE(3,NTAUQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
c +++ for A-vector Y. Miyamoto 2020
      DIMENSION GDUMPd(NG2Q,NUMKQ),EEd(NBNDQ,NUMKQ)
      INTEGER*4 S(3,3,48)
cc      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ)
     &         ,IOWF(MBLK,NUMKQ),
     &          IOVP(2,NTYQ,NUMKQ)
      COMMON/COMOPT/IOPT(10,5)
      PARAMETER (IRLATQ=144,NAS=72)
      DIMENSION EE(NBNDQ,NUMKQ),EENL(NBNDQ,NUMKQ),RCOSIN(NAS,IRLATQ),
     &          WK(NUMKQ),VINT(NBNDQ,IRLATQ),NSY(IRLATQ)
      DIMENSION FXNL(NTAUQ,NBNDQ,NUMKQ),FYNL(NTAUQ,NBNDQ,NUMKQ),
     &          FZNL(NTAUQ,NBNDQ,NUMKQ), OCC(NBNDQ,NUMKQ)
c ***  attention
      dimension NBSEQ(NUMKQ)
      common/tmod/itmod
      integer status(MPI_STATUS_SIZE),tag
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
c +++ for macroscopic current
      dimension RHOAX(NXYZ),RHOAY(NXYZ),RHOAZ(NXYZ)
      dimension PX(NBNDQ,NUMKQ),PY(NBNDQ,NUMKQ),PZ(NBNDQ,NUMKQ)
c
      data tag/21/
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c
      PI=4.D0*ATAN(1.D0)
      TPI=2.D0*PI
      FPI=4.D0*PI
      TPIBA2=TPIBA**2
      YMFAC=1.D0/DBLE(NKMESH)
C
C
C     MAIN LOOP
C
c ***  in case of metal band indices are renumbered ***
      do ik=1,numk
      if ( npfl.ne.0 ) then
       if ( NFL.gt.nbseq(ik)) then
          IOWF(1,ik)=NFL-npfl
       else
         IOWF(1,ik)=NFL
       endif
      else
       IOWF(1,ik)=nbseq(ik)
      endif
      enddo
c
c ***  temp check
c      write(6,*)' in sub. NONLOCF !!! '
c      write(6,*)' IOWF -> as necessary bands '
c      do ik=1,numk
c      write(6,*)' ik = ',ik,' IOWF = ',IOWF(1,ik)
c      write(6,*)' OCC = ',( OCC(ib,ik),ib=1,iowf(1,ik) )
c      enddo
c ***  temp check ; end
      if ( mod(itstep,itmod).eq.0 ) then
      EBND=0.D0
      NBND1=NFL+1
c ********* Note! EE(IB) has already been sent to Master ! 
C
      if (my_rank.eq.0 ) then
      DO 560 IK=1,NUMK
c        DO 561 IB=1,NFL
        DO 561 IB=1,IOWF(1,IK)
          EBND=EBND+EE(IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
  561   CONTINUE
                        IF( NPFL .EQ. 0 ) GO TO 560
c        DO 562 IB=NBND1,NBNDQ
        DO 562 IB=NBND1,NBSEQ(IK)
        DO 563 I=1,NEXPND
          EBND=EBND+EE(IB,IK)*YMFAC*RCOSIN(IK,I)
     &         *VINT(IB,I)*DBLE(NSY(I))*2.D0
  563   CONTINUE
  562   CONTINUE
  560 CONTINUE  ! end of IK loop
          WRITE(6,6666) EBND
 6666     FORMAT(38X,'*** NONLOCF: EBND = ',D13.5)
      endif ! end of if my_rank.eq.0 loop
      endif ! end of if mod(itstep,itmod).eq.0 loop
C
      DO 1951 I=1,NTAUQ
      DO 1951 J=1,3
      DFORCE(J,I)=0.D0
 1951 SFORCE(J,I)=0.D0
ccc ***      if (my_rank.ne.0 ) then
c *** temp check
c      write(6,*)'my_rank=',my_rank,' sub. NONLOCF!!'
c *** temp check
      DO 570 IK=1,NUMK
c      DO 570 IB=1,NBNDQ
      DO 570 IB=nbegin(my_rank),nend(my_rank)
        EE(IB,IK)=0.D0
c  ++ for macroscopic current
        PX(IB,IK)=0.D0
        PY(IB,IK)=0.D0
        PZ(IB,IK)=0.D0
c
c +++ for A-vector
        EEd(IB,IK)=0.d0
        EENL(IB,IK)=0.D0
  570 CONTINUE
      DO 571 ITAU=1,NTAUQ
      DO 571 IK=1,NUMK
c      DO 571 IB=1,NBNDQ
      DO 571 IB=nbegin(my_rank),nend(my_rank)
        FXNL(ITAU,IB,IK)=0.D0
        FYNL(ITAU,IB,IK)=0.D0
        FZNL(ITAU,IB,IK)=0.D0
  571 CONTINUE
ccc ***      endif ! end of if my_rank.ne.0 loop
C
      if ( MBLK.ne.1 ) then
      if (my_rank.eq.0 ) write(6,*)' something wrong in nonlocf'
      stop
      endif
      DO 580 IK=1,NUMK
c         DO 910 JJB=1,MBLK
c            IF(JJB.EQ.MBLK) THEN
c               NJ=MOD(NBND-1,MXBND)+1
c            ELSE
c               NJ=MXBND
c            ENDIF
c         IBI=MXBND*(JJB-1)
         IBI=0
cccc         READ(71,REC=IOWF(JJB,IK)) COEF
ccc ***           if ( my_rank.ne.0 ) then
             DO 581 IG=1,NG2(IK)
cc             RHOA(IG)=G2(4,IG,IK)*TPIBA2
             RHOA(IG)=GDUMP(IG,IK)*TPIBA2
             RHOAX(IG)=G2(1,IG,IK)*TPIBA
             RHOAY(IG)=G2(2,IG,IK)*TPIBA
             RHOAZ(IG)=G2(3,IG,IK)*TPIBA
  581        CONTINUE
c           DO 583 IB=1,NBSEQ(IK)
           DO 583 IB=nbegin(my_rank),nend(my_rank)
           iib=ib-nbegin(my_rank)+1
c *** temp check
c       write(6,*)'my_rank=',my_rank,'EE=',EE(ib,ik)
c *** temp check : end
             DO 582 IG=1,NG2(IK)
             WFAC=DREAL( DCONJG(COEF(IG,IIB,IK))*COEF(IG,IIB,IK) )
             EE(IB,IK)=EE(IB,IK)+
     &           0.5D0*DBLE( RHOA(IG) ) *WFAC
             PX(IB,IK)=PX(IB,IK)+RHOAX(IG)*WFAC
             PY(IB,IK)=PY(IB,IK)+RHOAY(IG)*WFAC
             PZ(IB,IK)=PZ(IB,IK)+RHOAZ(IG)*WFAC
  582        CONTINUE
c *** temp check
c            write(6,*)'my_rank=',my_rank,
c     &       ' EKINE(',IB,',',IK,')=',EE(ib,ik)
c            temp=0
c            do ig=1,ng2(ik)
c            temp=temp+dconjg( coef(ig,ib,ik) )*coef(ig,ib,ik)
c            enddo
c            write(6,*)'norm of ',ib,',',ik,'=',temp
c *** temp check ; end
  583      CONTINUE  ! IB loop end
c
           if ( my_rank.ne.0 ) then
            nbleng=nend(my_rank)-nbegin(my_rank)+1
            call MPI_Send(EE(nbegin(my_rank),IK),
     &                    PX(nbegin(my_rank),IK),
     &                    PY(nbegin(my_rank),IK),
     &                    PZ(nbegin(my_rank),IK), 4*nbleng,
     &        MPI_DOUBLE_PRECISION,0,tag,MPI_COMM_WORLD,ierr)
           else
            do icpu=1,ncpu
            nbleng=nend(icpu)-nbegin(icpu)+1
            call MPI_Recv(EE(nbegin(icpu),IK),
     &                    PX(nbegin(icpu),IK),
     &                    PY(nbegin(icou),IK),
     &                    PZ(nbegin(icou),IK),   4*nbleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag,MPI_COMM_WORLD,status,ierr)
            enddo
           endif ! end of if my_rank.ne.0 loop
c ++++ for A-vector  Y. Miyamoto 2020 this is still within ik loop
             do IG=1,NG2(IK)
              RHOA(IG)=GDUMPd(IG,IK)*TPIBA
             enddo
             do IB=nbegin(my_rank),nend(my_rank)
             iib=ib-nbegin(my_rank)+1
              do IG=1,NG2(IK)
               EEd(IB,IK)=EEd(IB,IK)+
     &           0.5D0*DBLE(RHOA(IG)
     &         *DCONJG(COEF(IG,IIB,IK))*COEF(IG,IIB,IK))
              enddo
             enddo
c
           if ( my_rank.ne.0 ) then
            nbleng=nend(my_rank)-nbegin(my_rank)+1
            call MPI_Send(EEd(nbegin(my_rank),IK),nbleng,
     &        MPI_DOUBLE_PRECISION,0,tag,MPI_COMM_WORLD,ierr)
           else
            do icpu=1,ncpu
            nbleng=nend(icpu)-nbegin(icpu)+1
            call MPI_Recv(EEd(nbegin(icpu),IK),nbleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag,MPI_COMM_WORLD,status,ierr)
            enddo
           endif ! end of if my_rank.ne.0 loop
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'DO 583 loop end'
c **** temp check : end
C
             DO 588 IG=1,NG2(IK)
  588        RHOA(IG)=SQRT(G2(4,IG,IK))*TPIBA
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'DO 588 loop end'
c **** temp check : end
         NG26=NG2(IK)/6
         CALL GETYLM(NG2Q,NG26,G2(1,1,IK),RHOA,YLM,TPIBA,NGcont)
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'after end of GETYLM'
c **** temp check : end
         CALL SEPPOTF( NG2Q, NG2(IK),NBSEQ(IK),NBNDQ, G2(1,1,IK),
     &   VPJ(1,1,1,1,ik),VPP,YLM,RHO2
c     &  ,WORK2(1,1),WORK2(1,2),WORK2(1,3),
     &  ,WORK2(1,1),WORK2(1,2),WORK2(1,3),WORK2(1,4),WORK2(1,5),
     &   WORK2(1,6),WORK2(1,7),
     &   COEF(1,1,ik),DCOEF,TPIBA,IOVP(1,1,IK),
     &   EENL(1,IK),FXNL(1,1,IK),FYNL(1,1,IK),
     &   FZNL(1,1,IK),
     &   NTAUQ,NTYQ,LREQ,TAU,NTYPE,NUMTY,NIDN, MXOFL,NGNL(1,IK)
     &  ,NGcont
c
     &  ,nbegin,nend,ncpuq,ncpu )
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'after end of SEPPOTF'
c **** temp check : end
  580 CONTINUE   ! end of IK loop
c ***  temp check
c      write(6,*)' After sub. SEPPOTF '
c      write(6,*)' EENL '
c      do ik=1,numk
c        write(6,*)( EENL(ib,IK),ib=1,iowf(1,ik) )
c      enddo
c      write(6,*)' WK !! '
c      write(6,*)( wk(ik),ik=1,numk )
c ***  temp check : end
      if ( my_rank.eq.0 ) then
      ENL=0.D0
      EKINE=0.D0
      PXTOT=0
      PYTOT=0
      PZTOT=0
c +++ for A-vector Y. Miyamoto 2020
      EKINEd=0.0d0
      DO 590 IK=1,NUMK
c        DO 591 IB=1,NFL
        DO 591 IB=1,IOWF(1,IK)
          EKINE=EKINE+EE(IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
c *** macroscopic current
          PXTOT=PXTOT+PX(IB,IK)*WK(IK) * OCC(IB,K)
          PYTOT=PYTOT+PY(IB,IK)*WK(IK) * OCC(IB,K)
          PZTOT=PZTOT+PZ(IB,IK)*WK(IK) * OCC(IB,K)
c
c +++ for A-vector Y. Miyamoto 2020
          EKINEd=EKINEd+EEd(IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
c
          ENL=ENL+EENL(IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
  591   CONTINUE
                        IF( NPFL .EQ. 0 ) GO TO 590
c        DO 592 IB=NBND1,NBNDQ
c   *****  Note! EE has already been sent to Maser (DO 583)
c   *****  Note! EENL has already been sent to Maser (sub. EPPOTF)
        DO 592 IB=NBND1,NBSEQ(IK)
          DO 593 I=1,NEXPND
            EKINE=EKINE+EE(IB,IK)*YMFAC*RCOSIN(IK,I)
     &           *VINT(IB,I)*DBLE(NSY(I))*2.D0
c +++ for A-vector (may not be used) Y. Miyamoto 2020
            EKINEd=EKINEd+EEd(IB,IK)*YMFAC*RCOSIN(IK,I)
     &           *VINT(IB,I)*DBLE(NSY(I))*2.D0
c
            ENL=ENL+EENL(IB,IK)*YMFAC*RCOSIN(IK,I)
     &           *VINT(IB,I)*DBLE(NSY(I))*2.D0
  593     CONTINUE ! end of I loop
  592   CONTINUE  ! end of IB loop
  590 CONTINUE    ! end of IK loop
c
c *** temp check for EKINEd
c      if ( mod(itstep,itmod).eq.0.and.my_rank.eq.0 ) then
c      write(6,*)' EKINEd = ',EKINEd
c      endif
c *** temp check: end
c
C     WRITE(6,*) NFL,NBND1
      DO 595 ITAU=1,NTAUQ
      FX=0.D0
      FY=0.D0
      FZ=0.D0
      DO 596 IK=1,NUMK
c      DO 597 IB=1,NFL
c   *****  Note! FXNL FYNL FZNL have already been sent to Maser(sub. SEPPOTF)
      DO 597 IB=1,IOWF(1,IK)
        FX=FX+FXNL(ITAU,IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
        FY=FY+FYNL(ITAU,IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
        FZ=FZ+FZNL(ITAU,IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
C       WRITE(6,*) FXNL(ITAU,IB,IK),FYNL(ITAU,IB,IK),FZNL(ITAU,IB,IK)
  597 CONTINUE
                        IF( NPFL .EQ. 0 ) GO TO 596
c      DO 599 IB=NBND1,NBNDQ
      DO 599 IB=NBND1,NBSEQ(IK)
      DO 598 I=1,NEXPND
        FX=FX+FXNL(ITAU,IB,IK)*YMFAC*RCOSIN(IK,I)
     &         *VINT(IB,I)*DBLE(NSY(I))*2.D0
        FY=FY+FYNL(ITAU,IB,IK)*YMFAC*RCOSIN(IK,I)
     &         *VINT(IB,I)*DBLE(NSY(I))*2.D0
        FZ=FZ+FZNL(ITAU,IB,IK)*YMFAC*RCOSIN(IK,I)
     &         *VINT(IB,I)*DBLE(NSY(I))*2.D0
  598 CONTINUE
C     WRITE(6,*) FXNL(ITAU,IB,IK),FYNL(ITAU,IB,IK),FZNL(ITAU,IB,IK)
  599 CONTINUE
  596 CONTINUE
C     WRITE(6,*) FXNL(ITAU,NFL,IK),FYNL(ITAU,NFL,IK),FZNL(ITAU,NFL,IK)
C     WRITE(6,*) FXNL(ITAU,NBND1,IK),FYNL(ITAU,NBND1,IK),
C    &           FZNL(ITAU,NBNDQ,IK)
      DFORCE(1,ITAU)=DFORCE(1,ITAU)-2.D0*FX*TPIBA/OMEGA
      DFORCE(2,ITAU)=DFORCE(2,ITAU)-2.D0*FY*TPIBA/OMEGA
      DFORCE(3,ITAU)=DFORCE(3,ITAU)-2.D0*FZ*TPIBA/OMEGA
  595 CONTINUE
CC      WRITE(6,*) ' EKINE=',EKINE
      ENL=ENL/OMEGA
CC      WRITE(6,*) ' NONL=',ENL
      CALL SYMFRC(S,NTOT,DFORCE,SFORCE,
     & NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,LATQ,RVEC, NLV )
      DO 7 ITAU=1,NTAUQ
      FORCE(1,ITAU)=FORCE(1,ITAU)+SFORCE(1,ITAU)
      FORCE(2,ITAU)=FORCE(2,ITAU)+SFORCE(2,ITAU)
      FORCE(3,ITAU)=FORCE(3,ITAU)+SFORCE(3,ITAU)
      DFORCE(1,ITAU)=FORCE(1,ITAU)
      DFORCE(2,ITAU)=FORCE(2,ITAU)
      DFORCE(3,ITAU)=FORCE(3,ITAU)
    7 CONTINUE
C
CTEMP WRITE(6,6668)
C6668 FORMAT(/
C    & '  *** NONLOCF:  ***  TOTAL FORCE: NEGATIVE (HARTREE/AU):')
C     DO 8 I=1,NTAUQ
C   8 WRITE(6,9) I, (FORCE(J,I),J=1,3)
C   9 FORMAT(14X,I4,3F15.7)
C     WRITE(6,*) ' '
C
      CALL SYMFRC(S,NTOT,DFORCE,FORCE,
     & NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,LATQ,RVEC, NLV )
C
      ETOT = EKINE + ENL + DELTA
      endif   ! end of if my_rank.eq.0 loop
C
c      endif   ! end of if mod(itstep,itmod).eq.0 loop
      RETURN
      END
C
C********************************************************************
C
      SUBROUTINE SEPPOTF(NG2Q,NG2,NBND,NBNDQ,G2K,VPJ,VPP,
c     &  YLM,EXTAU,WORK1,WORK2,WORK3,COEF,DCOEF,TPIBA,
     &  YLM,EXTAU,WORK1,WORK2,WORK3,WORK4,WORK5,WORK6,WORK7,
     &  COEF,DCOEF,TPIBA,
     &  IOVP,EENL,FXNL,FYNL,FZNL,
     &  NTAUQ,NTYQ,LREQ,TAU,NTYPE,NUMTY,NIDN, MXOFL,NGNL,NGcont
c
     & ,nbegin,nend,ncpuq,ncpu  )
C
C               PARTITIONED POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8(A-H,O-Z)
      include 'mpif.h'
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,4)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,9)
      DIMENSION G2K(4,NG2Q),YLM(NGcont,16)
c      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,10),
c      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,15),
      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,21),
c     &           WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),EXTAU(NG2Q)
     &  WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),WORK4(NG2Q),WORK5(NG2Q),
     &  WORK6(NG2Q),WORK7(NG2Q),EXTAU(NG2Q)
c      COMPLEX*16 Y00,Y11,Y12,Y13,SUKA1,SUKA2,SUKA3,CT(3),CD(3,3)
c      COMPLEX*16 SUKA1,SUKA2,SUKA3,CT(3),CD(3,3)
      COMPLEX*16 Y00,Y11,Y12,Y13,Y21,Y22,Y23,Y24,Y25
     &          ,Y31,Y32,Y33,Y34,Y35,Y36,Y37
      COMPLEX*16 SUKA1,SUKA2,SUKA3,SUKA4,SUKA5,SUKA6,SUKA7,
     & CT(7),CD(3,7)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
ccc     &          VPJ(NG2Q,3),VPP(3),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &  VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &  VPJ(NG2Q/3,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &  VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
     &  VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
      PARAMETER(NTYQ2=4)
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      DIMENSION EENL(NBNDQ),FXNL(NTAUQ,NBNDQ),FYNL(NTAUQ,NBNDQ),
     & FZNL(NTAUQ,NBNDQ)
      dimension NGNL(NTYQ)
      integer tag,status(MPI_STATUS_SIZE)
      data tag/10/
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c
c *** temp check
c      write(6,*)'my_rank=',my_rank,' in SEPPOTF NTYPE=',NTYPE
c      do ity=1,ntype
c      write(6,*)'my_rank=',my_rank,' in SEPPOTF NTYPE=',NTYPE
c      write(6,*)'my_rank=',my_rank,' in SEPPOTF NATM=',NUMTY(ity)
c      write(6,*)'my_rank=',my_rank,' in SEPPOTF MXOFL=',MXOFL(ity)
c       do iatm=1,numty(ity)
c       write(6,*)'my_rank=',my_rank,' in SEPPOTF ITAU='
c     &           ,NIDN(iatm,ity)
c       enddo
c      enddo
c      miya=13
c      if ( miya.eq.13 .and. my_rank.ne.0 ) then
c      stop
c      endif
c *** temp check : end
c
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      FPISQ=FPI**2
CC      CALL CLOCK(TIM0)
C
c ***  temp check
c      write(6,*)' in sub. SEPPOTF  NBND = ',NBND
c ***  temp check : end
C
CCC   LMAX=LREQ-1
C
cc ***      if ( my_rank.ne.0 ) then
      DO 10 ITY=1,NTYPE
C *****
             IF(NUMTY(ITY).LE.0) GOTO 10
C *****
      NATM=ABS(NUMTY(ITY))
      LMAX = MXOFL(ITY)
      DO 20 IATM=1,NATM
      ITAU=NIDN(IATM,ITY)
      FX=0.D0
      FY=0.D0
      FZ=0.D0
c        DO 22 IG=1,NG2
        DO 22 IG=1,NGNL(ITY)
        TEMP=TPIBA*(G2K(1,IG)*TAU(1,ITAU)+G2K(2,IG)*TAU(2,ITAU)
     &             +G2K(3,IG)*TAU(3,ITAU))
        EXTAU(IG)=DCMPLX(COS(TEMP),SIN(TEMP))
   22   CONTINUE
C
      DO 30 LI=1,LMAX
cccc      READ(82,REC=IOVP(LI,ITY))  VPP, VPJ
C
C     WRITE(6,*) ' CHECK VP'
C     WRITE(6,*) ' VPP',VPP(1)-VPP(2)-VPP(3)
C     DO 59 IG=1,NG2
C  59 IF(ABS(VPJ(IG,1)-VPJ(IG,2)-VPJ(IG,3)).GT.1.D-12)
C    &WRITE(6,*) ' VPJ ',IG,VPJ(IG,1)-VPJ(IG,2)-VPJ(IG,3)
C
      L=LI-1
      IF(L.EQ.0.AND.IBUN(1,ITY).NE.1) THEN
c         DO 50 IG=1,NG2
         DO 50 IG=1,NGNL(ITY)
c         Y00=DCMPLX(YLM(IG,1),0.D0)
         Y00=YLM(IG,1)
         SUKA1=Y00*EXTAU(IG)*VPJ(IG,1,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG,1)=SUKA1*G2K(1,IG)
         DCOEF(IG,2)=SUKA1*G2K(2,IG)
         DCOEF(IG,3)=SUKA1*G2K(3,IG)
   50    CONTINUE
c         DO 52 IB=1,NBND
         DO 52 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
            CT(1)=(0.D0,0.D0)
            CD(1,1)=(0.D0,0.D0)
            CD(2,1)=(0.D0,0.D0)
            CD(3,1)=(0.D0,0.D0)
c            DO 54 IG=1,NG2
            DO 54 IG=1,NGNL(ITY)
c            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
c            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
c            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
c            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG,3)
   54       CONTINUE
            EENL(IB)=EENL(IB)+CT(1)*DCONJG(CT(1))/VPP(1,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+IMAG(CD(1,1)*DCONJG(CT(1)))
     &              /VPP(1,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+IMAG(CD(2,1)*DCONJG(CT(1)))
     &              /VPP(1,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+IMAG(CD(3,1)*DCONJG(CT(1)))
     &              /VPP(1,li,ity)
   52    CONTINUE
      ELSEIF(L.EQ.0) THEN
C           PARTITIONING
         DO 1250 IP=2,3
c         DO 1050 IG=1,NG2
         DO 1050 IG=1,NGNL(ITY)
c         Y00=DCMPLX(YLM(IG,1),0.D0)
         Y00=YLM(IG,1)
         SUKA1=Y00*EXTAU(IG)*VPJ(IG,IP,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG,1)=SUKA1*G2K(1,IG)
         DCOEF(IG,2)=SUKA1*G2K(2,IG)
         DCOEF(IG,3)=SUKA1*G2K(3,IG)
 1050    CONTINUE
c ***  temp check
c       if ( ip.eq.2 ) then
c        write(6,*)' VPJ '
c        write(6,*)( VPJ(ig,ip,li,ity),ig=1,1500,100 )
c        write(6,*)' EXTAU '
c        write(6,*)( EXTAU(ig),ig=1,1500,100 )
c        write(6,*)' DCOEF '
c        do id=1,3
c        write(6,*)' id = ',id
c        write(6,*)( dcoef(ig,id),ig=1,1500,100 )
c        enddo
c        do ib=1,nbnd
c        write(6,*)' IB = ',ib
c        write(6,*)'  COEF  '
c        write(6,*)( coef(ig,ib),ig=1,1500,100 )
c        enddo
c       endif
c ***  temp check : end
c         DO 1052 IB=1,NBND
         DO 1052 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
            CT(1)=(0.D0,0.D0)
            CD(1,1)=(0.D0,0.D0)
            CD(2,1)=(0.D0,0.D0)
            CD(3,1)=(0.D0,0.D0)
c            DO 1054 IG=1,NG2
            DO 1054 IG=1,NGNL(ITY)
c            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
c            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
c            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
c            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG,3)
 1054       CONTINUE
            EENL(IB)=EENL(IB)+CT(1)*DCONJG(CT(1))/VPP(IP,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+IMAG(CD(1,1)*DCONJG(CT(1)))
     &              /VPP(IP,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+IMAG(CD(2,1)*DCONJG(CT(1)))
     &              /VPP(IP,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+IMAG(CD(3,1)*DCONJG(CT(1)))
     &              /VPP(IP,li,ity)
 1052    CONTINUE
 1250    CONTINUE
      ELSEIF(L.EQ.1.AND.IBUN(2,ITY).NE.1) THEN
         sq2=dsqrt(2.d0)
c         DO 60 IG=1,NG2
         DO 60 IG=1,NGNL(ITY)
c         Y11=DCMPLX( YLM(IG,2), 0.D0)
c         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
c         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
         Y11=YLM(IG,3)*sq2
         Y12=YLM(IG,4)*sq2
         Y13=YLM(IG,2)
         SUKA1=EXTAU(IG)*Y11*VPJ(IG,1,li,ity)
         SUKA2=EXTAU(IG)*Y12*VPJ(IG,1,li,ity)
         SUKA3=EXTAU(IG)*Y13*VPJ(IG,1,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG,1)=SUKA1*G2K(1,IG)
         DCOEF(IG,2)=SUKA1*G2K(2,IG)
         DCOEF(IG,3)=SUKA1*G2K(3,IG)
         WORK2(IG)=SUKA2
         DCOEF(IG,4)=SUKA2*G2K(1,IG)
         DCOEF(IG,5)=SUKA2*G2K(2,IG)
         DCOEF(IG,6)=SUKA2*G2K(3,IG)
         WORK3(IG)=SUKA3
         DCOEF(IG,7)=SUKA3*G2K(1,IG)
         DCOEF(IG,8)=SUKA3*G2K(2,IG)
         DCOEF(IG,9)=SUKA3*G2K(3,IG)
   60    CONTINUE
c         DO 62 IB=1,NBND
         DO 62 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
            CT(1)=(0.D0,0.D0)
            CD(1,1)=(0.D0,0.D0)
            CD(2,1)=(0.D0,0.D0)
            CD(3,1)=(0.D0,0.D0)
            CT(2)=(0.D0,0.D0)
            CD(1,2)=(0.D0,0.D0)
            CD(2,2)=(0.D0,0.D0)
            CD(3,2)=(0.D0,0.D0)
            CT(3)=(0.D0,0.D0)
            CD(1,3)=(0.D0,0.D0)
            CD(2,3)=(0.D0,0.D0)
            CD(3,3)=(0.D0,0.D0)
c            DO 64 IG=1,NG2
            DO 64 IG=1,NGNL(ITY)
c            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
c            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
c            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
c            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG,3)
c            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
            CT(2)=CT(2)+COEF(IG,IIB)*WORK2(IG)
c            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG,4)
c            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG,5)
c            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG,6)
            CD(1,2)=CD(1,2)+COEF(IG,IIB)*DCOEF(IG,4)
            CD(2,2)=CD(2,2)+COEF(IG,IIB)*DCOEF(IG,5)
            CD(3,2)=CD(3,2)+COEF(IG,IIB)*DCOEF(IG,6)
c            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
            CT(3)=CT(3)+COEF(IG,IIB)*WORK3(IG)
c            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG,7)
c            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG,8)
c            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG,9)
            CD(1,3)=CD(1,3)+COEF(IG,IIB)*DCOEF(IG,7)
            CD(2,3)=CD(2,3)+COEF(IG,IIB)*DCOEF(IG,8)
            CD(3,3)=CD(3,3)+COEF(IG,IIB)*DCOEF(IG,9)
   64       CONTINUE
            EENL(IB)=EENL(IB)+(CT(1)*DCONJG(CT(1))
     &             +CT(2)*DCONJG(CT(2))
     &             +CT(3)*DCONJG(CT(3)))/VPP(1,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+DIMAG(CD(1,1)*DCONJG(CT(1))
     &                +CD(1,2)*DCONJG(CT(2))
     &                +CD(1,3)*DCONJG(CT(3)))
     &              /VPP(1,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+DIMAG(CD(2,1)*DCONJG(CT(1))
     &                +CD(2,2)*DCONJG(CT(2))
     &                +CD(2,3)*DCONJG(CT(3)))
     &              /VPP(1,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+DIMAG(CD(3,1)*DCONJG(CT(1))
     &                +CD(3,2)*DCONJG(CT(2))
     &                +CD(3,3)*DCONJG(CT(3)))
     &              /VPP(1,li,ity)
   62    CONTINUE
      ELSEIF(L.EQ.1) THEN
         sq2=dsqrt(2.d0)
         DO 1261 IP=2,3
c         DO 61 IG=1,NG2
         DO 61 IG=1,NGNL(ITY)
c         Y11=DCMPLX( YLM(IG,2), 0.D0)
c         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
c         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
         Y11=YLM(IG,3)*sq2
         Y12=YLM(IG,4)*sq2
         Y13=YLM(IG,2)
         SUKA1=EXTAU(IG)*Y11*VPJ(IG,IP,li,ity)
         SUKA2=EXTAU(IG)*Y12*VPJ(IG,IP,li,ity)
         SUKA3=EXTAU(IG)*Y13*VPJ(IG,IP,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG,1)=SUKA1*G2K(1,IG)
         DCOEF(IG,2)=SUKA1*G2K(2,IG)
         DCOEF(IG,3)=SUKA1*G2K(3,IG)
         WORK2(IG)=SUKA2
         DCOEF(IG,4)=SUKA2*G2K(1,IG)
         DCOEF(IG,5)=SUKA2*G2K(2,IG)
         DCOEF(IG,6)=SUKA2*G2K(3,IG)
         WORK3(IG)=SUKA3
         DCOEF(IG,7)=SUKA3*G2K(1,IG)
         DCOEF(IG,8)=SUKA3*G2K(2,IG)
         DCOEF(IG,9)=SUKA3*G2K(3,IG)
   61    CONTINUE
c         DO 63 IB=1,NBND
         DO 63 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
            CT(1)=(0.D0,0.D0)
            CD(1,1)=(0.D0,0.D0)
            CD(2,1)=(0.D0,0.D0)
            CD(3,1)=(0.D0,0.D0)
            CT(2)=(0.D0,0.D0)
            CD(1,2)=(0.D0,0.D0)
            CD(2,2)=(0.D0,0.D0)
            CD(3,2)=(0.D0,0.D0)
            CT(3)=(0.D0,0.D0)
            CD(1,3)=(0.D0,0.D0)
            CD(2,3)=(0.D0,0.D0)
            CD(3,3)=(0.D0,0.D0)
c            DO 65 IG=1,NG2
            DO 65 IG=1,NGNL(ITY)
c            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
c            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
c            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
c            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG,3)
c            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
c            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG,4)
c            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG,5)
c            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG,6)
            CT(2)=CT(2)+COEF(IG,IIB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IIB)*DCOEF(IG,4)
            CD(2,2)=CD(2,2)+COEF(IG,IIB)*DCOEF(IG,5)
            CD(3,2)=CD(3,2)+COEF(IG,IIB)*DCOEF(IG,6)
c            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
c            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG,7)
c            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG,8)
c            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG,9)
            CT(3)=CT(3)+COEF(IG,IIB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IIB)*DCOEF(IG,7)
            CD(2,3)=CD(2,3)+COEF(IG,IIB)*DCOEF(IG,8)
            CD(3,3)=CD(3,3)+COEF(IG,IIB)*DCOEF(IG,9)
   65       CONTINUE
            EENL(IB)=EENL(IB)+(CT(1)*DCONJG(CT(1))
     &             +CT(2)*DCONJG(CT(2))
     &             +CT(3)*DCONJG(CT(3)))/VPP(IP,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+DIMAG(CD(1,1)*DCONJG(CT(1))
     &                +CD(1,2)*DCONJG(CT(2))
     &                +CD(1,3)*DCONJG(CT(3)))
     &              /VPP(IP,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+DIMAG(CD(2,1)*DCONJG(CT(1))
     &                +CD(2,2)*DCONJG(CT(2))
     &                +CD(2,3)*DCONJG(CT(3)))
     &              /VPP(IP,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+DIMAG(CD(3,1)*DCONJG(CT(1))
     &                +CD(3,2)*DCONJG(CT(2))
     &                +CD(3,3)*DCONJG(CT(3)))
     &              /VPP(IP,li,ity)
   63    CONTINUE
 1261    CONTINUE
      ELSEIF(L.EQ.2.AND.IBUN(3,ITY).NE.1) THEN
c *** temp check
c         write(6,*)' in SEPPOT'
c         write(6,*)' NGLN=',NGLN(ITY)
c         write(6,*)' YLM 5 '
c         write(6,*)(YLM(IG,5),IG=1,100,10)
c         write(6,*)' EXTAU '
c         write(6,*)(EXTAU(IG),IG=1,100,10)
c         write(6,*)' VPJ( partition 1'
c         write(6,*)( VPJ(IG,1,li,ity),IG=1,100,10)
c *** temp check: end
c *** need 1/sq2 because of YLM definition
         wari=1.d0/dsqrt(2.d0) ! I am sceptical on this
c         wari=1.d0
         DO 70 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0 )
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7) )*wari
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7) )*wari
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9) )*wari
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9) )*wari
         SUKA1=EXTAU(IG)*Y21*VPJ(IG,1,li,ity)
         SUKA2=EXTAU(IG)*Y22*VPJ(IG,1,li,ity)
         SUKA3=EXTAU(IG)*Y23*VPJ(IG,1,li,ity)
         SUKA4=EXTAU(IG)*Y24*VPJ(IG,1,li,ity)
         SUKA5=EXTAU(IG)*Y25*VPJ(IG,1,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG, 1)=SUKA1*G2K(1,IG)
         DCOEF(IG, 2)=SUKA1*G2K(2,IG)
         DCOEF(IG, 3)=SUKA1*G2K(3,IG)
         WORK2(IG)=SUKA2
         DCOEF(IG, 4)=SUKA2*G2K(1,IG)
         DCOEF(IG, 5)=SUKA2*G2K(2,IG)
         DCOEF(IG, 6)=SUKA2*G2K(3,IG)
         WORK3(IG)=SUKA3
         DCOEF(IG, 7)=SUKA3*G2K(1,IG)
         DCOEF(IG, 8)=SUKA3*G2K(2,IG)
         DCOEF(IG, 9)=SUKA3*G2K(3,IG)
         WORK4(IG)=SUKA4
         DCOEF(IG,10)=SUKA4*G2K(1,IG)
         DCOEF(IG,11)=SUKA4*G2K(2,IG)
         DCOEF(IG,12)=SUKA4*G2K(3,IG)
         WORK5(IG)=SUKA5
         DCOEF(IG,13)=SUKA5*G2K(1,IG)
         DCOEF(IG,14)=SUKA5*G2K(2,IG)
         DCOEF(IG,15)=SUKA5*G2K(3,IG)
   70    CONTINUE
       DO 71 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
         CT(1)=0.D0
         CD(1,1)=0.D0
         CD(2,1)=0.D0
         CD(3,1)=0.D0
         CT(2)=0.D0
         CD(1,2)=0.D0
         CD(2,2)=0.D0
         CD(3,2)=0.D0
         CT(3)=0.D0
         CD(1,3)=0.D0
         CD(2,3)=0.D0
         CD(3,3)=0.D0
         CT(4)=0.D0
         CD(1,4)=0.D0
         CD(2,4)=0.D0
         CD(3,4)=0.D0
         CT(5)=0.D0
         CD(1,5)=0.D0
         CD(2,5)=0.D0
         CD(3,5)=0.D0
         DO 72 IG=1,NGNL(ITY)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IIB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IIB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IIB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IIB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IIB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IIB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IIB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IIB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IIB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IIB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IIB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IIB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IIB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IIB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IIB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IIB)*DCOEF(IG,15)
   72    CONTINUE
            EENL(IB)=EENL(IB)+(CT(1)*DCONJG(CT(1))
     &             +CT(2)*DCONJG(CT(2))
     &             +CT(3)*DCONJG(CT(3))
     &             +CT(4)*DCONJG(CT(4))
     &             +CT(5)*DCONJG(CT(5)))/VPP(1,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+DIMAG(CD(1,1)*DCONJG(CT(1))
     &                +CD(1,2)*DCONJG(CT(2))
     &                +CD(1,3)*DCONJG(CT(3))
     &                +CD(1,4)*DCONJG(CT(4))
     &                +CD(1,5)*DCONJG(CT(5)))
     &              /VPP(1,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+DIMAG(CD(2,1)*DCONJG(CT(1))
     &                +CD(2,2)*DCONJG(CT(2))
     &                +CD(2,3)*DCONJG(CT(3))
     &                +CD(2,4)*DCONJG(CT(4))
     &                +CD(2,5)*DCONJG(CT(5)))
     &              /VPP(1,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+DIMAG(CD(3,1)*DCONJG(CT(1))
     &                +CD(3,2)*DCONJG(CT(2))
     &                +CD(3,3)*DCONJG(CT(3))
     &                +CD(3,4)*DCONJG(CT(4))
     &                +CD(3,5)*DCONJG(CT(5)))
     &              /VPP(1,li,ity)
   71  CONTINUE
      ELSEIF(L.EQ.2) THEN
c ** need 1/sq2 because of YLM definition
       wari=1.d0/dsqrt(2.d0) ! I am sceptical on this
c       wari=1.d0
       DO 1280 IP=2,3
         DO 80 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0 )
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7) )*wari
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7) )*wari
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9) )*wari
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9) )*wari
         SUKA1=EXTAU(IG)*Y21*VPJ(IG,IP,li,ity)
         SUKA2=EXTAU(IG)*Y22*VPJ(IG,IP,li,ity)
         SUKA3=EXTAU(IG)*Y23*VPJ(IG,IP,li,ity)
         SUKA4=EXTAU(IG)*Y24*VPJ(IG,IP,li,ity)
         SUKA5=EXTAU(IG)*Y25*VPJ(IG,IP,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG, 1)=SUKA1*G2K(1,IG)
         DCOEF(IG, 2)=SUKA1*G2K(2,IG)
         DCOEF(IG, 3)=SUKA1*G2K(3,IG)
         WORK2(IG)=SUKA2
         DCOEF(IG, 4)=SUKA2*G2K(1,IG)
         DCOEF(IG, 5)=SUKA2*G2K(2,IG)
         DCOEF(IG, 6)=SUKA2*G2K(3,IG)
         WORK3(IG)=SUKA3
         DCOEF(IG, 7)=SUKA3*G2K(1,IG)
         DCOEF(IG, 8)=SUKA3*G2K(2,IG)
         DCOEF(IG, 9)=SUKA3*G2K(3,IG)
         WORK4(IG)=SUKA4
         DCOEF(IG,10)=SUKA4*G2K(1,IG)
         DCOEF(IG,11)=SUKA4*G2K(2,IG)
         DCOEF(IG,12)=SUKA4*G2K(3,IG)
         WORK5(IG)=SUKA5
         DCOEF(IG,13)=SUKA5*G2K(1,IG)
         DCOEF(IG,14)=SUKA5*G2K(2,IG)
         DCOEF(IG,15)=SUKA5*G2K(3,IG)
   80    CONTINUE
       DO 81 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
         CT(1)=0.D0
         CD(1,1)=0.D0
         CD(2,1)=0.D0
         CD(3,1)=0.D0
         CT(2)=0.D0
         CD(1,2)=0.D0
         CD(2,2)=0.D0
         CD(3,2)=0.D0
         CT(3)=0.D0
         CD(1,3)=0.D0
         CD(2,3)=0.D0
         CD(3,3)=0.D0
         CT(4)=0.D0
         CD(1,4)=0.D0
         CD(2,4)=0.D0
         CD(3,4)=0.D0
         CT(5)=0.D0
         CD(1,5)=0.D0
         CD(2,5)=0.D0
         CD(3,5)=0.D0
         DO 82 IG=1,NGNL(ITY)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IIB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IIB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IIB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IIB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IIB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IIB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IIB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IIB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IIB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IIB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IIB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IIB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IIB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IIB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IIB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IIB)*DCOEF(IG,15)
   82    CONTINUE
            EENL(IB)=EENL(IB)+(CT(1)*DCONJG(CT(1))
     &             +CT(2)*DCONJG(CT(2))
     &             +CT(3)*DCONJG(CT(3))
     &             +CT(4)*DCONJG(CT(4))
     &             +CT(5)*DCONJG(CT(5)))/VPP(IP,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+DIMAG(CD(1,1)*DCONJG(CT(1))
     &                +CD(1,2)*DCONJG(CT(2))
     &                +CD(1,3)*DCONJG(CT(3))
     &                +CD(1,4)*DCONJG(CT(4))
     &                +CD(1,5)*DCONJG(CT(5)))
     &              /VPP(IP,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+DIMAG(CD(2,1)*DCONJG(CT(1))
     &                +CD(2,2)*DCONJG(CT(2))
     &                +CD(2,3)*DCONJG(CT(3))
     &                +CD(2,4)*DCONJG(CT(4))
     &                +CD(2,5)*DCONJG(CT(5)))
     &              /VPP(IP,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+DIMAG(CD(3,1)*DCONJG(CT(1))
     &                +CD(3,2)*DCONJG(CT(2))
     &                +CD(3,3)*DCONJG(CT(3))
     &                +CD(3,4)*DCONJG(CT(4))
     &                +CD(3,5)*DCONJG(CT(5)))
     &              /VPP(IP,li,ity)
   81   CONTINUE
 1280  CONTINUE
      ELSEIF(L.EQ.3.AND.IBUN(4,ITY).NE.1) THEN
c ** no partitioning
         wari=1.d0/dsqrt(2.d0)
         DO 90 IG=1,NGNL(ITY)
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))*wari
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))*wari
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))*wari
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))*wari
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))*wari
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))*wari
         SUKA1=EXTAU(IG)*Y31*VPJ(IG,1,li,ity)
         SUKA2=EXTAU(IG)*Y32*VPJ(IG,1,li,ity)
         SUKA3=EXTAU(IG)*Y33*VPJ(IG,1,li,ity)
         SUKA4=EXTAU(IG)*Y34*VPJ(IG,1,li,ity)
         SUKA5=EXTAU(IG)*Y35*VPJ(IG,1,li,ity)
         SUKA6=EXTAU(IG)*Y36*VPJ(IG,1,li,ity)
         SUKA7=EXTAU(IG)*Y37*VPJ(IG,1,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG, 1)=SUKA1*G2K(1,IG)
         DCOEF(IG, 2)=SUKA1*G2K(2,IG)
         DCOEF(IG, 3)=SUKA1*G2K(3,IG)
         WORK2(IG)=SUKA2
         DCOEF(IG, 4)=SUKA2*G2K(1,IG)
         DCOEF(IG, 5)=SUKA2*G2K(2,IG)
         DCOEF(IG, 6)=SUKA2*G2K(3,IG)
         WORK3(IG)=SUKA3
         DCOEF(IG, 7)=SUKA3*G2K(1,IG)
         DCOEF(IG, 8)=SUKA3*G2K(2,IG)
         DCOEF(IG, 9)=SUKA3*G2K(3,IG)
         WORK4(IG)=SUKA4
         DCOEF(IG,10)=SUKA4*G2K(1,IG)
         DCOEF(IG,11)=SUKA4*G2K(2,IG)
         DCOEF(IG,12)=SUKA4*G2K(3,IG)
         WORK5(IG)=SUKA5
         DCOEF(IG,13)=SUKA5*G2K(1,IG)
         DCOEF(IG,14)=SUKA5*G2K(2,IG)
         DCOEF(IG,15)=SUKA5*G2K(3,IG)
         WORK6(IG)=SUKA6
         DCOEF(IG,16)=SUKA6*G2K(1,IG)
         DCOEF(IG,17)=SUKA6*G2K(2,IG)
         DCOEF(IG,18)=SUKA6*G2K(3,IG)
         WORK7(IG)=SUKA7
         DCOEF(IG,19)=SUKA7*G2K(1,IG)
         DCOEF(IG,20)=SUKA7*G2K(2,IG)
         DCOEF(IG,21)=SUKA7*G2K(3,IG)
   90    CONTINUE
       DO 91 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
         CT(1)=0.D0
         CD(1,1)=0.D0
         CD(2,1)=0.D0
         CD(3,1)=0.D0
         CT(2)=0.D0
         CD(1,2)=0.D0
         CD(2,2)=0.D0
         CD(3,2)=0.D0
         CT(3)=0.D0
         CD(1,3)=0.D0
         CD(2,3)=0.D0
         CD(3,3)=0.D0
         CT(4)=0.D0
         CD(1,4)=0.D0
         CD(2,4)=0.D0
         CD(3,4)=0.D0
         CT(5)=0.D0
         CD(1,5)=0.D0
         CD(2,5)=0.D0
         CD(3,5)=0.D0
         CT(6)=0.D0
         CD(1,6)=0.D0
         CD(2,6)=0.D0
         CD(3,6)=0.D0
         CT(7)=0.D0
         CD(1,7)=0.D0
         CD(2,7)=0.D0
         CD(3,7)=0.D0
         DO 92 IG=1,NGNL(ITY)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IIB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IIB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IIB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IIB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IIB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IIB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IIB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IIB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IIB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IIB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IIB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IIB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IIB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IIB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IIB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IIB)*DCOEF(IG,15)
            CT(6)=CT(6)+COEF(IG,IIB)*WORK6(IG)
            CD(1,6)=CD(1,6)+COEF(IG,IIB)*DCOEF(IG,16)
            CD(2,6)=CD(2,6)+COEF(IG,IIB)*DCOEF(IG,17)
            CD(3,6)=CD(3,6)+COEF(IG,IIB)*DCOEF(IG,18)
            CT(7)=CT(7)+COEF(IG,IIB)*WORK7(IG)
            CD(1,7)=CD(1,7)+COEF(IG,IIB)*DCOEF(IG,19)
            CD(2,7)=CD(2,7)+COEF(IG,IIB)*DCOEF(IG,20)
            CD(3,7)=CD(3,7)+COEF(IG,IIB)*DCOEF(IG,21)
   92    CONTINUE
            EENL(IB)=EENL(IB)+(CT(1)*DCONJG(CT(1))
     &             +CT(2)*DCONJG(CT(2))
     &             +CT(3)*DCONJG(CT(3))
     &             +CT(4)*DCONJG(CT(4))
     &             +CT(5)*DCONJG(CT(5))
     &             +CT(6)*DCONJG(CT(6))
     &             +CT(7)*DCONJG(CT(7)))/VPP(1,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+DIMAG(CD(1,1)*DCONJG(CT(1))
     &                +CD(1,2)*DCONJG(CT(2))
     &                +CD(1,3)*DCONJG(CT(3))
     &                +CD(1,4)*DCONJG(CT(4))
     &                +CD(1,5)*DCONJG(CT(5))
     &                +CD(1,6)*DCONJG(CT(6))
     &                +CD(1,7)*DCONJG(CT(7)))
     &              /VPP(1,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+DIMAG(CD(2,1)*DCONJG(CT(1))
     &                +CD(2,2)*DCONJG(CT(2))
     &                +CD(2,3)*DCONJG(CT(3))
     &                +CD(2,4)*DCONJG(CT(4))
     &                +CD(2,5)*DCONJG(CT(5))
     &                +CD(2,6)*DCONJG(CT(6))
     &                +CD(2,7)*DCONJG(CT(7)))
     &              /VPP(1,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+DIMAG(CD(3,1)*DCONJG(CT(1))
     &                +CD(3,2)*DCONJG(CT(2))
     &                +CD(3,3)*DCONJG(CT(3))
     &                +CD(3,4)*DCONJG(CT(4))
     &                +CD(3,5)*DCONJG(CT(5))
     &                +CD(3,6)*DCONJG(CT(6))
     &                +CD(3,7)*DCONJG(CT(7)))
     &              /VPP(1,li,ity)
   91  CONTINUE
      ELSEIF(L.EQ.3) THEN
       wari=1.d0/dsqrt(2.d0)
       DO 1380 IP=2,3
         DO 100 IG=1,NGNL(ITY)
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))*wari
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))*wari
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))*wari
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))*wari
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))*wari
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))*wari
         SUKA1=EXTAU(IG)*Y31*VPJ(IG,IP,li,ity)
         SUKA2=EXTAU(IG)*Y32*VPJ(IG,IP,li,ity)
         SUKA3=EXTAU(IG)*Y33*VPJ(IG,IP,li,ity)
         SUKA4=EXTAU(IG)*Y34*VPJ(IG,IP,li,ity)
         SUKA5=EXTAU(IG)*Y35*VPJ(IG,IP,li,ity)
         SUKA6=EXTAU(IG)*Y36*VPJ(IG,IP,li,ity)
         SUKA7=EXTAU(IG)*Y37*VPJ(IG,IP,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG, 1)=SUKA1*G2K(1,IG)
         DCOEF(IG, 2)=SUKA1*G2K(2,IG)
         DCOEF(IG, 3)=SUKA1*G2K(3,IG)
         WORK2(IG)=SUKA2
         DCOEF(IG, 4)=SUKA2*G2K(1,IG)
         DCOEF(IG, 5)=SUKA2*G2K(2,IG)
         DCOEF(IG, 6)=SUKA2*G2K(3,IG)
         WORK3(IG)=SUKA3
         DCOEF(IG, 7)=SUKA3*G2K(1,IG)
         DCOEF(IG, 8)=SUKA3*G2K(2,IG)
         DCOEF(IG, 9)=SUKA3*G2K(3,IG)
         WORK4(IG)=SUKA4
         DCOEF(IG,10)=SUKA4*G2K(1,IG)
         DCOEF(IG,11)=SUKA4*G2K(2,IG)
         DCOEF(IG,12)=SUKA4*G2K(3,IG)
         WORK5(IG)=SUKA5
         DCOEF(IG,13)=SUKA5*G2K(1,IG)
         DCOEF(IG,14)=SUKA5*G2K(2,IG)
         DCOEF(IG,15)=SUKA5*G2K(3,IG)
         WORK6(IG)=SUKA6
         DCOEF(IG,16)=SUKA6*G2K(1,IG)
         DCOEF(IG,17)=SUKA6*G2K(2,IG)
         DCOEF(IG,18)=SUKA6*G2K(3,IG)
         WORK7(IG)=SUKA7
         DCOEF(IG,19)=SUKA7*G2K(1,IG)
         DCOEF(IG,20)=SUKA7*G2K(2,IG)
         DCOEF(IG,21)=SUKA7*G2K(3,IG)
  100    CONTINUE
       DO 101 IB=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
         CT(1)=0.D0
         CD(1,1)=0.D0
         CD(2,1)=0.D0
         CD(3,1)=0.D0
         CT(2)=0.D0
         CD(1,2)=0.D0
         CD(2,2)=0.D0
         CD(3,2)=0.D0
         CT(3)=0.D0
         CD(1,3)=0.D0
         CD(2,3)=0.D0
         CD(3,3)=0.D0
         CT(4)=0.D0
         CD(1,4)=0.D0
         CD(2,4)=0.D0
         CD(3,4)=0.D0
         CT(5)=0.D0
         CD(1,5)=0.D0
         CD(2,5)=0.D0
         CD(3,5)=0.D0
         CT(6)=0.D0
         CD(1,6)=0.D0
         CD(2,6)=0.D0
         CD(3,6)=0.D0
         CT(7)=0.D0
         CD(1,7)=0.D0
         CD(2,7)=0.D0
         CD(3,7)=0.D0
c         DO 102 IG=1,NG2
         DO 102 IG=1,NGNL(ITY)
            CT(1)=CT(1)+COEF(IG,IIB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IIB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IIB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IIB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IIB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IIB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IIB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IIB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IIB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IIB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IIB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IIB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IIB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IIB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IIB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IIB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IIB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IIB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IIB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IIB)*DCOEF(IG,15)
            CT(6)=CT(6)+COEF(IG,IIB)*WORK6(IG)
            CD(1,6)=CD(1,6)+COEF(IG,IIB)*DCOEF(IG,16)
            CD(2,6)=CD(2,6)+COEF(IG,IIB)*DCOEF(IG,17)
            CD(3,6)=CD(3,6)+COEF(IG,IIB)*DCOEF(IG,18)
            CT(7)=CT(7)+COEF(IG,IIB)*WORK7(IG)
            CD(1,7)=CD(1,7)+COEF(IG,IIB)*DCOEF(IG,19)
            CD(2,7)=CD(2,7)+COEF(IG,IIB)*DCOEF(IG,20)
            CD(3,7)=CD(3,7)+COEF(IG,IIB)*DCOEF(IG,21)
  102    CONTINUE
            EENL(IB)=EENL(IB)+(CT(1)*DCONJG(CT(1))
     &             +CT(2)*DCONJG(CT(2))
     &             +CT(3)*DCONJG(CT(3))
     &             +CT(4)*DCONJG(CT(4))
     &             +CT(5)*DCONJG(CT(5))
     &             +CT(6)*DCONJG(CT(6))
     &             +CT(7)*DCONJG(CT(7)))/VPP(IP,li,ity)
            FXNL(ITAU,IB)=FXNL(ITAU,IB)+DIMAG(CD(1,1)*DCONJG(CT(1))
     &                +CD(1,2)*DCONJG(CT(2))
     &                +CD(1,3)*DCONJG(CT(3))
     &                +CD(1,4)*DCONJG(CT(4))
     &                +CD(1,5)*DCONJG(CT(5))
     &                +CD(1,6)*DCONJG(CT(6))
     &                +CD(1,7)*DCONJG(CT(7)))
     &              /VPP(IP,li,ity)
            FYNL(ITAU,IB)=FYNL(ITAU,IB)+DIMAG(CD(2,1)*DCONJG(CT(1))
     &                +CD(2,2)*DCONJG(CT(2))
     &                +CD(2,3)*DCONJG(CT(3))
     &                +CD(2,4)*DCONJG(CT(4))
     &                +CD(2,5)*DCONJG(CT(5))
     &                +CD(2,6)*DCONJG(CT(6))
     &                +CD(2,7)*DCONJG(CT(7)))
     &              /VPP(IP,li,ity)
            FZNL(ITAU,IB)=FZNL(ITAU,IB)+DIMAG(CD(3,1)*DCONJG(CT(1))
     &                +CD(3,2)*DCONJG(CT(2))
     &                +CD(3,3)*DCONJG(CT(3))
     &                +CD(3,4)*DCONJG(CT(4))
     &                +CD(3,5)*DCONJG(CT(5))
     &                +CD(3,6)*DCONJG(CT(6))
     &                +CD(3,7)*DCONJG(CT(7)))
     &              /VPP(IP,li,ity)
  101  CONTINUE
 1380  CONTINUE
      ELSE
         write(6,*)' my_rank = ',my_rank
         Write(6,*)
     &   ' ILL-ORBITAL IS INDICATED OR MORE THAN TWO PARTIONING '
         STOP ' F-ORBITAL IS INDICATED OR MORE THAN TWO PARTIONING '
      ENDIF
C     WRITE(6,*) ' ENL=',ENL,'F=',FX,FY,FZ
   30 CONTINUE
C     DFORCE(1,ITAU)=DFORCE(1,ITAU)-FX*2.D0*TPIBA
C     DFORCE(2,ITAU)=DFORCE(2,ITAU)-FY*2.D0*TPIBA
C     DFORCE(3,ITAU)=DFORCE(3,ITAU)-FZ*2.D0*TPIBA
   20 CONTINUE
c ****  temp check
c      write(6,*)'my_rank=',my_rank,' end of DO 10 loop in SEPPOTF'
c ****  temp check : end
   10 CONTINUE
      if (my_rank.ne.0 ) then
      nbleng=nend(my_rank)-nbegin(my_rank)+1
      call MPI_Send(EENL(nbegin(my_rank)),nbleng,
     &       MPI_DOUBLE_PRECISION,0,tag,MPI_COMM_WORLD,ierr)
      call MPI_Send(FXNL(1,nbegin(my_rank)),ntauq*nbleng,
     &       MPI_DOUBLE_PRECISION,0,tag+1,MPI_COMM_WORLD,ierr)
      call MPI_Send(FYNL(1,nbegin(my_rank)),ntauq*nbleng,
     &       MPI_DOUBLE_PRECISION,0,tag+2,MPI_COMM_WORLD,ierr)
      call MPI_Send(FZNL(1,nbegin(my_rank)),ntauq*nbleng,
     &       MPI_DOUBLE_PRECISION,0,tag+3,MPI_COMM_WORLD,ierr)
      else  
      do icpu=1,ncpu
      nbleng=nend(icpu)-nbegin(icpu)+1
      call MPI_Recv(EENL(nbegin(icpu)),nbleng,
     &  MPI_DOUBLE_PRECISION,icpu,tag,MPI_COMM_WORLD,status,ierr)
      call MPI_Recv(FXNL(1,nbegin(icpu)),ntauq*nbleng,
     &  MPI_DOUBLE_PRECISION,icpu,tag+1,MPI_COMM_WORLD,status,ierr)
      call MPI_Recv(FYNL(1,nbegin(icpu)),ntauq*nbleng,
     &  MPI_DOUBLE_PRECISION,icpu,tag+2,MPI_COMM_WORLD,status,ierr)
      call MPI_Recv(FZNL(1,nbegin(icpu)),ntauq*nbleng,
     &  MPI_DOUBLE_PRECISION,icpu,tag+3,MPI_COMM_WORLD,status,ierr)
      enddo
      endif
C     WRITE(6,*) ' COEF CHECK ',COEF(1,1),COEF(1,2)
C     WRITE(6,*) ' ##NON-LOCAL##',ENL
CC      CALL CLOCK(TIM1)
C     WRITE(6,*) ' NON-LOCAL CPTIME= ',TIM1-TIM0
c ***  temp check
c      write(6,*)' in sub. SEPPOTF '
c      write(6,*)' EENL '
c      write(6,*)( eenl(ib),ib=1,nbnd )
c *** temp check : end
      RETURN
      END
