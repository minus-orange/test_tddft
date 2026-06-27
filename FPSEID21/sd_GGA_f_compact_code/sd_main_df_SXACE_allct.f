      PROGRAM PSPW
C
C         1/20/95
C           LOCAL DENSITY OF STATES
C
C         1/17/95
C           FIX BUGS IN NONLOCF FOR THE CASE ON NON-INTEGER 
C           OCC(IBAND,IK). ACTUALLY FOR THE CASE OF OCC = 0.5
C           FOR THE HIGHEST OCCUPIED BAND
C
C         12/16/94
C           CHANGES RELATED TO "DISPER"
C
C         11/29/94
C           IMPROVEMENT IN DCGMIN:
C              1.  QUICK RETURN FROM LINMIN
C              2.  FIC BUN IN CUMIN
C
C         6/17/94
C           FIX A BUG RELATED TO 'DO 3200 K = 1, LATQ (SHOULD BE NLV)'
C           ALSO, CAPABLE OF 'KPOINT=0' AND 'NPFL=0'
C                    CARE NKMESH AND WGT AFTER CALLING KWGT IN CRYST.
C                    CARE SKIP 'NDX ETC' CHECK AT THE BEGINNING OF
C                         FRPRMN.
C                    OTHER VERSIONS DO NOT FEATURE THESE TWO.
C
C         CAPABLE OF TREATING NON-METAL (NPFL = 0) CASE,
C                 OF TREATING (S, P) NON-LOCAL POTENTIAL CASE
C                                      4/26/94
C
C         A VERSION FOR SX3:  2/13/94   A. OSHIYAMA
C              SX3 TAKES A LOT OF SYTEM TIME FOR INPUT/OUTPUT.
C              SO 1 RECORD OF DIRECT-ACCESS FILES OF 71, IFIL6,
C              AND IFIL7 IS MADE BIG: I.E. NG2Q * MXBND WHERE
C              MXBND IS A PORTION OF NBND (NBND IS DEVIDED INTO
C              WORKING BLOCK). TRADE-OFF IS A INCREASE OF
C              PROGRAM MEMORY.
C
C         WHEN LINK THE PROGRAMS ON SX2, LINKER GIVES
C         35 ERRORS WITH SEVERITY OF 2. THEY ARE PARAMETER-
C         RGUMENT ATTRIBUTES ERROR.
C                     2/15/94
C
C         ON SX3, WE ENCOUNTER A PROBLEM OF HUGE SYSTEM TIME WHICH
C         MAYBE RELATED TO INPUT/OUTPUT. SO I CHANGED DO SEQUENCES
C         IN READ/WRITE STATEMENT TO ARAY SEQUENCES.
C                              1/20/94
C
C
C     PLANE WAVE LDA CALCULATION
C                        ORIGINAL VERSION WRITTEN BY ATSUSHI OSHIYAMA
C                        MODIFIED VERSION WRITTEN BY OSAMU SUGINO
C                        3-D FFT IS A MODIFICATION OF NCARL 1-D FFT
C     TOTAL ENERGY AND FORCE    (1990-06-22)
C     SEPARABLE POTENTIAL       (1990-09-04)
C     MONO-VACANCY MIGRATION IN SI16 SUPER CELL
C                               (FROM 1990-09-05)
C     CONJUGATE GRADIENT GEOMETRY OPTIMIZATION (1990-11-07)
C     MONO-VACANCY MIGRATION IN SI64 SUPER CELL(1990-11-15)
C     MEMORY SAVE VERSION                      (1990-11-28)
C     DIRECT ACCESS VERSION                    (1991-01-18)
C     DUAL SPACE    (DO  NOT WORK WELL)        (1991-02-06)
C     AS IMPURITY                              (1991-02-14)
C     PARTITIONED POTENTITAL VERSION           (1992-03-11)
C     NUMERICAL PSEUDOPOTENTIAL                (1992-03-11)
C
C            NRX,NRY,NRZ
C            NGQ,NG2Q,NBNDQ,NVIRTQ
C            NTAUQ
C            LATQ
C            SUBROUTINE CRYST,STRUC,ELECTF
C
      IMPLICIT REAL*8 (A-H,O-Z)
C*******************************************************
c *** for Ce-doped YAG cube cell with a=12.12816873 a.u. 61 Ry
C  ***** !!!!  promote single electron !!!!
c      PARAMETER(NRX=39,NRY=39,NRZ=39,NXYZ=NRX*NRY*NRZ,
c     &          NFLQ =14,NVIRTQ = 10, MXBND=NFLQ+NVIRTQ,
c     &          NBNDQ = NFLQ + NVIRTQ,
c     &          NGQ=NXYZ,NG2Q=NXYZ, NUMKQ=10 )
c      PARAMETER(NTAUQ=3,NTYQ=2,NUMQ=3, NCRQ=2, LREQ=3)
      PARAMETER(NUMQ=3, NCRQ=2, LREQ=3)
      PARAMETER(LATQ=800,MESHQ=1000)
C*******************************************************
c      PARAMETER(MBLKQ=(NBNDQ-1)/MXBND + 1  )
      PARAMETER(MBLKQ= 1  )
      PARAMETER(NTYQ2=4)
      PARAMETER (IRLATQ=144,NARF=IRLATQ)
      PARAMETER (NAS=144,NAD=72)
      DIMENSION  RVEC(4,LATQ),RR(LATQ),NWK(LATQ)
      DIMENSION RKK(IRLATQ),KG(3,IRLATQ),KZ(3,IRLATQ,48),NSY(IRLATQ)
      DIMENSION RCOSIN(NAS,IRLATQ),CCO(-NAD:NAD),SK(3,NAS),WK(NAS)
      DIMENSION JDR(48,NAS),MM(3,10000),NJD(NAS)
      INTEGER*4   S
      DIMENSION   S(3,3,48)
      COMMON/AVEC/A1(3),A2(3),A3(3),B1(3),B2(3),B3(3), COVA, ALAT
      COMMON/CONSTS/NG,NUMK,NBND,NTOT,OMEGA,GCUT2,ESELF,NTYPE
      COMMON/COMFIX/FATM(3,101),NFIX,IFATM(101)
      COMMON/COMOPT/IOPT(10,5)
      COMMON/SAITO2/IBUN(4,NTYQ2)
      COMMON/SMOOTH/ADUMP
c
      complex*16, allocatable, save, dimension(:) :: RHO1,RHO2,RHO3,
     &                                               RHO4,VG,RHOG,
     &         WSAVEX,WSAVEY,WSAVEZ
      complex*16, allocatable, save, dimension(:,:) :: WORK2
c
      real*8, allocatable, save, dimension(:) :: RHO,CELLDM
      real*8, allocatable, save, dimension(:,:) :: G,YLM,GDUMP
      real*8, allocatable, save, dimension(:,:,:) :: G2
c
      integer*4, allocatable, save, dimension(:) :: IFACX,IFACY,IFACZ,
     &        LX1,LX2,LY1,LY2,LZ1,LZ2,I2G,NG2,NUMTY,MXOFL,NUMC
      integer*4, allocatable, save, dimension(:,:) :: J2G,NIDN,NGNK
c
      real*8, allocatable, save, dimension(:) :: ZV,ZZ,WGT
      real*8, allocatable, save, dimension(:,:) :: RC0,COR

c *****
      complex*16, allocatable, save, dimension(:,:) :: DCOEF,CL1
      complex*16, allocatable, save, dimension(:,:,:) :: COEF
c
      real*8, allocatable, save, dimension(:,:) :: VGA, vn1,vn2,
     &        Vchg,FORCE,TAU,WORK,CTAU
      real*8, allocatable, save, dimension(:,:,:) :: OUT
c
      real*8, allocatable, save, dimension(:,:) :: DFORCE, SFORCE,VECK
      real*8, allocatable, save, dimension(:,:,:) :: VPP
      real*8, allocatable, save, dimension(:,:,:,:,:) :: VPJ
      integer*4, allocatable,save,dimension (:,:) :: IOWF,NGNL
      integer*4, allocatable,save,dimension(:,:,:) :: IOVP
c
      real*8, allocatable,save,dimension(:,:) :: OCC,EE,GG
     &        ,ALPPP,BETAPP
      real*8, allocatable,save,dimension(:) :: ee2,ee3,ee4,EXPG

ccc
c     work area for orthogonarization
      complex*16, allocatable,save,dimension(:,:) :: sig,x0,x1,
     &     work1,work20
c
      real*8, allocatable,save,dimension(:) :: EW,PE,fdump
      real*8, allocatable,save,dimension(:,:) :: EBNDW, VINT,EENL
      real*8, allocatable,save,dimension(:,:,:) :: FXNL,FYNL,FZNL
cC
      DATA IFIL2,IFIL3,IFIL4,IFIL5,IFIL6,IFIL7
     &     /  30,   32,   33,   34,   35,   36/
C
      call bannerSD
c *** this is mpi version only
      call clock0
c
      read(54,*)NRX,NRY,NRZ  ! read mesh
      NXYZ=NRX*NRY*NRZ
      read(54,*)NGQdummy,NG2Qdummy  ! read dummies
      NGQ=NXYZ
      NG2Q=NXYZ
      read(54,*)NUMKQ  ! read # of irreducible k-points
      read(54,*)NFLQ,NVIRTQ     ! read full band and others
      NBNDQ=NFLQ+NVIRTQ
      MXBND=NBNDQ
      read(54,*)NTAUQ,NTYQ      ! read # of atoms and atomic types
c
      allocate (  RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),RHO4(NXYZ),
     &            VG(NXYZ),RHOG(NXYZ),WORK2(NG2Q,7),
     &            WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ) )
c
      allocate (  RHO(NXYZ), G(4,NGQ), G2(4,NG2Q,NUMKQ), YLM(NG2Q,16)
     &           ,GDUMP(NG2Q,NUMKQ) )
c
      allocate ( IFACX(30),IFACY(30),IFACZ(30),
     &          LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ) )
      allocate ( I2G(NGQ),J2G(NG2Q,NUMKQ),NG2(NUMKQ),NGNL(NTYQ,NUMKQ) )
      allocate ( VECK(3,NUMKQ),WGT(NUMKQ),CELLDM(6)  )
      allocate ( NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ),NUMC(NTYQ) )
      allocate ( ZV(NTYQ),RC0(NCRQ,NTYQ), COR(NCRQ,NTYQ)  )
c 
      allocate ( COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,MXBND),CL1(NG2Q,10) )
      allocate ( VGA(NGQ,NTYQ),vn1(2*nxyz,2),vn2(2*nxyz,2)
     &          ,Vchg(NGQ,NTYQ) )
      allocate ( FORCE(3,NTAUQ),TAU(3,NTAUQ),OUT(NBNDQ,3,NUMKQ),
     &           WORK(6,NTAUQ), CTAU(3,NTAUQ) )
c
      allocate( DFORCE(3,NTAUQ),SFORCE(3,NTAUQ),ZZ(NTAUQ),VPP(3,4,NTYQ),
     &       VPJ(NG2Q,3,4,NTYQ,NUMKQ),IOWF(MBLKQ,NUMKQ),
     &       IOVP(2,NTYQ,NUMKQ) )
c
      allocate ( OCC(NBNDQ,NUMKQ),EE(NBNDQ,NUMKQ),ee2(nbndq),ee3(nbndq),
     &    ee4(nbndq),GG(4,NGQ),EXPG(NGQ),ALPPP(4,NTYQ),BETAPP(4,NTYQ)  )
c  ** for orthgonaization
      allocate (  sig(mxbnd,mxbnd),x0(mxbnd,mxbnd),
     &    x1(mxbnd,mxbnd),work1(mxbnd,mxbnd),work20(mxbnd,mxbnd)   )
c
      allocate(  EBNDW(NBNDQ,IRLATQ),EW(NBNDQ),PE(NBNDQ*IRLATQ),
     &          VINT(NBNDQ,IRLATQ)  )
      allocate ( EENL(NBNDQ,NUMKQ),FXNL(NTAUQ,NBNDQ,NUMKQ),
     &          FYNL(NTAUQ,NBNDQ,NUMKQ),FZNL(NTAUQ,NBNDQ,NUMKQ)  )
      allocate ( fdump(NXYZ) )  ! dumping factor for charge & V
C *******************************************************************
C
c      if ( ntyq.lt.2 ) then
c       write(6,*)' WARNNING! NTYQ should be bigger than 2.'
c       stop
c      endif
c  ***  smoothening factor ADUMP = 1.0d0 applied for RHO, VHXC
      IF ( IOPT(8,1).eq.1 .and. MXBND.LT.10 ) then
       write(6,*)' For GGA calculation, MXBND should be grater than 10!'
       stop
      endif
      IF ( MXBND.NE.NBNDQ ) STOP ' NBNDQ should be MXBND '
c      IF( MXBND*NG2Q .LT. NBNDQ*NBNDQ ) STOP
c     & ' ALLOCATION ERROR: MXBND NG2Q NBNDQ..'
      IF( NG2Q .LT. NBNDQ ) STOP
     & ' ALLOCATION ERROR: MXBND NG2Q NBNDQ..'
      IF( NAS.LT.3 ) STOP ' NAS SHOULD BE LARGER THAN 3 FOR DIPERSION'
C
      DO 1 I=1,5
      DO 1 J=1,10
    1 IOPT(J,I)=0
      ISUM=0
      DO 2 IK=1,NUMKQ
      DO 2 I=1,NTYQ
      DO 2 LI=1,2
      ISUM=ISUM+1
    2 IOVP(LI,I,IK)=ISUM
C
      CALL AINPUT(IOPT,CELLDM,MAXFN,OKSTEP,ZVAL,NBND,NFL,NPFL,RCUT,
     &            GCUT2,GRAT, KCONT)
C
      MBLK = MBLKQ
      WRITE(6,*) '                               **  MBLK = ',MBLK
      ISUM=0
      DO 3 IK=1,NUMKQ
      DO 3 I=1,MBLK
      ISUM=ISUM+1
    3 IOWF(I,IK)=ISUM
C
C ***  CARE
      IF( IOPT(1,2).EQ.3 .OR. IOPT(1,2).EQ.4 ) THEN
C          LOWER 2 LAYERS ARE ALWAYS FIXED: 6X2 LATERAL CELL
         MFIX = NFIX
CARE     NFIX0 = 6*2 * ( 2+1+1 )
CARE     NFIX0 = 6*2 * ( 2+1 )
C 2X4    NFIX0 = 4*2 * ( 2+1 )
         NFIX0 = 2*2 * ( 2+1 )
         NFIX1 = NTAUQ - NFIX0 + 1
         DO 12 I = NFIX1, NTAUQ
         MFIX = MFIX + 1
         IFATM(MFIX) = - I
         FATM(1,MFIX) = 0.0D+00
         FATM(2,MFIX) = 0.0D+00
   12    FATM(3,MFIX) = 0.0D+00
         NFIX = MFIX
      END IF
      IF( IOPT(1,2).EQ.10  .OR. IOPT(1,2).EQ.12  ) THEN
C          FIXED ATOMS FOR VICINAL SURFACE
         MFIX = NFIX
         IF(IOPT(1,2).EQ.10 )  NFIX1 = 55
         IF(IOPT(1,2).EQ.12 )  NFIX1 = 75
         DO 14 I = NFIX1, NTAUQ
         MFIX = MFIX + 1
         IFATM(MFIX) = - I
         FATM(1,MFIX) = 0.0D+00
         FATM(2,MFIX) = 0.0D+00
   14    FATM(3,MFIX) = 0.0D+00
         NFIX = MFIX
      END IF
C ***  CARE END
C
        IF( NFL .GT. NFLQ ) STOP ' **  NFL TOO LARGE...STOPPING'
        IF( NPFL .GT. NVIRTQ ) STOP ' **  NPFL TOO LARGE...STOPPING'
C
c      OPEN(71,ACCESS='DIRECT',RECL=MXBND*NG2Q*4,MAXREC=MBLK*NUMKQ)
c      OPEN(IFIL3,ACCESS='DIRECT',RECL=MXBND*NG2Q*4,MAXREC=MBLK)
c      OPEN(IFIL6,ACCESS='DIRECT',RECL=MXBND*NG2Q*4,MAXREC=MBLK)
c      OPEN(IFIL7,ACCESS='DIRECT',RECL=MXBND*NG2Q*4,MAXREC=MBLK)
c      OPEN(82,ACCESS='DIRECT',RECL=(NG2Q+1)*6,MAXREC=NUMKQ*NTYQ*2)
c      OPEN(IFIL2,ACCESS='DIRECT',RECL=NG2Q*12,MAXREC=NBNDQ)
c      OPEN(IFIL4,ACCESS='DIRECT',RECL=NG2Q*4,MAXREC=NBNDQ)
c      OPEN(IFIL5,ACCESS='DIRECT',RECL=NG2Q*4,MAXREC=NBNDQ)
C
      PI=4.D0*ATAN(1.D0)
C
      CALL CLOCK(TIM)
      WRITE(6,7000) TIM
 7000 FORMAT(23X,'****  CPU TIME BFR CRYST: ',F15.7,' SEC')
C
      NVIRT=NVIRTQ
C
C
C     RHO1 AND RHO2 ARE USED AS GGVECTOR
C     RHO3 IS USED AS I2GG
C     RHO4 IS USED AS INDEX
                  IF(NXYZ.LT.NGQ) STOP 'NXYZ<NGQ'
      CALL CRYST( NRX, NRY, NRZ, NXYZ, NG, NGQ,
     &            NBNDQ, NBND, ZVAL, NFL, NPFL, NUMK, NUMKQ,
     &            CELLDM, NTOT, S, VECK, WGT, G, I2G, OMEGA, GCUT,
     &            GCUT2, GRAT, GG, RHO3, RHO4, OCC, LATQ, RVEC, RCUT,
     &            NLV, RR, NWK, NTAUQ, NTYQ, NTYPE, TAU, CTAU, NUMTY,
     &            NIDN, RKK, KG, KZ, NSY, NEXPND, RCOSIN, CCO, NKMESH,
     &            SK, WK, JDR, MM, NJD, NDX, NDY, NDZ, MXOFL )
c *** ADUMP: Smoothing factor for RHO & VHXC
      ADUMP= GCUT2/( ( PI*2.D0/CELLDM(1) )**2 )
      ATEMP= ADUMP/10.d0
      do ig=1,NXYZ
c      wari=dexp( (G(4,ig)-4*ADUMP)/ATEMP ) + 1.d0
      wari=dexp( (G(4,ig)-ADUMP)/ATEMP ) + 1.d0
      fdump(ig)=1.d0/wari
      enddo
C
      CALL CLOCK(TIM)
      WRITE(6,7002) TIM
 7002 FORMAT(23X,'****  CPU TIME AFTR CRYST: ',F15.7,' SEC')
C
      TPIBA=2.D0*PI/CELLDM(1)
C
      CALL INITPW( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NGQ, NG,
     &             NG2Q, NG2, NBNDQ, NBNDQ, NUMK, NUMKQ,
     &             COEF, DCOEF, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
     &             OMEGA, ZVAL, IOWF, RHO, RHOG, RHO1, RHO2, RHO3,
     &             WGT, OCC, NTOT, S, NFL, NPFL, NKMESH, NEXPND,
     &             RCOSIN, NSY, VINT, WSAVEX, WSAVEY, WSAVEZ, IFACX,
     &             IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2
     &             ,RHO4,GG,EXPG,GDUMP,fdump)
C
C
      CALL CLOCK(TIM)
      WRITE(6,7004) TIM
 7004 FORMAT(23X,'****  CPU TIME AFT INITPW: ',F15.7,' SEC')
C
C     READ (PSEUDO-WAVEFUNCTION * R) FROM FILE
C
C        ***ALPPP AND BETAPP*** AND IBUN IN /SAITO2/
      ALPPP(1,1)=1.5D0
      ALPPP(2,1)=1.25D0
      ALPPP(3,1)=0.80D0
      ALPPP(4,1)=0.80D0
      BETAPP(1,1)=5.D0
      BETAPP(2,1)=5.D0
      BETAPP(3,1)=5.D0
      BETAPP(4,1)=5.D0
c      ALPPP(1,2)=1.00D0
c      ALPPP(2,2)=1.00D0
c      BETAPP(1,2)=5.D0
c      BETAPP(2,2)=5.D0
c **
c     if ( ntyq.gt.1 ) then
CCC   ALPPP(1,2)=0.80D0
CCC   ALPPP(2,2)=1.05D0
CCC   BETAPP(1,2)=5.D0
CCC   BETAPP(2,2)=5.D0
c     endif
      IBUN(1,1)=0  ! 1 for Ce s-orbital or K s-orbital
      IBUN(2,1)=0
      IBUN(3,1)=0
      IBUN(4,1)=0
      IBUN(1,2)=0  ! 1 for Y s-orbital or K s-orbital
      IBUN(2,2)=0
      IBUN(3,2)=0
      IBUN(1,3)=0  ! 1 for Al s-orbital or K s-orbital
      IBUN(2,3)=0
      IBUN(1,4)=0  ! 1 for O s-orbital or K s-orbital
      IBUN(2,4)=0
c      IBUN(1,2)=0  ! 1 for As s-orbital or K s-orbital
c      IBUN(2,2)=0
C            IBUN=1 PARTITION   0 NOT
      WRITE(6,*) ' ATOM TYPE: NTYPE = ', NTYPE
      DO 6002 ITP = 1, NTYPE
      DO 6002 LLL=1,2
 6002 IF(IBUN(LLL,ITP).NE.0) WRITE(6,6006) LLL, ITP, ALPPP(LLL,ITP),
     &                                               BETAPP(LLL,ITP)
 6006 FORMAT('    REAL SPACE PARTITION IS DONE FOR ',I1,'-TH L OF '
     &,I3,
     &'-TH ATOM:'/
     &       '                ALP = ',F10.6,' BETA = ',F10.6)
C
      CALL PRENON( 1, NG2Q, NG2, TPIBA, NGQ, NG, G,
c     &             NUMKQ, NUMK, G2, RHO2, RHO3, NUMTY, NTYQ, NTYPE,
     &    NUMKQ, NUMK, G2, RHO2,VGA,Vchg, RHO3, NUMTY, NTYQ, NTYPE,
     &             VPJ, VPP, NCRQ, ZV, RC0, COR, NUMC, ALPPP, BETAPP,
     &             IOVP, MXOFL, ADUMP,ATEMP,NGNL
     &            )
C
C   ***   INITIAL CHARGE DENSITY FROM THE OVERLAP OF ATOM CHARGE
          IF(IOPT(3,1) .EQ. 4) THEN
          CALL CHARGE( NRX, NRY, NRZ, NXYZ, NG, NGQ, G, TPIBA, RHO,
cc     &                 RHOG, RHO1, RHO2, RHO3, I2G, OMEGA, NTAUQ,
     &                 RHOG, RHO1, RHO2, Vchg, I2G, OMEGA, NTAUQ,
     &                 NTYQ, NTYPE, TAU, NUMTY, NIDN, WSAVEX, WSAVEY,
     &                 WSAVEZ, IFACX, IFACY, IFACZ,
     &                 LX1, LX2, LY1, LY2, LZ1, LZ2                  )
          ENDIF
C   ***
C
      CALL PRENON( 2, NG2Q, NG2, TPIBA, NGQ, NG, G,
c     &             NUMKQ, NUMK, G2, RHO2, RHO3, NUMTY, NTYQ, NTYPE,
     &        NUMKQ, NUMK, G2, RHO2,VGA,Vchg,RHO3, NUMTY, NTYQ, NTYPE,
     &             VPJ, VPP, NCRQ, ZV, RC0, COR, NUMC, ALPPP, BETAPP,
     &             IOVP, MXOFL, ADUMP, ATEMP,NGNL
     &            )
C
      CALL CLOCK(TIM)
      WRITE(6,7006) TIM
 7006 FORMAT(23X,'****  CPU TIME AFT PRENON: ',F15.7,' SEC')
c *** temp check
c      miya=13
c      if (miya.eq.13) stop
c *** temp check: end
C
      IF(IOPT(2,1).EQ.1) THEN
