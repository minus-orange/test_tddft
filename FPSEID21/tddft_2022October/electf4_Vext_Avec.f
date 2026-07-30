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
     &     ,NGcont,SEPWORK,SEPRED
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
      COMPLEX*16 SEPWORK(NGcont,5,NTAUQ),
     &           SEPRED(16,NTAUQ,MXBND)
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(119)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(119)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(128)
#endif
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
     &  ,NGcont,SEPWORK,SEPRED
c +++ for macroscopic current
     &   ,RHOAX,RHOAY,RHOAZ,PX,PY,PZ,PXTOT,PYTOT,PZTOT
c
     &  ,nbegin,nend,ncpuq,ncpu  )
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(128)
#endif
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

C********************************************************************
C Step 107: batched nonpartitioned s/p projector reductions.
C Projectors are generated once per atom, then each reduction kernel
C exposes atom x local-band gangs.  The final kernel keeps the original
C type, atom, and s-then-p accumulation order for every band.
      SUBROUTINE SEPPOTF_ACC(NG2Q,NBNDQ,G2K,VPJ,VPP,YLM,COEF,
     & TPIBA,TAU,EENL,FXNL,FYNL,FZNL,NTAUQ,NTYQ,NTYPE,NUMTY,NIDN,
     & MXOFL,NGNL,NGCONT,SEPWORK,SEPRED,MXBND,NB0,NB1)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION G2K(4,NG2Q),VPJ(NGCONT,3,4,NTYQ),
     & VPP(3,4,NTYQ),YLM(NGCONT,16),NUMTY(NTYQ),
     & NIDN(NTAUQ,NTYQ),MXOFL(NTYQ),NGNL(NTYQ),TAU(3,NTAUQ)
      DIMENSION EENL(NBNDQ),FXNL(NTAUQ,NBNDQ),
     & FYNL(NTAUQ,NBNDQ),FZNL(NTAUQ,NBNDQ)
      COMPLEX*16 COEF(NG2Q,MXBND),SEPWORK(NGCONT,5,NTAUQ),
     & SEPRED(16,NTAUQ,MXBND)
      NBLENG=NB1-NB0+1
      DO ITY=1,NTYPE
       NATM=NUMTY(ITY)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
       CALL PROF_START(140)
#endif
       CALL SEPPOTF_PROJECT_ACC(NG2Q,NGNL(ITY),NGCONT,NTAUQ,
     &  NTYQ,NATM,ITY,G2K,YLM,VPJ,TAU,TPIBA,NIDN,
     &  MXOFL(ITY),SEPWORK)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
       CALL PROF_STOP(140)
       CALL PROF_START(141)
#endif
       CALL SEPPOTF_S_BATCH_ACC(NG2Q,NGNL(ITY),NGCONT,NTAUQ,
     &  NTYQ,NATM,ITY,NBLENG,MXBND,G2K,COEF,NIDN,
     &  SEPWORK,SEPRED)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
       CALL PROF_STOP(141)
#endif
       IF (MXOFL(ITY).GE.2) THEN
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
        CALL PROF_START(142)
#endif
        CALL SEPPOTF_P_BATCH_ACC(NG2Q,NGNL(ITY),NGCONT,NTAUQ,
     &   NTYQ,NATM,ITY,NBLENG,MXBND,G2K,COEF,NIDN,
     &   SEPWORK,SEPRED)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
        CALL PROF_STOP(142)
#endif
       ENDIF
      ENDDO
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      CALL PROF_START(143)
#endif
      CALL SEPPOTF_FINAL_ACC(NBNDQ,NTAUQ,NTYQ,NTYPE,NUMTY,NIDN,
     & MXOFL,VPP,EENL,FXNL,FYNL,FZNL,SEPRED,MXBND,
     & NBLENG,NB0)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      CALL PROF_STOP(143)
      CALL PROF_START(144)