C
C   **********   DISPERSION
C
       WRITE(6,6666)
 6666  FORMAT(//'  ***  BAND DISPERSION: '/)
C
C
c      CALL FRPRMN( 1, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
      CALL FRPRMN(1,NRX,NRY,NRZ,NXYZ,VN1,VN2,NG, NGQ, NG2, NG2Q,
     &             NBNDQ, NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
cc     &             NUMK, NUMKQ, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     &             NUMK, NUMKQ, COEF, DCOEF, CL1, 
cc     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
cc     &   CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &   YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &   RHO4, RHOG, VECK, OCC, EE,EE2,EE3,EE4,WGT, TPIBA, VG, S,
     &         NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &         MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &         TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &         NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &         SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
     &         IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
 7008 FORMAT(23X,'****  CPU TIME AFT FRPRMN: ',F15.7,' SEC'///)
C
      ISER = 0
      write(6,*)
      write(6,*)' Before reading k-vectors'
      write(6,*)'   B-vectors'
      write(6,9911)b1
      write(6,9912)b2
      write(6,9913)b3
      write(6,*)
 9911 format(' B1 = ',3f14.6)
 9912 format(' B2 = ',3f14.6)
 9913 format(' B3 = ',3f14.6)
       DO 9999 IT = 1, IRLATQ
C ****
C          VECK IN UNIT OF 2 * PAI / ALAT
c       READ(5,*) (VECK(I,1),I=1,3)
c       IF(ABS(VECK(1,1)).GT.10.D0) GO TO 9980
       READ(5,*) skx,sky,skz
       veck(1,1)=b1(1)*skx+b2(1)*sky+b3(1)*skz
       veck(2,1)=b1(2)*skx+b2(2)*sky+b3(2)*skz
       veck(3,1)=b1(3)*skx+b2(3)*sky+b3(3)*skz
       IF(ABS(skx).GT.10.D0) GO TO 9980
             IF( IOPT(1,2) .EQ. 2 .OR. IOPT(1,2) .EQ. 13 ) THEN
             VECK(3,1) = VECK(3,1) / COVA
             END IF
       ISER = ISER + 1
       RCOSIN(1,ISER) = skx
       RCOSIN(2,ISER) = sky
       RCOSIN(3,ISER) = skz
       WRITE(6,7040) ( RCOSIN(K,ISER), K = 1, 3 )
 7040  FORMAT(' ***  K VECTORS IN UNIT OF 2*PI/A: ',3F10.6)
C
       CALL DISPER( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NG, NGQ,
     &              NG2, NG2Q, NBNDQ, NBNDQ,
     &      COEF(1,1,1), DCOEF, CWK1, CWK2, CL1, CL2, CL3, HD, HDO,
c     &              YLM, G, G2, RHO1, RHO2, RHO3, OMEGA, TPIBA, VG,
     &   YLM, G, G2, RHO1, RHO2, RHO3,VGA,Vchg,OMEGA, TPIBA, VG,
     &   I2G, J2G, WORK2, OUT, VPJ(1,1,1,1,1), VPP, IOWF,
     &              NCRQ, ZV, RC0, COR, NUMC,
     &   NTAUQ, NTYQ, NTYPE, LREQ, GCUT2, VECK, EE,EE2,EE3,EE4,
     &              TAU, NUMTY, NIDN, ALPPP, BETAPP, IOVP,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2,   NUMKQ, MXOFL
     &  ,sig,x0,x1,work1,work20,GG,RHO4,NGNL(1,1) )
C
      WRITE(6,7012)
 7012 FORMAT(/
     &'         IB     EIG              CONV          SIN(ROT)')
      DO 655 IB=1,NBNDQ
      EBNDW(IB,ISER) = OUT(IB,1,1)
  655 WRITE(6,656) IB,(OUT(IB,IG,1),IG=1,3)
  656 FORMAT('   BAND ',I4,3E15.7)
 9999  CONTINUE
C
 9980 WRITE(6,9962)
 9962 FORMAT(/////)
      DO 9970 II = 1, ISER
 9970 WRITE(6,9960) RCOSIN(1,II), RCOSIN(2,II), RCOSIN(3,II),
     &              ( EBNDW(IB,II), IB = 1, NBNDQ )
 9960 FORMAT(3D14.6/(5D14.6))
C
      CALL CLOCK(TIM)
      WRITE(6,7010) TIM
 7010 FORMAT(23X,'****  CPU TIME AFT DSPRSN: ',F15.7,' SEC')
       STOP
C
      ELSEIF(IOPT(2,1).EQ.2) THEN
C *******   FORCE CHECK
c      CALL FRPRMN( 1, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
      CALL FRPRMN(1,NRX,NRY,NRZ,NXYZ,vn1,vn2,NG,NGQ,NG2,NG2Q,
     &             NBNDQ, NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
c     &             NUMK, NUMKQ, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     &             NUMK, NUMKQ, COEF, DCOEF,  CL1, 
c     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
c     &  CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &  YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &  RHO4, RHOG, VECK, OCC, EE,EE2,EE3,EE4, WGT, TPIBA, VG, S,
     &             NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF,IOVP,
     &         MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE,LREQ,
     &             TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &         SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX,IFACY,
     &         IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     & ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
C
       CALL ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
     &              NBNDQ, NBNDQ, NUMK, NUMKQ, COEF, DCOEF,
     &      YLM, G, EXPG, G2,GDUMP, RHO, RHO4, RHO1, RHO2, RHOG,
     &              TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ, VPP,
     &              IOWF, IOVP, OMEGA, FORCE, DFORCE, SFORCE,
     &              NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &              VINT, NSY, FXNL, FYNL, FZNL,
     &              TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
cc     &              ZZ, ZVAL, NPFL, MXOFL, OCC                      )
     &              ZZ, ZVAL, NPFL, MXOFL, OCC,VGA,NGNL,CL1
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
        ETOT0=ETOT
C
        DO 9998 IT=1,50
        READ(5,*) I,J,DELTAR
        IF(I.LE.0.OR.J.LE.0.OR.DELTAR.EQ.0.D0) STOP ' FORCE IS CHECKED'
        TAU(I,J)=TAU(I,J)+DELTAR
C ****
          WRITE(6,*) ' *** FORCE CHECK: DELTAR AND TAU:',DELTAR
     &                 , ( TAU(KK,J), KK=1,3 )
C ****
c      CALL FRPRMN( 0, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
      CALL FRPRMN(0,NRX,NRY,NRZ,NXYZ,vn1,vn2,NG,NGQ,NG2,NG2Q,
     &             NBNDQ, NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
c     &             NUMK, NUMKQ, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     &             NUMK, NUMKQ, COEF, DCOEF, CL1,
c     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
c     &   CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &   YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &   RHO4, RHOG, VECK, OCC, EE,EE2,EE3,EE4, WGT, TPIBA, VG, S,
     &             NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &             MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &             TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &             SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ,IFACX,IFACY,
     &             IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
C
       CALL ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
     &              NBNDQ, NBNDQ, NUMK, NUMKQ, COEF, DCOEF,
     &      YLM, G, EXPG, G2,GDUMP, RHO, RHO4, RHO1, RHO2, RHOG,
     &              TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ, VPP,
     &              IOWF, IOVP, OMEGA, FORCE, DFORCE, SFORCE,
     &              NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &              VINT, NSY, FXNL, FYNL, FZNL,
     &              TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
c     &              ZZ, ZVAL, NPFL, MXOFL, OCC                      )
     &              ZZ, ZVAL, NPFL, MXOFL, OCC,VGA,NGNL ,CL1
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
C
      WRITE(6,7016) I, J, (ETOT-ETOT0)/DELTAR,FORCE(I,J)
 7016 FORMAT(/' ****** FORCE CHECK FOR ',I2,'-TH COMPONENT OF ',I3,
     & '-TH ATOM:'/
     &        '          DE/DR FORCE = ',2D15.7/)
        TAU(I,J)=TAU(I,J)-DELTAR
 9998   CONTINUE
C
      CALL CLOCK(TIM)
      WRITE(6,7014) TIM
 7014 FORMAT(23X,'****  CPU TIME AFT FRCCHK: ',F15.7,' SEC')
        STOP
C
      ELSEIF(IOPT(2,1).EQ.3) THEN
C ******   STEEPEST DECENT
      DO 9997 IT=1,500
      ISTRT = 0
      IF(IT.EQ.1) ISTRT=1
c      CALL FRPRMN( ISTRT, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
      CALL FRPRMN( ISTRT, NRX, NRY, NRZ, NXYZ,
     &  vn1,vn2,NG, NGQ, NG2, NG2Q,NBNDQ, NBNDQ, NFL, NPFL,
c     & NDX, NDY, NDZ,NUMK, NUMKQ, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     & NDX, NDY, NDZ,NUMK, NUMKQ, COEF, DCOEF, CL1, 
c     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
c     &       CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &        YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &  RHO4, RHOG, VECK, OCC, EE, EE2,EE3,EE4,WGT, TPIBA, VG, S,
     &           NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &           MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &             TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &           SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
     &           IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
C
       CALL ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
     &              NBNDQ, NBNDQ, NUMK, NUMKQ, COEF, DCOEF,
     &      YLM, G, EXPG, G2,GDUMP, RHO, RHO4, RHO1, RHO2, RHOG,
     &              TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ, VPP,
     &              IOWF, IOVP, OMEGA, FORCE, DFORCE, SFORCE,
     &              NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &              VINT, NSY, FXNL, FYNL, FZNL,
     &              TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
cc     &              ZZ, ZVAL, NPFL, MXOFL, OCC                      )
     &              ZZ, ZVAL, NPFL, MXOFL, OCC,VGA ,NGNL ,CL1
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
C
CARE
          FACTOR = 8.5D+00
          DO 1943 J=1,NTAUQ
          DO 1943 I=1,3
 1943     TAU(I,J)=TAU(I,J)-FORCE(I,J)*FACTOR
 9997 CONTINUE
      CALL CLOCK(TIM)
      WRITE(6,7018) TIM
 7018 FORMAT(23X,'****  CPU TIME AFT STP DCNT:',F15.7,' SEC')
        STOP
C
      ELSE IF( IOPT(10,1) .NE. 0 ) THEN
C
C   **********   LOCAL DENSITY OF STATES 
C
       WRITE(6,7300) IOPT(10,1)
 7300  FORMAT(//
     &'  ***  LOCAL DENSITY OF STATES: K SAMPLING = ',I4/)
C
c      CALL FRPRMN( 1, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
      CALL FRPRMN(1,NRX,NRY,NRZ,NXYZ,vn1,vn2,NG, NGQ, NG2, NG2Q,
     &             NBNDQ, NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
c     &             NUMK,NUMKQ,COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     &             NUMK,NUMKQ,COEF, DCOEF,  CL1, 
c     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
c     &        CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &         YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &  RHO4, RHOG, VECK, OCC, EE,EE2,EE3,EE4, WGT, TPIBA, VG, S,
     &        NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &        MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &        TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &        NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &        SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
     &        IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
C
      IF( IOPT(10,1) .EQ. 2 ) THEN
CARE
C    **  for quartz super cell near the gap
        NB1 = 67 
        NB2 = 79
CARE END
        READ(5,*) NMBRK
        WRITE(6,7310) NMBRK
 7310   FORMAT('          ',I4,' K-POINTS ARE USED'/)
        NB3 = NB2 - NB1 + 1
C
        REWIND 13
        WRITE(13) NMBRK, NB3
C
        DO 7320 IKK = 1, NMBRK
C ****
C            VECK IN UNIT OF 2 * PAI / ALAT
        READ(5,*) (VECK(I,1),I=1,3), WGT(1)
              IF( IOPT(1,2) .EQ. 2 .OR. IOPT(1,2) .EQ. 13 ) THEN
              VECK(3,1) = VECK(3,1) / COVA
              END IF
        WGT(1) = WGT(1) / OMEGA
        WRITE(6,7330) ( VECK(K,1), K = 1, 3 ), WGT(1)
 7330   FORMAT(' **  K VECTORS IN UNIT OF 2*PI/A: ',3F8.4,
     &        ' WGT = ',F8.4)
        CALL G2VECT( NGQ, NG, NG2Q, NG2(1), VECK(1,1), G, G2(1,1,1), 
     &               J2G(1,1), I2G, TPIBA, GCUT2,GG,RHO3,RHO4 )
C
        WRITE(13) IKK, WGT(1), NG2(1), ( J2G(IG,1), IG = 1, NG2(1) )
C             
        NUMK = 1
        NUMKQQ = 1
        CALL PRENON( 2, NG2Q, NG2(1), TPIBA, NGQ, NG, G, 
c     &               NUMKQQ, NUMK, G2(1,1,1), RHO2, RHO3, NUMTY, 
     &   NUMKQQ, NUMK, G2(1,1,1), RHO2,VGA,Vchg,RHO3, NUMTY, 
     &   NTYQ, NTYPE, VPJ(1,1,1,1,1), VPP, NCRQ, ZV, RC0, COR, 
     &   NUMC, ALPPP, BETAPP, IOVP(1,1,1), MXOFL ,ADUMP,ATEMP,NGNL)
C
        if ( MBLK.ne.1 ) then
         write(6,*)' MBLK is not one but',MBLK,' STOPPING...'
         stop
        endif
        DO 7401 IBLK = 1, MBLK
          IF( IBLK.EQ.MBLK ) THEN
            NB = MOD( NBNDQ-1, MXBND ) + 1
          ELSE
            NB = MXBND
          END IF
          IBI = MXBND * (IBLK - 1)
          DO 7402 IB = 1, NB
             DO 7410 IG = 1, NG2(1)
 7410          COEF(IG,IB,1) = ( 0.0D+00, 0.0D+00 )
          IBAND = IBI + IB
 7402     COEF(IBAND,IB,1) = ( 1.0D+00, 0.0D+00 )
cc 7401   WRITE(71,REC=IOWF(IBLK,1)) COEF
 7401   continue
C
        if ( MBLK.ne.1 ) then
         write(6,*)' MBLK is not one but',MBLK,' STOPPING...'
         stop
        endif
        DO 7600 IBLK = 1, MBLK
           IF(IBLK.LT.MBLK) THEN
             MBN = MXBND
           ELSE
             MBN = MOD( NBNDQ-1, MXBND ) + 1
           END IF
        IBI = MXBND * (IBLK-1)
ccc        READ(71,REC=IOWF(IBLK,1)) COEF
          DO 7602 IBND = 1, MBN
          IB = IBI + IBND
            DO 7605 JBLK = 1, IBLK
              IF(JBLK.LT.MBLK) THEN
                JMBN = MXBND
              ELSE
                JMBN = MOD( NBNDQ-1, MXBND ) + 1
              END IF
            JBI = MXBND * (JBLK-1)
              IF(JBLK.NE.IBLK) THEN
                IF(IBLK.EQ.2 .AND. IBND.GT.1) THEN
                  CONTINUE
                ELSE
ccc                  READ(71,REC=IOWF(JBLK,1)) DCOEF
                END IF
              END IF
             DO 7612 JBND = 1, JMBN
              JB = JBI + JBND
                              IF(JB.GE.IB) GO TO 7605
              CTEMP = (0.0D+00,0.0D+00)
              IF( JBLK.LT.IBLK) THEN
                DO 7638 IG = 1, NG2(1)
 7638     CTEMP = CTEMP + DCONJG(DCOEF(IG,JBND)) * COEF(IG,IBND,1)
                DO 7640 IG = 1, NG2(1)
 7640     COEF(IG,IBND,1) = COEF(IG,IBND,1)
     &                            - CTEMP * DCOEF(IG,JBND)
              ELSE
                DO 7618 IG = 1, NG2(1)
 7618     CTEMP = CTEMP + DCONJG(COEF(IG,JBND,1)) * COEF(IG,IBND,1)
                DO 7620 IG = 1, NG2(1)
 7620           COEF(IG,IBND,1) = COEF(IG,IBND,1)
     &                               - CTEMP * COEF(IG,JBND,1)
              END IF
 7612         CONTINUE
 7605       CONTINUE
            TEMP = 0.0D+00
            DO 7622 IG = 1, NG2(1)
 7622    TEMP = TEMP + DBLE(DCONJG(COEF(IG,IBND,1))*COEF(IG,IBND,1))
            TEMP = 1.0D+00/SQRT(TEMP)
            DO 7625 IG = 1, NG2(1)
 7625    COEF(IG,IBND,1) = TEMP * COEF(IG,IBND,1)
 7602     CONTINUE
ccc          WRITE(71,REC=IOWF(IBLK,1)) COEF
 7600   CONTINUE
C
        ITCF = 50
        CALL SDDIAG( 0.1D-08, ITCF, NRX, NRY, NRZ, NXYZ, NG2(1), 
cc     &               NG2Q, NBNDQ, NBNDQ, COEF, DCOEF, CWK1, CWK2, 
c     &      NG2Q, NBNDQ, NBNDQ, COEF(1,1,1), DCOEF, CWK1, CWK2, 
     &      NG2Q, NBNDQ, NBNDQ, COEF(1,1,1), DCOEF, 
c     &               CL1, CL2, CL3, HD, HDO, YLM, G2(1,1,1), RHO1,
c     &               CL1,YLM, G2(1,1,1),GDUMP(1,1), RHO1,
     &               YLM, G2(1,1,1),GDUMP(1,1), RHO1,
     &               RHO2, RHO3, TPIBA, VG, J2G(1,1), WORK2, 
     &     OUT(1,1,1), VPJ(1,1,1,1,1), VPP, IOWF(1,1), IOVP(1,1,1),
     &               MXBND, MBLK, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, 
     &    TAU, NUMTY, NIDN, EE(1,1),EE2,EE3,EE4, WSAVEX, WSAVEY, 
     &               WSAVEZ, IFACX, IFACY, IFACZ, LX1, LX2, LY1, 
     &   LY2, LZ1, LZ2,MXOFL,sig,x0,x1,work1,work20,0,NGNL(1,1))
C
          DO 960 IBLK = 1, MBLK
cc            READ(71,REC=IOWF(IBLK,1)) COEF
              IF(IBLK.EQ.MBLK) THEN
                NB = MOD(NBNDQ-1,MXBND) + 1
              ELSE
                NB = MXBND
              END IF
            IBI = MXBND * (IBLK-1)
            DO 965 IB = 1, NB
            IBAND = IBI + IB
            IF( IBAND.LT.NB1 .OR. IBAND.GT.NB2 ) GO TO 965
C
            WRITE(6,7398) IBAND, OUT(IBAND,1,1)
 7398       FORMAT('   **  IBAND  EK (EV) = ',I5,D15.7)
            WRITE(13)  OUT(IBAND,1,1), 
     &                 ( COEF(IG,IB,1), IG = 1, NG2(1) )
C
  965       CONTINUE   
  960     CONTINUE
 7320   CONTINUE  ! end of k-roop (IKK)
C ****
C
      END IF
C
      CALL CLOCK(TIM)
      WRITE(6,7390) TIM
 7390 FORMAT(23X,'****  CPU TIME AFT LDOS: ',F15.7,' SEC')
       STOP
C
      ENDIF
C
C
C     WRITE(6,7024)  (I,(TAU(J,I),J=1,3),I=1,NTAUQ)
      WRITE(6,7024)
 7024 FORMAT(///'  ***  CONJUGATE GRADIENT:'/)
C7024 FORMAT(///'  ***  CONJUGATE GRADIENT:'/
C    &         ('         ',I3,' TAU = ',3D13.5) )
C
C ****
      IF(MAXFN.EQ.0) GO TO 1100
C
C ****
C
      DO 363 NN=1,1
C *******  NO OF DIRECTIONS IN SEARCHING THE MINIMUM IN CG SCHEME
      NCYC=8
      N=3*NTAUQ
      N2=N+N
      IPRINT=0
C ******* REAL SPACE MEASURE WHICH COULD BE REGARDED AS ZERO:
C                      IF NEW COORDINATES DIFFER FROM THE PREVIOUS
C                      JUST BY EPS, THEN RETURN FROM LINMIN.
      EPS=0.005D+00
C ******* IF THE TOTAL ENERGY DOES NOT CHANGE BY MORE THAN EDECR,
C                      THEN RETURN FROM LINMIN.  UNIT = HR
      EDECR = 0.001D+00
C
      CALL DCGMIN( KCONT, NCYC, N, N2, TAU, ETOT, FORCE, OKSTEP, EPS,
     &             EDECR,
     &             MAXFN, IPRINT, IER, WORK,
     &             NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
     &             NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
c     &             NUMK, NUMKQ,
     &             NUMK, NUMKQ,VGA,vn1,vn2,
c     &             COEF, DCOEF, CWK1, CWK2, CL1, CL2, CL3, HD, HDO,
     &             COEF, DCOEF,  CL1,
     &   YLM, G, EXPG, G2,GDUMP, RHO, RHO1, RHO2, RHO3, RHO4,
     &   RHOG, VECK, OCC, EE, EE2,EE3,EE4,WGT, TPIBA, VG, S, NTOT,
     &             I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &             MXBND, MBLK, OMEGA, ZVAL, DFORCE, SFORCE,
     &             NTAUQ, NTYQ, NTYPE, LREQ, NUMTY, NIDN,
     &             ZV, RC0, COR, NUMC, NCRQ, LATQ, RVEC, NLV, ZZ,
     &             NKMESH, NEXPND, EENL, EBNDW, EW, PE, VINT, RCOSIN,
     &             WK, SK, NSY, KZ, FXNL, FYNL, FZNL,
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      WRITE(6,6600) NN, EDECR, EPS
 6600 FORMAT(//' **** COME BACK FROM DCGMIN: NN = ',I4,' EDECR = '
     &         ,D13.5/29X,'EPS = ',D13.5/
     &         10X,' TAU WRITTEN ON F77')
      REWIND 77
      WRITE(77,7100) ( (TAU(IK,ITAU),IK=1,3),ITAU, ITAU=1,NTAUQ)
 7100 FORMAT(( 3F16.7,7X,'TAU( ',I3,')' ))
c ****** Y. Miyamoto
      write(77,*)'  ---- in unit of lattice vectors ---- '
      do 877 itau=1,ntauq
      tau1=b1(1)*tau(1,itau)+b1(2)*tau(2,itau)+b1(3)*tau(3,itau)
      tau2=b2(1)*tau(1,itau)+b2(2)*tau(2,itau)+b2(3)*tau(3,itau)
      tau3=b3(1)*tau(1,itau)+b3(2)*tau(2,itau)+b3(3)*tau(3,itau)
      tau1=tau1/alat
      tau2=tau2/alat
      tau3=tau3/alat
      write(77,7110)tau1,tau2,tau3,itau
  877 continue
 7110 FORMAT(( 3F22.16,3X,'TAU( ',I3,')' ))
C
      IF(IER.EQ.-1) THEN
         WRITE(6,*) '         ERROR IN GRADIENT CALCULATION '
      ELSEIF(IER.EQ.1) THEN
         WRITE(6,*) '         NO CONVERGENCE AFTER MOST STEPS '
      ELSEIF(IER.EQ.2) THEN
         WRITE(6,*) '         RUNAWAY OF X-- STEPS HAVE BECOME LARGE'
      ENDIF
      WRITE(6,*)    '           **** IER = ',IER
  363 CONTINUE
      CALL CLOCK(TIM)
      WRITE(6,7020) TIM
 7020 FORMAT(///23X,'****  CPU TIME AFTR G OPT: ',F15.7,' SEC'///)
         GO TO 1110
C
C *****
C
 1100 CONTINUE
C     FOR NOOPT
CC
c      CALL FRPRMN( 1, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
      CALL FRPRMN(1,NRX,NRY,NRZ,NXYZ,vn1,vn2,NG, NGQ, NG2, NG2Q,
     &             NBNDQ, NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
     &            NUMK, NUMKQ, COEF, DCOEF,  CL1, 
c     &            NUMK, NUMKQ, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
c     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
c     &       CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &        YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &   RHO4, RHOG, VECK, OCC, EE, EE2,EE3,EE4,WGT, TPIBA, VG, S,
     &       NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &       MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &       TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &       NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &       SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
     &       IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &   ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
C
       CALL ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
     &              NBNDQ, NBNDQ, NUMK, NUMKQ, COEF, DCOEF,
     &      YLM, G, EXPG, G2,GDUMP, RHO, RHO4, RHO1, RHO2, RHOG,
     &              TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ, VPP,
     &              IOWF, IOVP, OMEGA, FORCE, DFORCE, SFORCE,
     &              NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &              VINT, NSY, FXNL, FYNL, FZNL,
     &              TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
ccc     &              ZZ, ZVAL, NPFL, MXOFL, OCC                      )
     &              ZZ, ZVAL, NPFL, MXOFL, OCC,VGA ,NGNL ,CL1
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
C
C *****
 1110 CONTINUE
C
C ****
            IF( IOPT(1,2).EQ.2 )
     &             CALL CRDAN( IOPT(1,2), TAU, FORCE, NTAUQ )
C ****
      CALL CLOCK(TIM)
      WRITE(6,7022) TIM
 7022 FORMAT(///23X,'****  CPU TIME END OF PSPW:',F15.7,' SEC'//)
C
      STOP
      END
C*****************************************************************
C
C     DCGMIN---FRPRMN & ELECTF
C           !
C           ---LINMIN---FRPRMN & ELECTF
C                    !
C                    ---CUMIN
C
C                               OSAMU SUGINO (1990-11-30)
C            MODIFICATION:      A. OSHIYAMA  (11/30/94)
C*****************************************************************
      SUBROUTINE
     &     DCGMIN( KCONT, NCYC, N, N2, TAU, ETOT, GRAD, OKSTEP, EPS,
     &             EDECR,
     &             MAXFN, IPRINT, IER, WORK,
     &             NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
     &             NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
c     &             NUMK, NUMKQ,
     &             NUMK, NUMKQ,VGA,vn1,vn2,
c     &             COEF, DCOEF, CWK1, CWK2, CL1, CL2, CL3, HD, HDO,
     &             COEF, DCOEF, CL1, 
     &  YLM, G, EXPG, G2,GDUMP, RHO, RHO1, RHO2, RHO3, RHO4,
     &   RHOG, VECK, OCC, EE,EE2,EE3,EE4, WGT, TPIBA, VG, S, NTOT,
     &             I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &             MXBND, MBLK, OMEGA, ZVAL, DFORCE, SFORCE,
     &             NTAUQ, NTYQ, NTYPE, LREQ, NUMTY, NIDN,
     &             ZV, RC0, COR, NUMC, NCRQ, LATQ, RVEC, NLV, ZZ,
     &             NKMESH, NEXPND, EENL, EBNDW, EW, PE, VINT, RCOSIN,
     &             WK, SK, NSY, KZ, FXNL, FYNL, FZNL,
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     & ,sig,x0,x1,work1,work20,fdump,NGNL )
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION   TAU(N), GRAD(N), WORK(N2)
c      COMPLEX*16  COEF(NG2Q,MXBND), DCOEF(NG2Q,MXBND),
      COMPLEX*16  COEF(NG2Q,MXBND,NUMKQ), DCOEF(NG2Q,MXBND)
c     &            ,CWK1(NG2Q,MXBND), CWK2(NG2Q,MXBND)
c      COMPLEX*16  CL1(NG2Q,MXBND),CL2(NG2Q,MXBND),CL3(NG2Q,MXBND),
c     &            HD(NG2Q,MXBND),HDO(NG2Q,MXBND)
      COMPLEX*16  CL1(NG2Q,MXBND)
C     COMPLEX*16 CTEMP,CHD
C
c      REAL*8 RHO(NXYZ),YLM(NG2Q,4),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
c      REAL*8 RHO(NXYZ),YLM(NG2Q,9),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
      REAL*8 RHO(NXYZ),YLM(NG2Q,16),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
c ***
      dimension VGA(NGQ,NTYQ),vn1(2*nxyz,2),vn2(2*nxyz,2)
C
      PARAMETER (IRLATQ=144,NAS=144)
      DIMENSION EBNDW(NBNDQ,IRLATQ),EW(NBNDQ),PE(NBNDQ*IRLATQ),
     &          VINT(NBNDQ,IRLATQ),EENL(NBNDQ,NUMKQ),
     &          RCOSIN(NAS,IRLATQ),WK(NAS),SK(3,NAS),NSY(IRLATQ),
     &          KZ(3,IRLATQ,48)
C
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),RHO4(NXYZ),
     &           RHOG(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3)
c     &           VG(NXYZ),WORK2(NG2Q,5)
     &           VG(NXYZ),WORK2(NG2Q,7)
      dimension fdump(NXYZ)
      INTEGER*4 S(3,3,48)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      DIMENSION I2G(NGQ),J2G(NG2Q,NUMKQ),NG2(NUMKQ)
      DIMENSION G(4,NGQ),G2(4,NG2Q,NUMKQ),WGT(NUMKQ)
      DIMENSION EXPG(NGQ),GDUMP(NG2Q,NUMKQ)
      DIMENSION NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     &          ZV(NTYQ),RC0(NCRQ,NTYQ),
     &          COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ),IOWF(MBLK,NUMKQ),
      DIMENSION VPJ(NG2Q,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ),IOWF(MBLK,NUMKQ),
     &          IOVP(2,NTYQ,NUMKQ),OCC(NBNDQ,NUMKQ),EE(NBNDQ,NUMKQ)
      DIMENSION NGNL(NTYQ,NUMKQ)
      dimension ee2(nbndq),ee3(nbndq),ee4(nbndq)
      DIMENSION DFORCE(3,NTAUQ),SFORCE(3,NTAUQ),RVEC(4,LATQ),ZZ(NTAUQ)
ccc
c     work area for orthogonization
      complex*16  sig(mxbnd,mxbnd),x0(mxbnd,mxbnd),
     &    x1(mxbnd,mxbnd),work1(mxbnd,mxbnd),work20(mxbnd,mxbnd)
C
      COMMON/COMOPT/IOPT(10,5)
      DIMENSION FXNL(NTAUQ,NBNDQ,NUMKQ),FYNL(NTAUQ,NBNDQ,NUMKQ),
     &          FZNL(NTAUQ,NBNDQ,NUMKQ)
      COMMON /NEED/ TLAST, ELAST, STEP, STEPSQ, FOL, AMOL, DN, SGN,
     &              AL(3), ALL(3), AR(3), ARR(3), GN, AM, IHELP, MODE
      DATA OBSOL/.9D0/
      ITN=0
      IST=0
C **                              CASE OF CONTINUATION
                                  IF(KCONT.EQ.1)  GOTO 500
C
C ***
      CALL FRPRMN(1,NRX,NRY,NRZ, NXYZ,vn1,vn2,NG, NGQ, NG2, NG2Q,
     &             NBNDQ, NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
     &             NUMK, NUMKQ, COEF, DCOEF,  CL1, 
     &        YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &    RHO4, RHOG, VECK, OCC, EE,EE2,EE3,EE4, WGT, TPIBA, VG, S,
     &       NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &       MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &       TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &        SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
     &        IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     & ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
 7008 FORMAT(23X,'*** DCGMIN:  CPU TIME AFT FRPRMN: ',F15.7,' SEC')
C
       CALL ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
     &              NBNDQ, NBNDQ, NUMK, NUMKQ, COEF, DCOEF,
     &     YLM, G, EXPG, G2,GDUMP, RHO, RHO4, RHO1, RHO2, RHOG,
     &              TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ, VPP,
     &              IOWF, IOVP, OMEGA, GRAD, DFORCE, SFORCE,
     &              NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &              VINT, NSY, FXNL, FYNL, FZNL,
     &              TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
ccc     &              ZZ, ZVAL, NPFL, MXOFL, OCC                      )
     &              ZZ, ZVAL, NPFL, MXOFL, OCC,VGA,NGNL ,CL1
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
C
C ***
      IFN=1
      DF=DABS(ETOT)
      IF(DF.LE.0.D0) DF=1.D0
   10 CONTINUE
      IST=IST+1
      DO 15 I=1,N
      WORK(I)=0.D0
   15 CONTINUE
      GGP=1.D0
      G1G1=0.D0
      DO 155 I=1,N
      G1G1=G1G1+GRAD(I)*GRAD(I)
      WORK(N+I)=GRAD(I)
  155 CONTINUE
C ***      CASE OF CONTINUATION
  500        IF(KCONT.EQ.1) THEN
             IFN=1
             IST=IST+1
             REWIND 78
             READ(78)  WORK, GRAD, TAU, ETOT, ALPHA, TLAST, STEP,
     &                 ELAST,
     &                 STEPSQ, FOL, AMOL, DN, SGN, AL, ALL, AR, ARR,
     &                 GN, AM, IHELP, MODE, DF, GGP, G1G1, GG, GG1, Z
             END IF
C ******
        WRITE(6,1998)
 1998   FORMAT(/' **  CONJUGATE GRADIENT GEOMETRY OPTIMIZATION: '
     &         ,'FLETCHER-REEVES SCHEME')
        IF(KCONT.EQ.1 ) WRITE(6,1999)
 1999   FORMAT( ' **  CONTINUATION FROM THE '
     &         ,'PREVIOUS CALCULATION')
        WRITE(6,*)  ' '
C ******
      DO 60 ICY=1,NCYC
C ******
        WRITE(6,2000) ICY
 2000   FORMAT(//'       DIRECTION:  ',I3)
C *******
            IF( KCONT.EQ.1 ) THEN
            ITN = ITN + 1
            GO TO 510
            END IF
C *******
      GG1=0.D0
      GG=0.D0
      DO 205 I = 1, N
      GG=GG+GRAD(I)**2
  205 GG1=GG1+GRAD(I)*WORK(N+I)
C **    TEST FOR OBSOLESCENCE CURVATURE INFORMATION
             IF(ICY.NE.1.AND.GG1**2.GT.OBSOL*GG*G1G1) GOTO 10
      ITN=ITN+1
C **
              IF(IPRINT.EQ.0) GOTO 20
                 IF(MOD(ITN,IABS(IPRINT)).NE.0) GOTO 20
                 PRINT 1001,IST,ITN,IFN
 1001            FORMAT(' DCGMIN:  ',  3I10)
                 IF(IPRINT.LT.0) GOTO 20
                 PRINT 1003,(TAU(I),I=1,N)
                 PRINT 1004,(GRAD(I),I=1,N)
 1003            FORMAT((' DCGMIN:  TAU  ',3D14.7))
 1004            FORMAT((' DCGMIN:  GRAD ',3D14.7))
   20         CONTINUE
C ***
C **   THIS IS THE FLETCHER-REEVES SCHEME *****
      Z=GG/GGP
C
      IF(Z.EQ.0.D0) GOTO 82
      GS=0.D0
      SS=0.D0
C ******     WORK = SEARCHING DIRECTION
      DO 21 I=1,N
      WORK(I)=Z*WORK(I)-GRAD(I)
      SS=SS+WORK(I)**2
   21 GS=GS+GRAD(I)*WORK(I)
          IF(GS.GE.0.D0) GOTO 10
C ******     INITIAL STEP FOR LINE MINIMIZATION
C  OKSTEP IS THE LARGEST FIRST STEP THAT WILL BE TRIED IN LINE SEARCH
      ALPHA=-2.D0*DF/GS
      SL=DSQRT(SS)
      IF(ALPHA*SL.GT.OKSTEP) ALPHA=OKSTEP/SL
      DF=ETOT
C ********
  510 CONTINUE
C ********  CRITERIONS TO GET OUT FROM LINMIN
C **          CC1: GRADIENT DECREASES BY THE FACTOR OF CC1
      CC1=0.10D0
C **          CC2: GRAD AND WORK ARE ORTHOGONAL TO EACH OTHER
C                      COS(THETA) .LT. CC2
      CC2=0.05D+00
C **          CC3: CRITERION IN REAL SPACE CHANGE.
      CC3=EPS
C **
C ***** TEMP CARE
C     IF(KCONT.EQ.1) THEN
C     WRITE(6,9992)  DF, GGP, G1G1, GG, GG1, Z
C9992 FORMAT(/'  BEFORE CALLING LINMIN: DF TO Z'/6D12.4 )
C     WRITE(6,9993) WORK(1), WORK(N), WORK(N+1), WORK(N+N),
C    &              GRAD(1), GRAD(N)
C     WRITE(6,9994) AL, ALL, AR, ARR
C9993 FORMAT( '   WORK WORK GRAD'/6D12.4)
C9994 FORMAT( '   AL ALL AR ARR'/(6D12.4))
C     END IF
C ***** TEMP CARE END
      CALL LINMIN( KCONT, N, TAU, ETOT, GRAD, WORK, ALPHA,
     &             CC1, CC2, CC3, EDECR, IFN, MAXFN-IFN, IER,
     &             NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
     &       NBNDQ, NFL, NPFL, NDX, NDY, NDZ, NUMK, NUMKQ,VGA,
     &       vn1,vn2,
     &             COEF, DCOEF,  CL1,
     &   YLM, G, EXPG, G2,GDUMP, RHO, RHO1, RHO2, RHO3, RHO4,
     &   RHOG, VECK, OCC, EE, EE2,EE3,EE4,WGT, TPIBA, VG, S, NTOT,
     &             I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &             MXBND, MBLK, OMEGA, ZVAL, DFORCE, SFORCE,
     &             NTAUQ, NTYQ, NTYPE, LREQ, NUMTY, NIDN,
     &             ZV, RC0, COR, NUMC, NCRQ, LATQ, RVEC, NLV, ZZ,
     &             NKMESH, NEXPND,   EENL, EBNDW, EW, PE, VINT,
     &             RCOSIN, WK, SK, NSY, KZ, FXNL, FYNL, FZNL,
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
C *******   CASE OF TIME OUT  **********
             IF(IER.EQ.1) THEN
             REWIND 78
             WRITE(78)  WORK, GRAD, TAU, ETOT, ALPHA, TLAST, STEP,
     &                  ELAST,
     &                  STEPSQ, FOL, AMOL, DN, SGN, AL, ALL, AR, ARR,
     &                  GN, AM, IHELP, MODE, DF, GGP, G1G1, GG, GG1, Z
             END IF
C ****** TEMP CARE
C     WRITE(6,9999) ETOT, ALPHA, TLAST, STEP, ELAST,STEPSQ, FOL, AMOL
C    &            , DN, SGN, GN, AM
C9999 FORMAT(/' AFTER WRITING ON FF78: FROM ETOT TO AM'/(6D12.4) )
C     WRITE(6,9998) IHELP, MODE, DF, GGP, G1G1, GG, GG1, Z
C9998 FORMAT( '                        FROM IHELP TO Z'/2I4/6D12.4 )
C     WRITE(6,9993) WORK(1), WORK(N), WORK(N+1), WORK(N+N),
C    &              GRAD(1), GRAD(N)
C     WRITE(6,9994) AL, ALL, AR, ARR
C ****** TEMP CARE END
C **************************************
          KCONT = 0
C **************************************
      IF(IER.NE.0) GOTO 82
        GGP=GG
        DF=DF-ETOT
        BIGDX=0.D0
        DO 31 I=1,N
        ADX=DABS(ALPHA*WORK(I))
   31   IF(ADX.GT.BIGDX) BIGDX=ADX
C ***********
          WRITE(6,2002) ETOT, GG, BIGDX
 2002     FORMAT(//'         ETOT  GG  BIGDX: ',3D13.5/)
C **********
        IF(BIGDX.LT.EPS) GOTO 82
   60 CONTINUE
      GOTO 10
C *****
C
   82 CONTINUE
      RETURN
      END
C*****************************************************************
      SUBROUTINE
     &     LINMIN( KCONT, N, TAU, ETOT, GRAD, D, T,
     &             CC1, CC2, CC3, EDECR, KF, MOST, IEX,
     &             NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
     &          NBNDQ, NFL, NPFL, NDX, NDY, NDZ, NUMK, NUMKQ,VGA,
     &          vn1,vn2,
     &             COEF, DCOEF,  CL1,
     &   YLM, G, EXPG, G2,GDUMP, RHO, RHO1, RHO2, RHO3, RHO4,
     &   RHOG, VECK, OCC, EE, EE2,EE3,EE4,WGT, TPIBA, VG, S, NTOT,
     &             I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &             MXBND, MBLK, OMEGA, ZVAL, DFORCE, SFORCE,
     &             NTAUQ, NTYQ, NTYPE, LREQ, NUMTY, NIDN,
     &             ZV, RC0, COR, NUMC, NCRQ, LATQ, RVEC, NLV, ZZ,
     &             NKMESH, NEXPND,   EENL, EBNDW, EW, PE, VINT,
     &             RCOSIN, WK, SK, NSY, KZ, FXNL, FYNL, FZNL,
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     & ,sig,x0,x1,work1,work20,fdump,NGNL )
C  UNIVARIATE MINIMIZATION TRANSLATED FROM PHIL WOLFE'S APL PGM
C  'LINEG'. SEARCHES FOR MINIMUM OF FUNCTION EVALUATED BY
C  'CALL FUNCT(N,TAU,ETOT,GRAD)' ALONG THE SEARCH DIRECTION D.
C  INITIAL FUNCTION VALUE ETOT AND GRADIENT GRAD AT POINT TAU MUST BE
C  GIVEN; FIRST TRIAL POINT IS TAU+T*D. KF IS INCREMENTED FOR EACH
C  FUNCTION EVALUATION.  THE ROUTINE EXECUTES AT MOST 'MOST' CALLS
C  OF FUNCT.  SUCCESSFUL EXIT  (IEX = 0)  OCCURS WHEN:
C         THE DIRECTIONAL DERIVATIVE IS  < CC1 TIMES ITS INITIAL VALUE
C     OR, THE D COMPONENT OF GRAD BECOMES < CC2 TIMES THE MAGNITUDE OF
C         GRAD.
C     OR, THE STEPS BECOME SMALLER THAN CC3.
C  OTHER EXIT CODE VALUES:
C           IEX=-1.. ERROR IN GRADIENT CALCULATION
C           IEX=1... NO CONVERGENCE AFTER 'MOST' STEPS
C           IEX=2... RUNAWAY OF X-- STEPS HAVE BECOME VERY LARGE
C  SEARCH IS BY EXTRAPOLATION FOLLOWED BY CLEVER CUBIC INTERPOLATION--
      IMPLICIT REAL*8(A-H,O-Z)
      COMMON /NEED/ TLAST, ELAST, STEP, STEPSQ, FOL, AMOL, DN, SGN,
     &              AL(3), ALL(3), AR(3), ARR(3), GN, AM, IHELP, MODE
      DIMENSION TAU(N),GRAD(N),D(N)
c      COMPLEX*16 COEF(NG2Q,MXBND), DCOEF(NG2Q,MXBND),
      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ), DCOEF(NG2Q,MXBND)
c     &           ,CWK1(NG2Q,MXBND), CWK2(NG2Q,MXBND)
c      COMPLEX*16 CL1(NG2Q,MXBND),CL2(NG2Q,MXBND),CL3(NG2Q,MXBND)
c      COMPLEX*16 HD(NG2Q,MXBND), HDO(NG2Q,MXBND)
      COMPLEX*16 CL1(NG2Q,MXBND)
      DIMENSION EXPG(NGQ)
      DIMENSION NGNL(NTYQ,NUMKQ)
C     COMPLEX*16 CTEMP,CHD
C
c      REAL*8 RHO(NXYZ),YLM(NG2Q,4),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
c      REAL*8 RHO(NXYZ),YLM(NG2Q,9),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
      REAL*8 RHO(NXYZ),YLM(NG2Q,16),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
C
      PARAMETER (IRLATQ=144,NAS=144)
      DIMENSION EBNDW(NBNDQ,IRLATQ),EW(NBNDQ),PE(NBNDQ*IRLATQ),
     &          VINT(NBNDQ,IRLATQ),EENL(NBNDQ,NUMKQ),
     &          RCOSIN(NAS,IRLATQ),WK(NAS),SK(3,NAS),NSY(IRLATQ),
     &          KZ(3,IRLATQ,48)
      dimension fdump(nxyz)
C
c ***
      dimension VGA(NGQ,NTYQ),vn1(2*nxyz,2),vn2(2*nxyz,2)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),RHO4(NXYZ),RHOG(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3)
c     &           VG(NXYZ),WORK2(NG2Q,5)
     &           VG(NXYZ),WORK2(NG2Q,7)
      INTEGER*4 S(3,3,48)
C***  WORK ARRAYS FOR FOURIER TRANSFORM
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
C
      DIMENSION I2G(NGQ),J2G(NG2Q,NUMKQ),NG2(NUMKQ)
      DIMENSION G(4,NGQ),G2(4,NG2Q,NUMKQ),WGT(NUMKQ),GDUMP(NG2Q,NUMKQ)
      DIMENSION NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     &          ZV(NTYQ),RC0(NCRQ,NTYQ),
     &          COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ),IOWF(MBLK,NUMKQ),
      DIMENSION VPJ(NG2Q,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ),IOWF(MBLK,NUMKQ),
     &          IOVP(2,NTYQ,NUMKQ),OCC(NBNDQ,NUMKQ),EE(NBNDQ,NUMKQ)
      dimension ee2(nbndq),ee3(nbndq),ee4(nbndq)
ccc
c     work area for orthogonization
      complex*16  sig(mxbnd,mxbnd),x0(mxbnd,mxbnd),
     &    x1(mxbnd,mxbnd),work1(mxbnd,mxbnd),work20(mxbnd,mxbnd)
C
      DIMENSION DFORCE(3,NTAUQ),SFORCE(3,NTAUQ),RVEC(4,LATQ),ZZ(NTAUQ)
      COMMON/COMOPT/IOPT(10,5)
      DIMENSION FXNL(NTAUQ,NBNDQ,NUMKQ),FYNL(NTAUQ,NBNDQ,NUMKQ),
     &          FZNL(NTAUQ,NBNDQ,NUMKQ)
C
c *** temp check
c       write(6,*)' in sub. LINMIN ...'
c       do i=1,n
c         write(6,*)tau(i)
c       enddo
c       miya=13
c       if ( miya.eq.13 ) stop 'check'
c *** temp check: end
C
      ISTRT = 0
      IOSH = 0
      IEX=0
C *****   CASE OF CONTINUATION
            IF(KCONT.EQ.1) THEN
              DO 10 I = 1, N
   10         D(I) = D(I) * SGN
              T = T * SGN
              KFO = KF
              ISTRT = 1
              GO TO 500
            END IF
C *****
      AMOL=0.D0
      DN=0.D0
      TLAST=0.D0
      DO 1 I=1,N
      DN=DN+D(I)**2
    1 AMOL=AMOL+GRAD(I)*D(I)
      SGN=1.D0
      IF(AMOL.GT.0.D0) SGN=-1.D0
      AMOL=AMOL*SGN
      DO 98 I=1,N
   98 D(I)=D(I)*SGN
      T=DABS(T)
      AR(1)=-1.D16
      AR(2)=-1.D16
      AR(3)=-1.D16
      FOL=ETOT
      AL(1)=0.D0
      AL(2)=FOL
      AL(3)=AMOL
C
      MODE=1
      KFO=KF
C *********     LOOP FOR LINE MINIMIZATION
  108 STEP=T-TLAST
      STEPSQ=STEP**2*DN
C
            DO 2 I=1,N
    2       TAU(I)=TAU(I)+STEP*D(I)
C
      TLAST=T
      ELAST=ETOT
c *** temp check
c       write(6,*)' in sub. LINMIN ...just before FRPRMN'
c       do i=1,n
c         write(6,*)tau(i)
c       enddo
c      write(6,*)' NRX NRY NRZ = ',NRX,NRY,NRZ
c      write(6,*)' NXYZ = ',NXYZ
c      write(6,*)' NG = ',NG
c      write(6,*)' NGQ = ',NGQ
c      write(6,*)' NBNDQ = ',NBNDQ
c      write(6,*)' NUMK = ',NUMK
c      write(6,*)' NUMKQ = ',NUMKQ
cc      write(6,*)' NG2 = ',NG2
cc      write(6,*)' NG2Q = ',NG2Q
c      write(6,*)' NTYQ = ',NTYQ
c      write(6,*)' NTAUQ = ',NTAUQ
cc       write(6,*)' vn1 '
cc       write(6,*)( vn1(i,1),i=1,nxyz,100)
cc       write(6,*)' vn2 '
cc       write(6,*)( vn2(i,1),i=1,nxyz,100)
c       write(6,*)'  Next: FRPRMN '
c       miya=13
c       if ( miya.eq.13 ) stop 'check'
c *** temp check: end
C ***
c      CALL FRPRMN( ISTRT, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
      CALL FRPRMN(ISTRT,NRX, NRY, NRZ, NXYZ,vn1,vn2,NG,NGQ,NG2,NG2Q,
     &             NBNDQ, NBNDQ, NFL, NPFL, NDX, NDY, NDZ,
c     &             NUMK, NUMKQ, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     &             NUMK, NUMKQ, COEF, DCOEF,  CL1, 
c     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
c     &          CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &           YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &  RHO4, RHOG, VECK, OCC, EE,EE2,EE3,EE4, WGT, TPIBA, VG, S,
     &             NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &           MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &             TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &           SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
     &           IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,7008) TIM
 7008 FORMAT(23X,'*** LINMIN:  CPU TIME AFT FRPRMN: ',F15.7,' SEC')
C
       CALL ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
     &              NBNDQ, NBNDQ, NUMK, NUMKQ, COEF, DCOEF,
     &       YLM, G, EXPG, G2,GDUMP, RHO, RHO4, RHO1, RHO2, RHOG,
     &              TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ, VPP,
     &              IOWF, IOVP, OMEGA, GRAD, DFORCE, SFORCE,
     &              NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &              VINT, NSY, FXNL, FYNL, FZNL,
     &              TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
cc     &              ZZ, ZVAL, NPFL, MXOFL, OCC                      )
     &              ZZ, ZVAL, NPFL, MXOFL, OCC,VGA,NGNL ,CL1
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
C
C ***
      KF=KF+1
      IF(KF-KFO.GT.MOST) IEX=1
      GN=0.D0
      AM=0.D0
      DO 3 I=1,N
      GN=GN+GRAD(I)**2
    3 AM=AM+GRAD(I)*D(I)
C *****
  500 CONTINUE
C
              WRITE(6,1001) T,ETOT,GN,AM
 1001         FORMAT(/' **LINMIN: T ETOT GRD**2 GRD*D = '/
     &                '           ',4D15.7)
C
C ****** TEMP CARE
C     IF(KFO.EQ.KF) THEN
C     WRITE(6,9999) ETOT, T, TLAST, STEP, ELAST,STEPSQ, FOL, AMOL
C    &            , DN, SGN, GN, AM
C9999 FORMAT(/' AT 500: FROM ETOT TO AM'/(6D12.4) )
C     WRITE(6,9998) IHELP, MODE
C9998 FORMAT( '         IHELP AND MODE  ',2I4)
C     END IF
C ****** TEMP CARE END
C
      IF(STEPSQ.GT.1.D16) IEX=2
      IF (IEX.NE.0) GOTO 197
      IF(ETOT.GT.FOL) GOTO 4
C ***
          IF(DABS(AM/AMOL).LE.CC1) GOTO 197
          IF(AM**2/(DN*GN).LE.CC2**2) GOTO 197
          IF(STEPSQ.LT.CC3**2) GOTO 197
          IF( ABS(ETOT-ELAST) .LT. EDECR ) IOSH = IOSH + 1
          IF( IOSH.GE.2 ) GO TO 197
          IF( ABS(ETOT-ELAST) .GE. EDECR ) IOSH = 0
C ****
    4 IF(AM.GE.0.D0.OR.ETOT-AL(2).GE.0.D0) GOTO 118
C ******************************************************************
  114 DO 5 I=1,3
    5 ALL(I)=AL(I)
      AL(1)=T
      AL(2)=ETOT
      AL(3)=AM
      IHELP=0
      IF(ALL(2).LT.AR(2)) IHELP=1
      GOTO (122,125),MODE
C *****
  118 DO 6 I=1,3
    6 ARR(I)=AR(I)
      AR(1)=T
      AR(2)=ETOT
      AR(3)=AM
      IHELP=0
      IF(ARR(2).LT.AL(2).AND.AR(2).LT.ARR(2).AND.AR(3).GT.0.D0) IHELP=2
      MODE=2
      GOTO 125
C ******
  122 T=CUMIN(ALL,AL)
      IF(AL(1).LT.T.AND.T.LE.AL(1)+4*(AL(1)-ALL(1))) GOTO 108
      T=AL(1)+4*(AL(1)-ALL(1))
      GOTO 108
C ******
  125 GOTO (129,131),IHELP
  126 TOLD=T
      T=CUMIN(AL,AR)
      IF(AL(1).LT.T.AND.T.LT.AR(1)) GOTO 108
      IEX=-1
      T=TOLD
      GOTO 197
C ******
  129 T=CUMIN(ALL,AL)
      GOTO 132
C ******
  131 T=CUMIN(AR,ARR)
  132 IF(AL(1).LT.T.AND.T.LT.AR(1)) GOTO 108
      GOTO 126
C ***********************************************************
  197 WRITE(6,2100) AM/AMOL, CC1, AM**2/(DN*GN), CC2, STEPSQ, CC3
     &            , ETOT-ELAST, EDECR
 2100 FORMAT(//'   ****   LINMIN:  AM/AMOL CC1   = ',2D13.5/
     &         '                   COS(TH) CC2   = ',2D13.5/
     &         '                   STEPSQ  CC3   = ',2D13.5/
     &         '                   DELTAE  EDECR = ',2D13.5)
      DO 198 I=1,N
  198 D(I)=D(I)*SGN
      T=T*SGN
C ***********************************************************
      RETURN
      END
C *******************************************************************
CUBIC INTERPOLATION ROUTINE: A.OSHIYAMA      11/29/94
      FUNCTION CUMIN(U,V)
C  FINDS MINIMUM BY CUBIC INTERPOLATION.
C       INPUT: U AND V ARE TRIPLES CONSISTING OF
C              (TAU, F(TAU), DF(TAU)/DX) WHERE X IS A COORDINATE
C              ALONG THE LINE.
C  WHEN NO REASONABLY NEARBY CUBIC MINIMUM EXISTS, THE ROUTINE
C  RETURNS +/- 10**2 TIMES THE INTERVAL WIDTH.
      IMPLICIT REAL * 8 (A-H,O-Z)
      DIMENSION U(3),V(3)
      DATA THRD, BIG/0.3333333333333333D+00, 1.0D+02/
C
      DX  = U(1)- V(1)
            IF( ABS(DX).LT.0.1D-25) STOP ' CUMIN: DX TOO SMALL'
      DYX = (U(2)- V(2)) / DX
      ALP = 6.0D+00 * ( 0.5D+00*(U(3)+V(3)) - DYX )
      IF( ABS(ALP) .LT. 0.1D-25) THEN
C ************   NOT CUBIC BUT PARABOLA
        A = ( U(3)-V(3) ) / DX
        IF ( A .LE. 0.0D+00 ) GO TO 100
        CUMIN = U(1) - U(3) / A
      ELSE
C ************   CUBIC
        A = U(3) * DX**2 / ALP
        B = 6.0D+00 * DX * ( DYX - THRD*(2.0D+00*U(3)+V(3)) ) / ALP
        DJ = B*B - 4.0D+00 * A
        IF( DJ .LE. 0.0D+00 ) GO TO 100
        DJ = SQRT(DJ)
        IF( ALP .GT. 0.0D+00) THEN
C ************   THE CUBE COEFFICIENT BEING POSITIVE
          CUMIN = U(1) + 0.5D+00 * ( B + DJ )
        ELSE
C ************   THE CUBE COEFFICIENT BEING NEGATIVE
          CUMIN = U(1) + 0.5D+00 * ( B - DJ )
        END IF
      END IF
      RETURN
C *******************************************************
  100 SGN = DX
      IF( U(2) .GT. V(2) ) SGN = -DX
      CUMIN = U(1) + SGN * BIG
      RETURN
      END
C **************************************************************
C--------------------------------------------------------
C
C     PRE-CONDITIONED CONJUGATE-GRADIENT METHOD
C         REF. PRB 40 12255 ('89) M. TETER, M. PAYNE, AND D. ALLAN
C              PRB 42 1400  ('90) D. M. BYLANDER, L. KLEINMAN,
C                                 AND S. LEE
C         CODED BY O. SUGINO 14 AUG, 1990
C         MEMORY SAVE VERSION (1990-11-28) OSAMU SUGINO
C
C     FRPRMN---LOCPOT
C           !
C           ---VOFRHO
C           !
C           ---RHOOFK
C           !
C           ---RHOGET
C           !
C           ---DMIXP
C           !
C           ---SDDIAG---HLOCAL
C                    !
C                    ---NONLOC
C                    !
C                    ---DIAGK
C*****************************************************************
      SUBROUTINE FRPRMN
c     &           ( ISTRT, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
     &   ( ISTRT, NRX, NRY, NRZ, NXYZ,VN1,VN2, NG, NGQ, NG2, NG2Q,
     &             NBNDQ, NBND, NFL, NPFL, NDX, NDY, NDZ,
cc     &             NUMK, NUMKQ, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     &             NUMK, NUMKQ, COEF, DCOEF, CL1, 
c     &             CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,
c     &         CL3, HD, HDO, YLM, G, G2, RHO, RHO1, RHO2, RHO3,VGA,
     &    YLM, G, G2,GDUMP, RHO, RHO1, RHO2, RHO3,VGA,
     &    RHO4, RHOG, VECK, OCC, EE,EE2,EE3,EE4, WGT, TPIBA, VG, S,
     &             NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
     &           MXBND, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &           TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
     &            SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
     &             IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     &  ,sig,x0,x1,work1,work20,fdump,NGNL )
C
      IMPLICIT REAL*8(A-H,O-Z)
C
      PARAMETER (IRLATQ=144,NAS=144)
C *********** <<<<<< CAUTION >>>>>> *************
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC      PARAMETER( KBSQ=18 )
c      PARAMETER( NDXQ=10 ,NDYQ=10 ,NDZQ=10, NVIRTQ =10)
      PARAMETER( NDXQ=10 ,NDYQ=10 ,NDZQ=10, NVIRTQ =56)
CC  *****  CARE ****
      PARAMETER( NB21Q= NVIRTQ - 1              )
CC  *****  CARE END ****
      PARAMETER( IRLQ=1  ,IILQ=1          )
      PARAMETER(IQ1 =IRLQ*(2*NDXQ+1)*(2*NDYQ+1)*(  NDZQ+1)*(NB21Q+1))
      PARAMETER(IQ2 =IRLQ*(4*NDXQ+1)*(4*NDYQ+1)*(2*NDZQ+1)*(NB21Q+1))
c      PARAMETER(IQ3 =(IILQ*IRLATQ-1)/2+1                            )
c      PARAMETER(IQ4 =(IILQ*3*IRLATQ-1)/2+1                          )
      PARAMETER(IQ5 =IRLQ*(NB21Q+1)*IRLATQ                          )
      PARAMETER(IQ6 =IRLQ*(NB21Q+1)*IRLATQ                          )
      PARAMETER(IQ7 =(IILQ*IRLATQ-1)/2+1                            )
      PARAMETER(IQ8 =IRLQ*(4*NDXQ+1)*(4*NDYQ+1)*IRLATQ*2            )
      PARAMETER(IQ9 =IRLQ*(4*NDXQ+1)*(4*NDYQ+1)*IRLATQ*2            )
      PARAMETER(IQMX6=2*NDZQ*(4*NDXQ+1)*(4*NDYQ+1)                  )
      PARAMETER(IQ3=IQMX6*13, IQ4=0 )
      PARAMETER(IQ10=(IILQ*2*IQMX6)/2                              )
      PARAMETER(IDIMQ=IQ1+IQ2+IQ3+IQ4+IQ5+IQ6+IQ7+IQ8+IQ9+IQ10  )
C
c **** 
      DIMENSION YY(IDIMQ)
C
c      COMPLEX*16  COEF(NG2Q,MXBND), DCOEF(NG2Q,MXBND),
      COMPLEX*16  COEF(NG2Q,MXBND,NUMKQ), DCOEF(NG2Q,MXBND)
c     &           ,CWK1(NG2Q,MXBND), CWK2(NG2Q,MXBND)
c      COMPLEX*16 CL1(NG2Q,MXBND),CL2(NG2Q,MXBND),CL3(NG2Q,MXBND)
c      COMPLEX*16 HD(NG2Q,MXBND),HDO(NG2Q,MXBND)
c      COMPLEX*16 CL1(NG2Q,MXBND)
      COMPLEX*16 CL1(NG2Q,10)
C
c      REAL*8 RHO(NXYZ),YLM(NG2Q,4),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
c      REAL*8 RHO(NXYZ),YLM(NG2Q,9),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
      REAL*8 RHO(NXYZ),YLM(NG2Q,16),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
C
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),RHO4(NXYZ),RHOG(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3)
c     &           VG(NXYZ),WORK2(NG2Q,5)
     &           VG(NXYZ),WORK2(NG2Q,7)
      INTEGER*4 S(3,3,48)
C   WORKING ARRAYS FOR FOURIER TRANSFORM
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      DIMENSION I2G(NGQ),J2G(NG2Q,NUMKQ),NG2(NUMKQ)
      DIMENSION G(4,NGQ),G2(4,NG2Q,NUMKQ),WGT(NUMKQ),GDUMP(NG2Q,NUMKQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     &          ZV(NTYQ),RC0(NCRQ,NTYQ),
     &          COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ),IOWF(MBLK,NUMKQ),
      DIMENSION VPJ(NG2Q,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ),IOWF(MBLK,NUMKQ),
     &          IOVP(2,NTYQ,NUMKQ),OCC(NBNDQ,NUMKQ),EE(NBNDQ,NUMKQ)
      DIMENSION NGNL(NTYQ,NUMKQ)
      dimension ee2(nbndq),ee3(nbndq),ee4(nbndq)
      COMMON/COMOPT/IOPT(10,5)
      COMMON/COMFRP/RMIX,TR2,ITCMAX,ITMAX,ITC1,ITC7
      COMMON /AVEC/  A1(3), A2(3), A3(3), B1(3), B2(3), B3(3)
     &             , COVA, ALAT
C
      DIMENSION EBNDW(NBNDQ,IRLATQ),PE(NBNDQ*IRLATQ),RCOSIN(NAS,IRLATQ)
      DIMENSION EW(NBNDQ),VINT(NBNDQ,IRLATQ),SK(3,NAS),KZ(3,IRLATQ,48),
     &          NSY(IRLATQ)
c ****
      dimension VGA(NGQ,NTYQ),VN1(2*nxyz,2),VN2(2*nxyz,2)
ccc
      dimension fdump(NXYZ)
c     work area for orthogonization
      complex*16  sig(mxbnd,mxbnd),x0(mxbnd,mxbnd),
     &    x1(mxbnd,mxbnd),work1(mxbnd,mxbnd),work20(mxbnd,mxbnd)
      COMMON/SMOOTH/ADUMP
C 
C
C *****
              IF( NPFL .EQ. 0 ) GO TO 4321
C
       if ( NDX.eq.0 .and. NDY.eq.0 .and. NDZ.eq.0 ) goto 4321
       IF(NDX.LE.NDXQ .AND. NDX.GT.0) GO TO 4321
       IF(NDY.LE.NDYQ .AND. NDY.GT.0) GO TO 4321
       IF(NDZ.LE.NDZQ .AND. NDZ.GT.0) GO TO 4321
       WRITE(6,4322) NDX, NDXQ, NDY, NDYQ, NDZ, NDZQ
       STOP
 4322  FORMAT(
     &  '   **** FRPRMN: WRONG!!!: NDX NDXQ NDY NDYQ NDZ NDZQ = ',6I4)
 4321  CONTINUE
C *****
      RDIF0 = 0.1D-08
      WRITE(6,6020) ITMAX, ITC7, ITC1, ITCMAX,
     &              ( I, (TAU(J,I), J=1,3), I=1, NTAUQ )
 6020 FORMAT(/' ******** FRPRMN: ITMAX(SCF) = ',I3,
     &        ' ITC7 ITC1 ITCMAX (CG) = ',3I3/
     &        '                      TAU:'/
     &                         (18X,I4,3D13.5) )
      WRITE(6,*) ' '
C
      PI=4.D0*ATAN(1.D0)
      PI2=PI*2.D0
      TPIBA2=TPIBA**2
C
      CALL PREFFT(NRX,NRY,NRZ,NXYZ,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
C
      CALL LOCPOT(NXYZ,NG,NGQ,G,TPIBA,RHO4,RHO1,
c     & I2G,RHO2,OMEGA,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC)
C
C
c ***  temp check
c      miya=13
c      if (miya.eq.13) then
c       write(6,*)' Before VOFRHO '
c       stop
c      endif
c ***  temp check end
C     CALL CLOCK(TIM)
C6000 FORMAT(23X,'****  FRPRMN: AFT LOCPOT: ',F15.7,' SEC')
C     WRITE(6,6000) TIM
C
      CALL VOFRHO(NRX,NRY,NRZ,NXYZ,NG,NGQ,G,TPIBA,
     & RHO1,RHO2,RHO3,RHO,RHOG,I2G,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2
     & ,CL1(1,1),CL1(1,2),CL1(1,3),CL1(1,4),CL1(1,5)
     & ,CL1(1,6),CL1(1,7),CL1(1,8),CL1(1,9),CL1(1,10)  )
C
C     CALL CLOCK(TIM)
C6002 FORMAT(23X,'****  FRPRMN: AFT VOFRHO: ',F15.7,' SEC')
C     WRITE(6,6002) TIM
C
C     POTENTIAL VG
C
      DO 502 IG=1,NXYZ
  502 VG(IG)=RHO3(IG)+RHO4(IG)
c *** Smoothing 
      adump4=4*adump
      do ig=1,nxyz
      jg=i2g(ig)
      vg(jg)=vg(jg)*fdump(ig)
      enddo
      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,VG,RHO1,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
c ***  temp check
c      miya=13
c      if ( miya.eq.13) then
c      write(6,*)' VG in real space '
c      write(6,*)( VG(i),i=1,1500,100 )
c      stop
c      endif
c ***  temp check : end
C
C#################################################################
      ICONV=0
      DO 1000 ITS=1,ITMAX
C
      DO 600 I=1,NXYZ
  600 RHO(I)=0.D0
C
      IF( IOPT(3,1).EQ.1 .OR. IOPT(3,1).EQ.2 .OR. IOPT(3,1).EQ.4 )
     &             THEN
         IF(ITS.EQ.1) THEN
            ITCF = ISTRT*ITC7 + (1-ISTRT)*ITC1
         ELSE
            ITCF=ITCMAX
         END IF
      ELSE
         IF(ITS.EQ.1) THEN
            ITCF=ITC1
         ELSE
            ITCF=ITCMAX
         ENDIF
      ENDIF
C
      ENL=0.D0
      EKINE=0.D0
      DO 2000 IK=1,NUMK
c *** temp check
       write(6,*)'  before SDDIAG IK = ',IK
c *** temp check end
      isd=1
C
      CALL SDDIAG( RDIF0, ITCF, NRX, NRY, NRZ, NXYZ, NG2(IK), NG2Q,
c     &    NBNDQ, NBND, COEF(1,1,IK), DCOEF,  CL1, 
     &    NBNDQ, NBND, COEF(1,1,IK), DCOEF,   
     &   YLM, G2(1,1,IK),GDUMP(1,IK), RHO1, RHO2, RHO3,
     &             TPIBA, VG, J2G(1,IK), WORK2, OUT(1,1,IK),
     &             VPJ(1,1,1,1,IK),VPP,
     &             IOWF(1,IK), IOVP(1,1,IK), MXBND, MBLK,
     &             OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
     &   NIDN, EE(1,IK),EE2,EE3,EE4, WSAVEX, WSAVEY, WSAVEZ, IFACX,
     &             IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
     & ,sig,x0,x1,work1,work20,isd,NGNL(1,IK) )
C
C     CALL CLOCK(TIM)
C6004 FORMAT(23X,'****  FRPRMN: AFT SDDIAG: ',F15.7,' SEC')
C     WRITE(6,6004) TIM
C
c *** temp check
       write(6,*)'  after SDDIAG IK = ',IK
c       if ( IK.eq.NUMK ) stop ' check end '
c *** temp check end
 2000 CONTINUE
C
C     END OF CG-LOOP
C
C     GENERATE NEW CHARGE DENSITY
C
C  ***   CHECK
C     WRITE(6,3600) NFL, NFL + NPFL
C3600 FORMAT(/
C    &'   ****   FRPRMN: E(K) FROM NFL = ',I3,
C    &' TO NFL+NPFL = ',I3,' BANDS:')
C     DO 3200 IK=1,NUMK
C     WRITE(6,3010) IK,( EE(JJ,IK)*27.212D0, JJ = NFL, NFL+NPFL )
C3010 FORMAT(4X,I3,2X,5D12.4/(9X,5D12.4) )
C3200 CONTINUE
C     WRITE(6,*) ' '
C  ***   CHECK END
c ***  temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)' Before RHOOFK '
c      stop
c      endif
c ***  temp check end
      NBND1 = NFL + 1
c *** temp check
c      do ik=numk,numk
c      write(6,*)' IK =',ik
c      write(6,*)' ng2(IK) = ',ng2(ik),' wgt(ik) = ',wgt(ik)
c      write(6,*)' IOWF '
c      write(6,1313)( IOWF(iblk,ik),iblk=1,MBLK )
c      write(6,*)' J2G '
c      write(6,1313)( j2g(ig,ik),ig=1,ng2(ik) )
c      enddo
c 1313 format(8i10)
c *** temp check end
      DO 630 IK=1,NUMK
c      DO 630 IK=1,NUMK-1
c ***  temp check
c      if ( ik.le.NUMK ) then
c      write(6,*)' before RHOOFK IK = ',ik 
c      else
c      stop
c      endif
c ***  temp check end
      CALL RHOOFK( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NG2(IK), NG2Q,
     &             NBNDQ, NBND, NFL, RHO, RHO1, RHO2, RHO3,
     &             COEF(1,1,IK),
     &             WGT(IK), J2G(1,IK), IOWF(1,IK), OCC(1,IK),
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2                    )
c ***  temp check
c      if ( ik.eq.NUMK ) then
c      write(6,*)' RHOOFK finished IK = ',ik 
c      stop
c      endif
c ***  temp check end
  630 CONTINUE
c ****  temp check
c       miya=12
c       if ( miya.eq.13 ) then
c        write(6,*)' END of RHOOFK !! '
c        write(6,*)' NKMESH NEXPND = ',NKMESH,NEXPND
c       stop
c       endif
C ****
                 IF( NPFL .EQ. 0 ) GO TO 8500
C ****
c ***  temp check
c      write(6,*)' Before BANDS '
c      write(6,*)' NKMESH NEXPND = ',NKMESH,NEXPND
c      miya=12
c      if ( miya.eq.13 ) then
c      write(6,*) ' before BANDS'
c      stop
c      endif
c ***  temp check end
      CALL BANDS( NBNDQ,NUMK, EE,
     &            NKMESH, NEXPND, EBNDW, EW, RCOSIN )
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)' BANDS finished!'
c      endif
c *** temp check end
      IBKK=0
      DO 631 KK=1,NEXPND
      DO 631 IB=1,NBNDQ-NBND1+1
        IBKK=IBKK+1
        PE(IBKK)=EBNDW(NBND1+IB-1,KK)
  631 CONTINUE
      EBND=0.D0
      DO 632 IB=1,NFL
        EBND=EBND+EW(IB)*2.D0
  632 CONTINUE
C
      NANNO=ZVAL/2+0.001
      IF (NANNO .LE. 1) EF1=EW(1)
     &                 -ABS( EW(3)-EW(1) )
      IF (NANNO .EQ. 2) EF1=EW(1)
      IF (NANNO .GT. 2) EF1=EW(NANNO-2)
      EF2=EW(NANNO+2)
      IF ( NANNO .GT. 20 ) then
      EF1=EW(NANNO-6)
      EF2=EW(NANNO+6)
      endif
C ******   TEMP  INPUT END
CC    WRITE(6,4242) EF1*27.212, EF2*27.212, NDX, NDY, NDZ,
CC   &              EBND*27.212
C4242 FORMAT(/'  ****  BEFORE DOS: EF1 = ',D12.4,' EF2 = ',D12.4/
C    &       '          BZ MESH: NDX NDY NDZ = ',3I3/
C    &       '          SUM OF EBND = ',D12.5/)
C     WRITE(6,4242)  NDX, NDY, NDZ
C4242 FORMAT('  ****  BEFORE DOS: NDX NDY NDZ = ',3I3)
      IIL=1
      IRL=1
C
c ****  temp check
c      miya=13
c      if ( miya.eq.13) then
c      write(6,*)' before DOS!'
c      endif
c ****  temp check end
      CALL DOS( PE, EBND, ZVAL, EF, EF1, EF2, YY, IDIMQ,
     &          NDX, NDY, NDZ, NBND1, NBNDQ, NEXPND, 48, IIL, IRL,
     &          NSY, KZ ,IRLATQ                                    )
C
c ****  temp check
c      miya=13
c      if ( miya.eq.13) then
c      write(6,*)' after DOS!'
c      endif
c ****  temp check end
      IBKK=0
      DO 633 KK=1,NEXPND
      DO 633 IB=1,NBNDQ-NBND1+1
        IBKK=IBKK+1
        VINT(IB+NBND1-1,KK)=PE(IBKK)
  633 CONTINUE
C
      IF( MOD(ITS,10) .LE. 1) THEN
         WRITE(6,4423) EBND, EF
         DO 4429 IB = NBND1, NFL + NPFL
         WRITE(6,4427) IB
 4429    WRITE(6,4426)  (VINT(IB,KK),KK=1,NEXPND)
 4423    FORMAT('  ****  AFTER DOS: SUM OF EBND = ',D12.5
     &          ,'  EF = ',D12.5)
 4427    FORMAT( '            IB = ',I4,'  AND VINT = :')
 4426    FORMAT( (10X,5D12.4) )
      END IF
C     WRITE(6,4424) ( (EBNDW(IB,KK),KK=1,NEXPND),IB=NBND1,NFL+NPFL )
C4424 FORMAT('        VINT = '/(12X,5D12.4) )
C
C ***   CHECK OF INTERPORATION OF E(K)
         SKDUMM  = SK(1,1)
C     WRITE(6,*) ' '
C     DO 635 IB = NBND1, NFL+NPFL, 3
C       DO 635 IK=1,NUMK
C       EIGENV=0.D0
C         DO 636 J=1,NEXPND
C         SUMJ=0.D0
C         DO 637 JJ=1,NSY(J)
C            COSSUM = SK(1,IK)*DBLE(KZ(1,J,JJ)) +
C    &                SK(2,IK)*DBLE(KZ(2,J,JJ)) +
C    &                SK(3,IK)*DBLE(KZ(3,J,JJ))
C            SUMJ=SUMJ+COS(PI2*COSSUM)
C 637     CONTINUE
C         EIGENV = EIGENV + EBNDW(IB,J)*SUMJ
C 636     CONTINUE
C       WRITE(6,4425) IB, IK, EE(IB,IK)*27.212, EIGENV*27.212
C4425 FORMAT('  ****  CHECK OF INTERPORATION: TRUE AND INTRPRTN'/
C    &        ' IB ',I3,' IK ',I3,4X,2D15.7)
C 635 CONTINUE
C     WRITE(6,*) ' '
C   ***  CHECK END
      DO 634 IK=1,NUMK
        CALL SUMCHR( MXBND, MBLK, NFL, NPFL, NRX, NRY, NRZ, NXYZ,
     &               RHO, RHO1, RHO2, RHO3, IOWF(1,IK), NG2Q,
c     &               NG2(IK), J2G(1,IK), COEF,
     &      NG2(IK), J2G(1,IK), COEF(1,1,IK),
     &               NKMESH, NEXPND, RCOSIN, NSY, IK, NBNDQ, NBND,
     &               VINT, OMEGA, WSAVEX, WSAVEY, WSAVEZ,
     &               IFACX, IFACY, IFACZ, LX1, LX2,
     &               LY1, LY2, LZ1, LZ2                           )
  634 CONTINUE
C ****
 8500            CONTINUE
C ****
      CALL RHOGET( NRX, NRY, NRZ, NXYZ, RHO, RHO1, RHOG,
     &             NTOT, S, OMEGA, ZVAL,RHO2,I2G,G,
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2,fdump   )
C
C
C     CALL CLOCK(TIM)
C6008 FORMAT(23X,'****  FRPRMN: AFT RHOGET: ',F15.7,' SEC')
C     WRITE(6,6008) TIM
C
      CALL VOFRHO( NRX, NRY, NRZ, NXYZ, NG, NGQ, G, TPIBA,
     &             RHO1, RHO2, RHO3, RHO, RHOG, I2G,
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2
     & ,CL1(1,1),CL1(1,2),CL1(1,3),CL1(1,4),CL1(1,5)
     & ,CL1(1,6),CL1(1,7),CL1(1,8),CL1(1,9),CL1(1,10)  )
C
C     CALL CLOCK(TIM)
C6010 FORMAT(23X,'****  FRPRMN: AFT VOFRHO: ',F15.7,' SEC')
C     WRITE(6,6010) TIM
C
C
      DO 503 IG=1,NXYZ
  503 RHO1(IG)=RHO3(IG)+RHO4(IG)
c *** Smoothing
      adump4=4*adump
      do ig=1,nxyz
      jg=i2g(ig)
      RHO1(jg)=RHO1(jg)*fdump(ig)
      enddo
      CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO1, RHO2,
     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &             LX1, LX2, LY1, LY2, LZ1, LZ2                 )
C
C     PRINT OUT CONVERGENCE OF THE POTENTIAL
C
      RDIF=0.D0
      DO 24 IG=1,NXYZ
   24 RDIF=RDIF+ABS(VG(IG)-RHO1(IG))**2
      RDIF=RDIF/NXYZ
C ******
             RDIF0 = RDIF * 0.5D+00
             IF( RDIF0 .GT. 0.1D-03 ) RDIF0 = 0.1D-04
C ******
      WRITE(6,124) ITS,RDIF
  124 FORMAT('     *** ITR #',I3,'  CONVERGENCE OF THE POTENTIAL IS '
     &      ,' **',D15.7)
      IF(RDIF.LT.TR2) then
      write(6,*)' Local SCF potential has been stored!'
      write(90)(dreal( RHO1(IR) )*13.6d0*2,IR=1,NXYZ )
      write(6,*)' Fourier components of eigen values'
      do 9428 ib=nbnd1,nfl+npfl
      write(6,4427) ib
 9428 write(6,4426)( ebndw(ib,kk),kk=1,nexpnd)
      write(6,*)' Fourier components of occupation #s'
      do 9429 ib=nbnd1,nfl+npfl
      write(6,4427) ib
 9429 write(6,4426) ( vint(ib,kk),kk=1,nexpnd)
      GOTO 1999
      end if
C
C
C *******************
      IF(IOPT(7,1).EQ.0) THEN
C        PANDEY'S EXTRAPOLATION (1) REAL SPACE
         TR3=1.D-15
c         CALL DMIXP( RHO1, VG, RMIX, R2, TR3, ITS, 3, NXYZ*2, 11, 12,
c         CALL DMIXP3( RHO1, VG, RMIX, R2, TR3, ITS, 3, NXYZ*2, 11, 12,
c     &               RHO2, RHO3,VN1,VN2, NXYZ*2)
         CALL potextr( RHO1, VG, RMIX, R2, TR3, ITS,  NXYZ*2,
     &               RHO2, RHO3,VN1,VN2)
c **** change isd
         if ( r2.le.1.d-02 ) then
          isd=1
         else
          isd=0
         endif
c
         IF(R2.LE.TR3) GOTO 1999
C
      ELSEIF(IOPT(7,1).EQ.2) THEN
C        PANDEY'S EXTRAPOLATION (2) G SPACE
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, VG, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                 )
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, RHO1, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                 )
         TR3=1.D-15
c         CALL DMIXP( RHO1, VG, RMIX, R2, TR3, ITS, 3, NXYZ*2, 11, 12,
c         CALL DMIXP3( RHO1, VG, RMIX, R2, TR3, ITS, 3, NXYZ*2, 11, 12,
c     &               RHO2, RHO3,VN1,VN2, NXYZ*2)
         CALL potextr( RHO1, VG, RMIX, R2, TR3, ITS,  NXYZ*2,
     &               RHO2, RHO3,VN1,VN2)
         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, VG, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                   )
c **** change isd
         if ( r2.le.1.d-02 ) then
          isd=1
         else
          isd=0
         endif
c
         IF(R2.LE.TR3) GOTO 1999
C
      ELSEIF(IOPT(7,1).EQ.3) THEN
C        PANDEY-KB'S EXTRAPOLATION
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, VG, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                 )
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, RHO1, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
         DO 33 IG=2,NG
         JG=I2G(IG)
         RHO1(JG)=RHO1(JG)*G(4,IG)/(G(4,IG)+1.92D0)
         VG  (JG)=VG  (JG)*G(4,IG)/(G(4,IG)+1.92D0)
   33    CONTINUE
         TR3=1.D-15
c         CALL DMIXP( RHO1, VG, RMIX, R2, TR3, ITS, 3, NXYZ*2, 11, 12,
c         CALL DMIXP3( RHO1, VG, RMIX, R2, TR3, ITS, 3, NXYZ*2, 11, 12,
c     &               RHO2, RHO3,VN1,VN2, NXYZ*2)
         CALL potextr( RHO1, VG, RMIX, R2, TR3, ITS, NXYZ*2,
     &               RHO2, RHO3,VN1,VN2)
         DO 35 IG=2,NG
         JG=I2G(IG)
         VG  (JG)=VG  (JG)/G(4,IG)*(G(4,IG)+1.92D0)
   35    CONTINUE
         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, VG, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                 )
C        DO 37 IG=1,NXYZ
C  37    VG(IG)=RHO2(IG)
c **** change isd
         if ( r2.le.1.d-02 ) then
          isd=1
         else
          isd=0
         endif
c
         IF(R2.LE.TR3) GOTO 1999
C
      ELSEIF(IOPT(7,1).EQ.4) THEN
C        OLD POTENTIAL IS REPLACED BY NEW ONE
         DO 38 IG=1,NXYZ
           VG(IG)=RHO1(IG)
   38    CONTINUE
      ELSE
CCC        KLEINMAN'S EXTRAPOLATION
CCC        VIN(G)=VIN(G)+RMIX*G**2*(VOUT(G)-VIN(G))/(G**2+B*Alat2))
CCC        RMIX=0.5
CCC        B   =1.92
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, VG, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, RHO1, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
         DO 27 IG=1,NXYZ
   27    RHO2(IG)=VG(IG)+RMIX*(RHO1(IG)-VG(IG))
         DO 25 IG=2,NG
         JG=I2G(IG)
         RHO2(JG)=VG(JG)+RMIX*(RHO1(JG)-VG(JG))
     &           *G(4,IG)/(G(4,IG)+1.92D0)
   25    CONTINUE
         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, VG,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX,I FACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
         DO 37 IG=1,NXYZ
   37    VG(IG)=RHO2(IG)
      ENDIF
C *******************************  EXTRAPOLATION END
C
      IF( IOPT(1,2).EQ.0 .OR. IOPT(1,2).EQ.5 .OR. IOPT(1,2).EQ.11 )
     &              GO TO 1000
      IF( MOD(ITS,10).EQ.0 ) THEN
CTEMPIO          REWIND 21
CTEMPIO          WRITE(21) NG,(RHOG(I2G(I)),I=1,NG)
          CALL WFWRIT(       MXBND, MBLK, NUMK, NUMKQ, NBND, IOWF,
     &                 COEF, NG2Q, NG2, RHO1, RHO2           )
          REWIND 25
          WRITE(25) VINT
          REWIND 24
          WRITE(24) RHO
            CALL CLOCK(TIM)
 6012       FORMAT(23X,'****  FRPRMN:  ',F15.7,' SEC')
          WRITE(6,6012) TIM
C
      ENDIF
C
 1000 CONTINUE
      ICONV=1
      WRITE(6,6030)
 6030 FORMAT(//// '  ********* WARNING!! CONVERGENCE CRITERION IS'
     &  ' NOT MET *** '///)
C
      CALL CLOCK(TIM)
 6004 FORMAT(23X,'****  FRPRMN: ',F15.7,' SEC')
      WRITE(6,6004) TIM
C
 1999 CONTINUE
C
c *** Start G-space to R-space FFT conversion of each wavefunctions
      if ( iopt(2,1).eq.5 ) then
      do 1997 ik=1,numk
       do 1996 iblk=1,mblk
ccc      read(71,rec=iowf(iblk,ik))coef  
        if ( iblk.eq.mblk ) then
         nb=mod(nbnd-1,mxbnd )+1
        else
         nb=mxbnd
        end if
        ibi=mxbnd*(iblk-1)
        do 1995 ib=1,nb
         iband=ibi+ib
C
          DO JG=1,NXYZ
          RHO1(JG)=(0.D0,0.D0)
          ENDDO
*VDIR NODEP(RHO1)
          DO IG=1,NG2(ik)
          JG=J2G(IG,IK)
          RHO1(JG)=COEF(IG,IBAND,IK)
          ENDDO
C
         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c
          write(88)RHO1
 1995   continue
 1996  continue
 1997 continue
      endif
c *** Start orbital analysis
      if ( iopt(2,1).eq.4 ) then
      call clock(t0)
      write(6,*)'    Orbital analysis !!!  '
      do 1010 ik=1,numk
      write(6,*)
      write(6,*)'  -----------  '
      if ( ik.gt.3 ) then
      write(6,*)'  for the ',ik,'th k-point'
      else if ( ik.eq.1 ) then
      write(6,*)'  for the first k-point'
      else if ( ik.eq.2 ) then
      write(6,*)'  for the second k-point'
      else if ( ik.eq.3 ) then
      write(6,*)'  for the third k-point'
      end if
      if ( g2(4,1,ik).gt.1.d-08 ) then
      do 1009 ig=1,ng2(ik)
 1009 g2(4,ig,ik)=dsqrt(g2(4,ig,ik)) 
      else
      do 1008 ig=2,ng2(ik)
 1008 g2(4,ig,ik)=dsqrt(g2(4,ig,ik)) 
      end if
      do 1011 iblk=1,mblk
ccc      read(71,rec=iowf(iblk,ik))coef  
       if ( iblk.eq.mblk ) then
        nb=mod(nbnd-1,mxbnd )+1
       else
        nb=mxbnd
       end if
      ibi=mxbnd*(iblk-1)
      do 1452 ib=1,nb
      iband=ibi+ib
c ***  for special treatment
      ngg2=ng2(ik)/18
      call orbanly(iband,ik,coef(1,iband,ik),rho1,rho2,ng2q,
cc     &     ng2(ik),g2(1,1,ik),cl1,
     &     ngg2,g2(1,1,ik),cl1,
     &     tau,ntauq,numty,ntyq,ntype,tpiba,mxofl,omega)
 1452 continue
 1011 continue
      do 1007 ig=1,ng2(ik)
      g2(4,ig,ik)=g2(4,ig,ik)**2
 1007 continue
 1010 continue
      call clock(t1)
      write(6,*)' Orbital analysis took ',t1-t0,' seconds '  
      end if
C
         IF( NPFL .GT. 0 ) WRITE(6,6040) EF * 27.212D+00
 6040    FORMAT(//'    *****     EF = ',D18.10,' EV'/)
C
      WRITE(6,6032)
 6032 FORMAT(/8X,'            IB     EIG              CONV'
     &'          SIN(ROT)    OCC')
      DO 655 IK=1,NUMK
      WRITE(6,657) IK,(VECK(I,IK),I=1,3)
  657 FORMAT(/' K VECTOR ',I4,3F15.7,'  CARTESIAN')
CARE      DO 655 IB=NFL-15,NFL+15
      DO 655 IB=1,NBND
  655 WRITE(6,656) IB,(OUT(IB,IG,IK),IG=1,3),OCC(IB,IK)
  656 FORMAT(2X,' BAND (EV) ',I4,3E15.7,F8.3)
C
      REWIND 77
      WRITE(77,7100) ( (TAU(IK,ITAU),IK=1,3),ITAU, ITAU=1,NTAUQ)
 7100 FORMAT(( 3F16.7,7X,'TAU( ',I3,')' ))
c ****** Y. Miyamoto
      write(77,*)'  ---- in unit of lattice vectors ---- '
      do 878 itau=1,ntauq
      tau1=b1(1)*tau(1,itau)+b1(2)*tau(2,itau)+b1(3)*tau(3,itau)
      tau2=b2(1)*tau(1,itau)+b2(2)*tau(2,itau)+b2(3)*tau(3,itau)
      tau3=b3(1)*tau(1,itau)+b3(2)*tau(2,itau)+b3(3)*tau(3,itau)
      tau1=tau1/alat
      tau2=tau2/alat
      tau3=tau3/alat
      write(77,7110)tau1,tau2,tau3,itau
  878 continue
 7110 FORMAT(( 3F22.16,3X,'TAU( ',I3,')' ))
CTEMPIO      REWIND 21
CTEMPIO      WRITE(21) NG,(RHOG(I2G(I)),I=1,NG)
      CALL WFWRIT(       MXBND, MBLK, NUMK, NUMKQ, NBND, IOWF,
     &             COEF, NG2Q, NG2, RHO1, RHO2           )
C
C ****  FOR LOCAL DENSITY OF STATES
      IF( IOPT(10,1) .EQ. 1) THEN
CARE
C    ***  for quartz super cell near the gap
        NB1 = 67
        NB2 = 79
CARE END
        NB3 = NB2 - NB1 + 1
C
        REWIND 13
        WRITE(13) NUMK, NB3
C
        DO 900 IK = 1, NUMK
        WRITE(13) IK, WGT(IK), NG2(IK), 
     &           ( J2G(IG,IK), IG = 1, NG2(IK) )
C
          DO 910 IBLK = 1, MBLK
cc          READ(71,REC=IOWF(IBLK,IK)) COEF
            IF( IBLK .EQ. MBLK ) THEN
              NB = MOD(NBND-1,MXBND) + 1
            ELSE
              NB = MXBND
            END IF
          IBI = MXBND * (IBLK-1)
            DO 915 IB = 1, NB
            IBAND = IBI + IB
            IF( IBAND .LT. NB1 .OR. IBAND .GT. NB2 ) GO TO 915
C
            WRITE(13) OUT(IBAND,1,IK), 
     &               ( COEF(IG,IB,IK), IG = 1, NG2(IK) )
C
  915       CONTINUE
  910     CONTINUE
  900   CONTINUE      
      END IF
C
C ***        END OF LDOS PREPARATION
C
      REWIND 25
      WRITE(25) VINT
      REWIND 24
      WRITE(24)  RHO
C
C   ***
      RETURN
      END
C
      SUBROUTINE WFWRIT(       MXBND, MBLK, NUMK, NUMKQ, NBND, IOWF,
     &                   COEF, NG2Q, NG2, RHO1, RHO2           )
      COMMON/COMOPT/IOPT(10,5)
      DIMENSION  NG2(NUMK ), IOWF(MBLK,NUMKQ)
c      COMPLEX*16 COEF(NG2Q,MXBND)
      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ)
c      REAL*4     RHO1(*), RHO2(*)
      REAL*8     RHO1(*), RHO2(*)
C
      IF(IOPT(4,2).EQ.0) THEN
         IWF=23
      ELSE
         IWF=IOPT(4,2)
      ENDIF
C
      REWIND IWF
C
      DO 450 IK = 1, NUMK
      DO 451 IBLK = 1, MBLK
cc      READ(71,REC=IOWF(IBLK,IK)) COEF
        IF(IBLK.EQ.MBLK) THEN
          NB = MOD(NBND-1,MXBND) + 1
        ELSE
          NB = MXBND
        END IF
      IBI = MXBND * ( IBLK-1 )
          DO 452 IB = 1, NB
          IBAND = IBI + IB
            DO 455 IG = 1, NG2(IK)
            RHO1(IG) = REAL( COEF(IG,IB,IK) )
  455       RHO2(IG) = IMAG( COEF(IG,IB,IK) )
  452     WRITE(IWF) ( RHO1(IG), RHO2(IG),  IG = 1, NG2(IK) )
  451 CONTINUE
  450 CONTINUE
C
      RETURN
      END
C--------------------------------------------------------
C
      SUBROUTINE
     &      DISPER( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NG, NGQ,
     &              NG2, NG2Q, NBNDQ, NBND,
     &              COEF, DCOEF, CWK1, CWK2, CL1, CL2, CL3, HD, HDO,
c     &              YLM, G, G2, RHO1, RHO2, RHO3, OMEGA, TPIBA, VG,
     &   YLM, G, G2,GDUMP,RHO1, RHO2, RHO3, VGA,Vchg, OMEGA, TPIBA, VG,
     &              I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF,
     &              NCRQ, ZV, RC0, COR, NUMC,
     &  NTAUQ, NTYQ, NTYPE, LREQ, GCUT2, VECK, EE,EE2,EE3,EE4,
     &              TAU, NUMTY, NIDN, ALPPP, BETAPP, IOVP,
     &              WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &              LX1, LX2, LY1, LY2, LZ1, LZ2, NUMKQ2, MXOFL
     &  ,sig,x0,x1,work1,work20,GG,J2GG,NGNL )
C
      IMPLICIT REAL*8(A-H,O-Z)
c      COMPLEX*16 CL1(NG2Q),CL2(NG2Q),CL3(NG2Q)
c      COMPLEX*16 HD(NG2Q),HDO(NG2Q)
c      COMPLEX*16 CL1(NG2Q,MXBND),CL2(NG2Q,MXBND),CL3(NG2Q,MXBND)
      COMPLEX*16 CL1(NG2Q,10),CL2(NG2Q,MXBND),CL3(NG2Q,MXBND)
      COMPLEX*16 HD(NG2Q,MXBND),HDO(NG2Q,MXBND)
      COMPLEX*16 CTEMP
      DIMENSION EE(NBNDQ),ee2(nbndq),ee3(nbndq),ee4(nbndq)
c      DIMENSION ALPPP(2,NTYQ),BETAPP(2,NTYQ),IOVP(2,NTYQ),
c      DIMENSION ALPPP(3,NTYQ),BETAPP(3,NTYQ),IOVP(2,NTYQ),
      DIMENSION ALPPP(4,NTYQ),BETAPP(4,NTYQ),IOVP(2,NTYQ),
     &          ZV(NTYQ),RC0(NCRQ,NTYQ),
     &          COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ)
C
c      REAL*8 YLM(NG2Q,4),OUT(NBNDQ,3),VECK(3)
c      REAL*8 YLM(NG2Q,9),OUT(NBNDQ,3),VECK(3)
      REAL*8 YLM(NG2Q,16),OUT(NBNDQ,3),VECK(3)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),
     &           COEF(NG2Q,MXBND),DCOEF(NG2Q,MXBND),
     &           CWK1(NG2Q,MXBND), CWK2(NG2Q,MXBND),
c     &           VG(NXYZ),WORK2(NG2Q,3)
c     &           VG(NXYZ),WORK2(NG2Q,5)
     &           VG(NXYZ),WORK2(NG2Q,7)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      DIMENSION I2G(NGQ),J2G(NG2Q)
      DIMENSION G(4,NGQ),G2(4,NG2Q),GDUMP(NG2Q)
      DIMENSION GG(4,NGQ),J2GG(NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ2)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),IOWF(MBLK,NUMKQ2)
c      DIMENSION VPJ(NG2Q,3,3,NTYQ),VPP(3,3,NTYQ),IOWF(MBLK,NUMKQ2)
      DIMENSION VPJ(NG2Q,3,4,NTYQ),VPP(3,4,NTYQ),IOWF(MBLK,NUMKQ2)
c *****
      dimension VGA(NG2Q,NTYQ),Vchg(NG2Q,NTYQ)
      dimension NGNL(NTYQ)
ccc
c     work area for orthogonization
      complex*16  sig(mxbnd,mxbnd),x0(mxbnd,mxbnd),
     &    x1(mxbnd,mxbnd),work1(mxbnd,mxbnd),work20(mxbnd,mxbnd)
C 
C
      DATA EPS/1.D-10/
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
C      WRITE(6,'('' VECK_DBG '',3F15.7)') (VECK(I),I=1,3)
C     WRITE(6,*) ' ----------------- K-VECTOR ----------------- '
C     WRITE(6,'(2X,3F15.7)') (VECK(I),I=1,3)
C
C     MAKE G2VECTOR CORRESPONDING TO VECK
C
      CALL G2VECT(NGQ,NG,NG2Q,NG2,VECK,G,G2,J2G,I2G,TPIBA,GCUT2
     &           ,GG,J2GG,RHO3,GDUMP)
C
      NUMK=1
      NUMKQ=1
      CALL PRENON( 2, NG2Q, NG2, TPIBA, NGQ, NG, G,
c     &             NUMKQ, NUMK, G2, RHO2, RHO3, NUMTY, NTYQ, NTYPE,
     &    NUMKQ, NUMK, G2, RHO2,VGA,Vchg,RHO3, NUMTY, NTYQ, NTYPE,
     &             VPJ, VPP, NCRQ, ZV, RC0, COR, NUMC, ALPPP,
     &             BETAPP, IOVP, MXOFL,ADUMP,ATEMP,NGNL       )
C
       DO 401 IBLK = 1, MBLK
         IF( IBLK.EQ.MBLK ) THEN
           NB = MOD( NBND-1, MXBND ) + 1
         ELSE
           NB = MXBND
         END IF
         IBI = MXBND * (IBLK - 1)
         DO 402 IB = 1, NB
             DO 410 IG = 1, NG2
  410        COEF(IG,IB) = ( 0.0D+00, 0.0D+00 )
         IBAND = IBI + IB
  402    COEF(IBAND,IB) = ( 1.0D+00, 0.0D+00 )
c  401  WRITE(71,REC=IOWF(IBLK,1)) COEF
  401  CONTINUE
C
       DO 600 IBLK = 1, MBLK
          IF(IBLK.LT.MBLK) THEN
            MBN = MXBND
          ELSE
            MBN = MOD( NBND-1, MXBND ) + 1
          END IF
       IBI = MXBND * (IBLK-1)
cc       READ(71,REC=IOWF(IBLK,1)) COEF
         DO 602 IBND = 1, MBN
         IB = IBI + IBND
           DO 605 JBLK = 1, IBLK
             IF(JBLK.LT.MBLK) THEN
               JMBN = MXBND
             ELSE
               JMBN = MOD( NBND-1, MXBND ) + 1
             END IF
           JBI = MXBND * (JBLK-1)
             IF(JBLK.NE.IBLK) THEN
               IF(IBLK.EQ.2 .AND. IBND.GT.1) THEN
                 CONTINUE
               ELSE
cc                 READ(71,REC=IOWF(JBLK,1)) DCOEF
               END IF
             END IF
             DO 612 JBND = 1, JMBN
             JB = JBI + JBND
                              IF(JB.GE.IB) GO TO 605
             CTEMP = (0.0D+00,0.0D+00)
             IF( JBLK.LT.IBLK) THEN
               DO 638 IG = 1, NG2
  638          CTEMP = CTEMP + DCONJG(DCOEF(IG,JBND)) * COEF(IG,IBND)
               DO 640 IG = 1, NG2
  640          COEF(IG,IBND) = COEF(IG,IBND)
     &                           - CTEMP * DCOEF(IG,JBND)
             ELSE
               DO 618 IG = 1, NG2
  618          CTEMP = CTEMP + DCONJG(COEF(IG,JBND)) * COEF(IG,IBND)
               DO 620 IG = 1, NG2
  620          COEF(IG,IBND) = COEF(IG,IBND)
     &                              - CTEMP * COEF(IG,JBND)
             END IF
  612        CONTINUE
  605      CONTINUE
           TEMP = 0.0D+00
           DO 622 IG = 1, NG2
  622      TEMP = TEMP + DBLE(DCONJG(COEF(IG,IBND))*COEF(IG,IBND))
           TEMP = 1.0D+00/SQRT(TEMP)
           DO 625 IG = 1, NG2
  625      COEF(IG,IBND) = TEMP * COEF(IG,IBND)
  602    CONTINUE
cc        WRITE(71,REC=IOWF(IBLK,1)) COEF
  600  CONTINUE
C
C
      ITCF=50
      CALL SDDIAG( 0.1D-08, ITCF, NRX, NRY, NRZ, NXYZ, NG2, NG2Q,
c     &             NBNDQ, NBND, COEF, DCOEF, CWK1, CWK2, CL1, CL2,
     &             NBNDQ, NBND, COEF, DCOEF, CWK1, CWK2,  CL2,
     &    CL3, HD, HDO, YLM, G2,GDUMP, RHO1, RHO2, RHO3,
     &             TPIBA, VG, J2G, WORK2, OUT, VPJ, VPP, IOWF,
     &             IOVP, MXBND, MBLK, OMEGA, NTAUQ, NTYQ, NTYPE,
     &   LREQ,TAU,NUMTY,NIDN,EE,EE2,EE3,EE4,WSAVEX, WSAVEY, WSAVEZ,
     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
     &             MXOFL,sig,x0,x1,work1,work20,0,NGNL)
C
      RETURN
      END
C***************************************************************
C     INITIALIZE CHRAGE DENSITY AND WAVEFUNCTION
C                     OSAMU SUGINO (1990-12-03)
C***************************************************************
      SUBROUTINE
     &     INITPW( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NGQ, NG,
     &             NG2Q, NG2, NBNDQ, NBND, NUMK,NUMKQ,
     &             COEF, DCOEF, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
     &             OMEGA, ZVAL, IOWF, RHO, RHOG, RHO1, RHO2, RHO3,
     &             WGT, OCC, NTOT, S, NFL, NPFL, NKMESH, NEXPND,
     &             RCOSIN, NSY, VINT, WSAVEX, WSAVEY, WSAVEZ, IFACX,
     &             IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
     &             INDX,GG,J2GG,GDUMP,fdump )
      IMPLICIT REAL*8 (A-H,O-Z)
C *******   TEMP   CARE!!    *************
      PARAMETER (IRLATQ=144,NAS=144)
C ****************************************
c      COMPLEX*16 COEF(NG2Q,MXBND), DCOEF(NG2Q,MXBND),
      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ), DCOEF(NG2Q,MXBND),
     &           RHOG(NXYZ),RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ)
      DIMENSION G(4,NGQ),G2(4,NG2Q,NUMKQ),I2G(NGQ),J2G(NG2Q,NUMKQ),
     &          VECK(3,NUMKQ),NG2(NUMKQ),RHO(NXYZ),IOWF(MBLK,NUMKQ),
     &          WGT(NUMKQ),OCC(NBNDQ,NUMKQ)
      DIMENSION GG(4,NGQ),INDX(NG2Q),J2GG(NG2Q),GDUMP(NG2Q,NUMKQ)
     &         ,fdump(NG2Q)
      INTEGER*4 S(3,3,48)
C     WORK ARRYS FOR FOURIER TRANSFORM
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION RCOSIN(NAS,IRLATQ), VINT(NBNDQ,IRLATQ), NSY(IRLATQ)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      COMPLEX*16 CTEMP
      COMMON/COMOPT/IOPT(10,5)
      COMMON/COMINI/MAXG2
      COMMON/AVEC/A1(3),A2(3),A3(3),B1(3),B2(3),B3(3), COVA, ALAT
      COMMON/SMOOTH/ADUMP
C
      CALL PREFFT(NRX,NRY,NRZ,NXYZ,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA*TPIBA
      EKIN=0.D0
      SUM=0.D0
      DO 10 IK=1,NUMK
      IG2=1
      DO 1 I=1,NG
      IF(IG2.GT.NG2Q) GOTO 100
c      G2(1,IG2,IK)=VECK(1,IK)+G(1,I)
c      G2(2,IG2,IK)=VECK(2,IK)+G(2,I)
c      G2(3,IG2,IK)=VECK(3,IK)+G(3,I)
c      G2(4,IG2,IK)=G2(1,IG2,IK)**2 + G2(2,IG2,IK)**2 + G2(3,IG2,IK)**2
c      GDIF= G2(4,IG2,IK)*TPIBA2
      GG(1,IG2)=VECK(1,IK)+G(1,I)
      GG(2,IG2)=VECK(2,IK)+G(2,I)
      GG(3,IG2)=VECK(3,IK)+G(3,I)
      GG(4,IG2)=GG(1,IG2)**2 + GG(2,IG2)**2 + GG(3,IG2)**2
      GDIF= GG(4,IG2)*TPIBA2
ccc      IF(GDIF.GT.GCUT2) GOTO 1  !!! comment out for full grids
c      J2G(IG2,IK)=I2G(I)
      J2GG(IG2)=I2G(I)
      IG2=IG2+1
    1 CONTINUE
      IG2=IG2-1
      CALL INDEXX(IG2,GG,INDX)
      DO IG=1,IG2
      G2(1,IG,IK)=GG(1,INDX(IG))
      G2(2,IG,IK)=GG(2,INDX(IG))
      G2(3,IG,IK)=GG(3,INDX(IG))
      G2(4,IG,IK)=GG(4,INDX(IG))
      J2G(IG,IK)=J2GG(INDX(IG))
      ENDDO
      GFAC=GCUT2/TPIBA2
      DO IG=1,IG2
      IF ( G2(4,IG,IK).LE.GFAC ) THEN
      GDUMP(IG,IK)=G2(4,IG,IK)
      ELSE
      GDUMP(IG,IK)=GFAC
      ENDIF
      ENDDO
      WRITE(6,200) IK, GCUT2,IG2
  200 FORMAT(' PLANE WAVE BASIS SET FOR K = ',I3,': GCUT2= ',F9.3,' RY'
     &,'  NG2= ',I10)
      NG2(IK)=IG2
C
c *** Following argolisms is too slow for FFT grids!
c      write(6,*)' sorting has started !'
c      DO 20 IG=1,NG2(IK)
c        DO 30 JG=IG,NG2(IK)
c          IF( G2(4,JG,IK).GE.G2(4,IG,IK) ) GOTO 30
c            DO 15 IR=1,4
c              Q=G2(IR,IG,IK)
c              G2(IR,IG,IK)=G2(IR,JG,IK)
c              G2(IR,JG,IK)=Q
c   15       CONTINUE
c            IR=J2G(IG,IK)
c            J2G(IG,IK)=J2G(JG,IK)
c            J2G(JG,IK)=IR
c   30   CONTINUE
c   20 CONTINUE
c      write(6,*)' sorting has finished !'
c
   10 CONTINUE   ! end of k-loop
C
      IF(IOPT(4,1).EQ.0) THEN
         DO 400 IK=1,NUMK
         DO 401 IBLK = 1, MBLK
           IF( IBLK.EQ.MBLK ) THEN
             NB = MOD( NBND-1, MXBND ) + 1
           ELSE
             NB = MXBND
           END IF
         IBI = MXBND * (IBLK - 1)
           DO 402 IB = 1, NB
               DO 410 IG = 1, NG2(IK)
  410          COEF(IG,IB,IK) = ( 0.0D+00, 0.0D+00 )
               IBAND = IBI + IB
  402      COEF(IBAND,IB,IK) = ( 1.0D+00, 0.0D+00 )
Care
Care       write(6,*) 'ik iblk iowf:',ik, iblk, iowf(iblk,ik)
Care
c  401    WRITE(71,REC=IOWF(IBLK,IK)) COEF
  401    continue
  400    CONTINUE
      ELSEIF (IOPT(4,1).eq.2) then
       write(6,*)' Now calling WFFFT !! '
         call WFFFT(NUMK,NUMKQ,MXBND,NBND,NG2,NG2Q,
     &   NRX,NRY,NRZ,NXYZ,COEF,RHO1,RHO2,
     &   WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &   LX1, LX2, LY1, LY2, LZ1, LZ2 ,j2g           )
      ELSE
C ***
         CALL WFREAD(       MXBND, MBLK, NUMK, NUMKQ, NBND, COEF, NG2,
     &                MAXG2, IOWF, NG2Q, RHO1, RHO2              )
C
      DO 5000 IK=1,NUMK
         DO 500 IBLK = 1, MBLK
            IF(IBLK.LT.MBLK) THEN
              MBN = MXBND
            ELSE
              MBN = MOD( NBND-1, MXBND ) + 1
            END IF
cccc         READ(71,REC=IOWF(IBLK,IK)) COEF
            DO 502 IBND = 1, MBN
              TEMP = 0.0D+00
              DO 504 IG = 1, NG2(IK)
  504   TEMP = TEMP+DBLE(DCONJG(COEF(IG,IBND,IK))*COEF(IG,IBND,IK))
              TEMP = 1.0D+00/SQRT(TEMP)
              DO 506 IG = 1, NG2(IK)
  506         COEF(IG,IBND,IK) = COEF(IG,IBND,IK) * TEMP
  502       CONTINUE
c  500    WRITE(71,REC=IOWF(IBLK,IK)) COEF
  500    CONTINUE
C
         DO 600 IBLK = 1, MBLK
            IF(IBLK.LT.MBLK) THEN
              MBN = MXBND
            ELSE
              MBN = MOD( NBND-1, MXBND ) + 1
            END IF
         IBI = MXBND * (IBLK-1)
ccc         READ(71,REC=IOWF(IBLK,IK)) COEF
           DO 602 IBND = 1, MBN
           IB = IBI + IBND
             DO 605 JBLK = 1, IBLK
               IF(JBLK.LT.MBLK) THEN
                 JMBN = MXBND
               ELSE
                 JMBN = MOD( NBND-1, MXBND ) + 1
               END IF
             JBI = MXBND * (JBLK-1)
               IF(JBLK.NE.IBLK) THEN
                 IF(IBLK.EQ.2 .AND. IBND.GT.1) THEN
                   CONTINUE
                 ELSE
ccc                   READ(71,REC=IOWF(JBLK,IK)) DCOEF
                 END IF
               END IF
               DO 612 JBND = 1, JMBN
               JB = JBI + JBND
                              IF(JB.GE.IB) GO TO 605
               CTEMP = (0.0D+00,0.0D+00)
               IF( JBLK.LT.IBLK) THEN
                 DO 638 IG = 1, NG2(IK)
  638    CTEMP = CTEMP + DCONJG(DCOEF(IG,JBND)) * COEF(IG,IBND,IK)
                 DO 640 IG = 1, NG2(IK)
  640            COEF(IG,IBND,IK) = COEF(IG,IBND,IK)
     &                              - CTEMP * DCOEF(IG,JBND)
               ELSE
                 DO 618 IG = 1, NG2(IK)
  618    CTEMP = CTEMP + DCONJG(COEF(IG,JBND,IK)) * COEF(IG,IBND,IK)
                 DO 620 IG = 1, NG2(IK)
  620           COEF(IG,IBND,IK) = COEF(IG,IBND,IK)
     &                              - CTEMP * COEF(IG,JBND,IK)
               END IF
  612          CONTINUE
  605        CONTINUE
             TEMP = 0.0D+00
             DO 622 IG = 1, NG2(IK)
  622   TEMP = TEMP + DBLE(DCONJG(COEF(IG,IBND,IK))*COEF(IG,IBND,IK))
             TEMP = 1.0D+00/SQRT(TEMP)
             DO 625 IG = 1, NG2(IK)
  625        COEF(IG,IBND,IK) = TEMP * COEF(IG,IBND,IK)
  602      CONTINUE
cccc         WRITE(71,REC=IOWF(IBLK,IK)) COEF
  600    CONTINUE
 5000 CONTINUE
C ***
      ENDIF
      IF(IOPT(3,1).EQ.0) THEN  ! charge is made internally
         RHO0=ZVAL/OMEGA
         DO 460 I=1,NXYZ
  460    RHO(I)=RHO0
         DO 462 IG=1,NXYZ
  462    RHOG(IG)=DCMPLX(RHO(IG),0.D0)
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, RHOG, RHO1,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
c *** Smoothing !!
c         adump4=4*adump
c         do ig=2,nxyz
c         jg=i2g(ig)
c         rhog(jg)=rhog(jg)*fdump(ig)
c         enddo
c         DO IG=1,NXYZ
c         RHO2(IG)=RHOG(IG)
c         ENDDO
c         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
c     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
c         DO IG=1,NXYZ
c         RHO(IG)=DBLE(RHO2(IG))
c         ENDDO
c *** Smoothing !! : END
      ELSEIF(IOPT(3,1).EQ.1) THEN ! charge is read from file
         REWIND 20
         READ(20) RHO
         DO 464 IG=1,NXYZ
  464    RHOG(IG)=DCMPLX(RHO(IG),0.D0)
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, RHOG, RHO1,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** Smoothing !!
c         adump4=4*adump
c         do ig=2,nxyz
c         jg=i2g(ig)
c         rhog(jg)=rhog(jg)*fdump(ig)
c         enddo
c         DO IG=1,NXYZ
c         RHO2(IG)=RHOG(IG)
c         ENDDO
c         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
c     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
c         DO IG=1,NXYZ
c         RHO(IG)=DBLE(RHO2(IG))
c         ENDDO
c *** Smoothing !! : END
      ELSEIF(IOPT(3,1).EQ.2) THEN ! charge is read from file (continue SCF)
         DO 467 I=1,NXYZ
  467    RHOG(I)=(0.D0,0.D0)
         REWIND 20
         READ(20) IDUM
         REWIND 20
         IF(IDUM.GT.NG) THEN
            READ(20) IDUM,(RHOG(I2G(I)),I=1,NG)
         ELSE
            READ(20) IDUM,(RHOG(I2G(I)),I=1,IDUM)
         ENDIF
c ***  check
         write(6,*)
         write(6,*)' check: charge is read from file 20'
         write(6,*)' ng, idum = ',ng,idum
         write(6,*)
c *** Smoothing !!
c         adump4=4*adump
c         do ig=2,nxyz
c         jg=i2g(ig)
c         rhog(jg)=rhog(jg)*fdump(ig)
c         enddo
c *** Smoothing !! : END
c ***  check end
         DO 465 IG=1,NXYZ
  465    RHO2(IG)=RHOG(IG)
         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
         DO 466 IG=1,NXYZ
  466    RHO(IG)=DBLE(RHO2(IG))
      ELSEIF(IOPT(3,1).EQ.3) THEN ! charge is made from pseudoWF
         DO 701 I=1,NXYZ
  701    RHO(I)=0.D0
         REWIND 25
         READ(25) VINT
C
C           WRITE(6,9004) (( VINT(I,J), I=NFL,NBNDQ), J=1,NEXPND)
C9004       FORMAT(//10X,' INITPW: VINT (NFL TO NBNDQ) ='/(20X,4D12.4))
C
         NBND1=NFL+1
         DO 630 IK = 1, NUMK
         CALL RHOOFK( MXBND, MBLK, NRX, NRY, NRZ, NXYZ,
     &                NG2(IK), NG2Q, NBNDQ, NBND, NFL,
     &    RHO, RHO1, RHO2, RHO3, COEF(1,1,IK), WGT(IK),
     &                J2G(1,IK), IOWF(1,IK), OCC(1,IK),
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
  630   CONTINUE
C *****
                     IF( NPFL .GT. 0 ) THEN
C *****
        DO 634 IK=1,NUMK
          CALL SUMCHR( MXBND, MBLK, NFL, NPFL, NRX, NRY, NRZ, NXYZ,
     &                 RHO, RHO1, RHO2, RHO3, IOWF(1,IK),
     &                 NG2Q, NG2(IK), J2G(1,IK), COEF(1,1,IK),
     &                 NKMESH, NEXPND, RCOSIN, NSY, IK, NBNDQ,
     &                 NBND, VINT, OMEGA, WSAVEX, WSAVEY, WSAVEZ,
     &                 IFACX, IFACY, IFACZ,
     &                 LX1, LX2, LY1, LY2, LZ1, LZ2                )
  634   CONTINUE
C
C *****
                     END IF
C *****
        CALL RHOGET( NRX, NRY, NRZ, NXYZ, RHO, RHO1, RHOG, NTOT, S,
     &               OMEGA, ZVAL,RHO2,I2G,G, WSAVEX, WSAVEY, WSAVEZ,
     &               IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2,
     &               LZ1, LZ2                                     )
C
      ENDIF
      RETURN
  100 WRITE(6,110) GCUT2
  110 FORMAT(' GCUT2=',1PE12.4,' IS TOO BIG. STOPPING')
      WRITE(6,*) ' TPIBA ',TPIBA,I,NG2Q
      STOP
      END
C
      SUBROUTINE WFFFT(NUMK,NUMKQ,MXBND,NBND,NG2,NG2Q,
     &   NRX,NRY,NRZ,NXYZ,COEF,RHO1,RHO2,
     &   WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &   LX1, LX2, LY1, LY2, LZ1, LZ2 ,j2g           )
      implicit double precision(a-h,o-z)
      complex*16 coef(ng2q,mxbnd,numkq)
      complex*16 rho1(nxyz),rho2(nxyz)
C     WORK ARRYS FOR FOURIER TRANSFORM
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      dimension ng2(numkq),j2g(ng2q,numkq)
      do 1 ik=1,numk
       do 2 ib=1,mxbnd
       read(88)( rho1(ir),ir=1,nxyz )
         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, RHO1, RHO2,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
       do 3 ig=1,ng2(ik)
        j2=j2g(ig,ik)
   3    coef(ig,ib,ik)=rho1(j2)
   2   continue 
   1  continue
      end
C
      SUBROUTINE WFREAD(
     &                   MXBND, MBLK, NUMK, NUMKQ, NBND, COEF, NG2,
     &                   MAXG2, IOWF, NG2Q, RHO1, RHO2           )
c      REAL*4     RHO1(*), RHO2(*)
      REAL*8     RHO1(*), RHO2(*)
      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ)
      DIMENSION IOWF(MBLK,NUMKQ),NG2(NUMKQ)
C
      REWIND 22
C
      DO 450 IK = 1, NUMK
        DO 451 IBLK = 1, MBLK
          IF(IBLK.EQ.MBLK) THEN
            NB = MOD(NBND-1,MXBND) + 1
          ELSE
            NB = MXBND
          END IF
        IBI = MXBND * (IBLK-1)
          DO 452 IB = 1, NB
          IBAND = IBI + IB
            IF(MAXG2.EQ.0) THEN
              READ(22) ( RHO1(IG), RHO2(IG), IG=1,NG2(IK) )
              DO 100 IG=1,NG2(IK)
  100         COEF(IG,IB,IK) = DCMPLX( DBLE(RHO1(IG)), DBLE(RHO2(IG)) )
            ELSE
              DO 462 IG=1,NG2(IK)
  462         COEF(IG,IB,IK)=(0.D0,0.D0)
              READ(22) ( RHO1(IG), RHO2(IG), IG=1,MAXG2)
              DO 110 IG=1,MAXG2
  110         COEF(IG,IB,IK) = DCMPLX( DBLE(RHO1(IG)), DBLE(RHO2(IG))  )
            ENDIF
  452     CONTINUE
c  451   WRITE(71,REC=IOWF(IBLK,IK)) COEF
  451   CONTINUE
  450 CONTINUE
C
      RETURN
      END
C***********************************************************
      SUBROUTINE GETYLM(NG2Q,NG2,G2K,RHOA,YLM,TPIBA)
      IMPLICIT REAL*8(A-H,O-Z)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,4),RHOA(NG2Q)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,9),RHOA(NG2Q)
      DIMENSION G2K(4,NG2Q),YLM(NG2Q,16),RHOA(NG2Q)
C                                      __
C
      PI=4.D0*ATAN(1.D0)
      F00=SQRT( 1.D0 / ( 4.D0*PI) )
      F10=SQRT( 3.D0 / ( 4.D0*PI) )
      F11=SQRT( 3.D0 / ( 8.D0*PI) )
      F20=SQRT( 5.d0 / (16.d0*PI) )
      F22=SQRT(15.d0 / (32.d0*PI) )
      F21=SQRT(15.d0 / ( 8.d0*PI) )
      F30=SQRT( 7.D0 / (16.d0*PI) )
      F31=SQRT(21.d0 / (64.D0*PI) )
      F32=SQRT(105.D0/ (32.D0*PI) )
      F33=SQRT(35.D0 / (64.D0*PI) )
      IF(RHOA(1).EQ.0.D0) THEN
         YLM(1,1)=F00
         YLM(1,2)=F10
         YLM(1,3)=0.D0
         YLM(1,4)=0.D0
         YLM(1,5)=F20*2.D0
         YLM(1,6)=0.D0
         YLM(1,7)=0.D0
         YLM(1,8)=0.D0
         YLM(1,9)=0.D0
         YLM(1,10)=F30*2.D0
         YLM(1,11)=0.D0
         YLM(1,12)=0.D0
         YLM(1,13)=0.D0
         YLM(1,14)=0.D0
         YLM(1,15)=0.D0
         YLM(1,16)=0.D0
         ISTA=2
      ELSE
         ISTA=1
      ENDIF
      DO 10 IG=ISTA,NG2
      R=RHOA(IG)/TPIBA
      R2=R*R
      R3=R*R2
      YLM(IG,1)=F00
      YLM(IG,2)=F10*G2K(3,IG)/R
      YLM(IG,3)=F11*G2K(1,IG)/R
      YLM(IG,4)=F11*G2K(2,IG)/R
      YLM(IG,5)=F20*( (3.D0*G2K(3,IG)**2 )/R2 - 1.D0 )
      YLM(IG,6)=F22*( G2K(1,IG)**2 - G2K(2,IG)**2 )/R2
      YLM(IG,7)=F21*( G2K(1,IG)*G2K(2,IG) )/R2
      YLM(IG,8)=F21*( G2K(3,IG)*G2K(1,IG) )/R2
      YLM(IG,9)=F21*( G2K(2,IG)*G2K(3,IG) )/R2
      YLM(IG,10)=F30*( 5*G2K(3,IG)**2/R2 -3.D0 )*G2K(3,IG) /R
      YLM(IG,11)=F33*G2K(1,IG)*( G2K(1,IG)**2 -3*G2K(2,IG)**2 ) /R3
      YLM(IG,12)=F33*G2K(2,IG)*( 3*G2K(1,IG)**2 -G2K(2,IG)**2 ) /R3
      YLM(IG,13)=F32*G2K(3,IG)*( G2K(1,IG)**2 -G2K(2,IG)**2 ) /R3
      YLM(IG,14)=F32*2*G2K(1,IG)*G2K(2,IG)*G2K(3,IG) /R3
      YLM(IG,15)=F31*G2K(1,IG)*( 5*G2K(3,IG)**2 -R2 ) /R3
      YLM(IG,16)=F31*G2K(2,IG)*( 5*G2K(3,IG)**2 -R2 ) /R3
   10 CONTINUE
c *** temp check
c      write(6,*)' in GETYLM check for RHOA'
c      write(6,*)(RHOA(IG),IG=1,100,10)
c      write(6,*)' in GETYLM check for G2K'
c      write(6,*)(G2K(2,IG),IG=1,100,10)
c      write(6,*)' in GETYLM check for YLM -4'
c      write(6,*)(YLM(IG,4),IG=1,100,10)
c      write(6,*)' in GETYLM check for YLM -5'
c      write(6,*)(YLM(IG,5),IG=1,100,10)
c      write(6,*)' in GETYLM check for YLM -6'
c      write(6,*)(YLM(IG,6),IG=1,100,10)
c *** temp check: end
      RETURN
      END
C****************************************************************
      SUBROUTINE SEPPOT( NG2Q, NG2, NBND, G2K, VPJ, VPP,
c     &   YLM, EXTAU, WORK1, WORK2, WORK3, WORK4,WORK5,COEF, DCOEF,
     &   YLM, EXTAU, WORK1, WORK2, WORK3, WORK4,WORK5,WORK6,WORK7,
     &   COEF, DCOEF,
     &                   TPIBA, IOVP, OMEGA, NTAUQ, NTYQ, LREQ,
     &                   TAU, NTYPE, NUMTY, NIDN, MXOFL,iopt,NGNL )
C
C               PARTITIONED POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8(A-H,O-Z)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,4)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,9)
      DIMENSION G2K(4,NG2Q),YLM(NG2Q,16)
      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,NBND),
     &    WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),WORK4(NG2Q),WORK5(NG2Q)
     &   ,WORK6(NG2Q),WORK7(NG2Q)
     &   ,EXTAU(NG2Q)
      COMPLEX*16 Y00,Y11,Y12,Y13
     &          ,Y21,Y22,Y23,Y24,Y25,Y31,Y32,Y33,Y34,Y35,Y36,Y37
     &          ,CT1,CT2,CT3,CT4,CT5,CT6,CT7
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
c     &          VPJ(NG2Q,3),VPP(3),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &    VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &    VPJ(NG2Q,3,3,NTYQ),VPP(3,3,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
     &    VPJ(NG2Q,3,4,NTYQ),VPP(3,4,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
      dimension NGNL(NTYQ)
      PARAMETER(NTYQ2=4)
c      COMMON/SAITO2/IBUN(2,NTYQ2)
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
CC      CALL CLOCK(TIM1)
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      FPISQ=FPI**2
C
CCCC  LMAX=LREQ-1
C
      DO 10 ITY=1,NTYPE
C ****
            IF(NUMTY(ITY).LE.0) GOTO 10
C ****
      NATM=ABS(NUMTY(ITY))
      LMAX = MXOFL(ITY)
C
      DO 20 IATM=1,NATM
      ITAU=NIDN(IATM,ITY)
c        DO 22 IG=1,NG2
        DO 22 IG=1,NGNL(ITY)
        TEMP=TPIBA*(G2K(1,IG)*TAU(1,ITAU)+G2K(2,IG)*TAU(2,ITAU)
     &             +G2K(3,IG)*TAU(3,ITAU))
        EXTAU(IG)=DCMPLX(COS(TEMP),SIN(TEMP))
   22   CONTINUE
c *** temp check
c      write(6,*)' sub SEPPOT:check in making EXTAU'
c      write(6,*)' G2K - 3 '
c      write(6,*)(G2K(3,IG),IG=1,100,10)
c      write(6,*)' EXYAU'
c      write(6,*)(EXTAU(IG),IG=1,100,10)
c *** temp check end
C
      DO 30 LI=1,LMAX
      L=LI-1
ccc      READ(82,REC=IOVP(LI,ITY)) VPP, VPJ
C
      IF(L.EQ.0.AND.IBUN(1,ITY).NE.1) THEN
C             NO PARTITIONING
c         DO 50 IG=1,NG2
         DO 50 IG=1,NGNL(ITY)
         Y00=DCMPLX(YLM(IG,1),0.D0)
   50    WORK1(IG)=Y00*EXTAU(IG)*VPJ(IG,1,LI,ITY)
         DO 52 IB=1,NBND
            CT1=(0.D0,0.D0)
c            DO 54 IG=1,NG2
            DO 54 IG=1,NGNL(ITY)
   54       CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
c            DO 56 IG=1,NG2
            DO 56 IG=1,NGNL(ITY)
   56       DCOEF(IG,IB)=DCOEF(IG,IB)+CT1*DCONJG(WORK1(IG))
   52    CONTINUE
      ELSEIF(L.EQ.0) THEN
C             PARTITIONING
         DO 1200 IP=2,3
c         DO 1050 IG=1,NG2
         DO 1050 IG=1,NGNL(ITY)
           Y00=DCMPLX(YLM(IG,1),0.D0)
 1050      WORK1(IG)=Y00*EXTAU(IG)*VPJ(IG,IP,LI,ITY)
         DO 1052 IB=1,NBND
            CT1=(0.D0,0.D0)
c            DO 1054 IG=1,NG2
            DO 1054 IG=1,NGNL(ITY)
 1054       CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
c            DO 1056 IG=1,NG2
            DO 1056 IG=1,NGNL(ITY)
 1056         DCOEF(IG,IB)=DCOEF(IG,IB)+CT1*DCONJG(WORK1(IG))
 1052    CONTINUE
 1200    CONTINUE
      ELSEIF(L.EQ.1.AND.IBUN(2,ITY).NE.1) THEN
C             NO PARTITIONING
c         DO 60 IG=1,NG2
         DO 60 IG=1,NGNL(ITY)
         Y11=DCMPLX( YLM(IG,2), 0.D0)
         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
         WORK1(IG)=EXTAU(IG)*Y11*VPJ(IG,1,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y12*VPJ(IG,1,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y13*VPJ(IG,1,LI,ITY)
   60    CONTINUE
         DO 62 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
c            DO 64 IG=1,NG2
            DO 64 IG=1,NGNL(ITY)
            CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT2=CT2+COEF(IG,IB)*WORK2(IG)
            CT3=CT3+COEF(IG,IB)*WORK3(IG)
   64       CONTINUE
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
            CT2=CT2/VPP(1,LI,ITY)/OMEGA
            CT3=CT3/VPP(1,LI,ITY)/OMEGA
c            DO 66 IG=1,NG2
            DO 66 IG=1,NGNL(ITY)
            DCOEF(IG,IB)=DCOEF(IG,IB)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
   66       CONTINUE
   62    CONTINUE
      ELSEIF(L.EQ.1) THEN
C             PARTITIONING
         DO 1261 IP=2,3
c         DO 61 IG=1,NG2
         DO 61 IG=1,NGNL(ITY)
         Y11=DCMPLX( YLM(IG,2), 0.D0)
         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
         WORK1(IG)=EXTAU(IG)*Y11*VPJ(IG,IP,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y12*VPJ(IG,IP,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y13*VPJ(IG,IP,LI,ITY)
   61    CONTINUE
         DO 63 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
c            DO 65 IG=1,NG2
            DO 65 IG=1,NGNL(ITY)
            CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT2=CT2+COEF(IG,IB)*WORK2(IG)
            CT3=CT3+COEF(IG,IB)*WORK3(IG)
   65       CONTINUE
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
            CT2=CT2/VPP(IP,LI,ITY)/OMEGA
            CT3=CT3/VPP(IP,LI,ITY)/OMEGA
c            DO 67 IG=1,NG2
            DO 67 IG=1,NGNL(ITY)
            DCOEF(IG,IB)=DCOEF(IG,IB)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
   67       CONTINUE
   63    CONTINUE
 1261    CONTINUE
      ELSEIF(L.EQ.2.AND.IBUN(3,ITY).NE.1) THEN
c *** temp check
c         write(6,*)' in SEPPOT'
c         write(6,*)' NGNL for d-',NGNL(ITY)
c         write(6,*)' YLM 5 '
c         write(6,*)(YLM(IG,5),IG=1,100,10)
c         write(6,*)' EXTAU '
c         write(6,*)(EXTAU(IG),IG=1,100,10)
c         write(6,*)' VPJ( partition 1'
c         write(6,*)( VPJ(IG,1,li,ity),IG=1,100,10)
c *** temp check: end
C             NO PARTITIONING
         DO 81 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0)
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7))
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7))
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9))
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9))
         WORK1(IG)=EXTAU(IG)*Y21*VPJ(IG,1,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y22*VPJ(IG,1,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y23*VPJ(IG,1,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y24*VPJ(IG,1,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y25*VPJ(IG,1,LI,ITY)
   81    CONTINUE
c *** temp check
c         write(6,*)'IN SEPPOT VPJ for d',VPJ(100,1,3,ITY)
c         write(6,*)'IN SEPPOT YLM 5',YLM(100,5)
c         write(6,*)'IN SEPPOT WORK 5',WORK5(100)
c *** temp check : end
         DO 82 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            DO 83 IG=1,NGNL(ITY)
            CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT2=CT2+COEF(IG,IB)*WORK2(IG)
            CT3=CT3+COEF(IG,IB)*WORK3(IG)
            CT4=CT4+COEF(IG,IB)*WORK4(IG)
            CT5=CT5+COEF(IG,IB)*WORK5(IG)
   83       CONTINUE
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
            CT2=CT2/VPP(1,LI,ITY)/OMEGA
            CT3=CT3/VPP(1,LI,ITY)/OMEGA
            CT4=CT4/VPP(1,LI,ITY)/OMEGA
            CT5=CT5/VPP(1,LI,ITY)/OMEGA
            DO 84 IG=1,NGNL(ITY)
            DCOEF(IG,IB)=DCOEF(IG,IB)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
   84       CONTINUE
   82    CONTINUE
c +*** temp check for lowest band
c          sum=0
c          do ig=1,NGNL(ITY)
c           sum=sum+dreal(DCOEF(IG,1)*COEF(IG,1))
c          enddo
c          write(6,*)' ity = ',ity,'DCOEF*COEF at band 1 =',sum
c *** temp check : end
      ELSEIF(L.EQ.2) THEN
C             PARTITIONING
         DO 1262 IP=2,3
         DO 71 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0)
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7))
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7))
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9))
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9))
         WORK1(IG)=EXTAU(IG)*Y21*VPJ(IG,IP,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y22*VPJ(IG,IP,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y23*VPJ(IG,IP,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y24*VPJ(IG,IP,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y25*VPJ(IG,IP,LI,ITY)
   71    CONTINUE
         DO 72 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            DO 73 IG=1,NGNL(ITY)
            CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT2=CT2+COEF(IG,IB)*WORK2(IG)
            CT3=CT3+COEF(IG,IB)*WORK3(IG)
            CT4=CT4+COEF(IG,IB)*WORK4(IG)
            CT5=CT5+COEF(IG,IB)*WORK5(IG)
   73       CONTINUE
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
            CT2=CT2/VPP(IP,LI,ITY)/OMEGA
            CT3=CT3/VPP(IP,LI,ITY)/OMEGA
            CT4=CT4/VPP(IP,LI,ITY)/OMEGA
            CT5=CT5/VPP(IP,LI,ITY)/OMEGA
            DO 74 IG=1,NGNL(ITY)
            DCOEF(IG,IB)=DCOEF(IG,IB)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
   74       CONTINUE
   72    CONTINUE
 1262    CONTINUE
      ELSEIF(L.EQ.3.AND.IBUN(4,ITY).NE.1) THEN
C             NO PARTITIONING
         DO 91 IG=1,NG2
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))
         WORK1(IG)=EXTAU(IG)*Y31*VPJ(IG,1,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y32*VPJ(IG,1,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y33*VPJ(IG,1,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y34*VPJ(IG,1,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y35*VPJ(IG,1,LI,ITY)
         WORK6(IG)=EXTAU(IG)*Y36*VPJ(IG,1,LI,ITY)
         WORK7(IG)=EXTAU(IG)*Y37*VPJ(IG,1,LI,ITY)
   91    CONTINUE
         DO 92 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            CT6=(0.D0,0.D0)
            CT7=(0.D0,0.D0)
            DO 93 IG=1,NG2
            CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT2=CT2+COEF(IG,IB)*WORK2(IG)
            CT3=CT3+COEF(IG,IB)*WORK3(IG)
            CT4=CT4+COEF(IG,IB)*WORK4(IG)
            CT5=CT5+COEF(IG,IB)*WORK5(IG)
            CT6=CT6+COEF(IG,IB)*WORK6(IG)
            CT7=CT7+COEF(IG,IB)*WORK7(IG)
   93       CONTINUE
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
            CT2=CT2/VPP(1,LI,ITY)/OMEGA
            CT3=CT3/VPP(1,LI,ITY)/OMEGA
            CT4=CT4/VPP(1,LI,ITY)/OMEGA
            CT5=CT5/VPP(1,LI,ITY)/OMEGA
            CT6=CT6/VPP(1,LI,ITY)/OMEGA
            CT7=CT7/VPP(1,LI,ITY)/OMEGA
            DO 94 IG=1,NG2
            DCOEF(IG,IB)=DCOEF(IG,IB)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
     &           +CT6*DCONJG(WORK6(IG))
     &           +CT7*DCONJG(WORK7(IG))
   94       CONTINUE
   92    CONTINUE
      ELSEIF(L.EQ.3) then
C             PARTITIONING
         DO 2262 IP=2,3
         DO 101 IG=1,NG2
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))
         WORK1(IG)=EXTAU(IG)*Y31*VPJ(IG,IP,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y32*VPJ(IG,IP,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y33*VPJ(IG,IP,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y34*VPJ(IG,IP,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y35*VPJ(IG,IP,LI,ITY)
         WORK6(IG)=EXTAU(IG)*Y36*VPJ(IG,IP,LI,ITY)
         WORK7(IG)=EXTAU(IG)*Y37*VPJ(IG,IP,LI,ITY)
  101    CONTINUE
         DO 102 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            CT6=(0.D0,0.D0)
            CT7=(0.D0,0.D0)
            DO 103 IG=1,NG2
            CT1=CT1+COEF(IG,IB)*WORK1(IG)
            CT2=CT2+COEF(IG,IB)*WORK2(IG)
            CT3=CT3+COEF(IG,IB)*WORK3(IG)
            CT4=CT4+COEF(IG,IB)*WORK4(IG)
            CT5=CT5+COEF(IG,IB)*WORK5(IG)
            CT6=CT6+COEF(IG,IB)*WORK6(IG)
            CT7=CT7+COEF(IG,IB)*WORK7(IG)
  103       CONTINUE
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
            CT2=CT2/VPP(IP,LI,ITY)/OMEGA
            CT3=CT3/VPP(IP,LI,ITY)/OMEGA
            CT4=CT4/VPP(IP,LI,ITY)/OMEGA
            CT5=CT5/VPP(IP,LI,ITY)/OMEGA
            CT6=CT6/VPP(IP,LI,ITY)/OMEGA
            CT7=CT7/VPP(IP,LI,ITY)/OMEGA
            DO 104 IG=1,NG2
            DCOEF(IG,IB)=DCOEF(IG,IB)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
     &           +CT6*DCONJG(WORK6(IG))
     &           +CT7*DCONJG(WORK7(IG))
  104       CONTINUE
  102    CONTINUE
 2262 CONTINUE
      ELSE
         STOP ' ILL ORBITAL IS INDICATED OR MORE THAN TWO PARTIONING '
      ENDIF
   30 CONTINUE
   20 CONTINUE
   10 CONTINUE
C     CALL CLOCK(TIM2)
C     WRITE(6,*) ' SEPPOT USED TIME=',TIM2-TIM1
C     STOP
      RETURN
      END
C------------PROGRAM UNIT POTENTIAL AND CHARGE---------------------
C**************************************************************
      SUBROUTINE VOFRHO(NRX,NRY,NRZ,NXYZ,NG,NGQ,G,TPIBA,
     & VCLR,VCSR,VG,RHO,RHOG,I2G,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2
     &,DX,DY,DZ,DXX,DYY,DZZ,DXY,DYZ,DZX,VWORK )
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 RHO(NXYZ)
      COMPLEX*16 VCLR(NXYZ),VCSR(NXYZ),VG(NXYZ),RHOG(NXYZ)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c ***  for GGA 
      COMPLEX*16 DX(NXYZ),DY(NXYZ),DZ(NXYZ)
     &      ,DXX(NXYZ),DYY(NXYZ),DZZ(NXYZ)
     &      ,DXY(NXYZ),DYZ(NXYZ),DZX(NXYZ),VWORK(NXYZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
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
      CALL PREFFT(NRX,NRY,NRZ,NXYZ,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
C     EXCHANGE CORRELATION CONTRIBUTION TO THE ONE-ELECTRON POTENTIAL
C
C
      IF(IGGA.EQ.1) THEN
       CALL G2VXC2(TPIBA,NRX,NRY,NRZ,NXYZ,NG,NGQ,G,
     & VG,RHO,RHOG,I2G,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,
     & LY1,LY2,LZ1,LZ2
     & , DX,DY,DZ,DXX,DYY,DZZ,DXY,DYZ,DZX,VWORK )
      ELSE
      CALL S2VXC2(NXYZ,RHO,VG)
      ENDIF
      CALL FFT3FX(NRX,NRY,NRZ,NXYZ,VG,VCLR,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
C        HARTREE POTENTIAL
C
      DO 47 IG=1,NXYZ
   47 VCSR(IG)=(0.D0,0.D0)
C
*VDIR NODEP(VCSR)
      DO 49 IG=2,NG
      JG=I2G(IG)
   49 VCSR(JG)=0.5D0*FPI*RHOG(JG)/(TPIBA2*G(4,IG))
      DO 48 IG=1,NXYZ
   48 VG(IG)=VG(IG)+VCSR(IG)*2.D0
C
c *** Smoothing of potential
c      adump4=4*adump
c      do ig=2,nxyz
c      jg=i2g(ig)
c      vg(jg)=vg(jg)*dexp(-g(4,ig)/adump4)
c      enddo
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
         EC=-B1/(1.D0+B2*DSQRT(RS)+B3*RS)
         VX=-4.D0*A0/(3.D0*RS)
         CC=-B1/(1.D0+B2*DSQRT(RS)+B3*RS)
         VC= (CC*CC/(3.D0*B1))*(B2*DSQRT(RS)/2.D0+B3*RS)
         VXC2=VX+EC-VC
         VCSR(IG)=VXC2
      ELSE
         RS=(3.D0/(4.D0*PAI*RHO(IG)))**(1.D0/3.D0)
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
         EX=-A0/RS
         EC=-B1/(1.D0+B2*DSQRT(RS)+B3*RS)
         XC2=EC+EX
         VCSR(IG)=XC2*RHO(IG)
      ELSE
         RS=(3.D0/(4.D0*PAI*RHO(IG)))**(1.D0/3.D0)
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
      SUBROUTINE RHOOFK( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NG2, NG2Q,
     &                   NBNDQ, NBND, NFL, RHO, RHO1, RHO2, RHO3,
     &                   COEF, WGT, J2G, IOWF, OCC, WSAVEX, WSAVEY,
     &                   WSAVEZ, IFACX, IFACY, IFACZ,
     &                   LX1, LX2, LY1, LY2, LZ1, LZ2               )
C
C                                   (1990-04-12) OSAMU SUGINO
C                                   (1990-08-21) OSAMU SUGINO
C     CONSTRUCTS THE FULLY-SYMMETRIZED CHARGE DENSITY.
C     INPUT : COEF
C     OUTPUT: RHO
C     WORK  : RHO1,RHO2,RHO3
C     SLAVE SUBROUTINES   FFT'S
C
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 RHO(NXYZ)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),COEF(NG2Q,MXBND)
      DIMENSION J2G(NG2Q),OCC(NBNDQ),IOWF(MBLK)
C     WORK ARRAYS FOR FOURIER TRANSFORM
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
C
C        GET RHOG
C
      DO 10 I=1,NXYZ
   10 RHO3(I)=(0.D0,0.D0)
      DO 20 IBLK = 1, MBLK
ccc      READ(71,REC=IOWF(IBLK)) COEF
        IF(IBLK.NE.MBLK) THEN
          MBN = MXBND
        ELSE
          MBN = MOD(NBND-1,MXBND) + 1
        END IF
      IBI = MXBND * (IBLK-1)
        DO 30 IBND = 1, MBN
        IB = IBI + IBND
                          IF(IB.GT.NFL) GO TO 25
          DO 21 I=1,NXYZ
   21     RHO2(I)=(0.D0,0.D0)
            DO 23 I=1,NG2
            II=J2G(I)
            RHO2(II)=COEF(I,IBND)
   23       CONTINUE
            CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
     &      WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &      LX1, LX2, LY1, LY2, LZ1, LZ2 )
            DO 24 I=1,NXYZ
   24       RHO2(I)=DCONJG(RHO2(I))*RHO2(I)
            DO 22 I=1,NXYZ
   22       RHO3(I)=RHO3(I)+RHO2(I)*OCC(IB)
   30   CONTINUE
   20 CONTINUE
   25                         CONTINUE
C
C        GATHER RHOG
C
      FWGT=WGT*2.D0
      DO 631 I=1,NXYZ
  631 RHO(I)=RHO(I)+DBLE(RHO3(I))*FWGT
C
      RETURN
      END
C*****************************************************************
      SUBROUTINE RHOGET(NRX,NRY,NRZ,NXYZ,RHO,RHO1,RHOG,NTOT,S,OMEGA,
     & ZVAL,RHO2,I2G,G,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2,
     & FDUMP)
C
C                                   (1990-04-12) OSAMU SUGINO
C                                   (1990-08-21) OSAMU SUGINO
C     CONSTRUCTS THE FULLY-SYMMETRIZED CHARGE DENSITY.
C     OUTPUT: RHO,RHOG
C     WORK  : RHO1
C     SLAVE SUBROUTINES   RHOTRA,FFT'S
C
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 RHO(NXYZ)
      COMPLEX*16 RHO1(NXYZ),RHOG(NXYZ)
C *** for smoothing !
      complex*16 RHO2(NXYZ)
      dimension I2G(NXYZ),G(4,NXYZ)
      INTEGER*4 S(3,3,48)
C     WORK ARRAYS FOR FOURIER TRANSFORM
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      dimension fdump(NXYZ)
      COMMON/SMOOTH/ADUMP
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
      IF( CHECK .GT. 1.D-3) THEN
         WRITE(6,*) ' '
         WRITE(6,*) '  **** RHOGET: INTEGRATED CHARGE  SUM ZVAL = ',
     &                   SUM, ZVAL
         STOP  ' INCORRECT TOTAL CHARGE '
      ELSE IF ( CHECK .GT. 1.D-7) THEN
         WRITE(6,*) ' '
         WRITE(6,*) '  **** RHOGET: INTEGRATED CHARGE  SUM ZVAL = ',
     &                   SUM, ZVAL
         WRITE(6,*) ' '
      END IF
C
C *******
C
C     MAKE LIST VECTORS FOR FFT
C
      CALL PREFFT(NRX,NRY,NRZ,NXYZ,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
C        RHO IN K SPACE
C
      DO 551 IG=1,NXYZ
  551 RHOG(IG)=DCMPLX(RHO(IG),0.D0)
      CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHOG,RHO1,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** Smoothing !!
         adump4=4*adump
         do ig=1,nxyz
         jg=i2g(ig)
         rhog(jg)=rhog(jg)*fdump(ig)
         enddo
         DO IG=1,NXYZ
         RHO2(IG)=RHOG(IG)
         ENDDO
         CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                LX1, LX2, LY1, LY2, LZ1, LZ2                )
         DO IG=1,NXYZ
         RHO(IG)=DBLE(RHO2(IG))
         ENDDO
c *** Smoothing !! : END
c **** smear negative rho: for SXACE!!
      rhomin=1.d-12
      do ir=1,nxyz
       if (rho(ir).lt.rhomin ) rho(ir)=rhomin
      enddo
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
C***********************************************************
      SUBROUTINE PRENON(JOPT,NG2Q,NG2,TPIBA,NGQ,NG,G,
c     &  NUMKQ,NUMK,G2,SPB,WORK3,NUMTY,NTYQ,NTYPE,VPJ,VPP
     &  NUMKQ,NUMK,G2,SPB,VGA,Vchg,WORK3,NUMTY,NTYQ,NTYPE,VPJ,VPP
     & ,NCRQ,ZV,RC0,COR,NUMC,ALPPP,BETAPP,IOVP, MXOFL,ADUMP,ATEMP,NGNL)
C***********************************************************
C
C               NUMERICAL POTENTIAL (1992-02-28) OSAMU SUGINO
C       JOPT:1   CONSTRUCT PP(G)
C            2   CONSTRUCT VPJ AND VPP
C
C
      IMPLICIT REAL*8(A-H,O-Z)
C        INPUT
      DIMENSION NG2(NUMKQ),NGNL(NTYQ,NUMKQ)
      DIMENSION G2(4,NG2Q,NUMKQ),NUMTY(NTYQ),G(4,NGQ)
      DIMENSION ZV(NTYQ),RC0(NCRQ,NTYQ),COR(NCRQ,NTYQ),NUMC(NTYQ)
c      DIMENSION  BETAPP(2,NTYQ),ALPPP(2,NTYQ),IOVP(2,NTYQ,NUMKQ)
c      DIMENSION  BETAPP(3,NTYQ),ALPPP(3,NTYQ),IOVP(2,NTYQ,NUMKQ)
      DIMENSION  BETAPP(4,NTYQ),ALPPP(4,NTYQ),IOVP(2,NTYQ,NUMKQ)
     &         , MXOFL(NTYQ)
C        WORK
      DIMENSION SPB(NG2Q),WORK3(NGQ)
c      PARAMETER(MESHQ=1000, ISPD=5, NTYQ2=4)
      PARAMETER(MESHQ=1000, ISPD=8, NTYQ2=4)
      DIMENSION RAD(MESHQ)
      DIMENSION PSPOT(MESHQ,ISPD),PSPOT2(MESHQ,ISPD)
c      DIMENSION PHIL(MESHQ,2)
c      DIMENSION PHIL(MESHQ,3)
      DIMENSION PHIL(MESHQ,4)
      DIMENSION WORK(MESHQ),WORK2(MESHQ)
c      DIMENSION VV(3),ZO(2,2)
c      DIMENSION VV(3),ZO(2,NTYQ2)
c      DIMENSION VV(3),ZO(3,NTYQ2)
      DIMENSION VV(3),ZO(4,NTYQ2)
C        OUTPUT
c      DIMENSION VPJ(NG2Q,3),VPP(3)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ)
c      DIMENSION VPJ(NG2Q,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ)
      DIMENSION VPJ(NG2Q,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ)
c                        ^ ^
c                        | |
c            partitioning   max of L
C
c ****
      dimension VGA(NGQ,NTYQ),Vchg(NGQ,NTYQ)
C
      DATA ISAISHO/1/
C
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
      FPI=4.D0*PI
C ***********   OCCUPATION OF ATOMIC ORBITALS  *********
C            FOR HYDROGEN
CCC   ZO(1,1)=1.D0
CCC   ZO(2,1)=0.D0
C            FOR SILICON
CCC   ZO(1,2)=2.D0
CCC   ZO(2,2)=2.D0
C *******************************************************
C
      IF(JOPT.EQ.1) THEN
cc         REWIND 81
cc         REWIND 83
         DO 610 ITY=1,NTYPE
         IF( NUMTY(ITY).LT.0 .OR. MXOFL(ITY).EQ.1 ) THEN
C **********************************************
C             READ PSEUDOPOTENTIAL
C
            CALL PSREAD2(ITY,ISPD,MESHQ,MESH,RAD,PSPOT
     &            ,PHIL,WORK
     &            ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
C
C             PSEUDOPOTENTIAL IN G-SPACE
C
            CALL PSOFG(NGQ,NG,G,MESHQ,MESH,
c     &           RAD,WORK,WORK2,WORK3,TPIBA
     &           RAD,WORK,WORK2,VGA(1,ITY),TPIBA
     &          ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
C **
            READ(5,*) ZO(1,ITY), ZO(2,ITY)
C
            DO 3611 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1)*PHIL(I,1)
3611        CONTINUE
              IF( MXOFL(ITY).EQ.1 ) THEN
            DO 3612 I=1,MESH
            WORK(I) = WORK(I) + ZO(2,ITY)*PHIL(I,2)*PHIL(I,2)
3612        CONTINUE
              END IF
C
            WRITE(6,9010) ITY, ZO(1,ITY), ZO(2,ITY)
 9010       FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) = ',I3,
     &                                      2D12.4 )
C
            CALL CDOFG(NGQ,NG,G,MESHQ,MESH,
c     &              RAD,WORK,WORK2,WORK3,TPIBA)
     &              RAD,WORK,WORK2,Vchg(1,ITY),TPIBA)
c         ELSE IF( MXOFL(ITY) .EQ. 2 ) THEN
         ELSE IF( MXOFL(ITY) .GE. 2 ) THEN
C **********************************************
C              READ PSEUDOPOTENTIAL
C
            CALL PSREAD(ITY,ISPD,MESHQ,MESH,RAD,PSPOT
     &            ,PSPOT2,PHIL,WORK
     &            ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
C
C               PSEUDOPOTENTIAL IN G-SPACE
C
            CALL PSOFG(NGQ,NG,G,MESHQ,MESH,
cc     &              RAD,WORK,WORK2,WORK3,TPIBA
     &              RAD,WORK,WORK2,VGA(1,ITY),TPIBA
     &             ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
C **
c *** for s- p-orbitals only
            if (MXOFL(ITY).EQ.2 ) then
            READ(5,*) ZO(1,ITY), ZO(2,ITY)
C
            DO 611 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1)*PHIL(I,1)
     &             +ZO(2,ITY)*PHIL(I,2)*PHIL(I,2)
 611        CONTINUE
C ** TEMP
C           DO 611 I=1,MESH
C 611       WORK(I) = FPI * EXP( -RAD(I)**2 ) * RAD(I)**2
C ** TEMP  END
C
            WRITE(6,9000) ITY, ZO(1,ITY), ZO(2,ITY)
 9000        FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) = ',I3,
     &                                       2D12.4 )
            elseif (MXOFL(ITY).EQ.3 ) then
            READ(5,*) ZO(1,ITY), ZO(2,ITY), ZO(3,ITY)
C
            DO 612 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1)*PHIL(I,1)
     &             +ZO(2,ITY)*PHIL(I,2)*PHIL(I,2)
     &             +ZO(3,ITY)*PHIL(I,3)*PHIL(I,3)
 612        CONTINUE
            WRITE(6,9001) ITY, ZO(1,ITY), ZO(2,ITY), ZO(3,ITY)
 9001        FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) ZO(3) = ',I3,
     &                                       3D12.4 )
            elseif (MXOFL(ITY).EQ.4 ) then
            READ(5,*) ZO(1,ITY), ZO(2,ITY), ZO(3,ITY), ZO(4,ITY)
C
            DO 613 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1)*PHIL(I,1)
     &             +ZO(2,ITY)*PHIL(I,2)*PHIL(I,2)
     &             +ZO(3,ITY)*PHIL(I,3)*PHIL(I,3)
     &             +ZO(4,ITY)*PHIL(I,4)*PHIL(I,4)
 613        CONTINUE
            WRITE(6,9012) ITY, ZO(1,ITY), ZO(2,ITY), ZO(3,ITY),
     &                          ZO(4,ITY)
 9012        FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) ZO(3) ZO(4)=
     &      ',I3,
     &                                       4D12.4 )
            endif
C
             CALL CDOFG(NGQ,NG,G,MESHQ,MESH,
c     &       RAD,WORK,WORK2,WORK3,TPIBA)
     &       RAD,WORK,WORK2,Vchg(1,ITY),TPIBA)
C **********************************************
         ELSE
           WRITE(6,9015) ITY, MXOFL(ITY)
 9015      FORMAT('   *** PRENON:   ITY  MXOFL(ITY) = ',2I5)
           STOP
         END IF
  610    CONTINUE
         RETURN
      ENDIF

C     MAKE VPJ AND JPP
C
C*****LOOP OVER TYPE OF ATOM
      DO 10 ITY=1,NTYPE
C
C        READ PSEUDOPOTENTIAL
C
      MXL = MXOFL(ITY)
c      IF( MXL .EQ. 2 ) THEN
      IF( MXL .GE. 2 ) THEN
       CALL PSREAD(ITY,ISPD,MESHQ,MESH,RAD,PSPOT,PSPOT2,PHIL,WORK
     &  ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
      ELSE
       CALL PSREAD2(ITY,ISPD,MESHQ,MESH,RAD,PSPOT,PHIL,WORK
     &  ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
      END IF
      IF(NUMTY(ITY).LT.0) GO TO 10
C
C         POTENTIAL PARTITIONING
C
        H=LOG(RAD(MESH)/RAD(1))/(MESH-1.D0)
        DO 3300 K=1,MESH
          DO 3310 LI=1,MXL
          PSPOT(K,LI)=(PSPOT(K,LI)-WORK(K))*H*RAD(K)
          AA=BETAPP(LI,ITY)*(RAD(K)-ALPPP(LI,ITY))
          IF(ABS(AA).LT.100.0D0)THEN
            F=1.D0/(1.D0+EXP(AA))
          ELSE
            F=0.D0
          ENDIF
          PSPOT2(K,LI*2-1)=PSPOT(K,LI)*F
          PSPOT2(K,LI*2  )=PSPOT(K,LI)*(1.D0-F)
 3310   CONTINUE
 3300   CONTINUE
c *** temp check
       write(6,*)' ++++ PSPOT in PRENON +++++ '
       do J=1,MXL
        write(6,*)' J = ',J
        write(6,8181)(PSPOT(K,J),K=1,MESH,100)
       enddo
 8181  format(4f12.6)
c *** temp check : end
C
        IF(ISAISHO.EQ.1) THEN
C
C         DISPLAY THE PARTITIONED POTENTIALS
C
        RMX=3.D0
CCC     WRITE(6,*) 'RMAX= ',RMX,'BUNKATSU=31'
        DO 3305 KK=1,31
          U=RMX*(KK-1)/30.D0
          DO 3308 K=1,MESH-1
            AA=(RAD(K)-U)*(RAD(K+1)-U)
            IF(AA.LT.0.D0)THEN
              II=K
            ENDIF
 3308     CONTINUE
C         WRITE(6,3307) RAD(II),PSPOT(II,1),PSPOT2(II,1),PSPOT2(II,2)
C         WRITE(6,3317) PSPOT(II,2),PSPOT2(II,3),PSPOT2(II,4)
 3305  CONTINUE
 3307  FORMAT(1H ,4E12.4)
 3317  FORMAT(1H ,12X,4E12.4)
       ENDIF
C
C*****LOOP OVER K-VECTOR
C     REWIND 82
c ****  for smoothing !!!!
c      do ig=1,NG
c      wari=dexp( (G(4,ig)-ADUMP)/ATEMP ) + 1.d0
c      WORK3(ig)=1.d0/dsqrt(wari)
c      enddo
      DO 1000 IK=1,NUMK
c ****  for smoothing !!!!
      do ig=1,NG2(IK)
c      wari=dexp( (G2(4,ig,ik)-4*ADUMP)/ATEMP ) + 1.d0
      wari=dexp( (G2(4,ig,ik)-ADUMP)/ATEMP ) + 1.d0
      WORK3(ig)=1.d0/dsqrt(wari)
      enddo
      do ig=1,NG2(IK)
      if ( WORK3(IG).lt.1.d-02 ) then
       NGNL(ITY,IK)=ig
       goto 1920
      endif
      enddo
 1920 continue
      write(6,*)' At IK = ',IK,',  Vnl needs ', NGNL(ITY,IK),
     & ' G-vectors.'
      write(6,*)' Ratio to full FFT grids = '
     &       ,DFLOAT(NGNL(ITY,IK))/DFLOAT(NG2(IK))
C*****LOOP OVER ANGULAR QUANTUM NUMBER
      DO 30 LI=1,MXL
C*****ZERO CLEAR
        DO 3 J=1,3
        VPP(J,LI,ity)=0.D0
        VV(J)=0.D0
c        DO 3 IG=1,NG2(IK)
        DO 3 IG=1,NGNL(ITY,IK)
        VPJ(IG,J,LI,ity,ik)=0.D0
    3   CONTINUE
      L=LI-1
C*****LOOP OVER MESH
      SUM=0.D0
      DO 50 I=1,MESH
C*****CONSTRUCT THE SPHERICAL BESSEL FUNCTION J_L(Q1*R)
      IF(L.EQ.0) THEN
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=1.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
c         DO 42 IG=ISTA,NG2(IK)
         DO 42 IG=ISTA,NGNL(ITY,IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I)*TPIBA
   42    SPB(IG)=SIN(TEMP)/TEMP
      ELSEIF(L.EQ.1) THEN
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
c         DO 44 IG=ISTA,NG2(IK)
         DO 44 IG=ISTA,NGNL(ITY,IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I)*TPIBA
   44    SPB(IG)=(SIN(TEMP)-TEMP*COS(TEMP))/TEMP**2
      ELSEIF(L.EQ.2) THEN ! d-orbital
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
         DO 46 IG=ISTA,NGNL(ITY,IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I)*TPIBA
   46    SPB(IG)=( (3.d0-TEMP**2)*SIN(TEMP)-3.d0*TEMP*COS(TEMP) )
     &           /TEMP**3
      ELSEIF(L.EQ.3) THEN ! f-orbital
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
         DO IG=ISTA,NG2(IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I)*TPIBA
         TEMP2=TEMP*TEMP
         TEMP3=TEMP*TEMP2
         TEMP4=TEMP2*TEMP2
         SPB(IG)=( (15.d0-6*TEMP2)*SIN(TEMP)+(TEMP3-15.d0*TEMP)
     &     *COS(TEMP) )  /TEMP4
         ENDDO
      ENDIF
c *** Smoothing !!! ***
c      do ig=1,NG2(ik)
      do ig=1,NGNL(ity,ik)
      SPB(ig)=WORK3(ig)*SPB(ig)
      enddo
C*****CALCULATE VPP&VPJ
      SUM=SUM+PHIL(I,LI)**2*H*RAD(I)
      VPP(1,li,ity)=VPP(1,li,ity)+PSPOT (I,LI    )*PHIL(I,LI)**2
      VPP(2,li,ity)=VPP(2,li,ity)+PSPOT2(I,2*LI-1)*PHIL(I,LI)**2
      VPP(3,li,ity)=VPP(3,li,ity)+PSPOT2(I,2*LI  )*PHIL(I,LI)**2
      VV(1)=VV(1)+(PSPOT (I,LI    )*PHIL(I,LI))**2/H/RAD(I)
      VV(2)=VV(2)+(PSPOT2(I,2*LI-1)*PHIL(I,LI))**2/H/RAD(I)
      VV(3)=VV(3)+(PSPOT2(I,2*LI  )*PHIL(I,LI))**2/H/RAD(I)
c      DO 52 IG=1,NG2(IK)
      DO 52 IG=1,NGNL(ITY,IK)
      VPJ(IG,1,li,ity,ik)=VPJ(IG,1,li,ity,ik)
     &          +FPI*PSPOT (I,LI    )*PHIL(I,LI)*RAD(I)*SPB(IG)
      VPJ(IG,2,li,ity,ik)=VPJ(IG,2,li,ity,ik)
     &          +FPI*PSPOT2(I,LI*2-1)*PHIL(I,LI)*RAD(I)*SPB(IG)
      VPJ(IG,3,li,ity,ik)=VPJ(IG,3,li,ity,ik)
     &          +FPI*PSPOT2(I,LI*2  )*PHIL(I,LI)*RAD(I)*SPB(IG)
   52 CONTINUE  ! end of ig loop
   50 CONTINUE  ! end of imesh (=radial mesh) loop
      DO 5320 KK=1,MESH
        WORK2(KK)=PHIL(KK,LI)**2
 5320 CONTINUE
      SUM2=DIADL(RAD,WORK2,MESH,H2,3,DX)
C
        IF(ABS(SUM-1.D0).GT.1.D-8) WRITE(6,6000) LI, SUM
 6000   FORMAT('        **** WARNING: SUM OF PHIL**2*H*R = ',I3,D20.12)
        IF(ABS(SUM2-1.D0).GT.1.D-8) WRITE(6,6002) LI, SUM2
 6002   FORMAT('        **** WARNING: DIADL OF PHIL**2 = ',I3,D20.12)
C
        IF(ISAISHO.EQ.1) THEN
            WRITE(6,8010) ITY, IK, LI, (VPP(KK,LI,ITY),KK=1,3)
 8010       FORMAT('   SUM OF VNL*PSIL**2: TOTAL AND PARTITIONED ',
     &              'FOR ITY = ',I4,' K = ',I3,' LI = ',I4,':'/
     &              10X,3D14.5)
            WRITE(6,8012)  ( VPP(KK,LI,ITY)/SQRT(VV(KK)), KK=1,3 )
 8012       FORMAT('   VPP / VV: ',3D14.5)
        ENDIF
C
cc      WRITE(82,REC=IOVP(LI,ITY,IK)) VPP, VPJ
CC       WRITE(6,*) ' VPJ LIST ',LI,ITY,IK
C        DO 20 IG=1,NG2(IK)
C  20    WRITE(6,'(I6,2E15.7)') IG,SQRT(G2(4,IG,IK))*TPIBA,VPJ(IG,1)
C    &                          /VPP(1)
C
   30 CONTINUE
c ****  here review VPJ and redefine cutoff length of G-vectors, NGNL
      do 152 ig=NGNL(ity,ik),1,-1
      vmax=0
      do li=1,mxl
      v1=dabs( VPJ(ig,1,li,ity,ik) )
      v2=dabs( VPJ(ig,2,li,ity,ik) )
      v3=dabs( VPJ(ig,3,li,ity,ik) )
      v123max=max(v1,v2,v3)
      vmax=max(vmax,v123max)
      enddo
      if ( vmax.gt.1.d-03 ) then
       NGNL(ity,ik)=ig
       goto 153
      endif
  152 continue
  153 continue
c *** temp check
c      if ( ity*ik.eq.1 ) then
c      write(6,*)' check VPJ at d-component'
c      do ig=1,100,10
c       write(6,*)' VPJ(',ig,')=',vpj(ig,1,3,1,1)
c      enddo
c      endif
c *** temp check: end
      write(6,*)' Now NGNL has been redefined '
      ratio=dfloat( NGNL(ity,IK) )/dfloat( NG2(IK) )
      write(6,1152)ity,ik,NGNL(ity,ik),ratio
 1000 CONTINUE
   10 CONTINUE
      ISAISHO=0
 1152 format(' NGNL(',i2,',',i3,')=',i10,
     & ' Ratio to the full grids = ',f22.16)
C
      RETURN
      END
C***********************************************************
      SUBROUTINE PSREAD(ITY,ISPD,MESHQ,MESH,
     & RAD,PSPOT,PSPOT2,PHIL,WORK,
     & NCRQ,ZV,RC0,COR,NUMC)
C***********************************************************
C
      IMPLICIT REAL*8(A-H,O-Z)
C        OUTPUT
      DIMENSION RAD(MESHQ)
      DIMENSION PSPOT(MESHQ,ISPD),PSPOT2(MESHQ,ISPD)
c      DIMENSION PHIL(MESHQ,2)
c      DIMENSION PHIL(MESHQ,3)
      DIMENSION PHIL(MESHQ,4)
      DIMENSION WORK(MESHQ)
      DIMENSION RC0(NCRQ),COR(NCRQ)
      DATA IST/1/
C
      IWT=40+ITY
      IWT2=45+ITY
      REWIND IWT
      REWIND IWT2
C
      NUMC=2
      NN=NUMC
c      READ(IWT ) ZV, (RC0(J),J=1,NN), COR(1)
c      READ(IWT2) ZV, (RC0(J),J=1,NN), COR(1)
      READ(IWT ,*) ZV, (RC0(J),J=1,NN), COR(1)
      READ(IWT2,*) ZV, (RC0(J),J=1,NN), COR(1)
      ZV=-ZV
      COR(2)=1.0D+00-COR(1)
      DO 605 J=1,NN
  605 RC0(J)=1.0D+00/RC0(J)
C
c      READ(IWT) NVST,MESH
c      READ(IWT2) NVST2,MESH2
      READ(IWT ,*) NVST,MESH
      READ(IWT2,*) NVST2,MESH2
C
        IF(IST.EQ.ITY) WRITE(6,3330) ITY, ZV
     &               ,(COR(JJ),RC0(JJ),JJ=1,NUMC ), NVST, NVST2, MESH
 3330   FORMAT(/' PSEUDOPOTENTIAL FOR ',I4,'  -TH ATOM: ZV = ',F10.2/
     &    20X,'     COR AND RC0 = ',2D13.5/
     &    20X,'                   ',2D13.5/
     &    20X,'     NVST NVST2 MESH = ',3I5)
C
        IF(MESH.GT.MESHQ .OR. MESH2.GT.MESHQ) THEN
          WRITE(6,3800) MESH, MESH2, MESHQ
 3800     FORMAT(///' ******   WARNING: MESH MESH2 MESHQ = ',3I6)
          STOP
        END IF
C
C
c      READ(IWT) (RAD(K),K=1,MESH)
c      READ(IWT2)(RAD(K),K=1,MESH)
      READ(IWT ,*) (RAD(K),K=1,MESH)
      READ(IWT2,*)(RAD(K),K=1,MESH)
C
C       READ PSEUDO ORBITALS
C
      DO 3101 J=1,NVST
c        READ(IWT) (PHIL(K,J),K=1,MESH)
        READ(IWT,*) (PHIL(K,J),K=1,MESH)
 3101 CONTINUE
      DO 3151 J=1,NVST2
C       READ(IWT2) (PHIL2(K),K=1,MESH)
c        READ(IWT2)
        READ(IWT2,*)
 3151 CONTINUE
C
C       READ PSEUDO POTENTITALS
C
      DO 3201 J=1,NVST
c        READ(IWT) (PSPOT(K,J),K=1,MESH)
c        READ(IWT2) (PSPOT2(K,J),K=1,MESH)
        READ(IWT ,*) (PSPOT(K,J),K=1,MESH)
        READ(IWT2,*) (PSPOT2(K,J),K=1,MESH)
 3201 CONTINUE
      DO 3251 J=1,NVST2-NVST
c        READ(IWT2) (PSPOT2(K,J+NVST),K=1,MESH)
        READ(IWT2,*) (PSPOT2(K,J+NVST),K=1,MESH)
 3251 CONTINUE
C
c **** temp check
       write(6,*)' ++++ PSPOT +++++ '
       do J=1,NVST
        write(6,*)' J = ',J
        write(6,8181)(PSPOT(K,J),K=1,MESH,100)
       enddo
 8181  format(4f12.6)
       write(6,*)' ++++ PSPOT2 +++++ '
       do J=1,NVST2
        write(6,*)' J = ',J
        write(6,8181)(PSPOT2(K,J),K=1,MESH,100)
       enddo
c **** temp check: end
cC ******   ASSUME D COMPONENT IS IN NVST2 = 3 -TH ARRAY
c      IF( NVST.NE.2 .OR. NVST2.NE.3 ) THEN
C ******   ASSUME D COMPONENT in higher quantum number IS IN NVST2 = 4 -TH ARRAY
c      IF( NVST.GT.3 .OR. NVST2.GT.4) THEN
      IF( NVST.GT.4 .OR. NVST2.GT.5) THEN
        WRITE(6,6000) NVST, NVST2
 6000   FORMAT(///
     &' ****  PSREAD: NOT PROGRAMMED FOR NVST AND NVST2 = ',2I5)
        STOP
      ELSE
        DO 7011 K=1,MESH
          WORK(K)=PSPOT2(K,NVST2)
 7011   CONTINUE
      ENDIF
      IST=IST+1
C
      RETURN
      END
C***********************************************************
      SUBROUTINE PSREAD2(ITY,ISPD,MESHQ,MESH,
     & RAD,PSPOT,PHIL,WORK,
     & NCRQ,ZV,RC0,COR,NUMC)
C***********************************************************
C
      IMPLICIT REAL*8(A-H,O-Z)
C        OUTPUT
      DIMENSION RAD(MESHQ)
      DIMENSION PSPOT(MESHQ,ISPD)
      DIMENSION PHIL(MESHQ,2)
      DIMENSION WORK(MESHQ)
      DIMENSION RC0(NCRQ),COR(NCRQ)
C ***  TEMP:  HYDROGEN IS THE IST-TH ATOM TYPE.
      DATA IST/3/
C
      IWT=40+ITY
      REWIND IWT
C
      NUMC=2
      NN=NUMC
c      READ(IWT ) ZV, (RC0(J),J=1,NN), COR(1)
      READ(IWT ,*) ZV, (RC0(J),J=1,NN), COR(1)
      ZV=-ZV
      COR(2)=1.0D+00-COR(1)
      DO 605 J=1,NN
  605 RC0(J)=1.0D+00/RC0(J)
C
c      READ(IWT) NVST,MESH
      READ(IWT,*) NVST,MESH
C
        IF(IST.EQ.ITY) WRITE(6,3330) ITY, ZV
     &               ,(COR(JJ),RC0(JJ),JJ=1,NUMC ), NVST, MESH
 3330   FORMAT(/' PSEUDOPOTENTIAL FOR ',I4,'  -TH ATOM: ZV = ',F10.2/
     &    20X,'     COR AND RC0 = ',2D13.5/
     &    20X,'                   ',2D13.5/
     &    20X,'     NVST  MESH = ',2I5)
C
        IF(MESH.GT.MESHQ ) THEN
          WRITE(6,3800) MESH,  MESHQ
 3800     FORMAT(///' ******   WARNING: MESH MESHQ = ',2I6)
          STOP
        END IF
C
C
c      READ(IWT) (RAD(K),K=1,MESH)
      READ(IWT,*) (RAD(K),K=1,MESH)
C
C       READ PSEUDO ORBITALS
C
      DO 3101 J=1,NVST
c        READ(IWT) (PHIL(K,J),K=1,MESH)
        READ(IWT,*) (PHIL(K,J),K=1,MESH)
 3101 CONTINUE
C
C       READ PSEUDO POTENTITALS
C
      DO 3201 J=1,NVST
c        READ(IWT) (PSPOT(K,J),K=1,MESH)
        READ(IWT,*) (PSPOT(K,J),K=1,MESH)
 3201 CONTINUE
C
C ******   TAKE NVST COMPONENT AS A LOCAL PART
        DO 7011 K=1,MESH
          WORK(K)=PSPOT(K,NVST)
 7011   CONTINUE
      IST=IST+1
C
      RETURN
      END
C***********************************************************
      SUBROUTINE PSOFG(NGQ,NG,G,MESHQ,MESH,
     &                 RAD,WORK,WORK2,WORK3,TPIBA
     & ,NCRQ,ZV,RC0,COR,NUMC)
C***********************************************************
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION RAD(MESHQ)
      DIMENSION WORK(MESHQ),WORK2(MESHQ)
      DIMENSION WORK3(NGQ),G(4,NGQ)
      DIMENSION RC0(NCRQ),COR(NCRQ)
C
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
      FPI=4.D0*PI
C
C         SUBTRACT LONG RANGE PART
        DO 5700 IA=1,NUMC
          R1=RC0(IA)
          R2=COR(IA)
          DO 5600 K=1,MESH
          WORK(K)=WORK(K)-ZV/RAD(K)*DERF(RAD(K)/R1)*R2
 5600     CONTINUE
 5700   CONTINUE
C
        DO 1200 K=1,MESH
          WORK2(K)=WORK(K)*RAD(K)*RAD(K)
 1200   CONTINUE
C         WRITE(6,*) ' RAD', RAD(1),RAD(2),RAD(MESH)
C         WRITE(6,*) ' WRK', WORK2(1),WORK2(2)
        WORK3(1)=DIADL(RAD,WORK2,MESH,H2,3,DX)*FPI
        DO 2000 I=2,NG
          RG=DSQRT(G(4,I)*TPIBA2)
          DO 2100 K=1,MESH
            WORK(K)=WORK2(K)*SIN(RG*RAD(K))/(RG*RAD(K))
 2100     CONTINUE
C         WRITE(6,*) ' RG', RG,I
C         WRITE(6,*) ' RAD', RAD(1),RAD(2),RAD(MESH)
C         WRITE(6,*) ' WRK', WORK(1),WORK(2)
          WORK3(I)=DIADL(RAD,WORK,MESH,H2,3,DX)*FPI
 2000   CONTINUE
ccc        WRITE(81) WORK3
CCC     WRITE(6,*) ' VGT LIST '
C       DO 30 IG=1,NG
C  30   WRITE(6,'(I6,2E15.7)') IG,SQRT(G(4,IG))*TPIBA,WORK3(IG)
        RETURN
        END
C***********************************************************
      SUBROUTINE CDOFG(NGQ,NG,G,MESHQ,MESH,
     &                 RAD,WORK,WORK2,WORK3,TPIBA)
C***********************************************************
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION RAD(MESHQ)
      DIMENSION WORK(MESHQ),WORK2(MESHQ)
      DIMENSION WORK3(NGQ),G(4,NGQ)
C
      TPIBA2=TPIBA**2
C
        DO 1200 K=1,MESH
          WORK2(K)=WORK(K)
 1200   CONTINUE
C         WRITE(6,*) ' RAD', RAD(1),RAD(2),RAD(MESH)
C         WRITE(6,*) ' WRK', WORK2(1),WORK2(2)
        WORK3(1)=DIADL(RAD,WORK2,MESH,H2,3,DX)
        DO 2000 I=2,NG
          RG=SQRT(G(4,I)*TPIBA2)
          DO 2100 K=1,MESH
            WORK(K)=WORK2(K)*SIN(RG*RAD(K))/(RG*RAD(K))
 2100     CONTINUE
C         WRITE(6,*) ' RG', RG,I
C         WRITE(6,*) ' RAD', RAD(1),RAD(2),RAD(MESH)
C         WRITE(6,*) ' WRK', WORK(1),WORK(2)
          WORK3(I)=DIADL(RAD,WORK,MESH,H2,3,DX)
 2000   CONTINUE
ccc        WRITE(83) WORK3
CCC     WRITE(6,*) ' CDG LIST '
C       DO 30 IG=1,NG
C  30   WRITE(6,'(I6,2E15.7)') IG,SQRT(G(4,IG))*TPIBA,WORK3(IG)
        RETURN
        END
C    *** REAL * 8 FUNCTION
C     INTEGRATION BY THE SIMPSON METHOD
C     INT=   F(1) +SUM(2F(2N) + 4F(2N+1))/3 + F(FIN)
      FUNCTION DIADL(X,Y,N,H,NMX,DX)
      IMPLICIT REAL*8(A-H,O-Z)
      PARAMETER ( MESQ=1000 )
      DIMENSION  X(MESQ),Y(MESQ)
      DATA FF1  ,FF2  ,FF3  ,FF4  /
     &     .2D1,.4D1,.0D1,.3D1 /
      DX=DLOG(Y(1)/Y(2))/DLOG(X(1)/X(2))+1.D0
      H=DLOG(X(N)/X(1))/(N-1)
      GO TO (10,20,30),NMX
   10 BEG=FF3
      GO TO 40
   20 DX=DLOG(X(2)*Y(2)/(X(1)*Y(1)))/H
   30 BEG=X(1)*Y(1)/DX
   40 SA=FF3
      SB=FF3
      DO 1 K=2,N,2
      SA=SA+X(K-1)*Y(K-1)
    1 SB=SB+X(K)*Y(K)
      NOE=N-(N/2)*2
      IF(NOE.EQ.0)THEN
        DIADL=H*(FF1*SA+FF2*SB-X(1)*Y(1)-X(N)*Y(N)*3.D0)/FF4+BEG
      ELSEIF(N.GE.6)THEN
        DIADL=H*(FF1*SA+FF2*SB-X(1)*Y(1)-X(N-1)*X(N-1)*2.D0
     &        -X(N-2)*Y(N-2)*4.D0-X(N-3)*Y(N-3))/FF4+BEG
     &       +H*(X(N-3)*Y(N-3)+X(N-2)*Y(N-2)*2.D0
     &        +X(N-1)*Y(N-1)*2.D0+X(N)*Y(N) )/2.D0
      ELSE
        WRITE(6,*) 'ERROR IN DIADL'
      ENDIF
      RETURN
      END
C
C*****************************************************************
      SUBROUTINE LOCPOT(NXYZ,NG,NGQ,G,TPIBA,VG,EIGT,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC)
C***********************************************************
C
C     CONSTRUCT LOCAL ONE-ELECTRON POTENTITL
C                                   (1990-08-21) OSAMU SUGINO
C               NUMERICAL POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 G(4,NGQ)
      COMPLEX*16 VG(NXYZ),EIGT(NXYZ)
c      DIMENSION I2G(NGQ),VGA(NGQ)
      DIMENSION I2G(NGQ),VGA(NGQ,NTYQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
      DIMENSION ZV(NTYQ),RC0(NCRQ,NTYQ),COR(NCRQ,NTYQ),NUMC(NTYQ)
CC      CALL CLOCK(TIM0)
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
      FPI=4.D0*PI
c      REWIND 81
C
      DO 81 IG=1,NXYZ
   81 VG(IG)=(0.D0,0.D0)
C
C
      DO 20 ITY=1,NTYPE
cc      READ(81)  VGA
        NUM=ABS(NUMTY(ITY))
        VG(1)=VG(1)+NUM*VGA(1,ITY)
        DO 22 K=1,NUM
          ITAU=NIDN(K,ITY)
*VDIR NODEP(VG)
          DO 80 IG=2,NG
          JG=I2G(IG)
          Q=TPIBA2*G(4,IG)
          SUM=  G(1,IG)*TAU(1,ITAU) + G(2,IG)*TAU(2,ITAU)
     &        + G(3,IG)*TAU(3,ITAU)
          SUM=SUM*TPIBA
          EIGT(IG)=DCMPLX(COS(SUM),-SIN(SUM))
          VG(JG)=VG(JG)+EIGT(IG)*VGA(IG,iTY)
C     IF(IG.EQ.2) WRITE(6,*) 'VGA(2)',VGA(2),EIGT(IG)
   80     CONTINUE
C
C
      DO 52 IA=1,NUMC(ITY)
      R02=RC0(IA,ITY)**2
*VDIR NODEP(VG)
      DO 82 IG=2,NG
      JG=I2G(IG)
      Q=TPIBA2*G(4,IG)
      VG(JG)=VG(JG)+ZV(ITY)*COR(IA,ITY)*FPI/Q
     &                 *EIGT(IG)*EXP(-0.25D0*Q*R02)
   82 CONTINUE
   52 CONTINUE
   22   CONTINUE
   20 CONTINUE
C
C
      DO 70 IG=1,NXYZ
   70 VG(IG)=VG(IG)/OMEGA
C
CC      CALL CLOCK(TIM1)
C     WRITE(6,*) '  LOCPOT CPTIME:',TIM1-TIM0
      RETURN
      END
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
      SUBROUTINE ELECTF( MXBND, MBLK, NXYZ, NG, NGQ, NG2, NG2Q,
     &                   NBNDQ, NBND, NUMK, NUMKQ, COEF, DCOEF,
     &    YLM, G, EXPG, G2,GDUMP, RHO, RHO4, RHO1, RHO2,RHOG,
     &                   TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ,
     &                   VPP, IOWF, IOVP, OMEGA, FORCE, DFORCE,
     &                   SFORCE,
     &                   NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &                   NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &                   VINT, NSY, FXNL, FYNL, FZNL,
     &                   TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
cc     &                   ZZ, ZVAL, NPFL, MXOFL, OCC                 )
     &                   ZZ, ZVAL, NPFL, MXOFL, OCC,VGA,NGNL,CL1
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
C
      IMPLICIT REAL*8 (A-H,O-Z)
c      REAL*8 YLM(NG2Q,4),RHO(NXYZ)
c      REAL*8 YLM(NG2Q,9),RHO(NXYZ)
      REAL*8 YLM(NG2Q,16),RHO(NXYZ)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHOG(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3),RHO4(NXYZ)
c     &           VG(NXYZ),WORK2(NG2Q,5),RHO4(NXYZ)
     &           VG(NXYZ),WORK2(NG2Q,7),RHO4(NXYZ)
      COMPLEX*16 CL1(NXYZ,10)
      DIMENSION I2G(NGQ),NG2(NUMKQ)
      DIMENSION G(4,NGQ),EXPG(NGQ),G2(4,NG2Q,NUMKQ),GDUMP(NG2Q,NUMKQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     &          ZV(NTYQ),RC0(NCRQ,NTYQ),
     &          COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ)
      COMPLEX*16 COEF(NG2Q,MXBND),DCOEF(NG2Q,MXBND)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ),IOWF(MBLK,NUMKQ)
c      DIMENSION VPJ(NG2Q,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ),IOWF(MBLK,NUMKQ)
      DIMENSION VPJ(NG2Q,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ),IOWF(MBLK,NUMKQ)
     &         ,IOVP(2,NTYQ,NUMKQ)
      INTEGER*4 S(3,3,48)
      DIMENSION FORCE(3,NTAUQ),DFORCE(3,NTAUQ),SFORCE(3,NTAUQ),
     &  ZZ(NTAUQ)
      DIMENSION RVEC(4,LATQ)
      COMMON/COMFIX/FATM(3,101),NFIX,IFATM(101)
      COMMON/COMOPT/IOPT(10,5)
C
      PARAMETER (IRLATQ=144,NAS=144)
      DIMENSION EE(NBNDQ,NUMKQ),EENL(NBNDQ,NUMKQ),RCOSIN(NAS,IRLATQ),
     & WK(NUMKQ),VINT(NBNDQ,IRLATQ),NSY(IRLATQ), OCC(NBNDQ,NUMKQ)
      DIMENSION FXNL(NTAUQ,NBNDQ,NUMKQ),FYNL(NTAUQ,NBNDQ,NUMKQ),
     & FZNL(NTAUQ,NBNDQ,NUMKQ)
c ***
      dimension VGA(NGQ,NTYQ)
c *** for FFT
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      dimension NGNL(NTYQ,NUMKQ)
C
C     CONSTRUCTS THE ONE-ELECTRON POTENTIAL RHO3
C
      CALL LOCPOTF(NXYZ,NG,NGQ,G,EXPG,RHO1,TPIBA,OMEGA,
cc     &             DELTA,VG,RHO,RHOG,I2G,FORCE,RHO2,
     &             DELTA,VG,RHO,RHOG,I2G,FORCE,VGA,
     &             NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,
     &             NCRQ,ZV,RC0,COR,NUMC,ZZ, ZVAL,
     &             ESELF, EWA, ELOCAL, EXC, EH
     &  ,CL1(1,1),CL1(1,2),CL1(1,3),CL1(1,4),CL1(1,5)
     &  ,CL1(1,6),CL1(1,7),CL1(1,8),CL1(1,9),CL1(1,10)
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
C
C     CALCULATE NON-LOCAL POTENTIAL CONTRIBUTION
C
      CALL NONLOCF( MXBND, MBLK, NXYZ, NG2, NG2Q,NBNDQ,NBND,
     &              NUMK, NUMKQ, IOVP,
     &    RHO4, COEF, DCOEF, YLM, G2,GDUMP, RHO2, TPIBA,
     &              DELTA, ETOT, WORK2, VPJ, VPP, IOWF, S, NTOT,
     &              FORCE, DFORCE, SFORCE, LATQ, RVEC, NLV,
     &              OMEGA, NTAUQ, NTYQ, NTYPE, LREQ,
     &              NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK, VINT,
     &              NSY, FXNL, FYNL, FZNL,
     &    TAU, NUMTY, NIDN, EKINE, ENL, NPFL, MXOFL, OCC, NGNL )
C
      CALL CLOCK(TIM)
      WRITE(6,6000) TIM
 6000 FORMAT(23X,'****  ELECTF: AFTER       ',F15.7,' SEC')
C
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
      WRITE(6,6004)
 6004 FORMAT(/
     & '  ******  TOTAL FORCE: NEGATIVE  (HARTREE/AU):')
      DO 10 I=1,NTAUQ
   10 WRITE(6,11) I, (FORCE(J,I),J=1,3)
   11 FORMAT(14X,I4,3F15.7)
      WRITE(6,*) ' '
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
C*
C*
C**************************************************************
      SUBROUTINE EWALDY(TPIBA,OMEGA,EWA,NGQ,NG,G,EXPG,
     & FORCE,LATQ,EWVEC,NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,ZV,ZZ,
     & A1,A2,A3,B1,B2,B3)
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 FORCE(3,NTAUQ),ZZ(NTAUQ)
      DIMENSION EWVEC(4,LATQ)
      DIMENSION G(4,NGQ),EXPG(NGQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     & ZV(NTYQ)
      REAL*8 A1(3),A2(3),A3(3),B1(3),B2(3),B3(3)
      REAL*8 FSUB(3),RP(3)
C
CC      CALL CLOCK(TIM0)
C
C     COMPUTE VARIOUS PARAMETERS
C
C *****  INPUT CARE
c             TOL=50.0D0
          TOL=140.0D0
c          TOL=280.0D0
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
      WRITE(6,6000) IMX,JMX,KMX
 6000 FORMAT(/10X,'  ** EWALDY: IMX JMX KMX = ',3I5)
C
      RMAX=RMAX*RMAX
      CALL AGEN(A1,A2,A3,IMX,JMX,KMX,NLV,LATQ,EWVEC,RMAX)
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
      DO 1540 I=1,NATOT
C
C     TERM WITH A=B
C
C     ADD TO SUMS (ENERGY)
C
        ESUMG=ESUMG+ZZ(I)*ZZ(I)*ESUM0
        IM=I-1
        IF(IM.NE.0) THEN
C
C    TERMS WITH A#B
C
          DO 1541 J=1,IM
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
 1541     CONTINUE
        ENDIF
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
C      CALL CLOCK(TIM1)
C      WRITE(6,*) '   EWALD G ',ESUMG,TIM1-TIM0
C     DO 3333 I=1,NATOT
C     WRITE(6,*) ' FORCES ',(FORCE(K,I),K=1,3)
C3333 CONTINUE
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
      DO 1610 I=1,NATOT
C
C     TERM WITH A=B
C
        ESUMR=ESUMR+ZZ(I)*ZZ(I)*ESUM0
        IM=I-1
        IF(IM.NE.0) THEN
C
C     TERMS WITH A#B
C
          DO 1611 J=1,IM
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
 1611     CONTINUE
        ENDIF
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
C     DO 17 I=1,NTAUQ
C  17 WRITE(6,*) (FORCE(J,I),J=1,3)
      RETURN
      END
C*
C*
      SUBROUTINE AGEN(B1,B2,B3,NRX,NRY,NRZ,NG,NGQ,G,GCUT)
C
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 B1(3),B2(3),B3(3),T(4)
      DIMENSION G(4,NGQ)
      INTEGER TNRM1,TNRM2,TNRM3
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
      WRITE(6,130) GCUT,NG,NRX*NRY*NRZ*4.0*3.141593/3.0/8.0
  130 FORMAT(' GCUT=',F15.7,' NG=',I8,' NG EFFICIENT=',F15.7)
      WRITE(6,*) ' IMAX=',IMAX,' JMAX=',JMAX,' KMAX=',KMAX
      RETURN
  100 WRITE(6,110) GCUT,NG
  110 FORMAT(' GCUT=',1PE12.4,' IS TOO BIG. STOPPING'/
     &       ' NGQ should be ',I9)
      STOP
      END
C*****************************************************************
      SUBROUTINE NONLOCF( MXBND, MBLK, NXYZ, NG2, NG2Q, NBNDQ,NBND,
     &                    NUMK, NUMKQ, IOVP,
     &      RHOA, COEF, DCOEF, YLM, G2,GDUMP, RHO2,
     &                    TPIBA, DELTA, ETOT, WORK2, VPJ, VPP, IOWF,
     &                    S, NTOT,
     &                    FORCE, DFORCE, SFORCE, LATQ, RVEC,NLV,
     &                    OMEGA, NTAUQ, NTYQ, NTYPE, LREQ,
     &                    NKMESH, NEXPND, NFL, EE, EENL, RCOSIN, WK,
     &                    VINT, NSY, FXNL, FYNL, FZNL,
     &                    TAU, NUMTY, NIDN, EKINE, ENL, NPFL, MXOFL, 
     &                    OCC, NGNL                     )
C
C
      IMPLICIT REAL*8 (A-H,O-Z)
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,4)
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,9)
      REAL*8 RHOA(NXYZ),YLM(NG2Q,16)
      COMPLEX*16 RHO2(NXYZ),
c     &           COEF(NG2Q,MXBND),DCOEF(NG2Q,MXBND),WORK2(NG2Q,3)
c     &    COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,MXBND),WORK2(NG2Q,3)
c     &    COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,MXBND),WORK2(NG2Q,5)
     &    COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,MXBND),WORK2(NG2Q,7)
      DIMENSION NG2(NUMKQ),RVEC(4,LATQ)
      DIMENSION G2(4,NG2Q,NUMKQ),GDUMP(NG2Q,NUMKQ),
     &          FORCE(3,NTAUQ),DFORCE(3,NTAUQ),SFORCE(3,NTAUQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
      INTEGER*4 S(3,3,48)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ),IOWF(MBLK,NUMKQ),
      DIMENSION VPJ(NG2Q,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ),IOWF(MBLK,NUMKQ),
     &          IOVP(2,NTYQ,NUMKQ)
      COMMON/COMOPT/IOPT(10,5)
      PARAMETER (IRLATQ=144,NAS=144)
      DIMENSION EE(NBNDQ,NUMKQ),EENL(NBNDQ,NUMKQ),RCOSIN(NAS,IRLATQ),
     &          WK(NUMKQ),VINT(NBNDQ,IRLATQ),NSY(IRLATQ)
      DIMENSION FXNL(NTAUQ,NBNDQ,NUMKQ),FYNL(NTAUQ,NBNDQ,NUMKQ),
     &          FZNL(NTAUQ,NBNDQ,NUMKQ), OCC(NBNDQ,NUMKQ)
      DIMENSION NGNL(NTYQ,NUMKQ)
      PI=4.D0*ATAN(1.D0)
      TPI=2.D0*PI
      FPI=4.D0*PI
      TPIBA2=TPIBA**2
      YMFAC=1.D0/DBLE(NKMESH)
C
C
C     MAIN LOOP
C
      EBND=0.D0
      NBND1=NFL+1
C
      DO 560 IK=1,NUMK
        DO 561 IB=1,NFL
          EBND=EBND+EE(IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
  561   CONTINUE
                        IF( NPFL .EQ. 0 ) GO TO 560
        DO 562 IB=NBND1,NBNDQ
        DO 563 I=1,NEXPND
          EBND=EBND+EE(IB,IK)*YMFAC*RCOSIN(IK,I)
     &         *VINT(IB,I)*DBLE(NSY(I))*2.D0
  563   CONTINUE
  562   CONTINUE
  560 CONTINUE
          WRITE(6,6666) EBND
 6666     FORMAT(38X,'*** NONLOCF: EBND = ',D13.5)
C
      DO 1951 I=1,NTAUQ
      DO 1951 J=1,3
      DFORCE(J,I)=0.D0
 1951 SFORCE(J,I)=0.D0
      DO 570 IK=1,NUMK
      DO 570 IB=1,NBNDQ
        EE(IB,IK)=0.D0
        EENL(IB,IK)=0.D0
  570 CONTINUE
      DO 571 ITAU=1,NTAUQ
      DO 571 IK=1,NUMK
      DO 571 IB=1,NBNDQ
        FXNL(ITAU,IB,IK)=0.D0
        FYNL(ITAU,IB,IK)=0.D0
        FZNL(ITAU,IB,IK)=0.D0
  571 CONTINUE
C
      DO 580 IK=1,NUMK
         DO 910 JJB=1,MBLK
            IF(JJB.EQ.MBLK) THEN
               NJ=MOD(NBND-1,MXBND)+1
            ELSE
               NJ=MXBND
            ENDIF
         IBI=MXBND*(JJB-1)
c         READ(71,REC=IOWF(JJB,IK)) COEF
             DO 581 IG=1,NG2(IK)
c             RHOA(IG)=G2(4,IG,IK)*TPIBA2
             RHOA(IG)=GDUMP(IG,IK)*TPIBA2
  581        CONTINUE
           DO 583 IB=1,NJ
             DO 582 IG=1,NG2(IK)
  582        EE(IB+IBI,IK)=EE(IB+IBI,IK)+
c     &           0.5D0*DBLE(RHOA(IG)*DCONJG(COEF(IG,IB))*COEF(IG,IB))
     &     0.5D0*DBLE(RHOA(IG)*DCONJG(COEF(IG,IB,IK))*COEF(IG,IB,IK))
  583      CONTINUE
C
             DO 588 IG=1,NG2(IK)
  588        RHOA(IG)=SQRT(G2(4,IG,IK))*TPIBA
         CALL GETYLM(NG2Q,NG2(IK),G2(1,1,IK),RHOA,YLM,TPIBA)
c **
         if (MXBND.LT.21) then
          write(6,*)' before SEPPOTF: DCOEF needs MXBD begger than 21'
          stop
         endif
c
         CALL SEPPOTF( NG2Q, NG2(IK), NJ, G2(1,1,IK),
c     &   VPJ,VPP,YLM,RHO2,WORK2(1,1),WORK2(1,2),WORK2(1,3),
     &   VPJ(1,1,1,1,IK),VPP,YLM,RHO2
     &  ,WORK2(1,1),WORK2(1,2),WORK2(1,3),WORK2(1,4),WORK2(1,5),
     &   WORK2(1,6),WORK2(1,7),
     &   COEF(1,1,IK),DCOEF,TPIBA,IOVP(1,1,IK),
     &   EENL(IBI+1,IK),FXNL(1,IBI+1,IK),FYNL(1,IBI+1,IK),
     &   FZNL(1,IBI+1,IK),
     &   NTAUQ,NTYQ,LREQ,TAU,NTYPE,NUMTY,NIDN, MXOFL,NGNL(1,IK) )
  910 CONTINUE
  580 CONTINUE
      ENL=0.D0
      EKINE=0.D0
      DO 590 IK=1,NUMK
        DO 591 IB=1,NFL
          EKINE=EKINE+EE(IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
          ENL=ENL+EENL(IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
  591   CONTINUE
                        IF( NPFL .EQ. 0 ) GO TO 590
        DO 592 IB=NBND1,NBNDQ
          DO 593 I=1,NEXPND
            EKINE=EKINE+EE(IB,IK)*YMFAC*RCOSIN(IK,I)
     &           *VINT(IB,I)*DBLE(NSY(I))*2.D0
            ENL=ENL+EENL(IB,IK)*YMFAC*RCOSIN(IK,I)
     &           *VINT(IB,I)*DBLE(NSY(I))*2.D0
  593     CONTINUE
  592   CONTINUE
  590 CONTINUE
C     WRITE(6,*) NFL,NBND1
      DO 595 ITAU=1,NTAUQ
      FX=0.D0
      FY=0.D0
      FZ=0.D0
      DO 596 IK=1,NUMK
      DO 597 IB=1,NFL
        FX=FX+FXNL(ITAU,IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
        FY=FY+FYNL(ITAU,IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
        FZ=FZ+FZNL(ITAU,IB,IK)*2.D0*WK(IK) * OCC(IB,IK)
C       WRITE(6,*) FXNL(ITAU,IB,IK),FYNL(ITAU,IB,IK),FZNL(ITAU,IB,IK)
  597 CONTINUE
                        IF( NPFL .EQ. 0 ) GO TO 596
      DO 599 IB=NBND1,NBNDQ
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
C
      RETURN
      END
C
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
     &  DELTA,VG,RHO,RHOG,I2G,FORCE,VGA,
     &  NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,ZZ, ZVAL,
     &  ESELF, EWA, ELOCAL, EXC, EH
     & ,DRX,DRY,DRZ,DRXX,DRYY,DRZZ,DRXY,DRYZ,DRZX,VWORK
     &                  ,NRX,NRY,NRZ
     &                  ,WSAVEX,WSAVEY,WSAVEZ
     &                  ,LX1,LX2,LY1
     &                  ,LY2,LZ1,LZ2
     &                  ,IFACX,IFACY,IFACZ)
c     &
C
C     CONSTRUCT LOCAL ONE-ELECTRON POTENTITL AND FORCE
C               NUMERICAL POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8 (A-H,O-Z)
      PARAMETER(LATQ=15630)
      REAL*8 G(4,NGQ),RHO(NXYZ),FORCE(3,NTAUQ),ZZ(NTAUQ)
      REAL*8 EXPG(NGQ)
      COMPLEX*16 EIGT(NXYZ),VG(NXYZ),RHOG(NXYZ),CI,CRG,CTEMP
c *** for GGA ***
      COMPLEX*16 DRX(NXYZ),DRY(NXYZ),DRZ(NXYZ)
     &  ,DRXX(NXYZ),DRYY(NXYZ),DRZZ(NXYZ)
     &  ,DRXY(NXYZ),DRYZ(NXYZ),DRZX(NXYZ),VWORK(NXYZ)
      DIMENSION I2G(NGQ),VGA(NGQ,NTYQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
c *** for FFT
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      COMMON/AVEC/A1(3),A2(3),A3(3),B1(3),B2(3),B3(3),COVA,ALAT
      COMMON/COMOPT/IOPT(10,5)
      DIMENSION EWVEC(4,LATQ)
      DIMENSION ZV(NTYQ),RC0(NCRQ,NTYQ),COR(NCRQ,NTYQ),NUMC(NTYQ)
C     DIMENSION AFORCE(3,16),BFORCE(3,16)
      CI=(0.D0,1.D0)
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      TPIBA2=TPIBA**2
      IGGA = IOPT(8,2)
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
C       EWALD SUM
C
      CALL EWALDY(TPIBA,OMEGA,EWA,NGQ,NG,G,EXPG,FORCE,LATQ,EWVEC,
     &           NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,ZV,ZZ,
     &           A1,A2,A3,B1,B2,B3)
C *****   EWALD END
C     WRITE(6,6002)
C6002 FORMAT(15X,'  ****  FORCE EWALD PARTS: NEGATIVE')
C     DO 9030 ITAU=1,NTAUQ
C9030 WRITE(6,'(23X,3F14.6)') (FORCE(I,ITAU),I=1,3)
C
C
C LOCAL POTENTITAL
C
      DO 25 IG=1,NXYZ
      EIGT(IG)=(0.D0,0.D0)
   25 VG(IG)=(0.D0,0.D0)
C
      ENERGY1=0.D0
      ENERGY2=0.D0
c      REWIND 81
      DO 20 ITY=1,NTYPE
c      READ(81) VGA
      NUM=ABS(NUMTY(ITY))
      VG(1)=VG(1)+VGA(1,ITY)*NUM/OMEGA
      DO 22 K=1,NUM
      ITAU=NIDN(K,ITY)
*VDIR NODEP(VG)
      DO 80 IG=2,NG
      JG=I2G(IG)
      Q=TPIBA2*G(4,IG)
      SUM=  G(1,IG)*TAU(1,ITAU) + G(2,IG)*TAU(2,ITAU)
     &    + G(3,IG)*TAU(3,ITAU)
      SUM=SUM*TPIBA
      EIGT(IG)=DCMPLX(COS(SUM),-SIN(SUM))
      CTEMP=VGA(IG,ITY)*EIGT(IG)/OMEGA
      VG(JG)=VG(JG)+CTEMP
      C1=G(1,IG)*TPIBA*OMEGA
      C2=G(2,IG)*TPIBA*OMEGA
      C3=G(3,IG)*TPIBA*OMEGA
      CRG=DCONJG(RHOG(JG))
      ENERGY1=ENERGY1+DBLE(CRG*CTEMP)
C     AFORCE(1,ITAU)=AFORCE(1,ITAU)+DBLE(-CI*CTEMP*C1*CRG)
C     AFORCE(2,ITAU)=AFORCE(2,ITAU)+DBLE(-CI*CTEMP*C2*CRG)
C     AFORCE(3,ITAU)=AFORCE(3,ITAU)+DBLE(-CI*CTEMP*C3*CRG)
      FORCE(1,ITAU)=FORCE(1,ITAU)+DBLE(-CI*CTEMP*C1*CRG)
      FORCE(2,ITAU)=FORCE(2,ITAU)+DBLE(-CI*CTEMP*C2*CRG)
      FORCE(3,ITAU)=FORCE(3,ITAU)+DBLE(-CI*CTEMP*C3*CRG)
   80 CONTINUE
C              LONG RANGE PART
      DO 52 IA=1,NUMC(ITY)
      R02=RC0(IA,ITY)**2
*VDIR NODEP(VG)
      DO 82 IG=2,NG
      JG=I2G(IG)
      Q=TPIBA2*G(4,IG)
      AA=ZV(ITY)*COR(IA,ITY)*FPI/Q*EXP(-0.25D0*Q*R02)/OMEGA
      VG(JG)=VG(JG)+EIGT(IG)*AA
      C1=AA*G(1,IG)*TPIBA*OMEGA
      C2=AA*G(2,IG)*TPIBA*OMEGA
      C3=AA*G(3,IG)*TPIBA*OMEGA
      CRG=DCONJG(RHOG(JG))
      ENERGY2=ENERGY2+DBLE(EIGT(IG)*AA*CRG)
C     BFORCE(1,ITAU)=BFORCE(1,ITAU)+DBLE(-CI*EIGT(IG)*C1*CRG)
C     BFORCE(2,ITAU)=BFORCE(2,ITAU)+DBLE(-CI*EIGT(IG)*C2*CRG)
C     BFORCE(3,ITAU)=BFORCE(3,ITAU)+DBLE(-CI*EIGT(IG)*C3*CRG)
      FORCE(1,ITAU)=FORCE(1,ITAU)+DBLE(-CI*EIGT(IG)*C1*CRG)
      FORCE(2,ITAU)=FORCE(2,ITAU)+DBLE(-CI*EIGT(IG)*C2*CRG)
      FORCE(3,ITAU)=FORCE(3,ITAU)+DBLE(-CI*EIGT(IG)*C3*CRG)
   82 CONTINUE
   52 CONTINUE
C
   22 CONTINUE
   20 CONTINUE
C
C * TEMP
C     WRITE(6,6004)
C6004 FORMAT(15X,'  ****  FORCE LOCAL PARTS: NEGATIVE ')
C     DO 9031 ITAU=1,NTAUQ
C9031 WRITE(6,'(23X,3F14.6)') (FORCE(I,ITAU),I=1,3)
C
      ELOCAL=0.D0
      DO 6351 IG=1,NXYZ
 6351 ELOCAL=ELOCAL+DBLE(DCONJG(VG(IG))*RHOG(IG))
      ELOCAL=OMEGA*ELOCAL
C
C         EXCHANGE CORRELATION PART
      IF(IGGA.EQ.1) THEN
       CALL G2XC2(TPIBA, NRX,NRY,NRZ,NXYZ,NG,NGQ,G,
     & RHO,RHOG,I2G,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,
     & LY1,LY2,LZ1,LZ2,EXC,VG,DRX,DRY,DRZ,
     & DRXX,DRYY,DRZZ,DRXY,DRYZ,DRZX,VWORK)
      ELSE
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
      DO 652 IG=2,NG
      JG=I2G(IG)
  652 EH=EH+0.5D0*FPI*DBLE(DCONJG(RHOG(JG))*RHOG(JG))/(TPIBA2*G(4,IG))
      EH=OMEGA*EH
C
C
      DELTA=EWA+EH+ELOCAL+EXC+ESELF
C
      RETURN
      END
C
C********************************************************************
C
      SUBROUTINE SEPPOTF(NG2Q,NG2,NBND,G2K,VPJ,VPP,
c     &  YLM,EXTAU,WORK1,WORK2,WORK3,COEF,DCOEF,TPIBA,
c     &  YLM,EXTAU,WORK1,WORK2,WORK3,WORK4,WORK5,COEF,DCOEF,TPIBA,
     &  YLM,EXTAU,WORK1,WORK2,WORK3,WORK4,WORK5,WORK6,WORK7,
     &  COEF,DCOEF,TPIBA,
     &  IOVP,EENL,FXNL,FYNL,FZNL,
     &  NTAUQ,NTYQ,LREQ,TAU,NTYPE,NUMTY,NIDN, MXOFL,NGNL )
C
C               PARTITIONED POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8(A-H,O-Z)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,4)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,9)
      DIMENSION G2K(4,NG2Q),YLM(NG2Q,16)
c      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,9),
c      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,15),
      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,21),
     & WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),WORK4(NG2Q),WORK5(NG2Q),
     & WORK6(NG2Q),WORK7(NG2Q),
     & EXTAU(NG2Q)
      COMPLEX*16 Y00,Y11,Y12,Y13,Y21,Y22,Y23,Y24,Y25
     &   ,Y31,Y32,Y33,Y34,Y35,Y36,Y37
     & ,SUKA1,SUKA2,SUKA3,SUKA4,SUKA5,SUKA6,SUKA7