#endif
!$acc update self(EENL(NB0:NB1))
!$acc update self(FXNL(1:NTAUQ,NB0:NB1))
!$acc update self(FYNL(1:NTAUQ,NB0:NB1))
!$acc update self(FZNL(1:NTAUQ,NB0:NB1))
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      CALL PROF_STOP(144)
#endif
      RETURN
      END

      SUBROUTINE SEPPOTF_PROJECT_ACC(NG2Q,NGL,NGCONT,NTAUQ,
     & NTYQ,NATM,ITY,G2K,YLM,VPJ,TAU,TPIBA,NIDN,LMAX,SEPWORK)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION G2K(4,NG2Q),YLM(NGCONT,16),
     & VPJ(NGCONT,3,4,NTYQ),TAU(3,NTAUQ),
     & NIDN(NTAUQ,NTYQ)
      COMPLEX*16 SEPWORK(NGCONT,5,NTAUQ)
      SQ2=DSQRT(2.D0)
!$acc parallel loop gang vector collapse(2) vector_length(128)
!$acc& present(G2K(1:4,1:NG2Q),YLM(1:NGCONT,1:16),
!$acc& VPJ(1:NGCONT,1:3,1:4,1:NTYQ),TAU(1:3,1:NTAUQ),
!$acc& NIDN(1:NTAUQ,1:NTYQ),
!$acc& SEPWORK(1:NGCONT,1:5,1:NTAUQ))
      DO IATM=1,NATM
       DO IG=1,NGL
        ITAU=NIDN(IATM,ITY)
        TEMP=TPIBA*(G2K(1,IG)*TAU(1,ITAU)
     &       +G2K(2,IG)*TAU(2,ITAU)+G2K(3,IG)*TAU(3,ITAU))
        PHR=COS(TEMP)
        PHI=SIN(TEMP)
        WR=PHR*YLM(IG,1)
        WI=PHI*YLM(IG,1)
        SEPWORK(IG,2,ITAU)=DCMPLX(WR*VPJ(IG,1,1,ITY),
     &                                  WI*VPJ(IG,1,1,ITY))
        IF (LMAX.GE.2) THEN
         WR=PHR*YLM(IG,3)*SQ2
         WI=PHI*YLM(IG,3)*SQ2
         SEPWORK(IG,3,ITAU)=DCMPLX(WR*VPJ(IG,1,2,ITY),
     &                                    WI*VPJ(IG,1,2,ITY))
         WR=PHR*YLM(IG,4)*SQ2
         WI=PHI*YLM(IG,4)*SQ2
         SEPWORK(IG,4,ITAU)=DCMPLX(WR*VPJ(IG,1,2,ITY),
     &                                    WI*VPJ(IG,1,2,ITY))
         WR=PHR*YLM(IG,2)
         WI=PHI*YLM(IG,2)
         SEPWORK(IG,5,ITAU)=DCMPLX(WR*VPJ(IG,1,2,ITY),
     &                                    WI*VPJ(IG,1,2,ITY))
        ENDIF
       ENDDO
      ENDDO
      RETURN
      END

      SUBROUTINE SEPPOTF_S_BATCH_ACC(NG2Q,NGL,NGCONT,NTAUQ,
     & NTYQ,NATM,ITY,NBLENG,MXBND,G2K,COEF,NIDN,
     & SEPWORK,SEPRED)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION G2K(4,NG2Q),NIDN(NTAUQ,NTYQ)
      COMPLEX*16 COEF(NG2Q,MXBND),SEPWORK(NGCONT,5,NTAUQ),
     & SEPRED(16,NTAUQ,MXBND)
!$acc parallel loop gang collapse(2) vector_length(256)
!$acc& present(G2K(1:4,1:NG2Q),COEF(1:NG2Q,1:MXBND),
!$acc& NIDN(1:NTAUQ,1:NTYQ),
!$acc& SEPWORK(1:NGCONT,1:5,1:NTAUQ),
!$acc& SEPRED(1:16,1:NTAUQ,1:MXBND))
      DO IATM=1,NATM
       DO IIB=1,NBLENG
        ITAU=NIDN(IATM,ITY)
        CTR=0.D0
        CTI=0.D0
        DXR=0.D0
        DXI=0.D0
        DYR=0.D0
        DYI=0.D0
        DZR=0.D0
        DZI=0.D0
!$acc loop vector reduction(+:CTR,CTI,DXR,DXI,DYR,DYI,DZR,DZI)
        DO IG=1,NGL
         WR=DBLE(SEPWORK(IG,2,ITAU))
         WI=DIMAG(SEPWORK(IG,2,ITAU))
         AR=DBLE(COEF(IG,IIB))
         AI=DIMAG(COEF(IG,IIB))
         PR=AR*WR-AI*WI
         PI=AR*WI+AI*WR
         CTR=CTR+PR
         CTI=CTI+PI
         DWR=WR*G2K(1,IG)
         DWI=WI*G2K(1,IG)
         DXR=DXR+AR*DWR-AI*DWI
         DXI=DXI+AR*DWI+AI*DWR
         DWR=WR*G2K(2,IG)
         DWI=WI*G2K(2,IG)
         DYR=DYR+AR*DWR-AI*DWI
         DYI=DYI+AR*DWI+AI*DWR
         DWR=WR*G2K(3,IG)
         DWI=WI*G2K(3,IG)
         DZR=DZR+AR*DWR-AI*DWI
         DZI=DZI+AR*DWI+AI*DWR
        ENDDO
        SEPRED(1,ITAU,IIB)=DCMPLX(CTR,CTI)
        SEPRED(2,ITAU,IIB)=DCMPLX(DXR,DXI)
        SEPRED(3,ITAU,IIB)=DCMPLX(DYR,DYI)
        SEPRED(4,ITAU,IIB)=DCMPLX(DZR,DZI)
       ENDDO
      ENDDO
      RETURN
      END

      SUBROUTINE SEPPOTF_P_BATCH_ACC(NG2Q,NGL,NGCONT,NTAUQ,
     & NTYQ,NATM,ITY,NBLENG,MXBND,G2K,COEF,NIDN,
     & SEPWORK,SEPRED)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION G2K(4,NG2Q),NIDN(NTAUQ,NTYQ)
      COMPLEX*16 COEF(NG2Q,MXBND),SEPWORK(NGCONT,5,NTAUQ),
     & SEPRED(16,NTAUQ,MXBND)
!$acc parallel loop gang collapse(2) vector_length(256)
!$acc& present(G2K(1:4,1:NG2Q),COEF(1:NG2Q,1:MXBND),
!$acc& NIDN(1:NTAUQ,1:NTYQ),
!$acc& SEPWORK(1:NGCONT,1:5,1:NTAUQ),
!$acc& SEPRED(1:16,1:NTAUQ,1:MXBND))
      DO IATM=1,NATM
       DO IIB=1,NBLENG
        ITAU=NIDN(IATM,ITY)
        C1R=0.D0
        C1I=0.D0
        X1R=0.D0
        X1I=0.D0
        Y1R=0.D0
        Y1I=0.D0
        Z1R=0.D0
        Z1I=0.D0
        C2R=0.D0
        C2I=0.D0
        X2R=0.D0
        X2I=0.D0
        Y2R=0.D0
        Y2I=0.D0
        Z2R=0.D0
        Z2I=0.D0
        C3R=0.D0
        C3I=0.D0
        X3R=0.D0
        X3I=0.D0
        Y3R=0.D0
        Y3I=0.D0
        Z3R=0.D0
        Z3I=0.D0