c     & ,CT(5),CD(3,5)  ! CT: Etot CD: grad 
     & ,CT(7),CD(3,7)  ! CT: Etot CD: grad
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
c     &          VPJ(NG2Q,3),VPP(3),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &    VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &    VPJ(NG2Q,3,3,NTYQ),VPP(3,3,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
     &    VPJ(NG2Q,3,4,NTYQ),VPP(3,4,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
      PARAMETER(NTYQ2=4)
c      COMMON/SAITO2/IBUN(2,NTYQ2)
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
      DIMENSION EENL(NBND),FXNL(NTAUQ,NBND),FYNL(NTAUQ,NBND),
     & FZNL(NTAUQ,NBND)
      dimension NGNL(NTYQ)
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      FPISQ=FPI**2
CC      CALL CLOCK(TIM0)
C
C
CCC   LMAX=LREQ-1
C
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
         Y00=DCMPLX(YLM(IG,1),0.D0)
         SUKA1=Y00*EXTAU(IG)*VPJ(IG,1,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG,1)=SUKA1*G2K(1,IG)
         DCOEF(IG,2)=SUKA1*G2K(2,IG)
         DCOEF(IG,3)=SUKA1*G2K(3,IG)
   50    CONTINUE
         DO 52 IB=1,NBND
            CT(1)=(0.D0,0.D0)
            CD(1,1)=(0.D0,0.D0)
            CD(2,1)=(0.D0,0.D0)
            CD(3,1)=(0.D0,0.D0)
c            DO 54 IG=1,NG2
            DO 54 IG=1,NGNL(ITY)
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
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
         Y00=DCMPLX(YLM(IG,1),0.D0)
         SUKA1=Y00*EXTAU(IG)*VPJ(IG,IP,li,ity)
         WORK1(IG)=SUKA1
         DCOEF(IG,1)=SUKA1*G2K(1,IG)
         DCOEF(IG,2)=SUKA1*G2K(2,IG)
         DCOEF(IG,3)=SUKA1*G2K(3,IG)
 1050    CONTINUE
         DO 1052 IB=1,NBND
            CT(1)=(0.D0,0.D0)
            CD(1,1)=(0.D0,0.D0)
            CD(2,1)=(0.D0,0.D0)
            CD(3,1)=(0.D0,0.D0)
c            DO 1054 IG=1,NG2
            DO 1054 IG=1,NGNL(ITY)
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
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
c         DO 60 IG=1,NG2
         DO 60 IG=1,NGNL(ITY)
         Y11=DCMPLX( YLM(IG,2), 0.D0)
         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
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
         DO 62 IB=1,NBND
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
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG,4)
            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG,5)
            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG,6)
            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG,7)
            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG,8)
            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG,9)
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
         DO 1261 IP=2,3
c         DO 61 IG=1,NG2
         DO 61 IG=1,NGNL(ITY)
         Y11=DCMPLX( YLM(IG,2), 0.D0)
         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
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
         DO 63 IB=1,NBND
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
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG,1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG,2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG,3)
            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG,4)
            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG,5)
            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG,6)
            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG,7)
            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG,8)
            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG,9)
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
         DO 70 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0 )
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7) )
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7) )
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9) )
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9) )
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
       DO 71 IB=1,NBND
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
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IB)*DCOEF(IG,15)
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
       DO 1280 IP=2,3
         DO 80 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0 )
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7) )
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7) )
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9) )
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9) )
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
       DO 81 IB=1,NBND
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
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IB)*DCOEF(IG,15)
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
         DO 90 IG=1,NG2
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))
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
       DO 91 IB=1,NBND
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
         DO 92 IG=1,NG2
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IB)*DCOEF(IG,15)
            CT(6)=CT(6)+COEF(IG,IB)*WORK6(IG)
            CD(1,6)=CD(1,6)+COEF(IG,IB)*DCOEF(IG,16)
            CD(2,6)=CD(2,6)+COEF(IG,IB)*DCOEF(IG,17)
            CD(3,6)=CD(3,6)+COEF(IG,IB)*DCOEF(IG,18)
            CT(7)=CT(7)+COEF(IG,IB)*WORK7(IG)
            CD(1,7)=CD(1,7)+COEF(IG,IB)*DCOEF(IG,19)
            CD(2,7)=CD(2,7)+COEF(IG,IB)*DCOEF(IG,20)
            CD(3,7)=CD(3,7)+COEF(IG,IB)*DCOEF(IG,21)
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
       DO 1380 IP=2,3
         DO 100 IG=1,NG2
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))
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
       DO 101 IB=1,NBND
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
         DO 102 IG=1,NG2
            CT(1)=CT(1)+COEF(IG,IB)*WORK1(IG)
            CD(1,1)=CD(1,1)+COEF(IG,IB)*DCOEF(IG, 1)
            CD(2,1)=CD(2,1)+COEF(IG,IB)*DCOEF(IG, 2)
            CD(3,1)=CD(3,1)+COEF(IG,IB)*DCOEF(IG, 3)
            CT(2)=CT(2)+COEF(IG,IB)*WORK2(IG)
            CD(1,2)=CD(1,2)+COEF(IG,IB)*DCOEF(IG, 4)
            CD(2,2)=CD(2,2)+COEF(IG,IB)*DCOEF(IG, 5)
            CD(3,2)=CD(3,2)+COEF(IG,IB)*DCOEF(IG, 6)
            CT(3)=CT(3)+COEF(IG,IB)*WORK3(IG)
            CD(1,3)=CD(1,3)+COEF(IG,IB)*DCOEF(IG, 7)
            CD(2,3)=CD(2,3)+COEF(IG,IB)*DCOEF(IG, 8)
            CD(3,3)=CD(3,3)+COEF(IG,IB)*DCOEF(IG, 9)
            CT(4)=CT(4)+COEF(IG,IB)*WORK4(IG)
            CD(1,4)=CD(1,4)+COEF(IG,IB)*DCOEF(IG,10)
            CD(2,4)=CD(2,4)+COEF(IG,IB)*DCOEF(IG,11)
            CD(3,4)=CD(3,4)+COEF(IG,IB)*DCOEF(IG,12)
            CT(5)=CT(5)+COEF(IG,IB)*WORK5(IG)
            CD(1,5)=CD(1,5)+COEF(IG,IB)*DCOEF(IG,13)
            CD(2,5)=CD(2,5)+COEF(IG,IB)*DCOEF(IG,14)
            CD(3,5)=CD(3,5)+COEF(IG,IB)*DCOEF(IG,15)
            CT(6)=CT(6)+COEF(IG,IB)*WORK6(IG)
            CD(1,6)=CD(1,6)+COEF(IG,IB)*DCOEF(IG,16)
            CD(2,6)=CD(2,6)+COEF(IG,IB)*DCOEF(IG,17)
            CD(3,6)=CD(3,6)+COEF(IG,IB)*DCOEF(IG,18)
            CT(7)=CT(7)+COEF(IG,IB)*WORK7(IG)
            CD(1,7)=CD(1,7)+COEF(IG,IB)*DCOEF(IG,19)
            CD(2,7)=CD(2,7)+COEF(IG,IB)*DCOEF(IG,20)
            CD(3,7)=CD(3,7)+COEF(IG,IB)*DCOEF(IG,21)
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
         STOP ' ILL ORBITAL IS INDICATED OR MORE THAN TWO PARTIONING '
      ENDIF