!$acc loop vector reduction(+:C1R,C1I,X1R,X1I,Y1R,Y1I,Z1R,Z1I,
!$acc& C2R,C2I,X2R,X2I,Y2R,Y2I,Z2R,Z2I,
!$acc& C3R,C3I,X3R,X3I,Y3R,Y3I,Z3R,Z3I)
        DO IG=1,NGL
         AR=DBLE(COEF(IG,IIB))
         AI=DIMAG(COEF(IG,IIB))
         W1R=DBLE(SEPWORK(IG,3,ITAU))
         W1I=DIMAG(SEPWORK(IG,3,ITAU))
         W2R=DBLE(SEPWORK(IG,4,ITAU))
         W2I=DIMAG(SEPWORK(IG,4,ITAU))
         W3R=DBLE(SEPWORK(IG,5,ITAU))
         W3I=DIMAG(SEPWORK(IG,5,ITAU))
         P1R=AR*W1R-AI*W1I
         P1I=AR*W1I+AI*W1R
         P2R=AR*W2R-AI*W2I
         P2I=AR*W2I+AI*W2R
         P3R=AR*W3R-AI*W3I
         P3I=AR*W3I+AI*W3R
         C1R=C1R+P1R
         C1I=C1I+P1I
         DWR=W1R*G2K(1,IG)
         DWI=W1I*G2K(1,IG)
         X1R=X1R+AR*DWR-AI*DWI
         X1I=X1I+AR*DWI+AI*DWR
         DWR=W1R*G2K(2,IG)
         DWI=W1I*G2K(2,IG)
         Y1R=Y1R+AR*DWR-AI*DWI
         Y1I=Y1I+AR*DWI+AI*DWR
         DWR=W1R*G2K(3,IG)
         DWI=W1I*G2K(3,IG)
         Z1R=Z1R+AR*DWR-AI*DWI
         Z1I=Z1I+AR*DWI+AI*DWR
         C2R=C2R+P2R
         C2I=C2I+P2I
         DWR=W2R*G2K(1,IG)
         DWI=W2I*G2K(1,IG)
         X2R=X2R+AR*DWR-AI*DWI
         X2I=X2I+AR*DWI+AI*DWR
         DWR=W2R*G2K(2,IG)
         DWI=W2I*G2K(2,IG)
         Y2R=Y2R+AR*DWR-AI*DWI
         Y2I=Y2I+AR*DWI+AI*DWR
         DWR=W2R*G2K(3,IG)
         DWI=W2I*G2K(3,IG)
         Z2R=Z2R+AR*DWR-AI*DWI
         Z2I=Z2I+AR*DWI+AI*DWR
         C3R=C3R+P3R
         C3I=C3I+P3I
         DWR=W3R*G2K(1,IG)
         DWI=W3I*G2K(1,IG)
         X3R=X3R+AR*DWR-AI*DWI
         X3I=X3I+AR*DWI+AI*DWR
         DWR=W3R*G2K(2,IG)
         DWI=W3I*G2K(2,IG)
         Y3R=Y3R+AR*DWR-AI*DWI
         Y3I=Y3I+AR*DWI+AI*DWR
         DWR=W3R*G2K(3,IG)
         DWI=W3I*G2K(3,IG)
         Z3R=Z3R+AR*DWR-AI*DWI
         Z3I=Z3I+AR*DWI+AI*DWR
        ENDDO
        SEPRED(5,ITAU,IIB)=DCMPLX(C1R,C1I)
        SEPRED(6,ITAU,IIB)=DCMPLX(X1R,X1I)
        SEPRED(7,ITAU,IIB)=DCMPLX(Y1R,Y1I)
        SEPRED(8,ITAU,IIB)=DCMPLX(Z1R,Z1I)
        SEPRED(9,ITAU,IIB)=DCMPLX(C2R,C2I)
        SEPRED(10,ITAU,IIB)=DCMPLX(X2R,X2I)
        SEPRED(11,ITAU,IIB)=DCMPLX(Y2R,Y2I)
        SEPRED(12,ITAU,IIB)=DCMPLX(Z2R,Z2I)
        SEPRED(13,ITAU,IIB)=DCMPLX(C3R,C3I)
        SEPRED(14,ITAU,IIB)=DCMPLX(X3R,X3I)
        SEPRED(15,ITAU,IIB)=DCMPLX(Y3R,Y3I)
        SEPRED(16,ITAU,IIB)=DCMPLX(Z3R,Z3I)
       ENDDO
      ENDDO
      RETURN
      END

      SUBROUTINE SEPPOTF_FINAL_ACC(NBNDQ,NTAUQ,NTYQ,NTYPE,
     & NUMTY,NIDN,MXOFL,VPP,EENL,FXNL,FYNL,FZNL,SEPRED,
     & MXBND,NBLENG,NB0)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),MXOFL(NTYQ),
     & VPP(3,4,NTYQ),EENL(NBNDQ),FXNL(NTAUQ,NBNDQ),
     & FYNL(NTAUQ,NBNDQ),FZNL(NTAUQ,NBNDQ)
      COMPLEX*16 SEPRED(16,NTAUQ,MXBND)