C     WRITE(6,*) ' ENL=',ENL,'F=',FX,FY,FZ
   30 CONTINUE
C     DFORCE(1,ITAU)=DFORCE(1,ITAU)-FX*2.D0*TPIBA
C     DFORCE(2,ITAU)=DFORCE(2,ITAU)-FY*2.D0*TPIBA
C     DFORCE(3,ITAU)=DFORCE(3,ITAU)-FZ*2.D0*TPIBA
   20 CONTINUE
   10 CONTINUE
C     WRITE(6,*) ' COEF CHECK ',COEF(1,1),COEF(1,2)
C     WRITE(6,*) ' ##NON-LOCAL##',ENL
CC      CALL CLOCK(TIM1)
C     WRITE(6,*) ' NON-LOCAL CPTIME= ',TIM1-TIM0
      RETURN
      END
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
      SUBROUTINE G2VECT(NGQ,NG,NG2Q,NG2,VECK,
     &          G,G2,GDUMP,J2G,I2G,TPIBA,GCUT2,GG,J2GG,INDX)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION G(4,NGQ),G2(4,NG2Q),I2G(NGQ),J2G(NG2Q),VECK(3)
      DIMENSION GG(4,NGQ),J2GG(NG2),INDX(NGQ),GDUMP(NG2Q)