!$acc parallel loop gang vector_length(1)
!$acc& present(NUMTY(1:NTYQ),NIDN(1:NTAUQ,1:NTYQ),
!$acc& MXOFL(1:NTYQ),VPP(1:3,1:4,1:NTYQ),
!$acc& EENL(1:NBNDQ),FXNL(1:NTAUQ,1:NBNDQ),
!$acc& FYNL(1:NTAUQ,1:NBNDQ),FZNL(1:NTAUQ,1:NBNDQ),
!$acc& SEPRED(1:16,1:NTAUQ,1:MXBND))
      DO IIB=1,NBLENG
       IB=NB0+IIB-1
       EVAL=0.D0
       DO ITAU=1,NTAUQ
        FXNL(ITAU,IB)=0.D0
        FYNL(ITAU,IB)=0.D0
        FZNL(ITAU,IB)=0.D0
       ENDDO
       DO ITY=1,NTYPE
        DO IATM=1,NUMTY(ITY)
         ITAU=NIDN(IATM,ITY)
         CTR=DBLE(SEPRED(1,ITAU,IIB))
         CTI=DIMAG(SEPRED(1,ITAU,IIB))
         DXR=DBLE(SEPRED(2,ITAU,IIB))
         DXI=DIMAG(SEPRED(2,ITAU,IIB))
         DYR=DBLE(SEPRED(3,ITAU,IIB))
         DYI=DIMAG(SEPRED(3,ITAU,IIB))
         DZR=DBLE(SEPRED(4,ITAU,IIB))
         DZI=DIMAG(SEPRED(4,ITAU,IIB))
         DEN=VPP(1,1,ITY)
         EVAL=EVAL+(CTR*CTR+CTI*CTI)/DEN
         FXNL(ITAU,IB)=FXNL(ITAU,IB)+(DXI*CTR-DXR*CTI)/DEN
         FYNL(ITAU,IB)=FYNL(ITAU,IB)+(DYI*CTR-DYR*CTI)/DEN
         FZNL(ITAU,IB)=FZNL(ITAU,IB)+(DZI*CTR-DZR*CTI)/DEN
         IF (MXOFL(ITY).GE.2) THEN
          PEVAL=0.D0
          PFX=0.D0
          PFY=0.D0
          PFZ=0.D0
          DO IP=0,2
           JC=5+4*IP
           CTR=DBLE(SEPRED(JC,ITAU,IIB))
           CTI=DIMAG(SEPRED(JC,ITAU,IIB))
           DXR=DBLE(SEPRED(JC+1,ITAU,IIB))
           DXI=DIMAG(SEPRED(JC+1,ITAU,IIB))
           DYR=DBLE(SEPRED(JC+2,ITAU,IIB))
           DYI=DIMAG(SEPRED(JC+2,ITAU,IIB))
           DZR=DBLE(SEPRED(JC+3,ITAU,IIB))
           DZI=DIMAG(SEPRED(JC+3,ITAU,IIB))
           PEVAL=PEVAL+CTR*CTR+CTI*CTI
           PFX=PFX+DXI*CTR-DXR*CTI
           PFY=PFY+DYI*CTR-DYR*CTI
           PFZ=PFZ+DZI*CTR-DZR*CTI
          ENDDO
          DEN=VPP(1,2,ITY)
          EVAL=EVAL+PEVAL/DEN
          FXNL(ITAU,IB)=FXNL(ITAU,IB)+PFX/DEN
          FYNL(ITAU,IB)=FYNL(ITAU,IB)+PFY/DEN
          FZNL(ITAU,IB)=FZNL(ITAU,IB)+PFZ/DEN
         ENDIF
        ENDDO
       ENDDO
       EENL(IB)=EVAL
      ENDDO
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
     &                    OCC,itstep,GDUMP,NGNL,NGcont,
     &                    SEPWORK,SEPRED
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
      COMPLEX*16 SEPWORK(NGcont,5,NTAUQ),
     &           SEPRED(16,NTAUQ,MXBND)
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
      PARAMETER (NTYQ2=4)
      COMMON/SAITO2/IBUN(4,NTYQ2)
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(129)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(129)
#endif
#ifdef _OPENACC
      IACCSP=1
#else
      IACCSP=0
#endif
      NBLACC=nend(my_rank)-nbegin(my_rank)+1
      if (NBLACC.le.0) IACCSP=0
      do 579 ITY=1,NTYPE
       if (NUMTY(ITY).le.0) IACCSP=0
       if (MXOFL(ITY).lt.1 .or. MXOFL(ITY).gt.2) IACCSP=0
       if (IBUN(1,ITY).eq.1) IACCSP=0
       if (MXOFL(ITY).ge.2 .and. IBUN(2,ITY).eq.1) IACCSP=0
  579 continue
! Step 107 maps one parent region around the k-point loop.  The accelerated
! path supports the tutorial nonpartitioned s/p projectors; all other shapes
! keep the original host implementation below.
!$acc data if(IACCSP.eq.1)
!$acc& present(COEF(1:NG2Q,1:MXBND,1:NUMKQ))
!$acc& copyin(G2(1:4,1:NG2Q,1:NUMKQ),
!$acc& VPJ(1:NGcont,1:3,1:4,1:NTYQ,1:NUMKQ),
!$acc& VPP(1:3,1:4,1:NTYQ),TAU(1:3,1:NTAUQ),
!$acc& NUMTY(1:NTYQ),NIDN(1:NTAUQ,1:NTYQ),
!$acc& MXOFL(1:NTYQ),NGNL(1:NTYQ,1:NUMKQ))
!$acc& create(YLM(1:NGcont,1:16),
!$acc& SEPWORK(1:NGcont,1:5,1:NTAUQ),
!$acc& SEPRED(1:16,1:NTAUQ,1:MXBND),
!$acc& EENL(1:NBNDQ,1:NUMKQ),
!$acc& FXNL(1:NTAUQ,1:NBNDQ,1:NUMKQ),
!$acc& FYNL(1:NTAUQ,1:NBNDQ,1:NUMKQ),
!$acc& FZNL(1:NTAUQ,1:NBNDQ,1:NUMKQ))
      DO 580 IK=1,NUMK
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_start(130)
         call prof_start(145)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(145)
         call prof_start(146)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(146)
         call prof_start(147)
#endif
c
           if ( my_rank.ne.0 ) then
            nbleng=nend(my_rank)-nbegin(my_rank)+1
            if ( nbleng.gt.0 ) then
            call MPI_Send(EE(nbegin(my_rank),IK),nbleng,
     &        MPI_DOUBLE_PRECISION,0,tag,MPI_COMM_WORLD,ierr)
            call MPI_Send(PX(nbegin(my_rank),IK),nbleng,
     &        MPI_DOUBLE_PRECISION,0,tag+1,MPI_COMM_WORLD,ierr)
            call MPI_Send(PY(nbegin(my_rank),IK),nbleng,
     &        MPI_DOUBLE_PRECISION,0,tag+2,MPI_COMM_WORLD,ierr)
            call MPI_Send(PZ(nbegin(my_rank),IK),nbleng,
     &        MPI_DOUBLE_PRECISION,0,tag+3,MPI_COMM_WORLD,ierr)
            endif
           else
            do icpu=1,ncpu
            nbleng=nend(icpu)-nbegin(icpu)+1
            if ( nbleng.gt.0 ) then
            call MPI_Recv(EE(nbegin(icpu),IK),nbleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag,MPI_COMM_WORLD,status,ierr)
            call MPI_Recv(PX(nbegin(icpu),IK),nbleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag+1,MPI_COMM_WORLD,status,ierr)
            call MPI_Recv(PY(nbegin(icpu),IK),nbleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag+2,MPI_COMM_WORLD,status,ierr)
            call MPI_Recv(PZ(nbegin(icpu),IK),nbleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag+3,MPI_COMM_WORLD,status,ierr)
            endif
            enddo
           endif ! end of if my_rank.ne.0 loop
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(147)
         call prof_start(148)
#endif
c ++++ for A-vector  Y. Miyamoto 2020 this is still within ik loop
             do IG=1,NG2(IK)
              RHOA(IG)=GDUMPd(IG,IK)*TPIBA
             enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(148)
         call prof_start(149)
#endif
             do IB=nbegin(my_rank),nend(my_rank)
             iib=ib-nbegin(my_rank)+1
              do IG=1,NG2(IK)
               EEd(IB,IK)=EEd(IB,IK)+
     &           0.5D0*DBLE(RHOA(IG)
     &         *DCONJG(COEF(IG,IIB,IK))*COEF(IG,IIB,IK))
              enddo
             enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(149)
         call prof_start(150)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(150)
         call prof_start(151)