C
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA*TPIBA
      IG2=1
      DO 1 I=1,NG
      IF(IG2.GT.NG2Q) GOTO 100
c      G2(1,IG2)=VECK(1)+G(1,I)
c      G2(2,IG2)=VECK(2)+G(2,I)
c      G2(3,IG2)=VECK(3)+G(3,I)
c      G2(4,IG2)=G2(1,IG2)**2 + G2(2,IG2)**2 + G2(3,IG2)**2
c      GDIF= G2(4,IG2)*TPIBA2
      GG(1,IG2)=VECK(1)+G(1,I)
      GG(2,IG2)=VECK(2)+G(2,I)
      GG(3,IG2)=VECK(3)+G(3,I)
      GG(4,IG2)=GG(1,IG2)**2 + GG(2,IG2)**2 + GG(3,IG2)**2
      GDIF= GG(4,IG2)*TPIBA2
cccc      IF(GDIF.GT.GCUT2) GOTO 1  !!! for full grids
C     WRITE(6,*) ' GDIF ',I,IG2,GDIF,G(4,I)*TPIBA2
c      J2G(IG2)=I2G(I)
      J2GG(IG2)=I2G(I)
      IG2=IG2+1
    1 CONTINUE
      IG2=IG2-1
      CALL INDEXX(IG2,GG,INDX)
      DO IG=1,IG2
      G2(1,IG)=GG(1,INDX(IG))
      G2(2,IG)=GG(2,INDX(IG))
      G2(3,IG)=GG(3,INDX(IG))
      G2(4,IG)=GG(4,INDX(IG))
      J2G(IG)=J2GG(INDX(IG))
      ENDDO
      GFAC=GCUT2/TPIBA2
      DO IG=1,IG2
      IF ( G2(4,IG).LE.GFAC ) THEN
      GDUMP(IG)=G2(4,IG)
      ELSE
      GDUMP(IG)=GFAC
      ENDIF
      ENDDO
      WRITE(6,200) (VECK(I),I=1,3),GCUT2,IG2
  200 FORMAT(' KVECT=',3F9.4,': GCUT2= ',F9.3,'  NG2= ',I5)
      WRITE(6,*) ' NG=',NG
      NG2=IG2
C
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
      RETURN
  100 WRITE(6,110) GCUT2
  110 FORMAT(' GCUT2=',1PE12.4,' IS TOO BIG. STOPPING')
      WRITE(6,*) ' TPIBA ',TPIBA,I,NG2Q
      STOP
      END
C****************************************************************
      SUBROUTINE GEN(A,A1,A2,A3,B1,B2,B3,NRX,NRY,NRZ,NXYZ,
     &                NG,NGQ,G,I2G,GCUT)
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
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 A1(3),A2(3),A3(3),B1(3),B2(3),B3(3),T(4)
      DIMENSION I2G(NGQ),G(4,NGQ)
      WRITE(6,3001) (A1(I),A2(I),A3(I),I=1,3)
 3001 FORMAT(' A-VECTORS'/,3(' ',3F15.7/))
      CALL RECIPS(A,A1,A2,A3,B1,B2,B3)
      WRITE(6,3002) (B1(I),B2(I),B3(I),I=1,3)
 3002 FORMAT(' B-VECTORS'/,3(' ',3F15.7/))
      NG=1
      IMAX=0
      JMAX=0
      KMAX=0
c      TNRM1=2*NRX-1
c      TNRM2=2*NRY-1
c      TNRM3=2*NRZ-1
      TNRM1=NRX
      TNRM2=NRY
      TNRM3=NRZ
      DO 10 I1=1,TNRM1
      I=I1-NRX/2
      DO 10 J1=1,TNRM2
      J=J1-NRY/2
      DO 10 K1=1,TNRM3
      K=K1-NRZ/2
      G2=0.D0
      DO 5 IR=1,3
      T(IR)=DBLE(I)*B1(IR)+DBLE(J)*B2(IR)+DBLE(K)*B3(IR)
    5 G2=G2+T(IR)*T(IR)
ccc      IF(G2.GT.GCUT) GO TO 10 !! comment out for full drigds
      IF(ABS(I).GT.IMAX) IMAX=ABS(I)
      IF(ABS(J).GT.JMAX) JMAX=ABS(J)
      IF(ABS(K).GT.KMAX) KMAX=ABS(K)
      DO 6 IR=1,3
    6 G(IR,NG)=T(IR)
      G(4,NG)=G2
      N1=I+1
      IF(I.LT.0) N1=N1+NRX
      N2=J+1
      IF(J.LT.0) N2=N2+NRY
      N3=K+1
      IF(K.LT.0) N3=N3+NRZ
      I2G(NG)=N1+(N2-1)*NRX+(N3-1)*NRX*NRY
      NG=NG+1
      IF(NG.GT.NGQ) GO TO 100
   10 CONTINUE
      NG=NG-1
      WRITE(6,130) GCUT,NG,NXYZ*4.0*3.141593/3.0/8.0
  130 FORMAT(' GCUT=',F15.7,' NG=',I8,' NG EFFICIENT=',F15.7)
      WRITE(6,*) ' IMAX=',IMAX,' JMAX=',JMAX,' KMAX=',KMAX
C
C   REORDER THE G'S IN ORDER OF INCREASING MAGNITUDE.
      DO 20 IG=1,NG
      DO 20 JG=IG,NG
      IF(G(4,JG).GE.G(4,IG)) GO TO 20
      DO 15 IR=1,4
      Q=G(IR,IG)
      G(IR,IG)=G(IR,JG)
   15 G(IR,JG)=Q
      IS=I2G(IG)
      I2G(IG)=I2G(JG)
      I2G(JG)=IS
   20 CONTINUE
      RETURN
  100 WRITE(6,110) GCUT,NGQ
  110 FORMAT(' GCUT=',1PE12.4,' IS TOO BIG. STOPPING',I9)
      STOP
      END
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
      REAL*8 A1(3),A2(3),A3(3),B1(3),B2(3),B3(3),T(4)
      DIMENSION I2G(NGQ),G(4,NGQ)
      DIMENSION I2GG(NGQ),GG(4,NGQ),INDX(NGQ)
      INTEGER TNRM1,TNRM2,TNRM3
      WRITE(6,3001) (A1(I),A2(I),A3(I),I=1,3)
 3001 FORMAT(' A-VECTORS'/,3(' ',3F15.7/))
      CALL RECIPS(A,A1,A2,A3,B1,B2,B3)
      WRITE(6,3002) (B1(I),B2(I),B3(I),I=1,3)
 3002 FORMAT(' B-VECTORS'/,3(' ',3F15.7/))
      NG=1
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
c ***  temp check
c      write(6,*)' TNRM1*TNRM2*TNRM3 = ',TNRM1*TNRM2*TNRM3
c      write(6,*)'  NXYZ = ',NXYZ
c      write(6,*)'  NGQ = ',NGQ
c ***  temp check ; end 
c
      DO 10 I1=0,TNRM1-1
      I=I1-NRX/2
      DO 10 J1=0,TNRM2-1
      J=J1-NRY/2
      DO 10 K1=0,TNRM3-1
      K=K1-NRZ/2
      G2=0.D0
      DO 5 IR=1,3
      T(IR)=DBLE(I)*B1(IR)+DBLE(J)*B2(IR)+DBLE(K)*B3(IR)
c      T(IR)=( DBLE(I)-0.5d0 )*B1(IR)
c     &     +( DBLE(J)-0.5d0 )*B2(IR)
c     &     +( DBLE(K)-0.5d0 )*B3(IR)
    5 G2=G2+T(IR)*T(IR)
ccc      IF(G2.GT.GCUT) GO TO 10   !!! comment out for FULL grids
      IF(ABS(I).GT.IMAX) IMAX=ABS(I)
      IF(ABS(J).GT.JMAX) JMAX=ABS(J)
      IF(ABS(K).GT.KMAX) KMAX=ABS(K)
      DO 6 IR=1,3
    6 GG(IR,NG)=T(IR)
      GG(4,NG)=G2
      N1=I+1
      IF(I.LT.0) N1=N1+NRX
      N2=J+1
      IF(J.LT.0) N2=N2+NRY
      N3=K+1
      IF(K.LT.0) N3=N3+NRZ
      I2GG(NG)=N1+(N2-1)*NRX+(N3-1)*NRX*NRY
      NG=NG+1
      IF(NG.GT.NGQ+1) GO TO 100
   10 CONTINUE
      NG=NG-1
      WRITE(6,130) GCUT,NG,NXYZ*4.0*3.141593/3.0/8.0
  130 FORMAT(' GCUT=',F15.7,' NG=',I8,' NG EFFICIENT=',F15.7)
      WRITE(6,*) ' IMAX=',IMAX,' JMAX=',JMAX,' KMAX=',KMAX
C
C   REORDER THE G'S IN ORDER OF INCREASING MAGNITUDE.
      CALL INDEXX(NG,GG,INDX)
      DO 20 IG=1,NG
      G(1,IG)=GG(1,INDX(IG))
      G(2,IG)=GG(2,INDX(IG))
      G(3,IG)=GG(3,INDX(IG))
      G(4,IG)=GG(4,INDX(IG))
      I2G(IG)=I2GG(INDX(IG))
   20 CONTINUE
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
      SUBROUTINE FFT3BX(NRX,NRY,NRZ,NG,RHOG,WORK,
     &                  WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,
     &                  LX1,LX2,LY1,LY2,LZ1,LZ2)
C***********************************************************
C     (REAL SPACE-->G-SPACE)
C                                   (1990-04-12) OSAMU SUGINO
C     INPUT :RHO,NR?,NG,WSAVE?,IFAC?,L??
C     OUTPUT:RHOG
C     WORK  :WORK
C
      IMPLICIT REAL*8 (A-H,O-Z)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION RHOG(2,NG),WORK(2,NG)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NG),LX2(NG),LY1(NG),LY2(NG),LZ1(NG),LZ2(NG)
C
C     DO 15 IG=1,NG
C     WORK(1,IG)=RHOG(1,IG)
C     WORK(2,IG)=RHOG(2,IG)
C  15 CONTINUE
      CALL FFTSV1(NG,RHOG,WORK)
      CALL CFFT3B(NG,NRX*NRY,NRZ,WORK,RHOG,WSAVEZ,IFACZ)
C
      CALL FFTXYZ(NG,NRX*NRY,NRZ,WORK,RHOG,LZ1,LZ2)
      CALL CFFT3B(NG,NRZ*NRX,NRY,RHOG,WORK,WSAVEY,IFACY)
C
      CALL FFTXYZ(NG,NRZ*NRX,NRY,RHOG,WORK,LY1,LY2)
      CALL CFFT3B(NG,NRY*NRZ,NRX,WORK,RHOG,WSAVEX,IFACX)
C
      CALL FFTXYZ(NG,NRY*NRZ,NRX,WORK,RHOG,LX1,LX2)
      CALL FFTSV2(NG,RHOG,WORK)
C     FAC=1.0D0/DBLE(NG)
      FAC=1.0D0
      DO 40 I=1,NG
      RHOG(1,I)= WORK(1,I)*FAC
      RHOG(2,I)= WORK(2,I)*FAC
   40 CONTINUE
C
      RETURN
      END
C***********************************************************
      SUBROUTINE FFT3FX(NRX,NRY,NRZ,NG,RHOG,WORK,
     &                  WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,
     &                  LX1,LX2,LY1,LY2,LZ1,LZ2)
C***********************************************************
C     (G-SPACE -->REAL SPACE)
C                                   (1990-04-12) OSAMU SUGINO
C     INPUT :RHOG,NR?,NG,WSAVE?,IFAC?,L??
C     OUTPUT:WORK
C     WORK  :NONE
C
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION  RHOG(2,NG),WORK(2,NG)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NG),LX2(NG),LY1(NG),LY2(NG),LZ1(NG),LZ2(NG)
C
c ***  temp check
c      write(6,*)' in sub. FFT3FX '
c      write(6,*)' WSAVEX '
c      write(6,*)( WSAVEX(ir),ir=1,nrx )
c      write(6,*)' WSAVEY '
c      write(6,*)( WSAVEY(ir),ir=1,nry )
c      write(6,*)' WSAVEZ '
c      write(6,*)( WSAVEZ(ir),ir=1,nrz )
c      write(6,*)' RHOG -- input '
c      write(6,*)((RHOG(i,ig),i=1,2),ig=1,NG,100)
c      miya=13
c      if ( miya.eq.13 ) stop 'check in FFT3FX '
c ***  temp check: end
      CALL FFTSV1(NG,RHOG,WORK)
      CALL CFFT3F(NG,NRX*NRY,NRZ,WORK,RHOG,WSAVEZ,IFACZ)
C
      CALL FFTXYZ(NG,NRX*NRY,NRZ,WORK,RHOG,LZ1,LZ2)
      CALL CFFT3F(NG,NRZ*NRX,NRY,RHOG,WORK,WSAVEY,IFACY)
C
      CALL FFTXYZ(NG,NRZ*NRX,NRY,RHOG,WORK,LY1,LY2)
      CALL CFFT3F(NG,NRY*NRZ,NRX,WORK,RHOG,WSAVEX,IFACX)
C
      CALL FFTXYZ(NG,NRY*NRZ,NRX,WORK,RHOG,LX1,LX2)
      CALL FFTSV2(NG,RHOG,WORK)
      FAC=1.0D0/DBLE(NG)
C     FAC=1.0D0
      DO 40 I=1,NG
      RHOG(1,I)= WORK(1,I)*FAC
      RHOG(2,I)= WORK(2,I)*FAC
   40 CONTINUE
      RETURN
      END
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
      REAL*8 A1(3),A2(3),A3(3),T(4)
      DIMENSION R(4,LATQ),RR(LATQ),NTOT(LATQ)
      INTEGER TNRM1
      DATA NR/15/
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
      DO 60 I=1,IND
   60 PRINT 200,I,RR(I),NTOT(I)
200   FORMAT(10X,'    SHELL NO.',I4,1X,' LENGTH SQUARED',1X,F9.3,2X,
     1   'NO. OF VECTS.',I4)
      RETURN
  100 WRITE(6,110) RCUT, NLV, LATQ
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
      PARAMETER(LATQ=144)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION A1(3),A2(3),A3(3),SP(3,3),KG(3,LATQ),KZ(3,LATQ,48)
     &         ,NNK(LATQ),RKK(LATQ), A3WK(3)
      INTEGER*4 S(3,3,48)
      READ(5,*) QFR
CARE * TEMP:  FOR REMOVING LATTICE VECTORS IN A3 DIRECTION
          DO 1 K = 1, 3
    1     A3WK(K) =           A3(K)
CC  1     A3WK(K) = 3.0D+00 * A3(K)
C ***         NORMALLY, THE FOLLOWING A3WK SHOULD BE REPLACED BY A3.
          CALL SRPGEN(A1,A2,A3WK,SP)
C ***   TEMP END
c      CALL RARR2(SP,S,NROT,1,QFR,1.0D-12,1,RKK,KG,KZ,NNK,NKG)
      CALL RARR3(SP,S,NROT,1,QFR,1.0D-12,1,RKK,KG,KZ,NNK,NKG)
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
      PARAMETER(LATQ=144)
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
      PARAMETER(NAS=144, LATQ=144,NARF=LATQ)
      PARAMETER(NAD=72 )
      REAL*8 SK,WK,SS,CCO,PAI,RCO
CCC   REAL*8 SS1,SS2,SS3
      DIMENSION NJD(NAS),CCO(-NAD:NAD)
      DIMENSION SK(3,NAS),WK(NAS),KR(3,NARF)
      DIMENSION MM(3,10000),RCO(NAS,NARF),JDR(48,NAS)
      INTEGER*4 RG(3,3,48)
      PAI=4.D0*ATAN(1.D0)
C
CCC   REWIND 63
      READ(5,*) N
      WRITE(6,6600) N
 6600 FORMAT(/8X,
     &'  **** MESHK: N = ',I4)
      IF(NAD .LT. 2*N-1 ) STOP ' N IS TOO BIG... OR CHANGE NAD.'
C
      DO 98 IH=-(N-1),N-1
      CCO(IH)=COS(2.0D0*PAI*DFLOAT(IH)/DFLOAT(N))
   98 CONTINUE
      CALL MESHK2(NG,RG,NS,NI,SK,WK,KR,NRF,MM,RCO,JDR,N,NJD,CCO)
C ****
      READ(5,*) NDX, NDY, NDZ
C
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
      PARAMETER(NAS=144, LATQ=144,NARF=LATQ)
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
      READ(5,*) M1,M2,M3
      IF( M1*M1 + M2*M2 + M3*M3 .EQ.0) GO TO 101
      READ(5,*) MM1,MM2,MM3
      READ(5,*) J1X,J2X,J3X
      READ(5,*) J1Y,J2Y,J3Y
      READ(5,*) J1Z,J2Z,J3Z
C
      DO 1 I1=-M1,M1,MM1
      DO 2 I2=-M2,M2,MM2
      DO 3 I3=-M3,M3,MM3
                        IF(IS.GT.NAS) STOP ' MESHK2: N IS TOO BIG...'
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
      WK(IS)=1.0D0/DFLOAT(ND)
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
C************************************************************
C
C     SUBROUTINE TO GET REAL SPACE ENERGY EBNDW(:)
C     FROM BAND ENERGIES E_N,K(:)'S
C
C************************************************************
      SUBROUTINE BANDS(NBNDQ,NUMK,EOFK,
     & NKMESH,NEXPND,EBNDW,EW,RCOSIN)
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
      PARAMETER (IRLATQ=144,NARF=IRLATQ,NAS=144)
      DIMENSION EOFK(NBNDQ,NUMK),EBNDW(NBNDQ,IRLATQ),
     & EW(NBNDQ),RCOSIN(NAS,NARF)
C
      YMFAC=1.D0/DBLE(NKMESH)
      DO 10 K=1,NBNDQ
      EW(K)=0.D0
      DO 10 I=1,IRLATQ
        EBNDW(K,I)=0.D0
 10   CONTINUE
C
c **** check bands
c      write(6,*)' check in sub: BANDS' 
c      do 19 ik=1,numk
c      write(6,*)' ik = ',ik
c      write(6,*)' Enk = '
c      write(6,1119)(eofk(ib,ik)*27.212,ib=1,nbndq)
c   19 continue
c 1119 format(4d20.12)
c      miya=13
c      if ( miya.eq.13 ) stop
c **** check end
      DO 20 IK=1,NUMK
      DO 20 IB=1,NBNDQ
        EW(IB)=EW(IB)+RCOSIN(IK,1)*YMFAC*EOFK(IB,IK)
        DO 30 I=1,NEXPND
          EBNDW(IB,I)=EBNDW(IB,I)+RCOSIN(IK,I)*YMFAC*EOFK(IB,IK)
 30     CONTINUE
 20   CONTINUE
C
C     WRITE(6,1020) NEXPND
C1020 FORMAT(//,'    BANDS: NEXPND EBNDW(13 TO 16, J) = ',I4)
C     DO 9999 J=1,NEXPND
C9999 WRITE(6,1030) J, EBNDW(13,J)*27.212, EBNDW(14,J)*27.212
C    &               , EBNDW(15,J)*27.212, EBNDW(16,J)*27.212
C1030 FORMAT( (6X,I3,4D13.5)  )
C     WRITE(6,1032) ( EW(IB)*27.212, IB = 1, NBNDQ )
C1032 FORMAT(   '         EW = :'/ (6X,5D13.5) )
C     WRITE(6,*) '         LATTICE     RCOSIN(K,LATTICE):'
C     DO 50 IK=1,NUMK
C     DO 50 I=1,NEXPND
C       WRITE(6,1030) I,RCOSIN(IK,I)
C  50 CONTINUE
c ***** check 
c      write(6,*)' check in SUB. BANDS '
c      do 112 i=1,nexpnd
c      write(6,*)' ebndw for i = ',i
c  112 write(6,1010)(ebndw(ib,i),ib=1,nbndq)
c 1010 format(4d20.12)
c      miya=13
c      if ( miya.eq.13 ) stop  ! up to here  OK
c ***** check end
C
      RETURN
      END
C *********************************************************
C *                                                       *
C * THIS PROGRAM IS USED FOR CALCULATING FERMI ENERGY     *
C * AND BRILOUIN ZONE INTEGRAL.                           *
C *                                                       *
C *********************************************************
      SUBROUTINE DOS(PE,EBND,ZNEL,EF,EF1,EF2,Y,NDIM
     &              ,NDX,NDY,NDZ,NB1,NB2,NKR,NNG,IIL,IRL
     &              ,NSY,KZ,LATQ
     &              )
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION PE(NB1:NB2,NKR)
C *****  FOR GAUSSIAN TYPE BASES **********
CCC   DIMENSION KZ(3,NKR,NNG),NSY(NKR)
      DIMENSION KZ(3,LATQ,NNG),NSY(LATQ)
      REAL*8 Y(NDIM)
C
      I1=1
      I2=I1+IRL*(2*NDX+1)*(2*NDY+1)*(NDZ+1)*(NB2-NB1+1)
      I3=I2+IRL*(4*NDX+1)*(4*NDY+1)*(2*NDZ+1)*(NB2-NB1+1)
c      I4=I3+(IIL*NKR-1)/2+1
      I4=I3
c      I5=I4+(IIL*3*NKR*NNG-1)/2+1
CCC ********************
C     Y(I3)= NSY(LATQ)
C     Y(I4)= KZ(3,LATQ,48)
CCC ********************
C     ISEQ=I4
C     DO 894 IK=1,NKR
C     Y(I3+IK-1)=NSY(IK)
C     DO 894 ISY=1,NNG
C     Y(ISEQ  )=KZ(1,IK,ISY)
C     Y(ISEQ+1)=KZ(2,IK,ISY)
C     Y(ISEQ+2)=KZ(3,IK,ISY)
C     ISEQ=ISEQ+3
C 894 CONTINUE
CCC ********************
      if ( I1.gt.NDIM .or. I2.gt.NDIM ) then
      write(6,*)' I1 or I2 begger than NDIM'
      stop
      endif
      CALL       EDEF(PE,Y(I1),Y(I2),NSY,KZ,LATQ
     &               ,NDX,NDY,NDZ,NB1,NB2,NKR,NNG
     &               )
C
c      I5=I4+(IIL*3*NKR-1)/2+1
c      IDIM=NDIM-I4+1
      IDIM=NDIM-I3+1
      NXY60=2*NDZ*(4*NDX+1)*(4*NDY+1)
      if ( IDIM.LT.NXY60*13 ) then
      write(6,*)' Before FERMI, wrong allocation !'
      stop
      endif
cccc      CALL       FERMI(   Y(I1),Y(I2),Y(I5),IDIM,EF,EF1,EF2
      CALL       FERMI(   Y(I1),Y(I2),Y(I3),IDIM,EF,EF1,EF2
     &               ,NDX,NDY,NDZ,ZNEL,NB1,NB2)
C
C
      I5 =I4+(IIL*3*NKR-1)/2+1
      I6 =I5 +IRL*(NB2-NB1+1)*NKR
      I7 =I6 +(IIL*NKR-1)/2+1
      I8 =I7 +IRL*(2*NDX+1)*(2*NDY+1)*NKR*2
      I9 =I8 +IRL*(2*NDX+1)*(2*NDY+1)*NKR*2
c      NXY6=(4*(NDX+NDY)+2)*6
      NXY6=   NDZ*(2*NDX+1)*(2*NDY+1)
      I10=I9 +(IIL*2*NXY6-1)/2+1
      IDIM=NDIM-(I10-1)
      if ( IDIM.LE.0 ) then
      write(6,*)' INVALID DIMENSION before VINTEG !!! '
      stop
      endif
      CALL VINTEG(Y(I1),KZ,Y(I5),Y(I6),Y(I7),Y(I8),Y(I9),EF,Y(I10)
     &           ,IDIM,NDX,NDY,NDZ,NXY6,NKR,NB1,NB2,IRL)
      I7 =I6 +IRL*(NB2-NB1+1)*NKR
      I8 =I7 +(IIL*NKR-1)/2+1
      I9 =I8 +IRL*(4*NDX+1)*(4*NDY+1)*NKR*2
      I10=I9 +IRL*(4*NDX+1)*(4*NDY+1)*NKR*2
c      NXY60=(8*(NDX+NDY)+2)*6
      NXY60=2*NDZ*(4*NDX+1)*(4*NDY+1)
      I11=I10+(IIL*2*NXY60)/2
      IDIM=NDIM-(I11-1)
      if ( IDIM.LE.0 ) then
      write(6,*)' INVALID DIMENSION before VINTEG part 2!!! '
      stop
      endif
      CALL VINTEG(Y(I2),KZ,Y(I6),Y(I7),Y(I8),Y(I9),Y(I10),EF,Y(I11)
     &           ,IDIM,NDX*2,NDY*2,NDZ*2,NXY60,NKR,NB1,NB2,IRL)
      CALL ROMB(PE,NSY,LATQ,Y(I5),Y(I6),NKR,NB1,NB2,EBND)
C
      RETURN
      END
C
      SUBROUTINE EDEF(PE,EMESH1,EMESH2,NSY,KZ,LATQ
     &               ,NDX,NDY,NDZ,NB1,NB2,NKR,NNG
     &               )
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION EMESH1(  -NDX:NDX,    -NDY:NDY,  0:NDZ  ,NB1:NB2)
      DIMENSION EMESH2(-NDX*2:NDX*2,-NDY*2:NDY*2,0:NDZ*2,NB1:NB2)
      DIMENSION PE(NB1:NB2,NKR)
C ***** FOR GAUSSIAN BASES VERSION *******
CCC   DIMENSION KZ(3,NKR,NNG),NSY(NKR)
      DIMENSION KZ(3,LATQ,NNG),NSY(LATQ)
c      dimension xk(7),yk(7),zk(7),ekint(20)
c      data p2/6.28318530717958648D0/
C
CC    REWIND 13
CC    READ(13) NSY,KZ
C
C     REWIND 51
C     WRITE(51) (NB2-NB1+1),NKR,NNG
C     WRITE(51) PE,KZ,NSY
C
C     WRITE(6,*) 'NB1,NB2,NKR,NNG = ',NB1,NB2,NKR,NNG
C
c***** check
c      write(6,*)' E(l) (eV): Fourier components of En(k)' 
c      do 210 ib=nb1,nb2
c      write(6,*)' ib =  ',ib
c      write(6,*)' **** E(l) ****'
c      write(6,1010)(k,pe(ib,k)*27.212,k=1,nkr)
c  210 continue
c 1010 format(3('E(',i3,')=',d20.12))
c **** Check Ek interporation !!!!  Y. Miyamoto 9/22/95
c      xk(1)=0.5d0
c      yk(1)=0.5d0
c      zk(1)=0
c      xk(2)=0.5d0
c      yk(2)=-1.d0/3.d0
c      zk(2)=0
c      xk(3)=-1.d0/3.d0
c      yk(3)=-1.d0/3.d0
c      zk(3)=0
c      xk(4)=-1.d0/3.d0
c      yk(4)=-1.d0/6.d0
c      zk(4)=0
c      xk(5)=-1.d0/3.d0
c      yk(5)= 1.d0/3.d0
c      zk(5)=0
c      xk(6)=-1.d0/6.d0
c      yk(6)=-1.d0/6.d0
c      zk(6)=0
c      xk(7)=0
c      yk(7)=0
c      zk(7)=0
c      DO 121 iK=1,7
c      x=xk(ik)*p2
c      y=yk(ik)*p2
c      z=zk(ik)*p2
c      do 122 ib=nb1,nb2
c  122 ekint(ib)=0
c      DO 120 K=1,NKR
c      S=0.0D0
c      DO 130 ISY=1,NSY(K)
c      S=S+COS(X*KZ(1,K,ISY)+Y*KZ(2,K,ISY)+Z*KZ(3,K,ISY))
c  130 CONTINUE
c      DO 140 IB=NB1,NB2
c      Ekint(IB)=Ekint(IB)+PE(IB,K)*S
c  140 CONTINUE
c  120 CONTINUE
c      write(6,*)' ik k = ',ik,xk(ik),yk(ik),zk(ik)
c      write(6,*)'  Ek(',nb1,') - Ek(',nb2,')  (eV)'
c      write(6,1121)(Ekint(ib)*27.212,ib=nb1,nb2)
c  121 CONTINUE
c 1121 format(4d20.12)
c      write(6,*)' Then call MESHE '
c***** check end 
      CALL MESHE(PE,EMESH1,KZ,NSY,LATQ
     &          ,NDX,NDY,NDZ,NKR,NB1,NB2,NNG)
      CALL MESHE(PE,EMESH2,KZ,NSY,LATQ
     &          ,NDX*2,NDY*2,NDZ*2,NKR,NB1,NB2,NNG)
C
      RETURN
      END
      SUBROUTINE MESHE(PE,EMESH,KZ,NSY,LATQ
     &                ,NDX,NDY,NDZ,NKR,NB1,NB2,NNG)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION PE(NB1:NB2,NKR)
      DIMENSION EMESH(-NDX:NDX,-NDY:NDY,0:NDZ,NB1:NB2)
C **** FPOR GAUSSIAN BASES VERSION *********
CCC   DIMENSION KZ(3,NKR,NNG),NSY(NKR)
      DIMENSION KZ(3,LATQ,NNG),NSY(LATQ)
c *** for check
c      dimension xk(7),yk(7),zk(7),Ekint(20)
c *** for check end
      DATA P2/6.28318530717958648D0/
C
C
      DO 2 IB=NB1,NB2
      DO 2 IX=-NDX,NDX
      DO 2 IY=-NDY,NDY
      DO 2 IZ=0,NDZ
      EMESH(IX,IY,IZ,IB)=0.0D0
    2 CONTINUE
C
c **** Check Ek interporation !!!!  Y. Miyamoto 9/22/95
c      xk(1)=0.5d0
c      yk(1)=0.5d0
c      zk(1)=0
c      xk(2)=0.5d0
c      yk(2)=-1.d0/3.d0
c      zk(2)=0
c      xk(3)=-1.d0/3.d0
c      yk(3)=-1.d0/3.d0
c      zk(3)=0
c      xk(4)=-1.d0/3.d0
c      yk(4)=-1.d0/6.d0
c      zk(4)=0
c      xk(5)=-1.d0/3.d0
c      yk(5)= 1.d0/3.d0
c      zk(5)=0
c      xk(6)=-1.d0/6.d0
c      yk(6)=-1.d0/6.d0
c      zk(6)=0
c      xk(7)=0
c      yk(7)=0
c      zk(7)=0
c      DO 121 iK=1,7
c      x=xk(ik)*p2
c      y=yk(ik)*p2
c      z=zk(ik)*p2
c      do 122 ib=nb1,nb2
c  122 ekint(ib)=0
c      DO 120 K=1,NKR
c      S=0.0D0
c      DO 130 ISY=1,NSY(K)
c      write(6,*)' K, ISY = ',K,isy
c      write(6,*)' KZ = ',kz(1,k,isy),kz(2,k,isy),kz(3,k,isy)
c      S=S+COS(X*KZ(1,K,ISY)+Y*KZ(2,K,ISY)+Z*KZ(3,K,ISY))
c  130 CONTINUE
c      DO 140 IB=NB1,NB2
c      Ekint(IB)=Ekint(IB)+PE(IB,K)*S
c  140 CONTINUE
c  120 CONTINUE
c      write(6,*)' ik k = ',ik,xk(ik),yk(ik),zk(ik)
c      write(6,*)'  Ek(',nb1,') - Ek(',nb2,')  (eV)'
c      write(6,1121)(Ekint(ib)*27.212,ib=nb1,nb2)
c  121 CONTINUE
c 1121 format(4d20.12)
c **** Check end
C
      ADX=P2/DFLOAT(2*NDX)
      ADY=P2/DFLOAT(2*NDY)
      ADZ=P2/DFLOAT(2*NDZ)
      DO 10 IX=-NDX,NDX
      X=ADX*IX
      DO 10 IY=-NDY,NDY
      Y=ADY*IY
      DO 10 IZ=0,NDZ
      Z=ADZ*IZ
      DO 20 K=1,NKR
      S=0.0D0
      DO 30 ISY=1,NSY(K)
      S=S+COS(X*KZ(1,K,ISY)+Y*KZ(2,K,ISY)+Z*KZ(3,K,ISY))
   30 CONTINUE
      DO 40 IB=NB1,NB2
      EMESH(IX,IY,IZ,IB)=EMESH(IX,IY,IZ,IB)+PE(IB,K)*S
   40 CONTINUE
   20 CONTINUE
   10 CONTINUE
C
C
      RETURN
      END
C
      SUBROUTINE FERMI(EMESH1,EMESH2,Y,NDIM,EF,EF1,EF2
     &                ,NDX,NDY,NDZ,ZNEL,NB1,NB2)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION EMESH1(  -NDX:NDX,    -NDY:NDY,  0:NDZ  ,NB1:NB2)
      DIMENSION EMESH2(-NDX*2:NDX*2,-NDY*2:NDY*2,0:NDZ*2,NB1:NB2)
CCC   DIMENSION PE(NB1:NB2,NKR)
      REAL*8 Y(NDIM)
CCC   DATA MCYCL,EPS /100,1.0D-9/
      DATA MCYCL,EPS /100,1.0D-8/
C
c      NXY6=(4*(NDX+NDY)+2)*6
c      NXY60=(8*(NDX+NDY)+2)*6
      NXY6=   NDZ*(2*NDX+1)*(2*NDY+1)
      NXY60=2*NDZ*(4*NDX+1)*(4*NDY+1)
C
      ZNE=(ZNEL-2.0D0*(NB1-1))/2.0D0
CCC   ZNE=ZNEL-(NB1-1)
C
      ICYCL=0
 1000 CONTINUE
      ICYCL=ICYCL+1
      IF(ICYCL.GT.MCYCL) GO TO 900
      EF=(EF1+EF2)*0.5D0
      S=0.0D0
      DO 10 IB=NB1,NB2
      S1=0.0D0
      S2=0.0D0
      CALL FERGEN(EMESH1(-NDX  ,  -NDY,0,IB),Y,S1,EF
     &           ,NDX,NDY,NDZ,NXY6)
      CALL FERGEN(EMESH2(-NDX*2,-NDY*2,0,IB),Y,S2,EF
     &           ,NDX*2,NDY*2,NDZ*2,NXY60)
      SS=(4.0D0*S2-S1)/3.0D0
      S=S+SS
   10 CONTINUE
      D=ABS(S-ZNE)
      IF(D.LE.EPS) GO TO 2000
      IF(S.GT.ZNE) THEN
      EF2=EF
      ELSE
      EF1=EF
      END IF
      GO TO 1000
 2000 CONTINUE
CCC   WRITE(6,*)
CCC  &'                 ****  FERMI: EF CONVERGED.'
CCC   WRITE(6,200) EF*27.212, S
CC200 FORMAT(21X,'EF = ',D17.9,' CHARGE = ',D17.9)
C
      RETURN
  900 WRITE(6,*) ' EF IS NOT CONVERGED'
      WRITE(6,202) EF1*27.212, EF2*27.212, EF*27.212, S
  202 FORMAT('  EF1 EF2 EF S = ',4D13.5)
      STOP
      END
      SUBROUTINE FERGEN(EMESH,E,S,EF,NDX,NDY,NDZ,NXY6)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION EMESH(-NDX:NDX,-NDY:NDY,0:NDZ)
      DIMENSION E(NXY6,13)
      DO 20 IZ=0,NDZ-1
      NIS=0
      DO 30 IY=-NDY,NDY-1
      DO 30 IX=-NDX,NDX-1
C
      A1=MAX(EMESH(IX,IY  ,IZ  ),EMESH(IX+1,IY  ,IZ  ))
      A2=MAX(EMESH(IX,IY+1,IZ  ),EMESH(IX+1,IY+1,IZ  ))
      A1=MAX(A1,A2)
      A2=MAX(EMESH(IX,IY  ,IZ+1),EMESH(IX+1,IY  ,IZ+1))
      A1=MAX(A1,A2)
      A2=MAX(EMESH(IX,IY+1,IZ+1),EMESH(IX+1,IY+1,IZ+1))
      A1=MAX(A1,A2)
C
      A2=MIN(EMESH(IX,IY  ,IZ  ),EMESH(IX+1,IY  ,IZ  ))
      A3=MIN(EMESH(IX,IY+1,IZ  ),EMESH(IX+1,IY+1,IZ  ))
      A2=MIN(A2,A3)
      A3=MIN(EMESH(IX,IY  ,IZ+1),EMESH(IX+1,IY  ,IZ+1))
      A2=MIN(A2,A3)
      A3=MIN(EMESH(IX,IY+1,IZ+1),EMESH(IX+1,IY+1,IZ+1))
      A2=MIN(A2,A3)
C
      IF(EF.GT.A2.AND.EF.LT.A1) THEN
      NIS=NIS+1
      E(NIS,1)=EMESH(IX  ,IY  ,IZ  )
      E(NIS,2)=EMESH(IX  ,IY+1,IZ  )
      E(NIS,3)=EMESH(IX  ,IY  ,IZ+1)
      E(NIS,4)=EMESH(IX  ,IY+1,IZ+1)
      E(NIS,5)=EMESH(IX+1,IY  ,IZ  )
      E(NIS,6)=EMESH(IX+1,IY+1,IZ  )
      E(NIS,7)=EMESH(IX+1,IY  ,IZ+1)
      E(NIS,8)=EMESH(IX+1,IY+1,IZ+1)
      ELSE
      IF(EF.GE.A1) THEN
      S=S+2.0D0
      END IF
      END IF
   30 CONTINUE
      IF(NIS.GT.NXY6) GO TO 900
      IF(NIS.EQ.0) GO TO 20
      CALL EFINTP(E(1,1),E(1,2),E(1,3),E(1,4)
     &           ,E(1,5),E(1,6),E(1,7),E(1,8)
     &           ,E(1,9),E(1,10),E(1,11),E(1,12),E(1,13),EF,S,NIS)
   20 CONTINUE
      S=S/DFLOAT(8*NDX*NDY*NDZ)
      RETURN
  900 WRITE(6,*) 'NXY6 IS TOO SMALL'
      STOP
      END
      SUBROUTINE EFINTP(E1,E2,E3,E4,E5,E6,E7,E8
     &                 ,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)
      DIMENSION E5(NIS),E6(NIS),E7(NIS),E8(NIS)
      DIMENSION EE1(NIS),EE2(NIS),EE3(NIS),EE4(NIS)
      LOGICAL LB(NIS)
      CALL TETRA3(E1,E2,E3,E5,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      CALL TETRA3(E2,E3,E5,E7,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      CALL TETRA3(E2,E5,E6,E7,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      CALL TETRA3(E4,E3,E2,E8,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      CALL TETRA3(E3,E2,E8,E6,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      CALL TETRA3(E3,E8,E7,E6,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      RETURN
      END
      SUBROUTINE TETRA3(E1,E2,E3,E4,EE1,EE2,EE3,EE4,LB,EF,S,NIS)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)
      DIMENSION EE1(NIS),EE2(NIS),EE3(NIS),EE4(NIS)
      LOGICAL LB(NIS)
      DO 10 I=1,NIS
      A     =MAX(E1(I) ,E2(I) )
      EE2(I)=MAX(E3(I) ,E4(I) )
      EE3(I)=MIN(E1(I) ,E2(I) )
      B     =MIN(E3(I) ,E4(I) )
      EE1(I)=MAX(A     ,EE2(I))
      A     =MIN(A     ,EE2(I))
      EE4(I)=MIN(EE3(I),B     )
      B     =MAX(EE3(I),B     )
      EE2(I)=MAX(A     ,B     )
      EE3(I)=MIN(A     ,B     )
   10 CONTINUE
      CALL TETRA4(EE1,EE2,EE3,EE4,LB,S,EF,NIS)
      RETURN
      END
      SUBROUTINE TETRA4(E1,E2,E3,E4,LB,S,EF,NIS)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)
      LOGICAL LB(NIS)
      DATA THIRD/0.333333333333333333333333333D0/
C
      DO 10 IN=1,NIS
      IF((E1(IN).EQ.E2(IN)).AND.(EF.EQ.E2(IN))) THEN
      LB(IN)=.TRUE.
      ELSE
      LB(IN)=.FALSE.
      END IF
   10 CONTINUE
C
      DO 20 IN=1,NIS
      IF(EF.GE.E1(IN)) THEN
      S=S+THIRD
      END IF
   20 CONTINUE
C
      DO 30 IN=1,NIS
      IF((EF.GT.E2(IN)).AND.(EF.LT.E1(IN))) THEN
      S=S+THIRD
     & -THIRD*(E1(IN)-EF)*(E1(IN)-EF)*(E1(IN)-EF)
     & /(E1(IN)-E4(IN))/(E1(IN)-E3(IN))/(E1(IN)-E2(IN))
      END IF
   30 CONTINUE
C
      DO 40 IN=1,NIS
      IF((EF.GE.E3(IN)).AND.(EF.LE.E2(IN)).AND.(E2(IN).NE.E3(IN)).AND.
     &   (.NOT.LB(IN))) THEN
      S=S+((EF-E1(IN))*(EF-E4(IN))*(EF-E4(IN))
     & /(E3(IN)-E1(IN))/(E2(IN)-E4(IN))/(E1(IN)-E4(IN))
     & +(EF-E4(IN))*(E2(IN)-EF)*(EF-E3(IN))
     & /(E2(IN)-E4(IN))/(E2(IN)-E3(IN))/(E1(IN)-E3(IN))
     & +(EF-E3(IN))*(EF-E3(IN))/(E1(IN)-E3(IN))/(E2(IN)-E3(IN)))
     & *THIRD
      END IF
   40 CONTINUE
C
      DO 50 IN=1,NIS
      IF((EF.EQ.E3(IN)).AND.(E3(IN).EQ.E2(IN)).AND.(.NOT.LB(IN))) THEN
      S=S+THIRD*(E3(IN)-E4(IN))/(E1(IN)-E4(IN))
      END IF
   50 CONTINUE
C
      DO 60 IN=1,NIS
      IF((EF.GT.E4(IN)).AND.(EF.LT.E3(IN))) THEN
      S=S-(E4(IN)-EF)*(E4(IN)-EF)*(E4(IN)-EF)
     & /(E1(IN)-E4(IN))/(E2(IN)-E4(IN))/(E3(IN)-E4(IN))
     & *THIRD
      END IF
   60 CONTINUE
C
      RETURN
      END
C
      SUBROUTINE ROMB(PE,NSY,LATQ,VP1,VP2,NKR,NB1,NB2,EBND)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION PE(NB1:NB2,NKR)
      DIMENSION VP1(NB1:NB2,NKR),VP2(NB1:NB2,NKR)
CCC   DIMENSION NSY(NKR)
      DIMENSION NSY(LATQ)
      DATA THIRD/0.3333333333333333333333333333333D0/
      DO 10 IB=NB1,NB2
C     WRITE(6,100) IB
C 100 FORMAT(1H ,' IB=',I6)
      DO 10 K=1,NKR
      A=(VP2(IB,K)*4.0D0-VP1(IB,K))*THIRD
      EBND=EBND+A*PE(IB,K)*NSY(K)*2.0D0
CCC   EBND=EBND+A*PE(IB,K)*NSY(K)
      PE(IB,K)=A
C     WRITE(6,200) K,A
C 200 FORMAT(1H ,'K=',I5,3X,'PE=',1E29.16)
   10 CONTINUE
C     WRITE(6,300) EBND
C 300 FORMAT(1H ,'EBND=',1E29.16)
      RETURN
      END
      SUBROUTINE VINTEG(EMESH,KJ,VP,KINT,VMESH,DMESH,LNX
     &                 ,EF,Y,IDIM,NDX,NDY,NDZ,NXY6,NKR,NB1,NB2,IRL)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION VP(NB1:NB2,NKR),KJ(3,NKR),KINT(NKR),LNX(2,NXY6)
      DIMENSION EMESH(-NDX:NDX,-NDY:NDY,0:NDZ,NB1:NB2)
      DIMENSION VMESH(-NDX:NDX,-NDY:NDY,NKR,2)
      DIMENSION DMESH(-NDX:NDX,-NDY:NDY,NKR,2)
      REAL*8 Y(IDIM)
      DATA P2/6.28318530717958648D0/
C
      ADX=1.0D0/DFLOAT(NDX*2)*P2
      ADY=1.0D0/DFLOAT(NDY*2)*P2
      ADZ=1.0D0/DFLOAT(NDZ*2)*P2
C
      DO 1000 K=1,NKR
      CALL KINGEN(KJ(1,K),KINT(K))
 1000 CONTINUE
C
      DO 2000 IB=NB1,NB2
      DO 2000 K=1,NKR
      VP(IB,K)=0.0D0
 2000 CONTINUE
C
      DO 10 IZ=0,NDZ-1
      LMOD=MOD(IZ,2)+1
      KMOD=LMOD+1
      IF(IZ.EQ.0) KMOD=1
      GO TO (1,2,3),KMOD
C
    1 CALL VDEF(VMESH(-NDX,-NDY,1,1),DMESH(-NDX,-NDY,1,1),KJ
     &         ,IZ,NDX,NDY,NKR,ADX,ADY,ADZ)
      CALL VDEF(VMESH(-NDX,-NDY,1,2),DMESH(-NDX,-NDY,1,2),KJ
     &         ,IZ+1,NDX,NDY,NKR,ADX,ADY,ADZ)
      GO TO 100
    2 CALL VDEF(VMESH(-NDX,-NDY,1,2),DMESH(-NDX,-NDY,1,2),KJ
     &         ,IZ+1,NDX,NDY,NKR,ADX,ADY,ADZ)
      GO TO 100
    3 CALL VDEF(VMESH(-NDX,-NDY,1,1),DMESH(-NDX,-NDY,1,1),KJ
     &         ,IZ+1,NDX,NDY,NKR,ADX,ADY,ADZ)
  100 CONTINUE
      DO 20 IB=NB1,NB2
      GO TO (11,12),LMOD
C
   11 CONTINUE
      CALL INTEG(EMESH(-NDX,-NDY,IZ,IB),EMESH(-NDX,-NDY,IZ+1,IB)
     &           ,VMESH(-NDX,-NDY,1,1),VMESH(-NDX,-NDY,1,2)
     &           ,DMESH(-NDX,-NDY,1,1),DMESH(-NDX,-NDY,1,2)
     &           ,LNX,KJ,KINT,EF,Y,IDIM,VP
     &           ,NB1,NB2,NKR,NDX,NDY,NDZ,NXY6,IB,IRL)
      GO TO 200
C
   12 CONTINUE
      CALL INTEG(EMESH(-NDX,-NDY,IZ,IB),EMESH(-NDX,-NDY,IZ+1,IB)
     &           ,VMESH(-NDX,-NDY,1,2),VMESH(-NDX,-NDY,1,1)
     &           ,DMESH(-NDX,-NDY,1,2),DMESH(-NDX,-NDY,1,1)
     &           ,LNX,KJ,KINT,EF,Y,IDIM,VP
     &           ,NB1,NB2,NKR,NDX,NDY,NDZ,NXY6,IB,IRL)
  200 CONTINUE
   20 CONTINUE
   10 CONTINUE
C
      WK=1.0D0/DFLOAT(8*NDX*NDY*NDZ)
      DO 50 IB=NB1,NB2
      DO 50 K=1,NKR
      VP(IB,K)=VP(IB,K)*WK
   50 CONTINUE
C
      RETURN
      END
      SUBROUTINE KINGEN(KJ,KINT)
      IMPLICIT INTEGER(A-Z)
      DIMENSION KJ(3)
      IF(KJ(3).EQ.0) THEN
      IZ=0
      ELSE
      IZ=1
      END IF
      IF(KJ(2).EQ.0) THEN
      IY=0
      ELSE
      IY=1
      END IF
      IF(KJ(1).EQ.0) THEN
      IX=0
      ELSE
      IX=1
      END IF
      KINT=IZ+2*IY+4*IX+1
      RETURN
      END
      SUBROUTINE VDEF(VMESH,DMESH,KJ,IZ,NDX,NDY,NKR,ADX,ADY,ADZ)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION VMESH(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION DMESH(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION KJ(3,NKR)
C
      DO 10 K=1,NKR
      Z=ADZ*IZ*KJ(3,K)
      XX=ADX*KJ(1,K)
      YY=ADY*KJ(2,K)
      DO 10 IX=-NDX,NDX
      X=XX*IX+Z
      DO 10 IY=-NDY,NDY
      Y=YY*IY+X
      VMESH(IX,IY,K)=COS(Y)
      DMESH(IX,IY,K)=SIN(Y)
   10 CONTINUE
C
      RETURN
      END
 
      SUBROUTINE INTEG(EMESH1,EMESH2,VMESH1,VMESH2,DMESH1,DMESH2
     &                ,LNX,KJ,KINT,EF,Y,IDIM,VP
     &                ,NB1,NB2,NKR,NDX,NDY,NDZ,NXY6,IB,IRL)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION EMESH1(-NDX:NDX,-NDY:NDY),EMESH2(-NDX:NDX,-NDY:NDY)
      DIMENSION VMESH1(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION VMESH2(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION DMESH1(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION DMESH2(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION KJ(3,NKR),LNX(2,NXY6),KINT(NKR),VP(NB1:NB2,NKR)
      REAL*8 Y(IDIM)
      DATA PAI/3.14159265358979324D0/
C
      NIS=0
      DO 10 IX=-NDX,NDX-1
      DO 10 IY=-NDY,NDY-1
      A1=MAX(EMESH1(IX,IY  ),EMESH1(IX+1,IY  ))
      A2=MAX(EMESH1(IX,IY+1),EMESH1(IX+1,IY+1))
      A1=MAX(A1,A2)
      A2=MAX(EMESH2(IX,IY  ),EMESH2(IX+1,IY  ))
      A1=MAX(A1,A2)
      A2=MAX(EMESH2(IX,IY+1),EMESH2(IX+1,IY+1))
      A1=MAX(A1,A2)
      A2=MIN(EMESH1(IX,IY  ),EMESH1(IX+1,IY  ))
      A3=MIN(EMESH1(IX,IY+1),EMESH1(IX+1,IY+1))
      A2=MIN(A2,A3)
      A3=MIN(EMESH2(IX,IY  ),EMESH2(IX+1,IY  ))
      A2=MIN(A2,A3)
      A3=MIN(EMESH2(IX,IY+1),EMESH2(IX+1,IY+1))
      A2=MIN(A2,A3)
      IF(EF.LT.A1.AND.EF.GT.A2) THEN
      NIS=NIS+1
      LNX(1,NIS)=IX
      LNX(2,NIS)=IY
      ELSE
      IF(EF.GE.A1) THEN
      DO 20 K=1,NKR
      GO TO (1,2,3,4,5,6,7,8) KINT(K)
    1 VP(IB,K)=VP(IB,K)+2.0D0
      GO TO 100
    2 F3=DFLOAT(NDZ)/PAI/DFLOAT(KJ(3,K))
      VP(IB,K)=VP(IB,K)+2.0D0*F3*(DMESH2(IX,IY,K)-DMESH1(IX,IY,K))
      GO TO 100
    3 F2=DFLOAT(NDY)/PAI/DFLOAT(KJ(2,K))
      VP(IB,K)=VP(IB,K)+2.0D0*F2*(DMESH1(IX,IY+1,K)-DMESH1(IX,IY,K))
      GO TO 100
    4 F2=DFLOAT(NDY)/PAI/DFLOAT(KJ(2,K))
      F3=DFLOAT(NDZ)/PAI/DFLOAT(KJ(3,K))
      VP(IB,K)=VP(IB,K)+2.0D0*F2*F3
     &        *(VMESH2(IX,IY,K)-VMESH1(IX,IY,K)
     &         +VMESH1(IX,IY+1,K)-VMESH2(IX,IY+1,K))
      GO TO 100
    5 F1=DFLOAT(NDX)/PAI/DFLOAT(KJ(1,K))
      VP(IB,K)=VP(IB,K)+2.0D0*F1*(DMESH1(IX+1,IY,K)-DMESH1(IX,IY,K))
      GO TO 100
    6 F1=DFLOAT(NDX)/PAI/DFLOAT(KJ(1,K))
      F3=DFLOAT(NDZ)/PAI/DFLOAT(KJ(3,K))
      VP(IB,K)=VP(IB,K)+2.0D0*F1*F3
     &        *(VMESH2(IX,IY,K)-VMESH1(IX,IY,K)
     &         +VMESH1(IX+1,IY,K)-VMESH2(IX+1,IY,K))
      GO TO 100
    7 F1=DFLOAT(NDX)/PAI/DFLOAT(KJ(1,K))
      F2=DFLOAT(NDY)/PAI/DFLOAT(KJ(2,K))
      VP(IB,K)=VP(IB,K)+2.0D0*F1*F2
     &        *(VMESH1(IX,IY+1,K)-VMESH1(IX,IY,K)
     &         +VMESH1(IX+1,IY,K)-VMESH1(IX+1,IY+1,K))
      GO TO 100
    8 F1=DFLOAT(NDX)/PAI/DFLOAT(KJ(1,K))
      F2=DFLOAT(NDY)/PAI/DFLOAT(KJ(2,K))
      F3=DFLOAT(NDZ)/PAI/DFLOAT(KJ(3,K))
      VP(IB,K)=VP(IB,K)+2.0D0*F1*F2*F3
     &        *(DMESH1(IX,IY,K)-DMESH2(IX,IY,K)
     &         -DMESH1(IX,IY+1,K)+DMESH2(IX,IY+1,K)
     &         -DMESH1(IX+1,IY,K)+DMESH2(IX+1,IY,K)
     &         +DMESH1(IX+1,IY+1,K)-DMESH2(IX+1,IY+1,K))
  100 CONTINUE
   20 CONTINUE
      END IF
      END IF
   10 CONTINUE
C
      IF(NIS*24.GT.IDIM) GO TO 900
      I1=1
      I2=I1+IRL*NIS*12
      IF(NIS.EQ.0) GO TO 990
      CALL INTEGP(EMESH1,EMESH2,VMESH1,VMESH2,LNX,Y(I1),Y(I2)
     &           ,EF,VP,NB1,NB2,NDX,NDY,NKR,NIS,IB)
  990 CONTINUE
C
      RETURN
  900 WRITE(6,*) ' NDX OR NDY IS TOO SMALL'
      STOP
      END
C
      SUBROUTINE INTEGP(EMESH1,EMESH2,VMESH1,VMESH2,LNX,E,V
     &           ,EF,VP,NB1,NB2,NDX,NDY,NKR,NIS,IB)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION EMESH1(-NDX:NDX,-NDY:NDY),EMESH2(-NDX:NDX,-NDY:NDY)
      DIMENSION VMESH1(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION VMESH2(-NDX:NDX,-NDY:NDY,NKR)
      DIMENSION LNX(2,NIS),E(NIS,12),V(NIS,13),VP(NB1:NB2,NKR)
C
      DO 10 IS=1,NIS
      IX=LNX(1,IS)
      IY=LNX(2,IS)
      E(IS,1)=EMESH1(IX  ,IY  )
      E(IS,2)=EMESH1(IX  ,IY+1)
      E(IS,3)=EMESH2(IX  ,IY  )
      E(IS,4)=EMESH2(IX  ,IY+1)
      E(IS,5)=EMESH1(IX+1,IY  )
      E(IS,6)=EMESH1(IX+1,IY+1)
      E(IS,7)=EMESH2(IX+1,IY  )
      E(IS,8)=EMESH2(IX+1,IY+1)
   10 CONTINUE
C
      DO 20 K=1,NKR
      DO 30 IS=1,NIS
      IX=LNX(1,IS)
      IY=LNX(2,IS)
      V(IS,1)=VMESH1(IX  ,IY  ,K)
      V(IS,2)=VMESH1(IX  ,IY+1,K)
      V(IS,3)=VMESH2(IX  ,IY  ,K)
      V(IS,4)=VMESH2(IX  ,IY+1,K)
      V(IS,5)=VMESH1(IX+1,IY  ,K)
      V(IS,6)=VMESH1(IX+1,IY+1,K)
      V(IS,7)=VMESH2(IX+1,IY  ,K)
      V(IS,8)=VMESH2(IX+1,IY+1,K)
   30 CONTINUE
      S=0.0D0
      CALL TETRA0(E(1,1),E(1,2),E(1,3),E(1,4)
     &           ,E(1,5),E(1,6),E(1,7),E(1,8)
     &           ,V(1,1),V(1,2),V(1,3),V(1,4)
     &           ,V(1,5),V(1,6),V(1,7),V(1,8)
     &           ,E(1,9),E(1,10),E(1,11),E(1,12)
     &           ,V(1,9),V(1,10),V(1,11),V(1,12)
     &           ,V(1,13),EF,S,NIS)
      VP(IB,K)=VP(IB,K)+S
   20 CONTINUE
      RETURN
      END
      SUBROUTINE TETRA0(E1,E2,E3,E4,E5,E6,E7,E8
     &                 ,V1,V2,V3,V4,V5,V6,V7,V8
     &                 ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4
     &                 ,LB,EF,S,NIS)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS),E5(NIS),E6(NIS)
     &         ,E7(NIS),E8(NIS)
      DIMENSION V1(NIS),V2(NIS),V3(NIS),V4(NIS),V5(NIS),V6(NIS)
     &         ,V7(NIS),V8(NIS)
      DIMENSION EE1(NIS),EE2(NIS),EE3(NIS),EE4(NIS)
      DIMENSION VV1(NIS),VV2(NIS),VV3(NIS),VV4(NIS)
      LOGICAL LB(NIS)
      CALL TETRA1(E1,E2,E3,E5,V1,V2,V3,V5
     &           ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      CALL TETRA1(E2,E3,E5,E7,V2,V3,V5,V7
     &           ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      CALL TETRA1(E2,E5,E6,E7,V2,V5,V6,V7
     &           ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      CALL TETRA1(E4,E3,E2,E8,V4,V3,V2,V8
     &           ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      CALL TETRA1(E3,E2,E8,E6,V3,V2,V8,V6
     &           ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      CALL TETRA1(E3,E8,E7,E6,V3,V8,V7,V6
     &           ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      RETURN
      END
      SUBROUTINE TETRA1(E1,E2,E3,E4,V1,V2,V3,V4
     &                 ,EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)
      DIMENSION V1(NIS),V2(NIS),V3(NIS),V4(NIS)
      DIMENSION EE1(NIS),EE2(NIS),EE3(NIS),EE4(NIS)
      DIMENSION VV1(NIS),VV2(NIS),VV3(NIS),VV4(NIS)
      DIMENSION LB(NIS)
C
      DO 10 IN=1,NIS
      IF(E1(IN).GE.E2(IN)) THEN
      A1=E1(IN)
      B1=V1(IN)
      A2=E2(IN)
      B2=V2(IN)
      ELSE
      A1=E2(IN)
      B1=V2(IN)
      A2=E1(IN)
      B2=V1(IN)
      END IF
C
      IF(E3(IN).GE.E4(IN)) THEN
      C1=E3(IN)
      D1=V3(IN)
      C2=E4(IN)
      D2=V4(IN)
      ELSE
      C1=E4(IN)
      D1=V4(IN)
      C2=E3(IN)
      D2=V3(IN)
      END IF
C
      IF(A1.GE.C1) THEN
      EE1(IN)=A1
      VV1(IN)=B1
      A1=C1
      B1=D1
      ELSE
      EE1(IN)=C1
      VV1(IN)=D1
      END IF
C
      IF(A2.GE.C2) THEN
      EE4(IN)=C2
      VV4(IN)=D2
      ELSE
      EE4(IN)=A2
      VV4(IN)=B2
      A2=C2
      B2=D2
      END IF
C
      IF(A1.GE.A2) THEN
      EE2(IN)=A1
      VV2(IN)=B1
      EE3(IN)=A2
      VV3(IN)=B2
      ELSE
      EE2(IN)=A2
      VV2(IN)=B2
      EE3(IN)=A1
      VV3(IN)=B1
      END IF
C
   10 CONTINUE
C
      CALL TETRA2(EE1,EE2,EE3,EE4,VV1,VV2,VV3,VV4,LB,EF,S,NIS)
      RETURN
      END
      SUBROUTINE TETRA2(E1,E2,E3,E4,V1,V2,V3,V4,LB,EF,S,NIS)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)
      DIMENSION V1(NIS),V2(NIS),V3(NIS),V4(NIS)
      DIMENSION LB(NIS)
      LOGICAL LB
      DATA UNIT/0.083333333333333333333333333D0/
C
      DO 10 IN=1,NIS
      IF((E1(IN).EQ.E2(IN)).AND.(EF.EQ.E2(IN))) THEN
      LB(IN)=.TRUE.
      ELSE
      LB(IN)=.FALSE.
      END IF
   10 CONTINUE
C
      DO 20 IN=1,NIS
      IF(EF.GE.E1(IN)) THEN
      S=S+(V1(IN)+V2(IN)+V3(IN)+V4(IN))*UNIT
      END IF
   20 CONTINUE
C
      DO 30 IN=1,NIS
      IF((EF.GT.E2(IN)).AND.(EF.LT.E1(IN))) THEN
      S=S+(V1(IN)+V2(IN)+V3(IN)+V4(IN))*UNIT
     & -UNIT*(E1(IN)-EF)*(E1(IN)-EF)*(E1(IN)-EF)
     & /(E1(IN)-E4(IN))/(E1(IN)-E3(IN))/(E1(IN)-E2(IN))
     & *(4.0D0*V1(IN)+(EF-E1(IN))*((V4(IN)-V1(IN))/(E4(IN)-E1(IN))
     & +(V3(IN)-V1(IN))/(E3(IN)-E1(IN))
     & +(V2(IN)-V1(IN))/(E2(IN)-E1(IN))))
      END IF
   30 CONTINUE
C
      DO 40 IN=1,NIS
      IF((EF.GE.E3(IN)).AND.(EF.LE.E2(IN)).AND.(E2(IN).NE.E3(IN)).AND.
     &   (.NOT.LB(IN))) THEN
      S=S+UNIT*((EF-E1(IN))*(EF-E4(IN))*(EF-E4(IN))
     & /(E3(IN)-E1(IN))/(E2(IN)-E4(IN))/(E1(IN)-E4(IN))
     & *(3.0D0*V4(IN)+(EF-E4(IN))*(V2(IN)-V4(IN))/(E2(IN)-E4(IN))
     &        +V3(IN)+(EF-E4(IN))*(V1(IN)-V4(IN))/(E1(IN)-E4(IN))
     &               +(EF-E3(IN))*(V1(IN)-V3(IN))/(E1(IN)-E3(IN)))
     & +(EF-E4(IN))*(E2(IN)-EF)*(EF-E3(IN))
     & /(E2(IN)-E4(IN))/(E2(IN)-E3(IN))/(E1(IN)-E3(IN))
     & *(2.0D0*V4(IN)+(EF-E4(IN))*(V2(IN)-V4(IN))/(E2(IN)-E4(IN))
     &  +2.0D0*V3(IN)+(EF-E3(IN))*(V2(IN)-V3(IN))/(E2(IN)-E3(IN))
     &               +(EF-E3(IN))*(V1(IN)-V3(IN))/(E1(IN)-E3(IN)))
     & +(EF-E3(IN))*(EF-E3(IN))/(E1(IN)-E3(IN))/(E2(IN)-E3(IN))
     & *(3.0D0*V3(IN)+(EF-E3(IN))*(V2(IN)-V3(IN))/(E2(IN)-E3(IN))
     &        +V4(IN)+(EF-E3(IN))*(V1(IN)-V3(IN))/(E1(IN)-E3(IN))))
      END IF
   40 CONTINUE
C
      DO 50 IN=1,NIS
      IF((EF.EQ.E3(IN)).AND.(E3(IN).EQ.E2(IN)).AND.(.NOT.LB(IN))) THEN
      S=S+UNIT*(E3(IN)-E4(IN))/(E1(IN)-E4(IN))
     & *(V2(IN)+(E3(IN)-E4(IN))*(V1(IN)-V4(IN))/(E1(IN)-E4(IN))
     &   +V3(IN)+2.0D0*V4(IN))
      END IF
   50 CONTINUE
C
      DO 60 IN=1,NIS
      IF((EF.GT.E4(IN)).AND.(EF.LT.E3(IN))) THEN
      S=S-UNIT*(E4(IN)-EF)*(E4(IN)-EF)*(E4(IN)-EF)
     & /(E1(IN)-E4(IN))/(E2(IN)-E4(IN))/(E3(IN)-E4(IN))
     & *(4.0D0*V4(IN)+(EF-E4(IN))*((V3(IN)-V4(IN))/(E3(IN)-E4(IN))
     & +(V1(IN)-V4(IN))/(E1(IN)-E4(IN))
     & +(V2(IN)-V4(IN))/(E2(IN)-E4(IN))))
      END IF
   60 CONTINUE
C
      RETURN
      END
C******************************************************************
C
C     SUBROUTINE TO GET CHARGE DENSITY RHO(:)
C     FROM MOMENTUM SPACE CHARGE DENSITY RHO_N,K(:)
C
C*******************************************************************
      SUBROUTINE SUMCHR( MXBND, MBLK, NFL, NPFL, NRX, NRY, NRZ, NXYZ,
     &                   RHO, RHO1, RHO2, RHO3, IOWF, NG2Q,
     &                   NG2, J2G, P,
     &                   NKMESH, NEXPND, RCOSIN, NSY, IK, NBNDQ, NBND,
     &                   VINT, OMEGA, WSAVEX, WSAVEY, WSAVEZ,
     &                   IFACX, IFACY, IFACZ, LX1, LX2,
     &                   LY1, LY2, LZ1, LZ2                        )
C
      IMPLICIT REAL*8 (A-H,O-Z)
      COMPLEX*16 RHO1(NXYZ),RHO3(NXYZ),P(NG2Q,MXBND)
      DIMENSION RHO(NXYZ),RHO2(NXYZ),J2G(NG2Q)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ), IOWF(MBLK)
      PARAMETER (IRLATQ=144,NAS=144)
      DIMENSION RCOSIN(NAS,IRLATQ),VINT(NBNDQ,IRLATQ),NSY(IRLATQ)
C
      YMFAC=1.D0/DBLE(NKMESH)
      DO 10 IBLK = 1, MBLK
             ICHK1 = MXBND * IBLK
             IF(ICHK1.LT.NFL) GO TO 10
             IBI = MXBND * (IBLK-1)
             IF( IBI .GT. NFL + NPFL ) GO TO 100
        IF(IBLK.NE.MBLK) THEN
          MBN = MXBND
        ELSE
          MBN = MOD(NBND-1,MXBND) + 1
        END IF
ccc      READ(71,REC=IOWF(IBLK)) P
        DO 12 IB = 1, MBN
        KBND = IBI + IB
             IF( KBND .LE. NFL  .OR. KBND .GT. NFL+NPFL ) GO TO 12
          DO 20 JG=1,NXYZ
   20     RHO1(JG)=0.D0
          DO 21 IG=1,NG2
          JG=J2G(IG)
          RHO1(JG)=P(IG,IB)
   21     CONTINUE
          CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO1, RHO3,
     &                 WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                 LX1, LX2, LY1, LY2, LZ1, LZ2                )
          DO 30 JG=1,NXYZ
   30     RHO2(JG)=DBLE(DCONJG(RHO1(JG))*RHO1(JG))
          DO 40 I=1,NEXPND
          FAC=2.D0*RCOSIN(IK,I)*YMFAC*VINT(KBND,I)*DBLE(NSY(I))/OMEGA
            DO 50 JG=1,NXYZ
   50       RHO(JG)=RHO(JG)+FAC*RHO2(JG)
   40     CONTINUE
   12   CONTINUE
   10 CONTINUE
C
  100 CONTINUE
      RETURN
      END
C*
C*
      SUBROUTINE CHARGE(NRX,NRY,NRZ,NXYZ,NG,NGQ,G,TPIBA,RHO,RHOG,
     &  RHO1,RHO2,VGA,I2G,OMEGA,NTAUQ,NTYQ,NTYPE,TAU,NUMTY,NIDN,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
C     SUBROUTINE GENERATES ATOMIC CHARGE DENSITY CONFIGURATION
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
cc      DIMENSION RHO(NXYZ),VGA(NGQ),TAU(3,NTAUQ),G(4,NGQ),I2G(NGQ),
      DIMENSION RHO(NXYZ),VGA(NGQ,NTYQ),TAU(3,NTAUQ),G(4,NGQ),I2G(NGQ),
     &  NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
      COMPLEX*16 RHOG(NXYZ),RHO1(NXYZ),RHO2(NXYZ)
C
C     ARRAYS FOR FFT
C
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
C
c ****  temp check  Aug. 31 '95
c      write(6,*)
c      write(6,*)'  ---- check in sub.CHARGE ---- '
c      write(6,*)'  NG and NGQ = ',NG,NGQ
c      write(6,*)'  NXYZ       = ',NXYZ
c      if ( NG.gt.NGQ ) stop ' NGQ too small '
c      if ( NG.gt.NXYZ ) stop ' NXYZ too small '
c      write(6,*)
c ****  temp check end
c      REWIND 83
      DO 100 IG=1,NXYZ
        RHOG(IG)=(0.D0,0.D0)
 100  CONTINUE
      DO 200 ITY=1,NTYPE
c        READ(83) VGA
        NUM=ABS(NUMTY(ITY))
        RHOG(1)=RHOG(1)+NUM*VGA(1,ITY)
cc        RHOG(1)=RHOG(1)+NUM*VGA(1)
        DO 210 K=1,NUM
          ITAU=NIDN(K,ITY)
c ****  temp check Aug.31 '95
c          write(6,*)' ITAU = ',ITAU
c          write(6,*)' I2G(NG)=',I2G(NG)
c          write(6,*)' VGA(NG)=',VGA(NG)
c          write(6,*)' RHOG(NG)=',RHOG(NG)
c          write(6,*)' G(1,NG)=',G(1,NG)
c          write(6,*)' G(2,NG)=',G(2,NG)
c          write(6,*)' G(3,NG)=',G(3,NG)
c          write(6,*)' G(4,NG)=',G(4,NG)
c ****  check end
          DO 220 IG=2,NG
            JG=I2G(IG)
            SUM=G(1,IG)*TAU(1,ITAU)+G(2,IG)*TAU(2,ITAU)
     &         +G(3,IG)*TAU(3,ITAU)
            SUM=SUM*TPIBA
            RHOG(JG)=RHOG(JG)
     &     +DCMPLX(COS(SUM)*VGA(IG,ITY),-SIN(SUM)*VGA(IG,ITY))
cc     &     +DCMPLX(COS(SUM)*VGA(IG),-SIN(SUM)*VGA(IG))
 220      CONTINUE
 210    CONTINUE
 200  CONTINUE
      DO 300 IG=1,NXYZ
        RHOG(IG)=RHOG(IG)/OMEGA
 300  CONTINUE
      DO 400 IG=1,NXYZ
        RHO1(IG)=RHOG(IG)
 400  CONTINUE
      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
      DO 500 IG=1,NXYZ
        RHO(IG)=DBLE(RHO1(IG))
 500  CONTINUE
      SUMCD=0.D0
      DO 600 IG=1,NXYZ
        SUMCD=SUMCD+RHO(IG)
 600  CONTINUE
      SUMCD=SUMCD*OMEGA/DBLE(NXYZ)
      WRITE(6,*) '           ***   CHARGE: TOTAL CHARGE : ',SUMCD
C
      RETURN
      END
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
      DIMENSION  TAU(3,NTAUQ), RTAU(3,NTAUQ)
      COMMON /AVEC/  A1(3), A2(3), A3(3), B1(3), B2(3), B3(3)
     &             , COVA, ALAT
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
        WRITE(6,1000)
 1000   FORMAT(//'     ****** CRDAN:    HEXAGONAL ALPHA QUARTZ')
        DO 100 I = 1, NTAUQ
  100   WRITE(6,1100) I, ( RTAU(K,I), K = 1, 3 )
 1100   FORMAT(12X,' ATOM ',I4,' RTAU = ',3D13.5)
        WRITE(6,*) ' '
      ELSE
        WRITE(6,*) ' IND .NE. 2:  NOT PROGRAMMED IND = ', IND
      END IF
C
      RETURN
      END