#endif
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'DO 583 loop end'
c **** temp check : end
C
             DO 588 IG=1,NG2(IK)
  588        RHOA(IG)=SQRT(G2(4,IG,IK))*TPIBA
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(151)
         call prof_stop(130)
#endif
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'DO 588 loop end'
c **** temp check : end
         NG26=NG2(IK)/6
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_start(131)
#endif
         CALL GETYLM(NG2Q,NG26,G2(1,1,IK),RHOA,YLM,TPIBA,NGcont)
!$acc update device(YLM(1:NGcont,1:16)) if(IACCSP.eq.1)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(131)
#endif
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'after end of GETYLM'
c **** temp check : end
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_start(132)
#endif
         CALL SEPPOTF( NG2Q, NG2(IK),NBSEQ(IK),NBNDQ, G2(1,1,IK),
     &   VPJ(1,1,1,1,ik),VPP,YLM,RHO2
c     &  ,WORK2(1,1),WORK2(1,2),WORK2(1,3),
     &  ,WORK2(1,1),WORK2(1,2),WORK2(1,3),WORK2(1,4),WORK2(1,5),
     &   WORK2(1,6),WORK2(1,7),
     &   COEF(1,1,ik),DCOEF,TPIBA,IOVP(1,1,IK),
     &   EENL(1,IK),FXNL(1,1,IK),FYNL(1,1,IK),
     &   FZNL(1,1,IK),
     &   NTAUQ,NTYQ,LREQ,TAU,NTYPE,NUMTY,NIDN, MXOFL,NGNL(1,IK)
     &  ,NGcont,SEPWORK,SEPRED,MXBND,IACCSP
c
     &  ,nbegin,nend,ncpuq,ncpu )
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(132)
#endif
c **** temp check
c       write(6,*)'my_rank=',my_rank,'IK=',ik,'after end of SEPPOTF'
c **** temp check : end
  580 CONTINUE   ! end of IK loop
!$acc end data
c ***  temp check
c      write(6,*)' After sub. SEPPOTF '
c      write(6,*)' EENL '
c      do ik=1,numk
c        write(6,*)( EENL(ib,IK),ib=1,iowf(1,ik) )
c      enddo
c      write(6,*)' WK !! '
c      write(6,*)( wk(ik),ik=1,numk )
c ***  temp check : end
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(133)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(133)
#endif
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
     &  NTAUQ,NTYQ,LREQ,TAU,NTYPE,NUMTY,NIDN, MXOFL,NGNL,NGcont,
     &  SEPWORK,SEPRED,MXBND,IACCSP
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
      COMPLEX*16 COEF(NG2Q,MXBND),DCOEF(NG2Q,21),
c     &           WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),EXTAU(NG2Q)
     &  WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),WORK4(NG2Q),WORK5(NG2Q),
     &  WORK6(NG2Q),WORK7(NG2Q),EXTAU(NG2Q)
      COMPLEX*16 SEPWORK(NGcont,5,NTAUQ),
     &           SEPRED(16,NTAUQ,MXBND)
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
      if (IACCSP.eq.1) then
       call SEPPOTF_ACC(NG2Q,NBNDQ,G2K,VPJ,VPP,YLM,COEF,TPIBA,TAU,
     &  EENL,FXNL,FYNL,FZNL,NTAUQ,NTYQ,NTYPE,NUMTY,NIDN,
     &  MXOFL,NGNL,NGcont,SEPWORK,SEPRED,MXBND,
     &  nbegin(my_rank),nend(my_rank))
       goto 900
      endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(134)
#endif
c        DO 22 IG=1,NG2
        DO 22 IG=1,NGNL(ITY)
        TEMP=TPIBA*(G2K(1,IG)*TAU(1,ITAU)+G2K(2,IG)*TAU(2,ITAU)
     &             +G2K(3,IG)*TAU(3,ITAU))
        EXTAU(IG)=DCMPLX(COS(TEMP),SIN(TEMP))
   22   CONTINUE
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(134)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_start(135)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(135)
         call prof_start(136)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(136)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_start(137)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(137)
         call prof_start(138)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
         call prof_stop(138)
#endif
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
  900 CONTINUE
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(139)
#endif
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(139)
#endif
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
