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
      include 'mpif.h'	
C
C  ***** !!!!  CARE ANOTHER NVIRTQ IN FRPRMN. !!!!
c      PARAMETER(NRX=45,NRY=75,NRZ=81,NXYZ=NRX*NRY*NRZ,
c     &          NGcont=INT( dfloat(NXYZ)/5.5d0 ),
c     &          NFLQ =35,NVIRTQ = 9, MXBND=NFLQ+NVIRTQ,
c     &          NBNDQ = NFLQ + NVIRTQ,
c     &          NGQ=NXYZ,NG2Q=NXYZ, NUMKQ=2 )
c      PARAMETER(NTAUQ=24,NTYQ=3,NUMQ=3, NCRQ=2, LREQ=3)
c
      PARAMETER( NUMQ=3, NCRQ=2, LREQ=3)
      PARAMETER(LATQ=800,MESHQ=1000)
C*******************************************************
c      PARAMETER(MBLKQ=(NBNDQ-1)/MXBND + 1  )
      PARAMETER(NTYQ2=4,ISPD=8)
      PARAMETER (IRLATQ=144,NARF=IRLATQ)
      PARAMETER (NAS=72,NAD=72)
cc      parameter ( ncpuq=22 )
c      include 'ncpuq.h'
c      parameter ( mxbnd2=(1.d0*mxbnd)/(1.d0*ncpuq)+1 )
c      parameter ( NTAUQ2=(1.d0*NTAUQ)/(1.d0*ncpuq)+1 )
c *** phase shift !!
      COMMON/PHASE/phshft
      COMMON/PULSE/t000,tw00,tau00  ! peak period width
      COMMON/EPOL/ExtX0,ExtY0,ExtZ0 ! Efield converted V/A-> a.u.
c
      COMMON/AVEC/A1(3),A2(3),A3(3),B1(3),B2(3),B3(3), COVA, ALAT
      COMMON/CONSTS/NG,NUMK,NBND,NTOT,OMEGA,GCUT2,ESELF,NTYPE
      COMMON/COMFIX/FATM(3,101),NFIX,IFATM(101)
      COMPLEX*16,allocatable,save,dimension(:)::RHO1,RHO2
     &      ,RHO3,RHO4,VG,RHOG
      complex*16,allocatable,save,dimension(:,:)::WORK2
c
c  *** for Sugino-FFT
c     &           ,WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c  *** for Kokubo-ASL-FFT
c     &           ,WSAVE_XYZ(NRX+NRY+NRZ)
c  *** for Kokubo-FFTW
       integer*8 plancfp,plancbp
c
c     &   ,EXTAU(NXYZ,NTAUQ)
c     &   ,EXTAU(NXYZ,NTAUQ,5)
c     &   ,EXTAU(NXYZ/6,NTAUQ,5)
c      complex*16
c     &   EXTAU(NGcont,5,NTAUQ),EXTBF(NGcont,5,NTAUQ2)
c ++++++
      complex*16,allocatable,save,dimension(:,:,:)::EXTAU,EXTBF
      COMPLEX*16,allocatable,save,dimension(:,:)::CWORK
C +++++
c      integer*4 displs,recvcnts
c      dimension displs(ncpuq),recvcnts(ncpuq)
      integer*4, allocatable,save, dimension(:):: displs,recvcnts
      real*8,allocatable,save,dimension(:,:)::Vloc
c ***  ! attention !  **********************************
      real*8,allocatable,save,dimension(:)::VG0,VG1,VG2,VG3,VGOLD,
     &            VG4,VG5
c **  ! attenstion
      REAL*8,allocatable,save,dimension(:)::RHO
      REAL*8,allocatable,save,dimension(:,:)::G,YLM
      real*8,allocatable,save,dimension(:,:,:)::G2
c *** for P-A using G-A
      real*8,allocatable,save,dimension(:,:,:)::GG2,G21,G22,G23,G24,G25
      real*8,allocatable,save,dimension(:,:,:)::YLM1,YLM2,YLM3,YLM4,YLM5
c *** for Sugino-FFT
c      DIMENSION   IFACX(30),IFACY(30),IFACZ(30),
c     &            LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &            LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo-ASL-FFT
c  *** LY2,LZ1,LZ2 are still necessary for ROTRA
c      DIMENSION LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c      DIMENSION IFAC_XYZ(60)
c  *** for Kokubo-FFTW-FFT
c  *** LY2,LZ1,LZ2 are still necessary for ROTRA
      integer,allocatable,save,dimension(:)::LY2,LZ1,LZ2
c ****  for WF storage
      real*8, allocatable,save,dimension(:)::wnorm
c
      INTEGER*4   S
      DIMENSION   S(3,3,48)
      DIMENSION CELLDM(6)
      integer,allocatable,save,DIMENSION(:)::I2G,NG2,NUMTY,MXOFL,NUMC
      real*8, allocatable,save,dimension(:,:)::VECK,RC0
      real*8, allocatable,save,dimension(:)::WGT,ZV
      real*8, allocatable,save,dimension(:,:)::COR
      integer,allocatable,save,dimension(:,:)::J2G,NGNL,NIDN
c ****  Large core memory is necessary for COEF.
c      COMPLEX*16  COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,10),
c     &            COEF0(NG2Q,MXBND,NUMKQ)
c      COMPLEX*16  COEF(NG2Q,MXBND2,NUMKQ),DCOEF(NG2Q,10),
c      COMPLEX*16  COEF(NG2Q,MXBND2,NUMKQ),DCOEF(NG2Q,15),
c      COMPLEX*16  COEF(NG2Q,MXBND2,NUMKQ),DCOEF(NG2Q,21),
c     &            COEF0(NG2Q,MXBND2,NUMKQ),CMAT(NBNDQ,NBNDQ)
      complex*16,allocatable,save,dimension(:,:,:)::coef,coef0
      complex*16,allocatable,save,dimension(:,:)::DCOEF,CMAT
c **  attension ! for local pseudo potential
      real*8, allocatable,save,dimension(:,:)::VGA,FORCE,TAU,
     &           force_ex
c ***  attnesion !
      real*8, allocatable,save,dimension(:,:)::TAU0,tau1,tau2
     & ,tau3,tau4,tau5
      real*8, allocatable,save,dimension(:,:)::WORK,CTAU
     &      ,DFORCE,SFORCE
      real*8, allocatable,save,dimension(:)::ZZ
      real*8, allocatable,save,dimension(:,:,:)::OUT
c +++ VPP A-vec independent  ; VPJ A-vec dependent
      real*8, allocatable,save,DIMENSION(:,:,:)::VPP
      integer,allocatable,save,dimension(:,:)::IOWF
      integer,allocatable,save,dimension(:,:,:)::IOVP
cc ******  necessary for Suzuki-Trotter
      real*8, allocatable,save,dimension(:,:,:,:)::VPP2  !  A-vec dependent!
c +++ for P-A VPP2 needs tobe P-A dependency
     &  ,VPP21,VPP22,VPP23,VPP24,VPP25
c +++ for P-A  VPJ needs update
      real*8, allocatable,save,DIMENSION(:,:)::VPJWORK ! parallel mesh intg
      real*8, allocatable,save,dimension(:,:,:,:,:)::VPJ,VPJ1,VPJ2
     &                                             ,VPJ3,VPJ4,VPJ5
c  *** for G-A version PSDATA need to be common!
      real*8, allocatable,save,dimension(:,:)::RAD
      real*8, allocatable,save,dimension(:,:,:)::PSPOT,PSPOT2,PHIL
c
      DIMENSION  RVEC(4,LATQ),RR(LATQ) ,NWK(LATQ)  ! fix 
c
      real*8, allocatable,save,dimension(:,:)::OCC,EE
     &  ,OCC0   !  old occupation number
      real*8, allocatable,save,DIMENSION(:)::EXPG
      real*8, allocatable,save,dimension(:,:)::GG,GDUMP
c **** for A-vector *****  2020 Y. Miyamoto
      real*8, allocatable,save,DIMENSION(:,:)::GDUMP1,GDUMP2
     &         ,GDUMP3,GDUMP4,GDUMP5,GDUMPd,EEd
c
      real*8, allocatable,DIMENSION(:,:)::ALPPP,BETAPP
c
      COMMON/COMOPT/IOPT(10,5)
      COMMON/SAITO2/IBUN(4,NTYQ2)
      COMMON/SMOOTH/ADUMP
c
      DIMENSION RKK(IRLATQ),KG(3,IRLATQ),KZ(3,IRLATQ,48),NSY(IRLATQ)
      DIMENSION RCOSIN(NAS,IRLATQ),CCO(-NAD:NAD),SK(3,NAS),WK(NAS)
c
      real*8, allocatable,save,DIMENSION(:,:)::EBNDW,VINT,EENL
      real*8, allocatable,save,dimension(:)::EW, fdump, Vplt,PE
      integer,allocatable,save,dimension(:,:)::JDR,MM
      dimension NJD(NAS)
      integer,allocatable,save,dimension(:)::NBSEQ
      real*8, allocatable,save,dimension(:,:,:)::FXNL,FYNL,FZNL
c
      integer status(MPI_STATUS_SIZE)
      common/tmod/itmod
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
c      dimension nbegin(0:ncpuq),nend(0:ncpuq)
c      common/cputask2/nbegint(0:ncpuq),nendt(0:ncpuq),ncpu2
c      dimension nbegint(0:ncpuq),nendt(0:ncpuq)
c      common/cputask3/nbegintt(0:ncpuq),nendtt(0:ncpuq),ncpu3
c      dimension nbegintt(0:ncpuq),nendtt(0:ncpuq)
c      common/cputask4/mshbegin(0:ncpuq),mshend(0:ncpuq),ncpu4
c      dimension mshbegin(0:ncpuq),mshend(0:ncpuq)
      integer, allocatable, save, dimension(:):: nbegin,nend
      integer, allocatable, save, dimension(:):: nbegint,nendt
      integer, allocatable, save, dimension(:):: nbegintt,nendtt
      integer, allocatable, save, dimension(:):: mshbegin,mshend
c
      logical VPJGENdo
      common/ExtDyn/VPJGENdo
c ***  for MD calculations
      real*8, allocatable,save,dimension(:)::atmss
      real*8, allocatable,save,dimension(:,:)::velo,fold
c *** for extra charge and external potnetial
      complex*16,allocatable,save,dimension(:)::VEXT,REXT,WEXT
c ***
c  ::: for macroscopic current
      real*8, allocatable,save,dimension(:)::RHOAX,RHOAY,RHOAZ
      real*8, allocatable,save,dimension(:,:)::PX,PY,PZ
c
      DATA IFIL2,IFIL3,IFIL4,IFIL5,IFIL6,IFIL7
     &     /  30,   32,   33,   34,   35,   36/
c      data dt/0.2d0/   ! in atomic unit = hbar**3/( m0*e**4 )
c                          = hbar/ Hartree
c      data ntstep/400/  ! time steps
C
c *******
      call MPI_Init(ierr)
c *******
      call MPI_COMM_SIZE(MPI_COMM_WORLD,ncpu,ierr)
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      call prof_init(my_rank)
      call prof_start(15)
c ** read size.data here!
      if (my_rank.eq.0 ) then

      read(54,*)NRX,NRY,NRZ  ! read mesh
      NXYZ=NRX*NRY*NRZ
      NGcont=INT( dfloat(NXYZ)/5.5d0 ) ! contracted G for nonlocal pot
      read(54,*)NGQdummy,NG2Qdummy  ! read dummies
      NGQ=NXYZ
      NG2Q=NXYZ
      read(54,*)NUMKQ  ! read # of irreducible k-points
      read(54,*)NFLQ,NVIRTQ     ! read full band and others
      NBNDQ=NFLQ+NVIRTQ
      MXBND=NBNDQ
      MBLKQ=(NBNDQ-1)/MXBND + 1 
      read(54,*)NTAUQ,NTYQ      ! read # of atoms and atomic types
c
      endif
c
      if (my_rank.eq.0 ) call bannerTDDFT
c *** this is for openmp only
c      call clock0
cc
      call MPI_Bcast(NRX,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NRY,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NRZ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NXYZ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NGcont,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NGQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NG2Q,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NUMKQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NFLQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NVIRTQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NBNDQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(MXBND,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(MBLKQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NTAUQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NTYQ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
c
c
      ncpu=ncpu-1  ! define # of slave CPUs
      ncpuq=ncpu+1
      allocate ( nbegin(0:ncpuq),nend(0:ncpuq) )
      allocate ( nbegint(0:ncpuq),nendt(0:ncpuq) )
      allocate ( nbegintt(0:ncpuq),nendtt(0:ncpuq) )
      allocate ( mshbegin(0:ncpuq),mshend(0:ncpuq) )
      ncpu2=ncpu
      ncpu3=ncpu
      ncpu4=ncpu
      mxbnd2=(1.d0*mxbnd)/(1.d0*ncpuq)+1 
      NTAUQ2=(1.d0*NTAUQ)/(1.d0*ncpuq)+1 
      allocate ( RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),RHO4(NXYZ),
     &            VG(NXYZ),RHOG(NXYZ),WORK2(NG2Q,7) )
      allocate( EXTAU(NGcont,5,NTAUQ),EXTBF(NGcont,5,NTAUQ2) )
      allocate( displs(ncpuq),recvcnts(ncpuq) )
      allocate ( CWORK(NXYZ,10) )
      allocate( Vloc(NXYZ,5) )
      allocate(  VG0(NXYZ),VG1(NXYZ),VG2(NXYZ),VG3(NXYZ),VGOLD(NXYZ),
     &            VG4(NXYZ),VG5(NXYZ) )
      allocate( RHO(NXYZ),G(4,NGQ),G2(4,NG2Q,NUMKQ),YLM(NGcont,16) )
c *** for P-A using G-A
      allocate( GG2(4,NG2Q,NUMKQ),
     &          G21(4,NG2Q,NUMKQ),G22(4,NG2Q,NUMKQ),G23(4,NG2Q,NUMKQ),
     &          G24(4,NG2Q,NUMKQ),G25(4,NG2Q,NUMKQ)  )
      allocate(  YLM1(NGcont,16,NUMKQ),YLM2(NGcont,16,NUMKQ),
     &          YLM3(NGcont,16,NUMKQ),
     &          YLM4(NGcont,16,NUMKQ),YLM5(NGcont,16,NUMKQ)  )
c  *** LY2,LZ1,LZ2 are still necessary for ROTRA
      allocate( LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ) )
      allocate( WNORM(NXYZ) )
      allocate(  I2G(NGQ),J2G(NG2Q,NUMKQ),NG2(NUMKQ),
     &            VECK(3,NUMKQ),WGT(NUMKQ),
     &            NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
     &            ZV(NTYQ),RC0(NCRQ,NTYQ),
     &            COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ) )
      allocate(  NGNL(NTYQ,NUMKQ) )
c ***
      allocate(  COEF(NG2Q,MXBND2,NUMKQ),DCOEF(NG2Q,21),
     &            COEF0(NG2Q,MXBND2,NUMKQ),CMAT(NBNDQ,NBNDQ) )
c
c **  attension ! for local pseudo potential
      allocate(  VGA(NGQ,NTYQ),
     &  FORCE(3,NTAUQ),TAU(3,NTAUQ),OUT(NBNDQ,3,NUMKQ),
     &           force_ex(3,NTAUQ),
c ***  attnesion !
     &  TAU0(3,ntauq),tau1(3,ntauq),tau2(3,ntauq),tau3(3,ntauq),
     &  tau4(3,ntauq),tau5(3,ntauq),
     &           WORK(6,NTAUQ), CTAU(3,NTAUQ)  )
      allocate(  DFORCE(3,NTAUQ),SFORCE(3,NTAUQ),ZZ(NTAUQ) )
c +++ VPP A-vec independent  ; VPJ A-vec dependent
      allocate(   VPP(3,4,NTYQ),VPJ(NGcont,3,4,NTYQ,NUMKQ)
     &          ,IOWF(MBLKQ,NUMKQ),IOVP(2,NTYQ,NUMKQ)
cc ******  necessary for Suzuki-Trotter
     &          ,VPP2(16,3,NTYQ,NUMKQ) !  A-vec dependent!
c +++ for P-A VPP2 needs tobe P-A dependency
     &  ,VPP21(16,3,NTYQ,NUMKQ),VPP22(16,3,NTYQ,NUMKQ)
     &  ,VPP23(16,3,NTYQ,NUMKQ),VPP24(16,3,NTYQ,NUMKQ)
     &  ,VPP25(16,3,NTYQ,NUMKQ)   )
c +++ for P-A  VPJ needs update
      allocate(  VPJWORK(NGcont,3) ) ! parallel mesh intg
      allocate(  VPJ1(NGcont,3,4,NTYQ,NUMKQ)
     &         ,VPJ2(NGcont,3,4,NTYQ,NUMKQ)
     &         ,VPJ3(NGcont,3,4,NTYQ,NUMKQ)
     &         ,VPJ4(NGcont,3,4,NTYQ,NUMKQ)
     &         ,VPJ5(NGcont,3,4,NTYQ,NUMKQ)  )
c
c  *** for G-A version PSDATA need to be common!
      allocate(  RAD(MESHQ,NTYQ2),PSPOT(MESHQ,ISPD,NTYQ2),
     &    PSPOT2(MESHQ,ISPD,NTYQ2),PHIL(MESHQ,4,NTYQ2)  )
      allocate( OCC(NBNDQ,NUMKQ),EE(NBNDQ,NUMKQ),
     & OCC0(NBNDQ,NUMKQ) )  !  old occupation number
      allocate(  GG(4,NGQ),EXPG(NGQ),GDUMP(NG2Q,NUMKQ) )
c
c **** for A-vector *****  2020 Y. Miyamoto
      allocate( GDUMP1(NG2Q,NUMKQ),GDUMP2(NG2Q,NUMKQ)
     &         ,GDUMP3(NG2Q,NUMKQ),GDUMP4(NG2Q,NUMKQ)
     &         ,GDUMP5(NG2Q,NUMKQ) )
      allocate(   GDUMPd(NG2Q,NUMKQ),EEd(NBNDQ,NUMKQ) )
c
c
      allocate(  ALPPP(4,NTYQ),BETAPP(4,NTYQ) )
c
      allocate( EBNDW(NBNDQ,IRLATQ),EW(NBNDQ),PE(NBNDQ*IRLATQ),
     &     VINT(NBNDQ,IRLATQ),JDR(48,NAS),MM(3,10000) )
      allocate(  EENL(NBNDQ,NUMKQ),FXNL(NTAUQ,NBNDQ,NUMKQ),
     &          FYNL(NTAUQ,NBNDQ,NUMKQ),FZNL(NTAUQ,NBNDQ,NUMKQ) )
      allocate(  NBSEQ(NUMKQ),fdump(NXYZ), Vplt(NXYZ)  )
c ***  for MD calculations
      allocate( atmss(ntauq),velo(3,ntauq),fold(3,ntauq) )
c *** for extra charge and external potnetial
      allocate( VEXT(NXYZ),REXT(NXYZ),WEXT(NXYZ) )
c *** for macroscopic current
      allocate( RHOAX(NXYZ),RHOAY(NXYZ),RHOAZ(NXYZ) )
      allocate( PX(NBNDQ,NUMKQ),PY(NBNDQ,NUMKQ),PZ(NBNDQ,NUMKQ) )
c *** preparing phase!!
      pi=dacos(-1.d0)
c      phshft=1.d0*pi
      phshft=0.d0*pi
      if ( my_rank.eq. 0 ) write(6,*)' PHASE shift of pulse = ',phshft
c:
c *** temp check
c      write(6,*)' my_rank=',my_rank,' Main routine has started!'
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c      miya=13
c      if ( miya.eq.13 ) stop
c *** temp check ; end
      if ( ncpuq.lt.ncpu  ) then
       if ( my_rank.eq.0 )
     &    write(6,*)' Too many CPUs: ncpuq should be ',ncpu
       call MPI_Finalize(ierr)
       stop
      endif
c **************************
c     read laser pulse parameter from FF53
      if (my_rank.eq.0) then
       read(53,*)wlength   ! optical wavelength     (nm)
       tw00=wlength/2.99792458d+02 ! period of optical oscillation
       read(53,*)t000       ! peak position of pulse (fs)
       read(53,*)tau00     ! half of pulse width    (fs)
      endif
      call MPI_Bcast(tw00,1,MPI_DOUBLE_PRECISION
     &  ,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(t000,1,MPI_DOUBLE_PRECISION
     &  ,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(tau00,1,MPI_DOUBLE_PRECISION
     &  ,0,MPI_COMM_WORLD,ierr)
c      read Efield vector in (V/A) from FF53
      if (my_rank.eq.0) then
       read(53,*) ExtX0,ExtY0,ExtZ0 ! Efield in V/A
      endif
      call MPI_Bcast(ExtX0,1,MPI_DOUBLE_PRECISION
     &  ,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(ExtY0,1,MPI_DOUBLE_PRECISION
     &  ,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(ExtZ0,1,MPI_DOUBLE_PRECISION
     &  ,0,MPI_COMM_WORLD,ierr)
c  *** converted V/A -> a.u.
      ExtX0=ExtX0/(13.6d0*2)*0.529177d0 ! converted in a.u.
      ExtY0=ExtY0/(13.6d0*2)*0.529177d0
      ExtZ0=ExtZ0/(13.6d0*2)*0.529177d0
c
C *******************************************************************
C
c      if ( ntyq.lt.2 ) then
c       write(6,*)' WARNNING! NTYQ should be bigger than 2.'
c       stop
c      endif
C
      IF( MXBND*NG2Q .LT. NBNDQ*NBNDQ ) STOP
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
     &            GCUT2,GRAT, KCONT,MXBND0,dt,ntstep)
C
c ******* distribute task to CPUs
      if ( my_rank.eq.0 ) then
       write(6,*)' This is a load distribution for band indices.'
      endif
      call cpu_block(mxbnd0,ncpu,nbegin,nend,ncpuq)
c **** 
      if ( my_rank.eq.0 ) then
       write(6,*)' The next is a load distribution for atomic sites.'
      endif
      call cpu_block(ntauq,ncpu,nbegint,nendt,ncpuq)
c ***
      if ( my_rank.eq.0 ) then
       write(6,*)' The next is a load distribution for mesh of PP.'
      endif
      call cpu_block(meshq,ncpu,mshbegin,mshend,ncpuq)
c ***
c *** Next are for MPI_Allgatherv in frprmn_tm12_check.f
       nlengt=nendt(0)-nbegint(0)+1
       recvcnts(1)=5*nlengt*(NGcont)
       displs(1)=0
      do icpu=1,ncpu
       iicpu=icpu+1
       nlengt=nendt(icpu)-nbegint(icpu)+1
       recvcnts(iicpu)=5*nlengt*(NGcont)
       displs(iicpu)=displs(icpu)+recvcnts(icpu)
      enddo
c      displs(ncpu+2)=displs(ncpu+1)+recvcnts(ncpu+1)
c    **temp check
c      if ( my_rank.eq.0 ) then
c       do icpu=0,ncpu
c        iicpu=icpu+1
c        write(6,2777)iicpu,recvcnts(iicpu),iicpu,displs(iicpu)
c       enddo
c 2777  format('recvcnts(',i3,')=',i10,' displs(',i3,')=',i12 ) 
c      endif
c    ** temp check end
c ***
c ***
      if ( my_rank.eq.0 ) then
       write(6,*)' The next is a load distribution',
     &     '      for double loops of atomic sites.'
      endif
      ntdbl=( ntauq*(ntauq+1) )/2
      call cpu_block(ntdbl,ncpu,nbegintt,nendtt,ncpuq)
c **** check mxbnd2!!!
      nbleng=nend(my_rank)-nbegin(my_rank)+1
      if ( mxbnd2.lt.nbleng ) then
        write(6,*)' my_rank',my_rank,' mxbnd2 should be ',nbleng
      endif
c *******
      MBLK = MBLKQ
      if ( my_rank.eq.0 ) then
      WRITE(6,*) '                               **  MBLK = ',MBLK
      endif
      ISUM=0
      DO 3 IK=1,NUMKQ
      DO 3 I=1,MBLK
      ISUM=ISUM+1
    3 IOWF(I,IK)=ISUM
C
C
c **** not necessary
c      if ( NFLQ+NVIRTQ.lt.9 ) then
c        write(6,*)' NFLQ + NVIRTQ must be bigger than 9 '
c        stop
c      endif
c        IF( NFL .GT. NFLQ ) STOP ' **  NFL TOO LARGE...STOPPING'
c        IF( NPFL .GT. NVIRTQ ) STOP ' **  NPFL TOO LARGE...STOPPING'
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
c      CALL cpu_time(TIM)
      if ( my_rank.eq.0 ) then
      WRITE(6,7000) TIM
 7000 FORMAT(23X,'****  CPU TIME BFR CRYST: ',F15.7,' SEC')
      endif
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
     &            SK, WK, JDR, MM, NJD, NDX, NDY, NDZ, MXOFL,atmss )
c *** ADUMP: Smoothing factor for RHO & VHXC
      ADUMP= GCUT2/( ( PI*2.D0/CELLDM(1) )**2 )
      ATEMP= ADUMP/10.d0
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' just after CRYST smoothing exponent factor'
c       write(6,'(4F22.16)')
c     & ( (G(4,ig)-ADUMP)/ATEMP,ig=1,NXYZ,500 )
c      endif
c *** temp check
      do ig=1,NXYZ
c      wari=dexp( (G(4,ig)-4*ADUMP)/ATEMP ) + 1.d0
      wari=dexp( (G(4,ig)-ADUMP)/ATEMP ) + 1.d0
      fdump(ig)=1.d0/wari
      enddo
C
      CALL CLOCK(TIM)
c      CALL cpu_time(TIM)
      if ( my_rank.eq.0 ) then
      WRITE(6,7002) TIM
 7002 FORMAT(23X,'****  CPU TIME AFTR CRYST: ',F15.7,' SEC')
      endif
c **** temp check
c      miya=13
c      if ( miya.eq.13 ) stop
c **** temp check : end
C
      TPIBA=2.D0*PI/CELLDM(1)
C
c      CALL INITPW( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NGQ, NG,
      CALL INITPW( MXBND2,MBLK, NRX, NRY, NRZ, NXYZ, NGQ, NG,
     &             NG2Q, NG2, NBNDQ, NBNDQ, NUMK, NUMKQ,
c     &             COEF, DCOEF, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
c     &      COEF, COEF0,DCOEF, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
     &      COEF, COEF0, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
     &             OMEGA, ZVAL, IOWF, RHO, RHOG, RHO1, RHO2, RHO3,
     &     WGT, OCC, OCC0,NTOT, S, NFL, NPFL, NKMESH, NEXPND,
c **** for Sugino-FFT
c     &     RCOSIN, NSY, VINT,NBSEQ2, WSAVEX, WSAVEY, WSAVEZ, IFACX,
c     &     IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,MXBND0,NBSEQ,
c **** for Kokubo-ASL-FFT
c     &     RCOSIN, NSY, VINT,NBSEQ2, WSAVE_XYZ, IFAC_XYZ,
c **** for Kokubo-FFTW
     &     RCOSIN, NSY, VINT,NBSEQ2, plancfp,plancbp,
     &     MXBND0,NBSEQ,
     &     RHO4,GG,EXPG,GDUMP,GMHF
c
     &   ,nbegin,nend,ncpuq,ncpu  )
C
c  *** temp check
      if (my_rank.eq.0 ) then
       write(6,*)' after calling INITPW '
       do IK=1,NUMK
c        write(6,*)' G2 at ik=',IK
c        do IG=1,NXYZ,5000
c         write(6,'(4F22.16)')(G2(J,IG,IK),J=1,4)
c        enddo
       write(6,*)' IK NG2(IK) = ',IK,NG2(IK)
       enddo
      endif
c  *** temp check end
c
c       call zero(rho4,nxyz)
c ****  temp check
c      write(6,*)'  After reading RHO from file ' 
c      write(6,*)'  RHO in real space !! '
c      write(6,1919)( RHO(IR),IR=1,NXYZ)
c ****  temp check end
C
      if (my_rank.eq.0 ) then
      write(6,*)' preparing external potential !'
      endif
      call rexgen(nrx,nry,nrz,nxyz,rext,OMEGA,A1,A2,A3,my_rank)
c *** make extra potential from REXT by FFT
c ** temp check
c      if (my_rank.eq.0 ) then
c      write(6,*)' check REXT after rexgen '
c      write(6,*)( REXT(IG),IG=1,NXYZ,100 )
c      endif
c ** temp check : end
C
      do IG=1,NXYZ
       WEXT(IG)=0.d0
      enddo
      if ( my_rank.eq.0 ) then
      write(6,*)'  Now make rho in G-space '
      endif
c ** for Sugino FFT
c         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, REXT, WEXT,
c     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c         CALL FFT3FX_ASL( NRX, NRY, NRZ, NXYZ, REXT, WEXT,
c     &                WSAVE_XYZ, IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3FX_fftw(NXYZ,REXT,plancfp,plancbp)
c ** for Kokubo fftw ASL compatible
      call FFT3FX_fftwASL(NRX,NRY,NRZ,NXYZ,REXT,WEXT
     &      ,plancfp,plancbp)
      TPIBA2=TPIBA**2
      FPI=4.d0*dacos(-1.d0)
c ***
      if ( my_rank.eq.0 ) then
      write(6,*)' Total excessive charge again = ',REXT(1)*omega
      endif
c *** this was OK !!
c ** temp check
c      if ( my_rank.eq.0 ) then
c      write(6,*)' check REXT after FFT3FX '
c      write(6,*)( REXT(IG),IG=1,NXYZ,100 )
c      endif
c ** temp check : end
c      miya=13
c      if ( miya.eq.13 ) stop
cc +++
      do ig=1,nxyz
       VEXT(ig)=0.d0
      enddo
c *** smoohting of external potential !! (really necessary?)
*VDIR NODEP(VEXT,REXT)
!ocl norecurrence(VEXT,REXT)
      do IG=2,NXYZ
       JG=I2G(IG)
       Q=TPIBA2*G(4,IG)
       VEXT(JG)=REXT(JG)*FPI/Q
      enddo
c   Now make Vext in real space
      do IG=1,NXYZ
       WEXT(IG)=0.d0
      enddo
c ** for Sugino FFT
c         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,VEXT,WEXT,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo FFT
c         CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,VEXT,WEXT,
c     & WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c         call FFT3BX_fftw(NXYZ,VEXT,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
         CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,VEXT,WEXT
     & ,plancfp,plancbp)
c *** temp check
c      if ( my_rank.eq.0 ) then
c       do ig=2,10
c        JG=I2G(IG)
c        write(6,2122)JG,G(4,IG),VEXT(JG)
c       enddo
c      endif
c 2122 format(i9,3f22.16)
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) stop
c *** temp check : end
c *** rescake VEXT !!
c      do IG=1,NXYZ
c       VEXT(IG)=VEXT(IG) -10.d0
c      enddo
c *** write external potential on file 94 !!!
      if ( my_rank.eq.0 ) then
      rewind 94
       efac=13.6d0*2
      write(94)( efac*dreal(VEXT(ig)),ig=1,nxyz)
      endif
C
C
      CALL CLOCK(TIM)
c      CALL cpu_time(TIM)
      if ( my_rank.eq.0 ) then
      WRITE(6,7004) TIM
 7004 FORMAT(23X,'****  CPU TIME AFT INITPW: ',F15.7,' SEC')
      endif
c **** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c       write(6,*)'my_rank',my_rank,'INITPW is finished'
c      stop
c      endif
c **** temp check : end
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
c     if ( ntyq.gt.1 ) then
CCC   ALPPP(1,2)=0.80D0
CCC   ALPPP(2,2)=1.05D0
CCC   BETAPP(1,2)=5.D0
CCC   BETAPP(2,2)=5.D0
c     endif
      IBUN(1,1)=0  ! s-orbital for type 1
      IBUN(2,1)=0  ! p-orbital for type 1
      IBUN(3,1)=0  ! p-orbital for type 1
      IBUN(4,1)=0  ! p-orbital for type 1
c      IBUN(1,2)=0  ! s-orbital for type 2
c      IBUN(2,2)=0  ! p-orbital for type 2
C            IBUN=1 PARTITION   0 NOT
      if ( my_rank.eq.0 )WRITE(6,*) ' ATOM TYPE: NTYPE = ', NTYPE
      DO 6002 ITP = 1, NTYPE
      DO 6002 LLL=1,3
 6002 IF(IBUN(LLL,ITP).NE.0 .and. my_rank.eq.0 )
     &  WRITE(6,6006) LLL, ITP, ALPPP(LLL,ITP),
     &                         BETAPP(LLL,ITP)
 6006 FORMAT('    REAL SPACE PARTITION IS DONE FOR ',I1,'-TH L OF '
     &,I3,
     &'-TH ATOM:'/
     &       '                ALP = ',F10.6,' BETA = ',F10.6)
C
c +++ proceed previous A-vector
      if (my_rank.eq.0 ) then
        read(60,*) AVX,AVY,AVZ
      endif
       call MPI_Bcast(AVX,1,MPI_DOUBLE_PRECISION,
     &  0,MPI_COMM_WORLD,ierr)
       call MPI_Bcast(AVY,1,MPI_DOUBLE_PRECISION,
     &  0,MPI_COMM_WORLD,ierr)
       call MPI_Bcast(AVZ,1,MPI_DOUBLE_PRECISION,
     &  0,MPI_COMM_WORLD,ierr)
c
      DO IK=1,NUMK
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX
         GAY=G2(2,IG,IK)-AVY
         GAZ=G2(3,IG,IK)-AVZ
         GG2(1,IG,IK)=GAX
         GG2(2,IG,IK)=GAY
         GG2(3,IG,IK)=GAZ
         GG2(4,IG,IK)=GAX**2 + GAY**2 + GAZ**2
        ENDDO
      ENDDO
c +++ temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' Before PRENON '
c       do ik=1,NUMK
c        do ity=1,NTYPE
c         write(6,*)' ik ity NGNL=',ik,ity,NGNL(ITY,IK)
c         if (NGNL(ITY,IK).gt.NXYZ/6) then
c           write(6,*)' Too large NGNL '
c           stop
c         endif
c        enddo
c       enddo
c       do ik=1,NUMK
c        write(6,*)' ik =',ik
c        write(6,*)' GG2 vectors just made!'
c        do ig=1,NXYZ,500
c         write(6,'(4F22.16)')( GG2(j,ig,ik),j=1,4 )
c        enddo
c       enddo
c      endif
c ++++
cc
c ****  for option 1 use G for local potential VGA 
      if (my_rank.eq.0)  then
       write(6,*)' call prenon for local potential'
      endif
c      CALL PRENON( 1, NG2Q, NG2, TPIBA, NGQ, NG, G,
      CALL PRENON( 1, NG2Q, NXYZ, TPIBA, NGQ, NXYZ, G,
     &      NUMKQ, NUMK,G2,GG2, RHO2, VGA,RHO3, NUMTY, NTYQ, NTYPE,
     &             VPJ, VPP,
c  for parallel
     &      VPJWORK,
c
     &      NCRQ, ZV, RC0, COR, NUMC, ALPPP, BETAPP,
     &             IOVP, MXOFL,VPP2,OMEGA,ADUMP,ATEMP,NGNL
c     &    ,RAD,PSPOT,PSPOT2,PHIL)
     &    ,RAD,PSPOT,PSPOT2,PHIL,NGcont
c
     &    ,mshbegin,mshend,ncpuq )
C
c      if (my_rank.eq.0 ) then
c       do ik=1,NUMK
c        write(6,*)' ik =',ik
c        write(6,*)' GG2 vectors after PRENON(1, '
c        do ig=1,NXYZ,500
c         write(6,'(4F22.16)')( GG2(j,ig,ik),j=1,4 )
c        enddo
c       enddo
c      endif
c **** for option 2 use G-A for non-local potential 
c                           VPJ,VPA,VPP,VPP2
c 
c *** temp check
c       do ity=1,ntype
c       if (my_rank.lt.4 ) then
c       write(6,*)'after prenon 1 my_rank ity VGA =',my_rank,ity,
c     & (VGA(IG,ITY),IG=1,2) 
c       endif
c       enddo
c *** temp check end
C
      if (my_rank.eq.0)  then
       write(6,*)' call prenon for nonlocal potential'
      endif
      call prof_start(7)
c      CALL PRENON( 2, NG2Q, NG2, TPIBA, NGQ, NG, G,
      CALL PRENON( 2, NG2Q, NXYZ, TPIBA, NGQ, NXYZ, G,
     &       NUMKQ, NUMK,G2, GG2, RHO2, VGA,RHO3, NUMTY, NTYQ, NTYPE,
     &             VPJ, VPP,
c  for parallel
     &      VPJWORK,
c
     &      NCRQ, ZV, RC0, COR, NUMC, ALPPP, BETAPP,
     &             IOVP, MXOFL,VPP2,OMEGA,ADUMP,ATEMP,NGNL
     &   ,RAD,PSPOT,PSPOT2,PHIL,NGcont
c
     &   ,mshbegin,mshend,ncpuq )
      call prof_stop(7)
C
      CALL CLOCK(TIM)
c      CALL cpu_time(TIM)
      if ( my_rank.eq.0 ) then
      WRITE(6,7006) TIM
 7006 FORMAT(23X,'****  CPU TIME AFT PRENON: ',F15.7,' SEC')
      endif
cc ++++
       if (my_rank.eq.0 ) then
        write(6,*)' just after PRENON!'
       do ik=1,NUMK
        do ity=1,ntype
         write(6,*)' ik ity NGNL=',ik,ity,NGNL(ITY,IK)
         if (NGNL(ITY,IK).gt.NGcont ) then
           write(6,*)' Too large NGNL '
           stop
         endif
c         write(6,*)' check RAD from psread2 '
c         write(6,*)' ity = ',ity
c         write(6,8080)( RAD(K,ITY), K=1,MESHQ,100 )
c         write(6,*)' check PHIL from psread2 '
c         do IIL=1,MXOFL(ITY)
c          write(6,*)' IIL=',IIL
c          write(6,*)' PHIL '
c          write(6,8080)( PHIL(K,IIL,ITY), K=1,MESHQ,100 )
c          write(6,*)' PSPOT '
c          write(6,8080)( PSPOT(K,IIL,ITY), K=1,MESHQ,100 )
        enddo
       enddo
c 8080 format(4f22.16)
       endif
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' just after PRENON!'
c       write(6,*)' +++ VPJ +++ '
c       do ik=1,numk
c        write(6,*)' ik=',ik
c        do ity=1,ntype
c         write(6,*)' ity=',ity
c         write(6,'(4F22.16)')( VPJ(ig,1,1,ity,ik)
c     &     ,ig=1,NGNL(ity,ik),500)
c        enddo
c       enddo
c       write(6,*)' just after PRENON!'
c       write(6,*)' GG2 '
c       do ik=1,numk
c        write(6,*)' IK=',ik
c        do ig=1,NG2Q,500
c        write(6,'(4f22.16)')( GG2(IJ,IG,ik),IJ=1,4 )
c        enddo
c       enddo
cc  +*
c       write(6,*)' VPP2 '
c       do ik=1,numk
c        do ity=1,NTYPE
c         write(6,'(4F22.16)')( VPP2(IIL,1,ITY,IK),IIL=1,16 )
c        enddo
c       enddo
c       write(6,*)' RAD '
c       do ity=1,NTYPE
c        write(6,*)' ity = ',ity
c        write(6,'(4f22.16)')( RAD(K,ITY),K=1,MESHQ,100)
c       enddo
c      endif
c *** temp check : end
C
c *** temp check
c      miya=13
c      if ( miya.eq.13. ) stop
c *** temp check ; end
c ****  initial velocities (Cartesian)
      itseq=0
      do ity=1,ntype
      do it=1,abs( numty(ity) )
      itseq=itseq+1
      if ( itseq.gt.ntauq ) stop ' small ntauq !! '
c *****
      if ( my_rank.eq.0 ) then
      read(5,*)( velo(j,itseq),j=1,3 )
      endif
      call MPI_Bcast(velo(1,itseq),3,MPI_DOUBLE_PRECISION,
     &  0,MPI_COMM_WORLD,ierr)
c *****
      enddo
      enddo
      if ( my_rank.eq.0 ) then
      write(6,*)' Initial Velocities '
      do itau=1,itseq
      write(6,7110)( velo(j,itau),j=1,3 ),itau
      enddo
c ***  time from past run
      read(5,*)time0
c ** read previous ETOT 
      if ( time0.gt.1.d-06 .and. my_rank.eq.0 ) then
       read(28,*)ETOT_old
      endif
      write(6,*)' simulation time from the past run '
      write(6,*)'          ',time0,' fsec '
      write(6,*)'    ETOT_old = ',ETOT_old,' HR'
      endif
      call MPI_Bcast(time0,1,MPI_DOUBLE_PRECISION,
     &  0,MPI_COMM_WORLD,ierr)
c
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' Before time step loop ! '
c      endif
c      miya=13
c      if (miya.eq.13 ) stop
c *** temp check end
c
c  ***  Start of time-evolution !!
c
c
c ***** for nonlocac pseudopotentials
c      DO IG=1,NG2
c       RHO3(IG)=SQRT(G2(4,IG))*TPIBA
c      ENDDO
c       CALL GETYLM(NG2Q,NG2,G2,RHO3,YLM,TPIBA)
c *****
      if ( my_rank.eq.0 ) then
      write(6,*)' Start time evolution '
      write(6,*)' dt = ',dt
      write(6,*)' ntstep = ',ntstep
      endif
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) stop
c *** temp check : end
      dtfsec=dt*0.0242d0
c **** read previous energy by external field
      if ( my_rank.eq.0 ) then
      read(18,*)Eext,DELTAd_old
      endif
c
cc   we make vector potential 'Avec' as time integral of constant E field
cc   This value is for 150 mJ/cm2 with FWHM=30 fs
cc      Estr=0.6138320d0  ! in unit of V/angstrom (1V/A=1.327x10^13 W/cm^2)
cc   This value is for 0.1 J/cm2 with FWHM=30 fs
c      Estr=0.50119d0  ! in unit of V/angstrom (1V/A=1.327x10^13 W/cm^2)
cc   This value is for 0.2 J/cm2 with FWHM=30 fs
cc      Estr=0.708792d0  ! in unit of V/angstrom (1V/A=1.327x10^13 W/cm^2)
c      Estr=Estr/(13.6d0*2)*0.529177d0  ! in atomic unit
c    
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' just before do 100 (itstep)'
c       write(6,*)' GG2 '
c       do ik=1,numk
c        write(6,*)' IK=',ik
c        do ig=1,NG2Q,500
c        write(6,'(4f22.16)')( GG2(IJ,IG,ik),IJ=1,4 )
c        enddo
c       enddo
c      endif
cc  +*
c       write(6,*)' VPP2 '
c       do ik=1,numk
c        do ity=1,NTYPE
c         write(6,'(4F22.16)')( VPP2(IIL,1,ITY,IK),IIL=1,16 )
c        enddo
c       enddo
c       write(6,*)' RAD '
c       do ity=1,NTYPE
c        write(6,*)' ity = ',ity
c        write(6,'(4f22.16)')( RAD(K,ITY),K=1,MESHQ,100)
c       enddo
c      endif
c *** temp check : end
      call prof_stop(15)
! Keep static reciprocal-grid and occupation metadata resident for the
! complete time-step loop.  Both arrays are initialized during setup and
! remain host-read-only until time evolution finishes.
!$acc enter data copyin(J2G(1:NG2Q,1:NUMKQ),
!$acc& OCC(1:NBNDQ,1:NUMKQ))
      do 100 itstep=0,ntstep
      call prof_start(1)
      time=time0+dtfsec*itstep
cc ** need for work on ions (vector potential version)
      if ( itstep.eq.0.and.my_rank.eq.0 ) then
       read(62,*) Ework
c *** temp check
c        miya=13
c         if (miya.eq.13 ) then
c          write(6,*)' Ework was read ='
c         stop
c         endif
c *** temp check end
      endif
c *** call time-dependent factor of the external charge & potential
      ta=time*100.d0/2.42d0  ! time in a.u.
c **** next parts are for vector potential version
c
       if (itstep.eq.0 ) then
        GFAC=GMHF*2
        if (my_rank.eq.0 ) then
         write(6,*)' +++ GFAC = ',GFAC
        endif
        GFACQ=dsqrt(GFAC)
       endif
c
        m=2
        pm=1.d0/( 4.d0 - 4.d0**(1.d0/dfloat(2*m-1) ) )
        pr1=pm
        pr2=pm
        pr3=1.d0-4*pm
        pr4=pr2
        pr5=pr1
      ta1=ta+dt*pr1
      ta2=ta1+dt*pr2
      ta3=ta2+dt*pr3
      ta4=ta3+dt*pr4
      ta5=ta4+dt*pr5
      if ( dabs(ta+dt-ta5).ge.1.E-08 ) stop 'wrong pr'
c *** temp check
c        miya=13
c         if (miya.eq.13.and.my_rank.eq.0 ) then
c          write(6,*)' itstep =',itstep
c          write(6,*)' before calling Ext_field'
c         stop
c         endif
c *** temp check end
      call tdep(ft1,dft1,ta1)
       call Ext_field(ExtX1,ExtY1,ExtZ1,ft1)
      call tdep(ft2,dft2,ta2)
       call Ext_field(ExtX2,ExtY2,ExtZ2,ft2)
      call tdep(ft3,dft3,ta3)
       call Ext_field(ExtX3,ExtY3,ExtZ3,ft3)
      call tdep(ft4,dft4,ta4)
       call Ext_field(ExtX4,ExtY4,ExtZ4,ft4)
      call tdep(ft5,dft5,ta5)
       call Ext_field(ExtX5,ExtY5,ExtZ5,ft5)
c *** temp check
c        miya=13
c         if (miya.eq.13.and.my_rank.eq.0 ) then
c          write(6,*)' itstep =',itstep
c          write(6,*)' after calling Ext_field'
c         stop
c         endif
c *** temp check end
       if (itstep.gt.0 ) then
        AVX1=AVX +1.d0/TPIBA*ExtX1*dt*pr1  ! dt has been read from AINPUT
        AVY1=AVY +1.d0/TPIBA*ExtY1*dt*pr1
        AVZ1=AVZ +1.d0/TPIBA*ExtZ1*dt*pr1
        AV21=AVX1**2 + AVY1**2 + AVZ1**2
c
        AVX2=AVX1+1.d0/TPIBA*ExtX2*dt*pr2 ! dt has been read from AINPUT
        AVY2=AVY1+1.d0/TPIBA*ExtY2*dt*pr2
        AVZ2=AVZ1+1.d0/TPIBA*ExtZ2*dt*pr2
        AV22=AVX2**2 + AVY2**2 + AVZ2**2
c
        AVX3=AVX2+1.d0/TPIBA*ExtX3*dt*pr3 ! dt has been read from AINPUT
        AVY3=AVY2+1.d0/TPIBA*ExtY3*dt*pr3
        AVZ3=AVZ2+1.d0/TPIBA*ExtZ3*dt*pr3
        AV23=AVX3**2 + AVY3**2 + AVZ3**2
c
        AVX4=AVX3+1.d0/TPIBA*ExtX4*dt*pr4 ! dt has been read from AINPUT
        AVY4=AVY3+1.d0/TPIBA*ExtY4*dt*pr4
        AVZ4=AVZ3+1.d0/TPIBA*ExtZ4*dt*pr4
        AV24=AVX4**2 + AVY4**2 + AVZ4**2
c
        AVX5=AVX4+1.d0/TPIBA*ExtX5*dt*pr5 ! dt has been read from AINPUT
        AVY5=AVY4+1.d0/TPIBA*ExtY5*dt*pr5
        AVZ5=AVZ4+1.d0/TPIBA*ExtZ5*dt*pr5
        AV25=AVX5**2 + AVY5**2 + AVZ5**2
       endif
c **** temp check: A-vec was confirmed 2020-09-07 Miyamoto
c       if (itstep.gt.0 ) then
c
c +++ from ta+pr1*dt to ta4*dt*pr5
c ++++ at final dt
      call tdep(ft,dft,ta)  ! time-dependence of E-field
        call Ext_field(ExtX,ExtY,ExtZ,ft) ! polarization !!
c
c *** abs of Ext is needed to judge to call Part1to5 in FRPRMN !
       ExtABS1=ExtX1**2+ExtY1**2+ExtZ1**2
       ExtABS2=ExtX2**2+ExtY2**2+ExtZ2**2
       ExtABS3=ExtX3**2+ExtY3**2+ExtZ3**2
       ExtABS4=ExtX4**2+ExtY4**2+ExtZ4**2
       ExtABS5=ExtX5**2+ExtY5**2+ExtZ5**2
       ExtABS=dmax1(ExtABS1,ExtABS2,ExtABS3,ExtABS4,ExtABS5)
       if (ExtABS.le.1.D-16) then
        if (itstep.eq.1 ) then
         VPJGENdo=.true.
        else
         VPJGENdo=.false.
        endif
       else
        VPJGENdo=.true.
       endif
       if (itstep.gt.0 ) then
        AVX=AVX+1.d0/TPIBA*ExtX*dt  ! dt has been read from AINPUT
        AVY=AVY+1.d0/TPIBA*ExtY*dt
        AVZ=AVZ+1.d0/TPIBA*ExtZ*dt
        AV2=AVX**2 + AVY**2 + AVZ**2
        GFAQ3=dsqrt(GFAC)/dsqrt(3.d0)
        AVE=-2*( (GFAQ3-AVX)*ExtX +(GFAQ3-AVY)*ExtY
     &          +(GFAQ3-AVZ)*ExtZ )
       endif
c  *** temp check for A-vector
c      if ( mod(itstep,itmod).eq.0 .and. my_rank.eq.0 ) then
c       time=ta *2.42d-02   ! in fs 
c       write(99,2992)time, AVX ,AVY , AVZ
c       time=ta1*2.42d-02   ! in fs 
c       write(99,2992)time, AVX1,AVY1, AVZ1
c       time=ta2*2.42d-02   ! in fs 
c       write(99,2992)time, AVX2,AVY2, AVZ2
c       time=ta3*2.42d-02   ! in fs 
c       write(99,2992)time, AVX3,AVY3, AVZ3
c       time=ta4*2.42d-02   ! in fs 
c       write(99,2992)time, AVX4,AVY4, AVZ4
c       time=ta5*2.42d-02   ! in fs 
c       write(99,2992)time, AVX5,AVY5, AVZ5
c       time=ta *2.42d-02   ! in fs 
c       write(99,2992)time, AVX ,AVY , AVZ
c      endif
c 2992 format(4f22.16)
c *** remake GDUMP for next time sttep
      call prof_start(2)
       DO IK=1,NUMK
c *** for YLM under P-A
       if (itstep.gt.0 ) then
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX
         GAY=G2(2,IG,IK)-AVY
         GAZ=G2(3,IG,IK)-AVZ
         GG2(1,IG,IK)=GAX
         GG2(2,IG,IK)=GAY
         GG2(3,IG,IK)=GAZ
         GG2(4,IG,IK)=GAX**2 + GAY**2 + GAZ**2
        ENDDO
       endif
c
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' just after remake GG2 itstep=',itstep
c       write(6,*)' GG2 '
c       write(6,*)' IK=',ik
c       do ig=1,NG2Q,1000
c        write(6,'(4f22.16)')( GG2(IJ,IG,ik),IJ=1,4 )
c       enddo
cc      endif
c  +*
c
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX
         GAY=G2(2,IG,IK)-AVY
         GAZ=G2(3,IG,IK)-AVZ
         Gleng=G2(4,IG,IK)
         GGAvec=(GAX**2+GAY**2+GAZ**2)
         GGAvecd=-2*( GAX*ExtX+GAY*ExtY+GAZ*ExtZ ) !A= int E
c         GGAvecd= 2*( GAX*ExtX+GAY*ExtY+GAZ*ExtZ ) ! A=-int E
c         IF ( GGAvec.LE.GFAC+AV2 ) then
c          GDUMP(IG,IK)=GGAvec
c          GDUMPd(IG,IK)=GGAvecd
c         else
c          GDUMP(IG,IK)=GFAC+AV2
c          GDUMPd(IG,IK)=AVE
c         endif
         IF ( GGAvec.LE.GFAC ) then
          GDUMP(IG,IK)=GGAvec
          GDUMPd(IG,IK)=GGAvecd
         else
          GDUMP(IG,IK)=GFAC
          GDUMPd(IG,IK)=0
         endif
        ENDDO
c       if (itstep.gt.0 ) then
c        AVX=AVX+1.d0/TPIBA*ExtX*dt  ! dt has been read from AINPUT
c        AVY=AVY+1.d0/TPIBA*ExtY*dt
c        AVZ=AVZ+1.d0/TPIBA*ExtZ*dt
c        AV2=AVX**2 + AVY**2 + AVZ**2
c        GFAQ3=dsqrt(GFAC)/dsqrt(3.d0)
c        AVE=-2*( (GFAQ3-AVX)*ExtX +(GFAQ3-AVY)*ExtY
c     &          +(GFAQ3-AVZ)*ExtZ )
c       endif
       ENDDO  ! end of IK loop
      call prof_stop(2)
c 
c   *****  A subroutine for lattice dynamics is necessary here !
c
      call prof_start(3)
      if ( itstep.eq.0 ) call nkin(velo,atmss,ntauq,Ekin)
      if ( itstep.ne.0 ) call md(tau,fold,velo,atmss,ntauq,dt
     &            ,tau1,tau2,tau3,tau4,tau5)
      call prof_stop(3)
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c       write(6,*)' my_rank=',my_rank,' sub nkin and md are finished!'
c       stop
c      endif
c *** temp check : end
      if ( itstep.eq.1 ) call clock(T00)
c      if ( itstep.eq.1 ) call cpu_time(T00)
CC
c
c      if (my_rank.eq.0 .and. mod(itstep,itmod).eq.0 ) then
c       write(6,*)' before frprmn itstep=',itstep
c       write(6,*)' GDUMP  '
c       write(6,'(4F22.16)')(GDUMP(IG,1),IG=1,NXYZ,5000)
c       write(6,*)' GDUMP1 '
c       write(6,'(4F22.16)')(GDUMP1(IG,1),IG=1,NXYZ,5000)
c       write(6,*)' GDUMP2 '
c       write(6,'(4F22.16)')(GDUMP2(IG,1),IG=1,NXYZ,5000)
c       write(6,*)' GDUMP3 '
c       write(6,'(4F22.16)')(GDUMP3(IG,1),IG=1,NXYZ,5000)
c       write(6,*)' GDUMP4 '
c       write(6,'(4F22.16)')(GDUMP4(IG,1),IG=1,NXYZ,5000)
c       write(6,*)' GDUMP5 '
c       write(6,'(4F22.16)')(GDUMP5(IG,1),IG=1,NXYZ,5000)
c      endif
c
      call prof_start(4)
      CALL FRPRMN( 1, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
     &        NBNDQ, NBNDQ,NBSEQ,NBSEQ2,NFL, NPFL, NDX, NDY, NDZ,
     &             NUMK, NUMKQ, COEF, DCOEF, COEF0,CMAT,
     &          YLM, G, G2,
c ***
     & RHO, RHO1, RHO2, RHO3,VGA,
     &             RHO4, RHOG, VECK, OCC, EE, WGT, TPIBA, VG, S,
c ***  attention !
     &          VG0,VG1,VG2,VG3,VG4,VG5,VGOLD,
     &             NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
c ***  attention !
     &             VPP2,
     &     MXBND2,MXBND0,1, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &             TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
c ***  attention !
     &             TAU0,TAU1,TAU2,TAU3,TAU4,TAU5,Vloc,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
c *** for Sugino FFT
c     &             SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
c     &             IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL,dt
c *** for Kokubo FFT
c   *** LY2,LZ1,LZ2 are still necessary for ROTRA
c     &             LY2, LZ1, LZ2,
c     &             SK, NSY, KZ, WSAVE_XYZ, IFAC_XYZ, MXOFL,dt
c *** for Kokubo FFTW 
c   *** LY2,LZ1,LZ2 are still necessary for ROTRA
     &             LY2, LZ1, LZ2,
     &             SK, NSY, KZ, plancfp,plancbp, MXOFL,dt
     &   ,itstep,ntstep,
     &   itmod,EXTAU,EXTBF,recvcnts,displs,NTAUQ2,GDUMP
     &   ,GMHF,fdump,NGNL
     &   ,VEXT,ft,ft1,ft2,ft3,ft4,ft5,Efieldp,Efieldm,CWORK,Vplt,time
c +++ for A-vector GDUMP1 to GDUMP 5
     &   ,GDUMP1,GDUMP2,GDUMP3,GDUMP4,GDUMP5
     &         ,GG2,G21,G22,G23,G24,G25,YLM1,YLM2,YLM3,YLM4,YLM5,
     &      VPJWORK,VPJ1,VPJ2,VPJ3,VPJ4,VPJ5,
     &     VPP21,VPP22,VPP23,VPP24,VPP25,
     &   RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,
     &   AVX1,AVY1,AVZ1,AVX2,AVY2,AVZ2,AVX3,AVY3,AVZ3,
     &   AVX4,AVY4,AVZ4,AVX5,AVY5,AVZ5
c
     &  ,NGcont
c
     &  ,nbegin,nend,nbegint,nendt,nbegintt,nendtt,mshbegin,mshend
     &  ,ncpuq,ncpu
c
     &  ,NVIRTQ)
      call prof_stop(4)
C
c  ****  temp
      if ( mod(itstep,itmod).eq.0  ) then
      CALL CLOCK(TIM)
      if ( my_rank.eq.0 ) then
c ++++ store E-field as a function of time
c       write(92,1213)time,Efieldp,Efieldm
c **** compute dipole moment
       call dipole(rho,nxyz,nrx,nry,nrz,alat,a1,a2,a3,omega,time)
c ****
c      CALL cpu_time(TIM)
c ******
c      if ( my_rank.eq.0 ) then
      WRITE(6,7008) TIM
        write(6,7777)time
        write(6,*)
       write(6,*)' ****  expectation values (eV) *** '
        do ik=1,numk        
        write(6,*)' ***  for ',ik,'-th k-point'
        write(6,1212)( ee(ib,ik)*27.212d0,ib=1,nbseq(ik) )
        enddo
 1212 format(4d20.8)
 1213 format(3f22.16)
 7777 format(' Time (fsec) = ',f22.16)
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      stop
c      endif
c *** temp check : end
      endif  ! end of if ( my_rank.eq.0 ) loop
c ******
      endif  ! end of if mod(itstep,imod).eq.0 ) loop
c *** temp check
c      miya=13
c      if ( miya.eq.13 .and. my_rank.eq.0  ) then
c       write(6,*)'my_rank=',my_rank,' Eigen values: end'
c      stop
c      endif
c *** temp check : end
c  *** store perticular WF's in real space !!!
c *** Start the G-space to R-space FFT conversion of each wavefunctions
      if ( itstep.eq.ntstep .and. iopt(2,1).eq.5 ) then
c ***** Gather Wfs from Slave CPUs to the Master CPU 
      do 1997 ik=1,numk
c       if (my_rank.ne.0 ) then
c        nbleng=nend(my_rank)-nbegin(my_rank)+1
c        call MPI_Send(Coef(1,nbegin(my_rank),ik),nxyz*nbleng,
c     &       MPI_DOUBLE_COMPLEX,0,24,MPI_COMM_WORLD,ierr)
c       else
c        do icpu=1,ncpu
c        nbleng=nend(icpu)-nbegin(icpu)+1
c        call MPI_Recv(Coef(1,nbegin(icpu),ik),nxyz*nbleng,
c     &       MPI_DOUBLE_COMPLEX,icpu,24,MPI_COMM_WORLD,status,ierr)
c        enddo
c       endif
ccc      read(71,rec=iowf(iblk,ik))coef
        do 1995 icpu=0,ncpu
        nbleng=nend(icpu)-nbegin(icpu)+1
        if ( icpu.eq.0 ) then
         if ( my_rank.eq.0 ) then
          do ib0=1,nbleng
           do ig=1,nxyz
            coef0(ig,ib0,ik)=coef(ig,ib0,ik)
           enddo
          enddo
         endif
        else  ! icpu.ne.0
         if ( my_rank.eq.icpu) then
          do ib0=1,nbleng
           do ig=1,nxyz
            coef0(ig,ib0,ik)=coef(ig,ib0,ik)
           enddo
          enddo
          call MPI_Send(coef0(1,1,ik),nbleng*nxyz,
     &     MPI_DOUBLE_COMPLEX,0,24,MPI_COMM_WORLD,ierr) 
         else
          if ( my_rank.eq.0 ) then
          call MPI_Recv(coef0(1,1,ik),nbleng*nxyz,
     &     MPI_DOUBLE_COMPLEX,icpu,24,MPI_COMM_WORLD,status,ierr) 
          endif
         endif
        endif ! end of if icpu.eq.0 loop
        if ( my_rank.eq.0 ) then
        do 1996 ib=nbegin(icpu),nend(icpu)
c         iband=ib
         iib=ib-nbegin(icpu)+1
c       if (ib.eq.64 ) then
       if (ib.eq.221 .or. ib.eq.222
     &   .or.ib.eq.236 .or. ib.eq.237 ) then
c 
cc *** temp check
          write(6,*)' message from CPU #',my_rank
          write(6,*)
     &    'Charge for IK = ',ik,' IB = ',ib,' is stored.'
cc *** temp check end
C
          DO JG=1,NXYZ
          RHO1(JG)=(0.D0,0.D0)
          ENDDO
*VDIR NODEP(RHO1)
!ocl norecurrence(RHO1)
          DO IG=1,NG2(ik)
          JG=J2G(IG,IK)
c          RHO1(JG)=COEF(IG,IB,IK)
          RHO1(JG)=COEF0(IG,IIB,IK)
          ENDDO
C
c *** for Sugino FFT
c         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo FFT
c         CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
c     & WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW 
c          call FFT3BX_fftw(NXYZ,RHO1,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
         CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
     & plancfp,plancbp)
c
c         do jg=1,nxyz
c         wnorm(jg)=real( dconjg(rho1(jg))*rho1(jg) )
c         enddo
c ***  temp :check 
c         write(6,*)' WNORM : '
c         write(6,*)( wnorm(ir),ir=1,10 )
c         sum=0
c         do ir=1,nxyz
c         sum=sum+wnorm(ir)
c         enddo
c         sum=sum/dfloat(nxyz)
c         write(6,*)' SUM of WNORM = ',sum
c ***  temp :check : end 
c ************
c         write(88)wnorm
         write(88)rho1
c
         endif   !if  ib and ik match the states, which we want to store.
c
 1996   continue  ! end of ib  loop
        endif  ! end of if my_rank.eq.0
 1995   continue  ! end of icpu loop
c
 1997 continue    ! end of k- loop
      endif  ! end of if istep.eq.nstep .and. iopt(2,4).eq.5
c
      if ( itstep.eq.ntstep .and. IOPT(2,1).eq.4 ) then
      call clock(t0)
c      call cpu_time(t0)
      if ( my_rank.eq.0 ) then
      write(6,*)' Message from CPU #',my_rank
      write(6,*)'    Orbital analysis !!!  '
      endif
      do 1010 ik=1,numk
      if ( my_rank.ne.0 ) then
c       nbleng=nend(my_rank)-nbegin(my_rank)+1
c       call MPI_Send(Coef(1,nbegin(my_rank),ik),nxyz*nbleng,
c     &      MPI_DOUBLE_COMPLEX,0,24,MPI_COMM_WORLD,ierr)
      else
c       do icpu=1,ncpu
c       nbleng=nend(icpu)-nbegin(icpu)+1
c       call MPI_Recv(Coef(1,nbegin(icpu),ik),nxyz*nbleng,
c     &      MPI_DOUBLE_COMPLEX,icpu,24,MPI_COMM_WORLD,status,ierr)
c       enddo
      write(6,*)
      write(6,*)'  -----------  '
c      endif  
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
      endif
      end if ! end of if my_rank.ne.0 loop
c ***  temp check
       write(6,*)' Before Orbital analysis NBSEQ = ',nbseq(ik)
c      miya=13
c      if ( miya.eq.13 ) stop
c **   temp check : end
      do 1452 icpu=0,ncpu
      nbleng=nend(icpu)-nbegin(icpu)+1
      if ( icpu.eq.0 ) then
       if ( my_rank.eq.0 ) then
        do ib0=1,nbleng
         do ig=1,nxyz
          coef0(ig,ib0,ik)=coef(ig,ib0,ik)
         enddo
        enddo
       endif
      else
       if ( my_rank.ne.0 ) then
        do ib0=1,nbleng
         do ig=1,nxyz
          coef0(ig,ib0,ik)=coef(ig,ib0,ik)
         enddo
        enddo
        call MPI_Send(coef0(1,1,ik),nbleng*nxyz,
     &   MPI_DOUBLE_COMPLEX,0,24,MPI_COMM_WORLD,ierr) 
       else
        call MPI_Recv(coef0(1,1,ik),nbleng*nxyz,
     &   MPI_DOUBLE_COMPLEX,icpu,24,MPI_COMM_WORLD,status,ierr) 
       endif
      endif  ! end of if icpu.eq.0 loop
      if ( my_rank.eq.0 ) then
      do 1453 ib=nbegin(icpu),nend(icpu)
      iband=ib
      iib=ib-nbegin(icpu)+1
c **  for special treatent
      ngg2=ng2(ik)/18
c      call orbanly(iband,ik,coef(1,iband,ik),rho1,rho2,ng2q,
      call orbanly(my_rank,iband,ik,coef0(1,iib,ik),rho1,rho2,ng2q,
     &     ngg2,g2(1,1,ik),work2,
     &     tau,ntauq,numty,ntyq,ntype,tpiba,mxofl,omega)
 1453 continue
      do 1007 ig=1,ng2(ik)
      g2(4,ig,ik)=g2(4,ig,ik)**2
 1007 continue
      endif   ! if my_rank.eq.0 loop: end
 1452 continue
 1010 continue  ! end of ik loop
      call clock(t1)
c      call cpu_time(t1)
      if ( my_rank.eq.0 ) write(6,*)
     &    ' Orbital analysis took ',t1-t0,' seconds '
      endif
c  ****  temp end
c   ***  temp check
c      write(6,*)' just finish FRPRMN and before ELECTF '
c      write(6,*)'   RHO   '
c      write(6,*)( RHO(IG),ig=1,1500,100 )
c      write(6,*)'    RHOG   '
c      write(6,*)( RHOG(IG),ig=1,1500,100 )
c      write(6,*)'   I2G   '
c      write(6,*)( I2G(IG),ig=1,1500,100 )
C
C        HARTREE ENERGY
C
c      FPI=4.d0*DACOS(-1.d0)
c      EH=0.D0
c      TPIBA2=TPIBA**2
c      DO IG=2,NG
c      JG=I2G(IG)
c      EH=EH+0.5D0*FPI*DBLE(DCONJG(RHOG(JG))*RHOG(JG))/(TPIBA2*G(4,IG))
c      ENDDO
c      EH=OMEGA*EH
c      write(6,*)' EH = ',EH
C
c   ***  temp check : end
C 
c  **** temp check
c       miya=13
c       if ( miya.eq.13 .and. my_rank.eq.0 ) then
c        write(6,*)' Before going ELECTF : stop ! '
c       stop
c       endif
c  **** temp check : end
c *** temp check
c      if ( my_rank.ne.0 ) then
c      write(6,*)'my_rank=',my_rank,' itstep=',itstep
c      do ik=1,numk
c       write(6,*)'my_rank=',my_rank,'IK=',ik
c       do ib=nbegin(my_rank),nend(my_rank)
c        write(6,*)'my_rank=',my_rank,'IB=',ib
c        write(6,*)'my_rank=',my_rank,
c     &   ' coef=',( coef(ig,ib,ik),ig=1,nxyz,nxyz/2 )
c       enddo
c      enddo
c      endif
c *** temp check : end
c
c       call MPI_Barrier(MPI_COMM_WORLD,ierr)
c
c  *** temp check VGA
c      if ( mod(itstep,itmod).eq.1 .and. my_rank.eq.0 ) then
c       write(6,*)' itstep after frprmn =',itstep
c       do ik=1,NUMK
c        write(6,*)' G2leng IK=',IK
c        write(6,'(4F22.16)')( G2(4,IG,IK),IG=1,2)
c       enddo
c
c *** temp check for GGA
c       if (my_rank.eq.0.and.mod(itstep,itmod).eq.0 ) then
c       write(6,*)' itstep=',itstep
c       write(6,*)' Just before calling ELECTF : GG2'
c       do ik=1,NUMK
c        do ig=1,NG2Q,500
c         write(6,'(4F22.16)')(GG2(J,IG,IK),J=1,4)
c        enddo
c       enddo
c       do ity=1,NTYPE
c        do ik=1,NUMK
c         write(6,*)' VPJ(IG,1,1,',ITY,',',IK,')'
c         write(6,'(4F22.16)')(VPJ(IG,1,1,ITY,IK),ig=1,NG2Q/3,500)
c        enddo
c       enddo
c       endif
c *** temp check for GGA : end
c
c       do ik=1,NUMK
c        write(6,*)' GDUMP IK=',IK
c        write(6,'(4F22.16)')( GDUMP(IG,IK),IG=1,NXYZ,NXYZ/10)
c       enddo
c
c       do ity=1,ntype
c        write(6,*)'VGA  ity = ',ity
c        write(6,'(4F22.16)')( VGA(IG,ITY),IG=1,2)
c       enddo
c
c      endif
c *** temp check end
c
c  *** for initial smoothin of RHOG (read from file and FFT)
c   The following smoothin is too much !
c    Since RHOG was made from past RHO and the past RHO
c      which was fft of dumped RHOG in the last simulation
c      if (itstep.eq.0 ) then
c         do ig=1,nxyz
c         jg=i2g(ig)
c         rhog(jg)=rhog(jg)*fdump(ig)
c         enddo
c      endif
c   *** temp check RHOG
c      if (my_rank.eq.0 .and.mod(itstep,itmod).eq.0 ) then
c       write(6,*)' check RHOG itstep =',itstep
c       write(6,'(4F22.16)')( RHOG(IG),IG=1,NXYZ/6,500 )
c      endif
c
c       CALL ELECTF( MXBND, 1, NXYZ, NG, NGQ, NG2, NG2Q,
c ** temp check
c       if (my_rank.eq.0 ) then
c       write(6,*)' plancfp,plancbp before ELECTF '
c       write(6,*) plancfp,plancbp
cc       write(6,*)' check REXT before ELECTF '
cc       write(6,*)( REXT(IG),IG=1,NXYZ,100 )
c       endif
c ** temp check : end
       call prof_start(5)
       CALL ELECTF( MXBND2,MXBND0,1, NXYZ, NG, NGQ, NG2, NG2Q,
     &       NBNDQ, NBNDQ, NUMK, NUMKQ, NBSEQ,COEF, DCOEF,
c     &              YLM, G, EXPG, G2, RHO, RHO4, RHO1, RHO2, RHOG,
     &              YLM, G, EXPG, GG2, RHO, RHO4, RHO1, RHO2, RHOG,
     &              RHOAX,RHOAY,RHOAZ,
     &              TPIBA, ETOT, VG, S, NTOT, I2G, WORK2, VPJ, VPP,
     &              IOWF, IOVP, OMEGA, FORCE, DFORCE, SFORCE,
     &              NTAUQ, NTYQ, NTYPE, LREQ, LATQ, RVEC, NLV,
     &              NKMESH, NEXPND, NFL, EE,PX,PY,PZ
     &                       EENL, RCOSIN, WK,
     &              VINT, NSY, FXNL, FYNL, FZNL,
     &              TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
c     &              ZZ, ZVAL, NPFL, MXOFL, OCC ,itstep          )
     &      ZZ, ZVAL, NPFL, MXOFL, OCC ,itstep,VGA,GDUMP,NGNL
     &                  ,NRX,NRY,NRZ
c +++ for A-vector +++  Y. Miyamoto 2020
     &     ,GDUMPd,EEd,EKINEd
c *** for Sugino FFT
c     &                  ,WSAVEX,WSAVEY,WSAVEZ
c     &                  ,LX1,LX2,LY1
c     &                  ,LY2,LZ1,LZ2
c     &      ,IFACX,IFACY,IFACZ,REXT,WEXT,ft,dft,DELTAd,COWRK)
c *** for Kokubo FFT
c     &                  ,WSAVE_XYZ
c     &                  ,IFAC_XYZ,REXT,WEXT,ft,dft,DELTAd,CWORK)
c *** for Kokubo FFTW
     &                  ,plancfp,plancbp
     &                  ,REXT,WEXT,ft,dft,DELTAd,CWORK
c
     &                  ,NGcont
c
     &   ,nbegin,nend,nbegint,nendt,nbegintt,nendtt,ncpuq,ncpu)
       call prof_stop(5)
! FRPRMN created this mapping before all return paths.  ELECTF has now
! finished consuming the host-current coefficients, so release it here.
!$acc exit data delete(COEF(1:NG2Q,1:MXBND2,1:NUMKQ))
c
cc
c *** include vector potential contribution
c *** temp check
      if (itstep.eq.0.and.my_rank.eq.0 ) then
       do it=1,ntauq
        write(6,*)' it =',it,' ZZ=',ZZ(it)
       enddo
	      endif
c *** temp check: end
      call prof_start(6)
      do it=1,ntauq
       force_ex(1,it)=-ZZ(it)*ExtX  ! ZZ negative
       force_ex(2,it)=-ZZ(it)*ExtY
       force_ex(3,it)=-ZZ(it)*ExtZ
c *** temp check ! just to check ion field
c       force_ex(1,it)=-0  ! ZZ negative
c       force_ex(2,it)=-0
c       force_ex(3,it)=-0
c *** temp check : end
       do j=1,3
        force(j,it)=force(j,it)-force_ex(j,it)  ! force negative
c        force(j,it)=force(j,it)+force_ex(j,it)  ! (test)
       enddo
      enddo
c
      if ( itstep.ge.1 ) then
c
c **** integrate External Energy
       Eext=Eext+dt*0.5d0*(DELTAd_old+DELTAd)
       DELTAd_old=DELTAd
c work by A-vect on electronic system
        Ework=Ework+EKINEd*dt
c *** temp check
c      if (my_rank.eq.0 .and.mod(itstep,itmod).eq.0 ) then
c       write(6,*)' Ework from EKINEd ',Ework
c      endif
c *** temp check : end
c work by A-vect on ionic systems1
       do it=1,ntauq
        do j=1,3
         Ework=Ework-force_ex(j,it)*velo(j,it)*dt
c         Ework=Ework+force_ex(j,it)*velo(j,it)*dt ! test
        enddo
       enddo 
c
       call vd(force,fold,velo,atmss,ntauq,dt)
       call nkin(velo,atmss,ntauq,Ekin)
      endif
c
      call fsave(force,fold,ntauq)
      call prof_stop(6)
c
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c
      if ( mod(itstep,itmod).eq.0 .and. my_rank.eq.0 ) then
c
      write(6,*) ' force by Ext-field'
      do it=1,ntauq
      write(6,*)' tau = ',it
      write(6,'(3f22.16)')(force_ex(j,it),j=1,3)
      enddo
c
      write(6,*) ' E-field'
      write(6,'(3f22.16)')ExtX*13.6d0*2/.529177d0
     &                   ,ExtY*13.6d0*2/.529177d0
     &                   ,ExtZ*13.6d0*2/.529177d0
      write(6,*) ' A-vector'
      write(6,'(3f22.16)')AVX,AVY,AVZ
c
      write(6,*)' Total energy for electron and nuclei (HR)'
      write(6,4142)ETOT 
 4142 format(' Eelec       = ',d20.12)
      write(6,4143)Ekin
 4143 format(' Enucl       = ',d20.12)
      write(6,4144)Eext
 4144 format(' Eext        = ',d20.12)
c      write(6,4141)ETOT + Ekin - Eext
      write(6,4141)ETOT + Ekin - Eext - Ework
 4141 format(' Eelec+Enucl-Eext-Ework= ',d20.12)
c *** check with previous ETOT
       if ( time0.gt.1.d-06 .and. itstep.eq.0 ) then
        if ( dabs( ETOT-ETOT_old ) .gt.1.0d-05 ) then
c        if ( dabs( ETOT-ETOT_old ) .gt.5.0d-02 ) then ! for check
         write(6,*)' ETOT is discontinous!'
         write(6,*)' ETOT = ',ETOT
         write(6,*)' ETOT_old = ',ETOT_old
         write(6,*)'   Wrong input data or rh or wf!'
         stop
        else
         write(6,*)' OK! The calculation is successfully continued'
        endif
       endif ! end of checking previous ETOT
      endif  ! end of writing ETOT Ekin Eext and ETOT + Ekin - Eext
      if ( itstep.eq.ntstep .and. my_rank.eq.0 ) then
       rewind(19)
       write(19,*)Eext,DELTAd
       rewind(29)
       write(29,*)ETOT
c *** for vector potential terms
       write(61,'(3f22.16)') AVX,AVY,AVZ
       write(63,'(f22.16)') Ework
c
      endif
c **** note !! We must write here new Eext
c      if ( itste.ge.1 ) then
c **** integrate External Energy
c       Eext=Eext+dt*DELTAd
c      endif
c      WRITE(6,7018) TIM
c 7018 FORMAT(23X,'****  CPU TIME AFT STP DCNT:',F15.7,' SEC')
c
      if ( mod(itstep,itmod).eq.0 .and. my_rank.eq.0 ) then
c      write(6,*)' Time (fsec) = ',time
      write(6,7777)time
      write(6,*)' Positions '
      do itau=1,ntauq
      tau11=b1(1)*tau(1,itau)+b1(2)*tau(2,itau)+b1(3)*tau(3,itau)
      tau12=b2(1)*tau(1,itau)+b2(2)*tau(2,itau)+b2(3)*tau(3,itau)
      tau13=b3(1)*tau(1,itau)+b3(2)*tau(2,itau)+b3(3)*tau(3,itau)
      tau11=tau11/alat
      tau12=tau12/alat
      tau13=tau13/alat
      write(6,7110)tau11,tau12,tau13,itau
      enddo
      write(6,*)' Velocities'
      do itau=1,ntauq
      write(6,7110)( velo(j,itau),j=1,3 ),itau
      enddo
      endif
c
      call prof_stop(1)
  100 continue
!$acc exit data delete(J2G(1:NG2Q,1:NUMKQ),
!$acc& OCC(1:NBNDQ,1:NUMKQ))
c
      if ( ntstep.ge.1 .and. my_rank.eq.0 ) then
      call clock(T01)
c      call cpu_time(T01)
      write(6,1299)ntstep,T01-T00
 1299 format(I6,' steps took ',d20.12,' sec ')
      endif
c
c  ***  End of time-evolution !!
c
c
c  *** store modified external energy
c       if ( my_rank.eq.0 ) then
c       rewind 18
c       write(18,*)Eext
c       endif
c
c  ***  store coef in file !!
c      call wfwrit(coef,ng2q,ng2,mxbnd,mxbnd0,numkq,numk
      call wfwrit(coef,coef0,ng2q,ng2,mxbnd2,mxbnd0,numkq,numk
     &           ,occ0,nbndq,nxyz,
c
     &   nbegin,nend,ncpuq,ncpu )
c ******
      if ( my_rank.eq.0 ) then
c  ***  store rho in file !!
      rewind 24
      write(24)rho
c *** store time-dep rho !
      write(30)rho
c  ***  display final TAU ( in lattice unit )
      write(77,*)'  ---- final TAU --------------  '
      do itau=1,ntauq
      write(77,7110)( tau(i,itau),i=1,3 ),itau
      enddo
      write(77,*)' in unit of lattice vectors ---- '
      do 877 itau=1,ntauq
      tau11=b1(1)*tau(1,itau)+b1(2)*tau(2,itau)+b1(3)*tau(3,itau)
      tau12=b2(1)*tau(1,itau)+b2(2)*tau(2,itau)+b2(3)*tau(3,itau)
      tau13=b3(1)*tau(1,itau)+b3(2)*tau(2,itau)+b3(3)*tau(3,itau)
      tau11=tau11/alat
      tau12=tau12/alat
      tau13=tau13/alat
c ***
      call reset(tau11)
      call reset(tau12)
      call reset(tau13)
c ***
      write(77,7110)tau11,tau12,tau13,itau
  877 continue
c ***** Final velocity
      write(77,*)' Velocities '
      do itau=1,ntauq
      write(77,7110)( velo(j,itau),j=1,3 ),itau
      enddo
 7110 FORMAT(( 3F22.16,3X,'TAU( ',I3,')' ))
c **** Fial simulation time
      write(77,7111)time
 7111 format(' Simulation time = ',f22.16,' fsec')
C
c ******
      endif
C *****
C
      if ( my_rank.eq.0 ) then
      CALL CLOCK(TIM)
c      CALL cpu_time(TIM)
      WRITE(6,7022) TIM
 7022 FORMAT(///23X,'****  CPU TIME END OF PSPW:',F15.7,' SEC'//)
 7008 FORMAT(23X,'****  CPU TIME AFT FRPRMN: ',F15.7,' SEC'///)
      endif
C
      call prof_report()
c      STOP
c *****
      call ENDFFT_fftwASL(NRX,NRY,NRZ)
c ****
c *****
      call MPI_Finalize(ierr)
c *****
      END
c
      subroutine Ext_field(ExtX,ExtY,ExtZ,ft)
      implicit double precision(a-h,o-z)
      COMMON/EPOL/ExtX0,ExtY0,ExtZ0  ! converted V/A->a.u.
c
      ExtX=ExtX0*ft
      ExtY=ExtY0*ft
      ExtZ=ExtZ0*ft
c
      return
      end
C***********************************************************
      SUBROUTINE PRENON(JOPT,NG2Q,NG2,TPIBA,NGQ,NG,G,
     &  NUMKQ,NUMK,Gold,G2,SPB,VGA,WORK3,NUMTY,NTYQ,NTYPE,VPJ,VPP
c ** for parallel
     & ,VPJWORK
c
     & ,NCRQ,ZV,RC0,COR,NUMC,ALPPP,BETAPP,IOVP, MXOFL,VPP2,OMEGA
     & ,ADUMP,ATEMP,NGNL
     & ,RAD,PSPOT,PSPOT2,PHIL,NGcont
c
     & ,mshbegin,mshend,ncpuq )
C***********************************************************
C
C               NUMERICAL POTENTIAL (1992-02-28) OSAMU SUGINO
C       JOPT:1   CONSTRUCT PP(G) of local potential
C            2   CONSTRUCT VPJ AND VPP and VPP2 for nonlocal
C
C
      IMPLICIT REAL*8(A-H,O-Z)
C        INPUT
ccc      DIMENSION NG2(NUMKQ)
      include 'mpif.h'
c      include 'ncpuq.h'
      dimension NGNL(NTYQ,NUMKQ)
      dimension Gold(4,NG2Q,NUMKQ) ! G without A
      DIMENSION G2(4,NG2Q,NUMKQ),NUMTY(NTYQ),G(4,NGQ)
      DIMENSION ZV(NTYQ),RC0(NCRQ,NTYQ),COR(NCRQ,NTYQ),NUMC(NTYQ)
c      DIMENSION  BETAPP(3,NTYQ),ALPPP(3,NTYQ),IOVP(2,NTYQ,NUMKQ)
      DIMENSION  BETAPP(4,NTYQ),ALPPP(4,NTYQ),IOVP(2,NTYQ,NUMKQ)
     &         , MXOFL(NTYQ)
C        WORK
c      DIMENSION SPB(NG2Q),WORK3(NGQ)
      DIMENSION SPB(NG2Q),WORK3(NGQ),VGA(NGQ,NTYQ)
c      PARAMETER(MESHQ=1000, ISPD=5, NTYQ2=4)
c      PARAMETER(MESHQ=1000, ISPD=6, NTYQ2=4)
      PARAMETER(MESHQ=1000, ISPD=8, NTYQ2=4)
c  *** for G-A version PSDATA need to be common!
      dimension RAD(MESHQ,NTYQ2),PSPOT(MESHQ,ISPD,NTYQ2),
     &    PSPOT2(MESHQ,ISPD,NTYQ2),PHIL(MESHQ,4,NTYQ2)
c  ****
c      DIMENSION RAD(MESHQ)
c      DIMENSION PSPOT(MESHQ,ISPD),PSPOT2(MESHQ,ISPD)
cc      DIMENSION PHIL(MESHQ,2)
cc      DIMENSION PHIL(MESHQ,3)
c      DIMENSION PHIL(MESHQ,4)
      DIMENSION WORK(MESHQ),WORK2(MESHQ)
c      DIMENSION VV(3),ZO(2,2)
c      DIMENSION VV(3),ZO(2,NTYQ2)
c      DIMENSION VV(3),ZO(3,NTYQ2)
      DIMENSION VV(3),ZO(4,NTYQ2)
C        OUTPUT
c      DIMENSION VPJ(NG2Q,3),VPP(3)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ)
c                          ^ ^
c                          | |
c             partitioning   max of L
      DIMENSION VPJWORK(NGcont,3)  ! for parallel computing
C
c      dimension VPP2(4,3,NTYQ,NUMKQ)
c      dimension VPP2(9,3,NTYQ,NUMKQ)
      dimension VPP2(16,3,NTYQ,NUMKQ)  ! VPP2 also depends on A
      DATA ISAISHO/1/
cc      common/cputask4/mshbegin(0:ncpuq),mshend(0:ncpuq),ncpu4
      dimension mshbegin(0:ncpuq),mshend(0:ncpuq)
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c
c +++ temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' ** In PRENON *** '
c       do ik=1,NUMK
c        write(6,*)' ik =',ik
c        write(6,*)' Gold(=G2) '
c        do ig=1,NG2Q,500
c         write(6,'(4F22.16)')( Gold(j,ig,ik),j=1,4 )
c        enddo
c       enddo
c       write(6,*)' GG2(=G2) '
c       do ik=1,NUMK
c        do ig=1,NG2Q,500
c         write(6,'(4F22.16)')( G2(j,ig,ik),j=1,4 )
c        enddo
c       enddo
c      endif
c ++++
C
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
      FPI=4.D0*PI
      pi8=8.d0*pi
      pi16=16.d0*pi
      pi32=32.d0*pi
c      pi64=64.d0*pi
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
c            CALL PSREAD2(ITY,ISPD,MESHQ,MESH,RAD,PSPOT
            CALL PSREAD2(ITY,ISPD,MESHQ,MESH,RAD(1,ITY),PSPOT(1,1,ITY)
     &            ,PHIL(1,1,ITY),WORK
     &            ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
c
c      call MPI_Bcast(RAD(1,ITY),MESH,MPI_DOUBLE_PRECISION,
c     &   0,MPI_COMM_WORLD,ierr)
c
c        call MPI_Bcast(PHIL(1,1,ITY),4*MESH,MPI_DOUBLE_PRECISION,
c     &    0,MPI_COMM_WORLD,ierr)
c
c        call MPI_Bcast(PSPOT(1,1,ITY),ISPD*MESH,MPI_DOUBLE_PRECISION,
c     &   0,MPI_COMM_WORLD,ierr)
c
c ++++
c            if (my_rank.eq.0 ) then
c             write(6,*)' check RAD from psread2 '
c             write(6,*)' ity = ',ity
c             write(6,8080)( RAD(K,ITY), K=1,MESHQ,100 )
c             write(6,*)' check PHIL from psread2 '
c             do IIL=1,MXOFL(ITY)
c              write(6,*)' IIL=',IIL
c              write(6,*)' PHIL '
c              write(6,8080)( PHIL(K,IIL,ITY), K=1,MESHQ,100 )
c              write(6,*)' PSPOT '
c              write(6,8080)( PSPOT(K,IIL,ITY), K=1,MESHQ,100 )
c             enddo
c 8080        format(4f22.16)
c            endif
c
C             PSEUDOPOTENTIAL IN G-SPACE
C
            CALL PSOFG(NGQ,NG,G,MESHQ,MESH,
c     &           RAD,WORK,WORK2,WORK3,TPIBA
     &           RAD(1,ITY),WORK,WORK2,VGA(1,ITY),TPIBA
     &          ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
C **
            if ( my_rank.eq.0 ) then
            READ(5,*) ZO(1,ITY), ZO(2,ITY)
            endif
            call MPI_Bcast(ZO(1,ITY),1,MPI_DOUBLE_PRECISION,
     &         0,MPI_COMM_WORLD,ierr)
            call MPI_Bcast(ZO(2,ITY),1,MPI_DOUBLE_PRECISION,
     &         0,MPI_COMM_WORLD,ierr)
C
            DO 3611 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1,ITY)*PHIL(I,1,ITY)
3611        CONTINUE
              IF( MXOFL(ITY).EQ.1 ) THEN
            DO 3612 I=1,MESH
            WORK(I) = WORK(I) + ZO(2,ITY)*PHIL(I,2,ITY)*PHIL(I,2,ITY)
3612        CONTINUE
              END IF
C
            if ( my_rank.eq.0 ) then
            WRITE(6,9010) ITY, ZO(1,ITY), ZO(2,ITY)
 9010       FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) = ',I3,
     &                                      2D12.4 )
            endif
C
            CALL CDOFG(NGQ,NG,G,MESHQ,MESH,
     &              RAD(1,ITY),WORK,WORK2,WORK3,TPIBA)
c         ELSE IF( MXOFL(ITY) .EQ. 2 ) THEN
         ELSE IF( MXOFL(ITY) .GE. 2 ) THEN
C **********************************************
C              READ PSEUDOPOTENTIAL
C
            CALL PSREAD(ITY,ISPD,MESHQ,MESH,RAD(1,ITY),PSPOT(1,1,ITY)
     &            ,PSPOT2(1,1,ITY),PHIL(1,1,ITY),WORK
     &            ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))

c      call MPI_Bcast(RAD(1,ITY),MESH,MPI_DOUBLE_PRECISION,
c     &   0,MPI_COMM_WORLD,ierr)
c
c        call MPI_Bcast(PHIL(1,1,ITY),4*MESH,MPI_DOUBLE_PRECISION,
c     &    0,MPI_COMM_WORLD,ierr)
c
c        call MPI_Bcast(PSPOT(1,1,ITY),ISPD*MESH,MPI_DOUBLE_PRECISION,
c     &   0,MPI_COMM_WORLD,ierr)
c
c        call MPI_Bcast(PSPOT2(1,1,ITY),ISPD*MESH,
c     &         MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ierr)
c
c ++++
c            if (my_rank.eq.0 ) then
c             write(6,*)' check RAD from psread '
c             write(6,*)' ity = ',ity
c             write(6,8080)( RAD(K,ITY), K=1,MESHQ,100 )
c             do IIL=1,MXOFL(ITY)
c              write(6,*)' IIL=',IIL
c              write(6,8080)( PHIL(K,IIL,ITY), K=1,MESHQ,100 )
c             enddo
c            endif
C               PSEUDOPOTENTIAL IN G-SPACE
C
            CALL PSOFG(NGQ,NG,G,MESHQ,MESH,
c     &              RAD,WORK,WORK2,WORK3,TPIBA
     &              RAD(1,ITY),WORK,WORK2,VGA(1,ITY),TPIBA
     &             ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
C **
         IF (MXOFL(ITY).eq.2 ) THEN
            if (my_rank.eq.0 ) then
            READ(5,*) ZO(1,ITY), ZO(2,ITY)
            endif
            call MPI_Bcast(ZO(1,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            call MPI_Bcast(ZO(2,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
C
            DO 611 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1,ITY)*PHIL(I,1,ITY)
     &             +ZO(2,ITY)*PHIL(I,2,ITY)*PHIL(I,2,ITY)
 611        CONTINUE
C ** TEMP
C           DO 611 I=1,MESH
C 611       WORK(I) = FPI * EXP( -RAD(I)**2 ) * RAD(I)**2
C ** TEMP  END
C
            if ( my_rank.eq.0 ) then
            WRITE(6,9000) ITY, ZO(1,ITY), ZO(2,ITY)
 9000        FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) = ',I3,
     &                                       2D12.4 )
            endif
c
          ELSEIF (MXOFL(ITY).eq.3 ) THEN
             if (my_rank.eq.0 ) then
             read(5,*)ZO(1,ITY),ZO(2,ITY),ZO(3,ITY)
             endif
            call MPI_Bcast(ZO(1,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            call MPI_Bcast(ZO(2,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            call MPI_Bcast(ZO(3,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            DO 612 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1,ITY)*PHIL(I,1,ITY)
     &             +ZO(2,ITY)*PHIL(I,2,ITY)*PHIL(I,2,ITY)
     &             +ZO(3,ITY)*PHIL(I,3,ITY)*PHIL(I,3,ITY)
 612        CONTINUE
            if (my_rank.eq.0 ) then
            WRITE(6,9001) ITY, ZO(1,ITY), ZO(2,ITY), ZO(3,ITY)
 9001        FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) ZO(3) = ',I3,
     &                                       3D12.4 )
            endif
c
          ELSEIF (MXOFL(ITY).eq.4 ) THEN
             if (my_rank.eq.0 ) then
             read(5,*)ZO(1,ITY),ZO(2,ITY),ZO(3,ITY),ZO(4,ITY)
             endif
            call MPI_Bcast(ZO(1,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            call MPI_Bcast(ZO(2,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            call MPI_Bcast(ZO(3,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            call MPI_Bcast(ZO(4,ITY),1,MPI_DOUBLE_PRECISION,
     &          0,MPI_COMM_WORLD,ierr)
            DO 613 I=1,MESH
            WORK(I)=ZO(1,ITY)*PHIL(I,1,ITY)*PHIL(I,1,ITY)
     &             +ZO(2,ITY)*PHIL(I,2,ITY)*PHIL(I,2,ITY)
     &             +ZO(3,ITY)*PHIL(I,3,ITY)*PHIL(I,3,ITY)
     &             +ZO(4,ITY)*PHIL(I,4,ITY)*PHIL(I,4,ITY)
 613        CONTINUE
            if (my_rank.eq.0 ) then
            WRITE(6,9002) ITY, ZO(1,ITY), ZO(2,ITY), ZO(3,ITY),ZO(4,ITY)
 9002        FORMAT(/10X,'*****  PRENON: ITY ZO(1) ZO(2) ZO(3) ZO(4) = '
     &          ,I3,           4D12.4)
            endif
          ENDIF
             CALL CDOFG(NGQ,NG,G,MESHQ,MESH,
     &       RAD(1,ITY),WORK,WORK2,WORK3,TPIBA)
C
C **********************************************
         ELSE
           if ( my_rank.eq.0 ) then
           WRITE(6,9015) ITY, MXOFL(ITY)
 9015      FORMAT('   *** PRENON:   ITY  MXOFL(ITY) = ',2I5)
           STOP
           endif
        END IF
  610    CONTINUE
c *** temp check
c            if (my_rank.eq.0 ) then
c             write(6,*)' before returning prenont 1 '
c             do ity=1,NTYPE
c             write(6,*)' ity = ',ity
c             write(6,8080)( RAD(K,ITY), K=1,MESHQ,100 )
c             write(6,*)' check PHIL from psread2 '
c             do IIL=1,MXOFL(ITY)
c              write(6,*)' IIL=',IIL
c              write(6,*)' PHIL '
c              write(6,8080)( PHIL(K,IIL,ITY), K=1,MESHQ,100 )
c              write(6,*)' PSPOT '
c              write(6,8080)( PSPOT(K,IIL,ITY), K=1,MESHQ,100 )
c             enddo
c             enddo
cc 8080        format(4f22.16)
c            endif
c *** temp check: end
         RETURN
      ENDIF
C  (JOPT=2)
C     MAKE VPJ AND VPP
C
C*****LOOP OVER TYPE OF ATOM
c *** temp check for GG2
c      if (my_rank.eq.0 ) then
c      write(6,*)' JOPT=2 in PRENON'
c       do ik=1,NUMK
c        do ig=1,NG2Q,500
c         write(6,'(4F22.16)')( G2(j,ig,ik),j=1,4 )
c        enddo
c       enddo
c      endif
c *** temp check : end
      DO 10 ITY=1,NTYPE
c +++ temp check
c      if (my_rank.eq.0 ) then
c        write(6,*)' Before PSREAD2'
c        write(6,*)' check PRENON at nonlocal stage'
c        write(6,*)' ITY = ',ITY
c        write(6,*)' RAD '
c        write(6,8080)( RAD(K,ITY),K=1,MESHQ,100)
c          write(6,*)'  PHIL '
c             do IIL=1,MXOFL(ITY)
c              write(6,*)' IIL=',IIL
c              write(6,8080)( PHIL(K,IIL,ITY), K=1,MESHQ,100 )
c             enddo
cc 8080   format(4f22.16)
c      endif
c +++ temp check : end
C
C        READ PSEUDOPOTENTIAL
C
      MXL = MXOFL(ITY)
c      IF( MXL .EQ. 2 ) THEN
      IF( MXL .GE. 2 ) THEN
       CALL PSREAD(ITY,ISPD,MESHQ,MESH,RAD(1,ITY),PSPOT(1,1,ITY)
     &  ,PSPOT2(1,1,ITY),PHIL(1,1,ITY),WORK
     &  ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
      ELSE
       CALL PSREAD2(ITY,ISPD,MESHQ,MESH,RAD(1,ITY),PSPOT(1,1,ITY)
     & ,PHIL(1,1,ITY),WORK
     &  ,NCRQ,ZV(ITY),RC0(1,ITY),COR(1,ITY),NUMC(ITY))
      END IF
c
c
      IF(NUMTY(ITY).LT.0) GO TO 10
C
C         POTENTIAL PARTITIONING
c +++ temp check
c      if (my_rank.eq.0 ) then
c        write(6,*)' check PRENON at nonlocal stage'
c        write(6,*)' ITY = ',ITY
c        write(6,*)' RAD '
c        write(6,8080)( RAD(K,ITY),K=1,MESHQ,100)
c          write(6,*)'  PHIL '
c             do IIL=1,MXOFL(ITY)
c              write(6,*)' IIL=',IIL
c              write(6,8080)( PHIL(K,IIL,ITY), K=1,MESHQ,100 )
c             enddo
cc 8080   format(4f22.16)
c      endif
c +++ temp check : end
C
        H=LOG(RAD(MESH,ITY)/RAD(1,ITY))/(MESH-1.D0)
        DO 3300 K=1,MESH
          DO 3310 LI=1,MXL
          PSPOT(K,LI,ITY)=(PSPOT(K,LI,ITY)-WORK(K))*H*RAD(K,ITY)
          AA=BETAPP(LI,ITY)*(RAD(K,ITY)-ALPPP(LI,ITY))
          IF(ABS(AA).LT.100.0D0)THEN
            F=1.D0/(1.D0+EXP(AA))
          ELSE
            F=0.D0
          ENDIF
          PSPOT2(K,LI*2-1,ITY)=PSPOT(K,LI,ITY)*F
          PSPOT2(K,LI*2  ,ITY)=PSPOT(K,LI,ITY)*(1.D0-F)
 3310   CONTINUE
 3300   CONTINUE
c *** temp check
       if(my_rank.eq.0 ) then
       write(6,*)' ++++ PSPOT in PRENON +++++ '
       do J=1,MXL
        write(6,*)' J = ',J
        write(6,8181)(PSPOT(K,J,ITY),K=1,MESH,100)
       enddo
 8181  format(4f12.6)
       endif
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
            AA=(RAD(K,ITY)-U)*(RAD(K+1,ITY)-U)
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
c      wari=dexp( (G(4,ig)-4*ADUMP)/ATEMP ) + 1.d0
c      WORK3(ig)=1.d0/dsqrt(wari)
c      enddo
      DO 1000 IK=1,NUMK
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' G2 ! '
c       do IG=1,NG2,500
c       write(6,'(4f22.16)')(G2(J,IG,IK),J=1,4)
c       enddo
c      endif
c *** temp check: end
c ****  for smoothing !!!! determine by G (not G-A)
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' smoothing exponent factor in PRENON'
c       write(6,*)' ADUMP ATEMP =',ADUMP,ATEMP
c       write(6,'(4F22.16)')
c     &  ( (Gold(4,ig,ik)-ADUMP)/ATEMP,ig=1,NG2,500 )
c      endif
c *** temp check end
      do ig=1,NG2
c      wari=dexp( (G2(4,ig,ik)-4*ADUMP)/ATEMP ) + 1.d0
      wari=dexp( (Gold(4,ig,ik)-ADUMP)/ATEMP ) + 1.d0
      WORK3(ig)=1.d0/dsqrt(wari)
      enddo
c *** for efficiency
      do ig=1,ng2
      if ( work3(ig).lt.1.d-02 ) then
      NGNL(ITY,IK)=ig
      goto 1920
      endif
      enddo
 1920 continue
      if ( my_rank.eq.0 ) then
      write(6,*)' At IK = ',IK,',  Vnl needs ', NGNL(ITY,IK),
     &   ' G-vectors.'
      write(6,*)' Ratio to full FFT grids = '
     &       ,DFLOAT(NGNL(ITY,IK))/DFLOAT(NG2)
      if ( NGNL(ITY,IK) .gt. NG2Q/3 ) then
       write(6,*)' in sub. PRENON :::'
       write(6,*)' NG2Q/3 should be bigger than ',NGNL(ITY,IK)
       stop
      endif
      endif
c
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' Just before DO 30 PRENON'
c       write(6,*)' ITY = ',ITY
c       write(6,*)' RAD '
c       write(6,'(4f22.16)')(RAD(I,ITY),I=1,MESH,100)
c      endif
c *** temp check
C*****LOOP OVER ANGULAR QUANTUM NUMBER
      DO 30 LI=1,MXL
C*****ZERO CLEAR
        DO 3 J=1,3
        VPP(J,LI,ity)=0.D0
        if ( LI.eq.1 ) then
        VPP2(LI,J,ity,ik)=0.D0
        elseif (LI.eq.2) then
        VPP2(LI  ,J,ity,ik)=0.D0
        VPP2(LI+1,J,ity,ik)=0.D0
        VPP2(LI+2,J,ity,ik)=0.D0
        elseif (LI.eq.3) then
        VPP2(LI+2,J,ity,ik)=0.D0
        VPP2(LI+3,J,ity,ik)=0.D0
        VPP2(LI+4,J,ity,ik)=0.D0
        VPP2(LI+5,J,ity,ik)=0.D0
        VPP2(LI+6,J,ity,ik)=0.D0
        elseif (LI.eq.4) then
        VPP2(LI+6,J,ity,ik)=0.D0
        VPP2(LI+7,J,ity,ik)=0.D0
        VPP2(LI+8,J,ity,ik)=0.D0
        VPP2(LI+9,J,ity,ik)=0.D0
        VPP2(LI+10,J,ity,ik)=0.D0
        VPP2(LI+11,J,ity,ik)=0.D0
        VPP2(LI+12,J,ity,ik)=0.D0
        endif
        VV(J)=0.D0
c        DO 3 IG=1,NG2(IK)
c        DO 3 IG=1,NG2
        DO 3 IG=1,NGNL(ITY,IK)
        VPJ(IG,J,LI,ity,ik)=0.D0
    3   CONTINUE
c
C*****CALCULATE VPP&VV which do not depend on G-A vector
      SUM=0.D0
      do I=1,MESH
      SUM=SUM+PHIL(I,LI,ITY)**2*H*RAD(I,ITY)
      VPP(1,li,ity)=VPP(1,li,ity)+PSPOT (I,LI    ,ITY)*PHIL(I,LI,ITY)**2
      VPP(2,li,ity)=VPP(2,li,ity)+PSPOT2(I,2*LI-1,ITY)*PHIL(I,LI,ITY)**2
      VPP(3,li,ity)=VPP(3,li,ity)+PSPOT2(I,2*LI  ,ITY)*PHIL(I,LI,ITY)**2
      SUM1=(PSPOT (I,LI    ,ITY)*PHIL(I,LI,ITY))**2/H/RAD(I,ITY)
      SUM2=(PSPOT2(I,2*LI-1,ITY)*PHIL(I,LI,ITY))**2/H/RAD(I,ITY)
      SUM3=(PSPOT2(I,2*LI  ,ITY)*PHIL(I,LI,ITY))**2/H/RAD(I,ITY)
      VV(1)=VV(1)+SUM1
      VV(2)=VV(2)+SUM2
      VV(3)=VV(3)+SUM3
      enddo
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in PRENON '
c       write(6,*)' li=',li,' ity=',ity
c       write(6,*)' VPP ',VPP(1,li,ity)
c      endif
c *** temp check : end
c
      L=LI-1
C*****LOOP OVER MESH under LI,ity,ik loop
c      DO 50 I=1,MESH  ! this loop is parallelized
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' Just before DO 50 PRENON'
c       write(6,*)' ITY = ',ITY
c       write(6,*)' RAD '
c       write(6,'(4f22.16)')(RAD(I,ITY),I=1,MESH,100)
c      endif
c *** temp check : end
c +++ clean up VPJWORK befor mesh int
      DO IG=1,NGcont
       VPJWORK(IG,1)=0
       VPJWORK(IG,2)=0
       VPJWORK(IG,3)=0
      ENDDO
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' region of mesh integral'
c       write(6,*)mshbegin(my_rank),mshend(my_rank)
c      endif
c *** temp check: end
      DO 50 I=mshbegin(my_rank),mshend(my_rank)
C*****CONSTRUCT THE SPHERICAL BESSEL FUNCTION J_L(Q1*R)
      IF(L.EQ.0) THEN
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=1.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
c         DO 42 IG=ISTA,NG2(IK)
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in PRENON before DO 42'
c       write(6,*)' ISTA = ',ISTA
c       write(6,*)' G2 vector at ISTA'
c       write(6,*)G2(4,ISTA,IK)
c       write(6,*)'  RAD='
c       write(6,'(4f22.16)')(RAD(KMESH,ITY),KMESH=1,MESH,100)
c       write(6,*(' then RAD(I,ITY)=',RAD(I,ITY)
cc       miya=13
cc       if (miya.eq.13) stop
c      endif
c *** temp check end
c         DO 42 IG=ISTA,NG2
         DO 42 IG=ISTA,NGNL(ITY,IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I,ITY)*TPIBA
   42    SPB(IG)=SIN(TEMP)/TEMP
      ELSEIF(L.EQ.1) THEN
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
c         DO 44 IG=ISTA,NG2(IK)
c         DO 44 IG=ISTA,NG2
         DO 44 IG=ISTA,NGNL(ITY,IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I,ITY)*TPIBA
   44    SPB(IG)=(SIN(TEMP)-TEMP*COS(TEMP))/TEMP**2
      ELSEIF(L.EQ.2) THEN ! d-orbital
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
         DO 46 IG=ISTA,NGNL(ITY,IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I,ITY)*TPIBA
   46    SPB(IG)=( (3.d0-TEMP**2)*SIN(TEMP)-3.d0*TEMP*COS(TEMP) )
     &           /TEMP**3
      ELSEIF(L.EQ.3) THEN ! f-orbital
         IF(G2(4,1,IK).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
         DO 47 IG=ISTA,NGNL(ITY,IK)
         TEMP=SQRT(G2(4,IG,IK))*RAD(I,ITY)*TPIBA
         TEMP2=TEMP*TEMP
         TEMP3=TEMP*TEMP2
         TEMP4=TEMP2*TEMP2
         SPB(IG)=( (15.d0-6*TEMP2)*SIN(TEMP)+(TEMP3-15.d0*TEMP)
     &     *COS(TEMP) )  /TEMP4
   47    CONTINUE
      ENDIF
c *** Smoothing !!
c      do ig=1,NG2
      do ig=1,NGNL(ITY,IK)
      SPB(ig)=WORK3(ig)*SPB(ig)
      enddo
C*****  next was commented out done by another mesh
c      SUM=SUM+PHIL(I,LI,ITY)**2*H*RAD(I,ITY)
c      VPP(1,li,ity)=VPP(1,li,ity)+PSPOT (I,LI    ,ITY)*PHIL(I,LI,ITY)**2
c      VPP(2,li,ity)=VPP(2,li,ity)+PSPOT2(I,2*LI-1,ITY)*PHIL(I,LI,ITY)**2
c      VPP(3,li,ity)=VPP(3,li,ity)+PSPOT2(I,2*LI  ,ITY)*PHIL(I,LI,ITY)**2
c      SUM1=(PSPOT (I,LI    ,ITY)*PHIL(I,LI,ITY))**2/H/RAD(I,ITY)
c      SUM2=(PSPOT2(I,2*LI-1,ITY)*PHIL(I,LI,ITY))**2/H/RAD(I,ITY)
c      SUM3=(PSPOT2(I,2*LI  ,ITY)*PHIL(I,LI,ITY))**2/H/RAD(I,ITY)
c      VV(1)=VV(1)+SUM1
c      VV(2)=VV(2)+SUM2
c      VV(3)=VV(3)+SUM3
c
C*****CALCULATE VPJ&VPP2
c      DO 52 IG=1,NG2(IK)
c      DO 52 IG=1,NG2
      DO 52 IG=1,NGNL(ITY,IK)
c      VPJ(IG,1,li,ity,ik)=VPJ(IG,1,li,ity,ik)
      VPJWORK(IG,1)=VPJWORK(IG,1)
     &       +FPI*PSPOT (I,LI    ,ITY)*PHIL(I,LI,ITY)*RAD(I,ITY)*SPB(IG)
c      VPJ(IG,2,li,ity,ik)=VPJ(IG,2,li,ity,ik)
      VPJWORK(IG,2)=VPJWORK(IG,2)
     &       +FPI*PSPOT2(I,LI*2-1,ITY)*PHIL(I,LI,ITY)*RAD(I,ITY)*SPB(IG)
c      VPJ(IG,3,li,ity,ik)=VPJ(IG,3,li,ity,ik)
      VPJWORK(IG,3)=VPJWORK(IG,3)
     &       +FPI*PSPOT2(I,LI*2  ,ITY)*PHIL(I,LI,ITY)*RAD(I,ITY)*SPB(IG)
   52 CONTINUE
   50 CONTINUE  ! end of mesh:  next need Allreduce of VPJ
c +++ 2020 begin insert
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' In PRENON:  VPJWORK IK=',IK
c       write(6,*)' ITY =',ITY,' LI=',LI
c       write(6,'(4F22.16)')(VPJWORK(IG,1),IG=1,NGNL(ITY,IK),500)
c      endif
c *** temp check : end
      LngthDat=3*(NGcont)
c      if (my_rank.eq.0 ) then
c       write(6,*)' just before ALLReduce VPJ '
c       write(6,*)' LngthDat= ',LngthDat
c      endif
      call MPI_ALLReduce(VPJWORK(1,1),VPJ(1,1,li,ity,ik),LngthDat,
     &  MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' LI ITY IK =',li,ity,ik
c       write(6,*)' VPJ '
c       write(6,'(4F22.16)')( VPJ(IG,1,LI,ity,ik),IG=1,NGNL(ITY,IK),500)
c      endif
c *** temp check : end
c +++ 2020 end insert
c
      DO 5320 KK=1,MESH
        WORK2(KK)=PHIL(KK,LI,ITY)**2
 5320 CONTINUE
      SUM2=DIADL(RAD(1,ITY),WORK2,MESH,H2,3,DX)
C
        IF(ABS(SUM-1.D0).GT.1.D-8 .and. my_rank.eq.0 )
     &   WRITE(6,6000) LI, SUM
 6000   FORMAT('        **** WARNING: SUM OF PHIL**2*H*R = ',I3,D20.12)
        IF(ABS(SUM2-1.D0).GT.1.D-8 .and. my_rank.eq.0)
     &   WRITE(6,6002) LI, SUM2
 6002   FORMAT('        **** WARNING: DIADL OF PHIL**2 = ',I3,D20.12)
C
        IF(ISAISHO.EQ.1 .and. my_rank.eq.0) THEN
            WRITE(6,8010) ITY, IK, LI, (VPP(KK,LI,ITY),KK=1,3)
 8010       FORMAT('   SUM OF VNL*PSIL**2: TOTAL AND PARTITIONED ',
     &              'FOR ITY = ',I4,' K = ',I3,' LI = ',I4,':'/
     &              10X,3D14.5)
            WRITE(6,8012)  ( VPP(KK,LI,ITY)/SQRT(VV(KK)), KK=1,3 )
 8012       FORMAT('   VPP / VV: ',3D14.5)
        ENDIF
C
ccccccc      WRITE(82,REC=IOVP(LI,ITY,IK)) VPP, VPJ
c ****  temp check
c      write(6,*)' in sub. PRENON '
c       WRITE(6,*) ' VPJ LIST ',LI,ITY,IK
c       DO 20 IG=1,NG2(IK)
c 20    WRITE(6,'(I6,2E15.7)') IG,SQRT(G2(4,IG,IK))*TPIBA,
c     &  VPJ(IG,1,LI,ITY,IK)
c     &                          /VPP(1,LI,ITY)
c ****  temp check end
C
   30 CONTINUE
c ****  here review VPJ and redefine cutoff length of G-vectors, NGNL
      do 152 ig=NGNL(ITY,IK),1,-1
      vmax=0
      do li=1,mxl
      v1=dabs( VPJ(ig,1,li,ity,ik) )
      v2=dabs( VPJ(ig,2,li,ity,ik) )
      v3=dabs( VPJ(ig,3,li,ity,ik) )
      v123max=max(v1,v2,v3)
      vmax=max(vmax,v123max)
      enddo
      if ( vmax.gt.1.d-03 ) then
       NGNL(ITY,IK)=ig
       goto 153
      endif
  152 continue
  153 continue
      if ( my_rank.eq.0 ) then
      write(6,*)' Now NGNL has been redefined '
      endif
      ratio=dfloat( NGNL(ITY,IK) )/dfloat( NG2 )
      if ( my_rank.eq.0 ) then
      write(6,1152)ity,ik,NGNL(ITY,IK),ratio
      endif
 1000 CONTINUE
c *****Calculate VPP2 in G-space
      do ik=1,numk
      do il=1,mxofl(ity)
       if ( il.eq.1 ) then  ! s-component
       do ip=1,3
c         do ig=1,ng2(ik)
c         do ig=1,ng2
         do ig=1,NGNL(ITY,IK)
         VPP2(il,ip,ity,ik)=VPP2(il,ip,ity,ik)
     &  +VPJ(ig,ip,il,ity,ik)**2
         enddo
         VPP2(il,ip,ity,ik)=VPP2(il,ip,ity,ik)/fpi/OMEGA
       enddo
       elseif( il.eq.2 ) then ! p-components
        if ( G2(4,1,ik).eq.0.D0 ) then
         ISTA=2
        else
         ISTA=1
        endif
       do ip=1,3
c *** attention! (tentative!)
c         if (G2(4,1,ik).eq.0.d0 ) then
c         VPP2(il+2,ip,ity,ik)=( VPJ(1,ip,il,ity,ik) )**2
c         endif
c *** attention end:
c         do ig=ISTA,ng2(ik)
c         do ig=ISTA,ng2
         do ig=ISTA,NGNL(ITY,IK)
         VPP2(il  ,ip,ity,ik)=VPP2(il  ,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*G2(1,ig,ik) )**2/G2(4,ig,ik)
         VPP2(il+1,ip,ity,ik)=VPP2(il+1,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*G2(2,ig,ik) )**2/G2(4,ig,ik)
         VPP2(il+2,ip,ity,ik)=VPP2(il+2,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*G2(3,ig,ik) )**2/G2(4,ig,ik)
         enddo
         VPP2(il  ,ip,ity,ik)=VPP2(il  ,ip,ity,ik)*3.d0/fpi/OMEGA
         VPP2(il+1,ip,ity,ik)=VPP2(il+1,ip,ity,ik)*3.d0/fpi/OMEGA
         VPP2(il+2,ip,ity,ik)=VPP2(il+2,ip,ity,ik)*3.d0/fpi/OMEGA
c *** comments: factors of VPP2(3,ip) VPP2(4,ip) are corrected in exnlp by 1/sqr2
       enddo
       elseif( il.eq.3 ) then ! d-components
        if ( G2(4,1,ik).eq.0.D0 ) then
         ISTA=2
        else
         ISTA=1
        endif
       do ip=1,3
c         do ig=ISTA,ng2(ik)
c         do ig=ISTA,ng2
c *** attention! (tentative!)
         if (G2(4,1,ik).eq.0.d0 ) then
         VPP2(il+2,ip,ity,ik)=( VPJ(1,ip,il,ity,ik)*2.d0 )**2
         endif
c *** attention end:
         do ig=ISTA,NGNL(ITY,IK)
         GG2=G2(4,ig,ik)
         VPP2(il+2,ip,ity,ik)=VPP2(il+2,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*( 3.D0*G2(3,ig,ik)**2/GG2-1.d0 ) )**2
         VPP2(il+3,ip,ity,ik)=VPP2(il+3,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*(G2(1,ig,ik)**2-G2(2,ig,ik)**2)/GG2 )**2
         VPP2(il+4,ip,ity,ik)=VPP2(il+4,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*G2(1,ig,ik)*G2(2,ig,ik)/GG2 )**2
         VPP2(il+5,ip,ity,ik)=VPP2(il+5,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*G2(3,ig,ik)*G2(1,ig,ik)/GG2 )**2
         VPP2(il+6,ip,ity,ik)=VPP2(il+6,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*G2(2,ig,ik)*G2(3,ig,ik)/GG2 )**2
         enddo
         VPP2(il+2,ip,ity,ik)=VPP2(il+2,ip,ity,ik)* 5.d0/pi16/OMEGA
         VPP2(il+3,ip,ity,ik)=VPP2(il+3,ip,ity,ik)*15.d0/pi16/OMEGA
         VPP2(il+4,ip,ity,ik)=VPP2(il+4,ip,ity,ik)*15.d0/fpi/OMEGA
         VPP2(il+5,ip,ity,ik)=VPP2(il+5,ip,ity,ik)*15.d0/fpi/OMEGA
         VPP2(il+6,ip,ity,ik)=VPP2(il+6,ip,ity,ik)*15.d0/fpi/OMEGA
c         VPP2(il+3,ip,ity,ik)=VPP2(il+3,ip,ity,ik)*15.d0/pi32/OMEGA
c         VPP2(il+4,ip,ity,ik)=VPP2(il+4,ip,ity,ik)*15.d0/pi8/OMEGA
c         VPP2(il+5,ip,ity,ik)=VPP2(il+5,ip,ity,ik)*15.d0/pi8/OMEGA
c         VPP2(il+6,ip,ity,ik)=VPP2(il+6,ip,ity,ik)*15.d0/pi8/OMEGA
       enddo
       elseif( il.eq.4 ) then ! f-components
        if ( G2(4,1,ik).eq.0.D0 ) then
         ISTA=2
        else
         ISTA=1
        endif
       do ip=1,3
c         do ig=ISTA,ng2(ik)
c         do ig=ISTA,ng2
c *** attention! (tentative!)
         if (G2(4,1,ik).eq.0.d0 ) then
         VPP2(il+6,ip,ity,ik)=( VPJ(1,ip,il,ity,ik)*2.d0 )**2
         endif
c *** attention end:
         do ig=ISTA,NGNL(ITY,IK)
         GX=G2(1,IG,IK)
         GY=G2(2,IG,IK)
         GZ=G2(3,IG,IK)
         GG=dsqrt( G2(4,ig,ik) )
         GG2=G2(4,ig,ik)
         GG3=GG2*GG
         VPP2(il+ 6,ip,ity,ik)=VPP2(il+ 6,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*(5*GZ**2/GG2 -3.D0)*GZ/GG )**2
         VPP2(il+ 7,ip,ity,ik)=VPP2(il+ 7,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*GX*( GX**2 -3*GY**2 )/GG3 )**2
         VPP2(il+ 8,ip,ity,ik)=VPP2(il+ 8,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*GY*( 3*GX**2 -GY**2 )/GG3 )**2
         VPP2(il+ 9,ip,ity,ik)=VPP2(il+ 9,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*GZ*( GX**2 - GY**2  )/GG3 )**2
         VPP2(il+10,ip,ity,ik)=VPP2(il+10,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*2*GZ*GX*GY/GG3 )**2
         VPP2(il+11,ip,ity,ik)=VPP2(il+11,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*GX*(5*GZ**2 - GG2)/GG3 )**2
         VPP2(il+12,ip,ity,ik)=VPP2(il+12,ip,ity,ik)
     &  +( VPJ(ig,ip,il,ity,ik)*GY*(5*GZ**2 - GG2)/GG3 )**2
         enddo
         VPP2(il+ 6,ip,ity,ik)=VPP2(il+ 6,ip,ity,ik)*  7.d0/pi16/OMEGA
c         VPP2(il+ 7,ip,ity,ik)=VPP2(il+ 7,ip,ity,ik)* 35.d0/pi64/OMEGA
c         VPP2(il+ 8,ip,ity,ik)=VPP2(il+ 8,ip,ity,ik)* 35.d0/pi64/OMEGA
c         VPP2(il+ 9,ip,ity,ik)=VPP2(il+ 9,ip,ity,ik)*105.d0/pi32/OMEGA
c         VPP2(il+10,ip,ity,ik)=VPP2(il+10,ip,ity,ik)*105.d0/pi32/OMEGA
c         VPP2(il+11,ip,ity,ik)=VPP2(il+11,ip,ity,ik)* 21.d0/pi64/OMEGA
c         VPP2(il+12,ip,ity,ik)=VPP2(il+12,ip,ity,ik)* 21.d0/pi64/OMEGA
         VPP2(il+ 7,ip,ity,ik)=VPP2(il+ 7,ip,ity,ik)* 35.d0/pi32/OMEGA
         VPP2(il+ 8,ip,ity,ik)=VPP2(il+ 8,ip,ity,ik)* 35.d0/pi32/OMEGA
         VPP2(il+ 9,ip,ity,ik)=VPP2(il+ 9,ip,ity,ik)*105.d0/pi16/OMEGA
         VPP2(il+10,ip,ity,ik)=VPP2(il+10,ip,ity,ik)*105.d0/pi16/OMEGA
         VPP2(il+11,ip,ity,ik)=VPP2(il+11,ip,ity,ik)* 21.d0/pi32/OMEGA
         VPP2(il+12,ip,ity,ik)=VPP2(il+12,ip,ity,ik)* 21.d0/pi32/OMEGA
       enddo
       endif
c ***  temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' VPP2 ity,il= ',ity,il
c       write(6,*)(VPP2(il  ,ip,ity,ik),ip=1,3 )
c       if ( il.eq.2 ) then
c        write(6,*)(VPP2(il+1,ip,ity,ik),ip=1,3 )
c        write(6,*)(VPP2(il+2,ip,ity,ik),ip=1,3 )
c       endif
c      endif
c *** temp check : end
      enddo  !  il loop
      enddo  !  ik loop
c
   10 CONTINUE
c *** temp check for GG2
c      if (my_rank.eq.0 ) then
c      write(6,*)' GG2 after DO 10 in PRENON'
c       do ik=1,NUMK
c        do ig=1,NG2Q,500
c         write(6,'(4F22.16)')( G2(j,ig,ik),j=1,4 )
c        enddo
c       enddo
c      endif
c *** temp check : end
c ***  temp check
c      miya=13
c      if ( miya.eq.13 ) stop
c ***  temp check : end
      ISAISHO=0
 1152 format(' NGNL(',i2,',',i3,')=',i10,
     & ' Ratio to the full grids = ',f22.16) 
C
c *** temp check
c            if (my_rank.eq.0 ) then
c             write(6,*)' before returning prenont 2 '
c             do ity=1,ntype
c             write(6,*)' ity = ',ity
c             write(6,8080)( RAD(K,ITY), K=1,MESHQ,100 )
c             write(6,*)' check PHIL from psread2 '
c             do IIL=1,MXOFL(ITY)
c              write(6,*)' IIL=',IIL
c              write(6,*)' PHIL '
c              write(6,8080)( PHIL(K,IIL,ITY), K=1,MESHQ,100 )
c              write(6,*)' PSPOT '
c              write(6,8080)( PSPOT(K,IIL,ITY), K=1,MESHQ,100 )
c             enddo
c             enddo
cc 8080        format(4f22.16)
c            endif
c *** temp check: end
      RETURN
      END
C***********************************************************
      SUBROUTINE PSREAD(ITY,ISPD,MESHQ,MESH,
     & RAD,PSPOT,PSPOT2,PHIL,WORK,
     & NCRQ,ZV,RC0,COR,NUMC)
C***********************************************************
C
      IMPLICIT REAL*8(A-H,O-Z)
      include 'mpif.h'
C        OUTPUT
      DIMENSION RAD(MESHQ)
      DIMENSION PSPOT(MESHQ,ISPD),PSPOT2(MESHQ,ISPD)
c      DIMENSION PHIL(MESHQ,2)
c      DIMENSION PHIL(MESHQ,3)
      DIMENSION PHIL(MESHQ,4)
      DIMENSION WORK(MESHQ)
      DIMENSION RC0(NCRQ),COR(NCRQ)
      DATA IST/1/
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
C
      IWT=40+ITY
      IWT2=45+ITY
      if ( my_rank.eq.0 ) then
      REWIND IWT
      REWIND IWT2
      endif
C
      NUMC=2
      NN=NUMC
      if ( my_rank.eq.0 ) then
c      READ(IWT ) ZV, (RC0(J),J=1,NN), COR(1)
c      READ(IWT2) ZV, (RC0(J),J=1,NN), COR(1)
      READ(IWT,* ) ZV, (RC0(J),J=1,NN), COR(1)
      READ(IWT2,*) ZV, (RC0(J),J=1,NN), COR(1)
      endif
      call MPI_Bcast(ZV,1,MPI_DOUBLE_PRECISION,
     &         0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(COR(1),1,MPI_DOUBLE_PRECISION
     &       ,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(RC0,NN,MPI_DOUBLE_PRECISION,
     &       0,MPI_COMM_WORLD,ierr)
      ZV=-ZV
      COR(2)=1.0D+00-COR(1)
      DO 605 J=1,NN
  605 RC0(J)=1.0D+00/RC0(J)
C
      if (my_rank.eq.0 ) then
c      READ(IWT) NVST,MESH
c      READ(IWT2) NVST2,MESH2
      READ(IWT,*) NVST,MESH
      READ(IWT2,*) NVST2,MESH2
      endif
      call MPI_Bcast(NVST ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(NVST2,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(MESH ,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(MESH2,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
C
      IF(IST.EQ.ITY .and.my_rank.eq.0 ) WRITE(6,3330) ITY, ZV
     &               ,(COR(JJ),RC0(JJ),JJ=1,NUMC ), NVST, NVST2, MESH
 3330   FORMAT(/' PSEUDOPOTENTIAL FOR ',I4,'  -TH ATOM: ZV = ',F10.2/
     &    20X,'     COR AND RC0 = ',2D13.5/
     &    20X,'                   ',2D13.5/
     &    20X,'     NVST NVST2 MESH = ',3I5)
C
      IF(MESH.GT.MESHQ .OR. MESH2.GT.MESHQ) THEN
       if ( my_rank.eq.0 ) then
          WRITE(6,3800) MESH, MESH2, MESHQ
 3800     FORMAT(///' ******   WARNING: MESH MESH2 MESHQ = ',3I6)
          STOP
       endif
        END IF
C
C
      if ( my_rank.eq.0 ) then
c      READ(IWT) (RAD(K),K=1,MESH)
c      READ(IWT2)(RAD(K),K=1,MESH)
      READ(IWT,*) (RAD(K),K=1,MESH)
      READ(IWT2,*)(RAD(K),K=1,MESH)
      endif
      call MPI_Bcast(RAD,MESH,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
C
C       READ PSEUDO ORBITALS
C
      DO 3101 J=1,NVST
        if ( my_rank.eq.0 ) then
c        READ(IWT) (PHIL(K,J),K=1,MESH)
        READ(IWT,*) (PHIL(K,J),K=1,MESH)
        endif
        call MPI_Bcast(PHIL(1,j),MESH,MPI_DOUBLE_PRECISION,
     &    0,MPI_COMM_WORLD,ierr)
 3101 CONTINUE
      DO 3151 J=1,NVST2
cC       READ(IWT2) (PHIL2(K),K=1,MESH)
        if ( my_rank.eq.0 ) then
c        READ(IWT2)
        READ(IWT2,*)
        endif
 3151 CONTINUE
C
C       READ PSEUDO POTENTITALS
C
      DO 3201 J=1,NVST
        if ( my_rank.eq.0 ) then
c        READ(IWT) (PSPOT(K,J),K=1,MESH)
        READ(IWT,*) (PSPOT(K,J),K=1,MESH)
        endif
        call MPI_Bcast(PSPOT(1,j),mesh,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
        if ( my_rank.eq.0 ) then
c        READ(IWT2) (PSPOT2(K,J),K=1,MESH)
        READ(IWT2,*) (PSPOT2(K,J),K=1,MESH)
        endif
        call MPI_Bcast(PSPOT2(1,j),mesh,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
 3201 CONTINUE
      DO 3251 J=1,NVST2-NVST
        if ( my_rank.eq.0 ) then
c        READ(IWT2) (PSPOT2(K,J+NVST),K=1,MESH)
        READ(IWT2,*) (PSPOT2(K,J+NVST),K=1,MESH)
        endif
        call MPI_Bcast(PSPOT2(1,j+nvst),mesh,
     &         MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ierr)
 3251 CONTINUE
C
c **** temp check
       if (my_rank.eq.0 ) then
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
       endif
c **** temp check: end
C ******   ASSUME D COMPONENT IS IN NVST2 = 3 -TH ARRAY
c      IF( NVST.NE.2 .OR. NVST2.NE.3 ) THEN
c      IF( NVST.GT.3 .OR. NVST2.GT.4) THEN
      IF( NVST.GT.4 .OR. NVST2.GT.5) THEN
        if ( my_rank.eq.0 ) then
        WRITE(6,6000) NVST, NVST2
        endif
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
      include 'mpif.h'
C        OUTPUT
      DIMENSION RAD(MESHQ)
      DIMENSION PSPOT(MESHQ,ISPD)
      DIMENSION PHIL(MESHQ,4)
      DIMENSION WORK(MESHQ)
      DIMENSION RC0(NCRQ),COR(NCRQ)
C ***  TEMP:  HYDROGEN IS THE IST-TH ATOM TYPE.
      DATA IST/2/
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
C
      IWT=40+ITY
      if ( my_rank.eq.0 ) then
      REWIND IWT
      endif
C
      NUMC=2
      NN=NUMC
      if (my_rank.eq.0 ) then
c      READ(IWT ) ZV, (RC0(J),J=1,NN), COR(1)
      READ(IWT,* ) ZV, (RC0(J),J=1,NN), COR(1)
      endif
      call MPI_Bcast(ZV,1,MPI_DOUBLE_PRECISION,
     &    0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(RC0,NN,MPI_DOUBLE_PRECISION,
     &    0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(COR(1),1,MPI_DOUBLE_PRECISION,
     &    0,MPI_COMM_WORLD,ierr)
      ZV=-ZV
      COR(2)=1.0D+00-COR(1)
      DO 605 J=1,NN
  605 RC0(J)=1.0D+00/RC0(J)
C
      if ( my_rank.eq.0 ) then
c      READ(IWT) NVST,MESH
      READ(IWT,*) NVST,MESH
      endif
      call MPI_Bcast(NVST,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(MESH,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
C
c      IF(IST.EQ.ITY .and. my_rank.eq.0 ) WRITE(6,3330) ITY, ZV
      IF( my_rank.eq.0 ) WRITE(6,3330) ITY, ZV
     &               ,(COR(JJ),RC0(JJ),JJ=1,NUMC ), NVST, MESH
 3330   FORMAT(/' PSEUDOPOTENTIAL FOR ',I4,'  -TH ATOM: ZV = ',F10.2/
     &    20X,'     COR AND RC0 = ',2D13.5/
     &    20X,'                   ',2D13.5/
     &    20X,'     NVST  MESH = ',2I5)
C
        IF(MESH.GT.MESHQ ) THEN
          if ( my_rank.eq.0 ) then
          WRITE(6,3800) MESH,  MESHQ
          endif
 3800     FORMAT(///' ******   WARNING: MESH MESHQ = ',2I6)
          STOP
        END IF
C
C
      if (my_rank.eq.0) then
c      READ(IWT) (RAD(K),K=1,MESH)
c      write(6,*)' READ RAD'
      READ(IWT,*) (RAD(K),K=1,MESH)
      endif
      call MPI_Bcast(RAD,MESH,MPI_DOUBLE_PRECISION,
     &    0,MPI_COMM_WORLD,ierr)
C
C       READ PSEUDO ORBITALS
C
      DO 3101 J=1,NVST
        if ( my_rank.eq.0 ) then
c         write(6,*)' READ PHIL J=',J
c        READ(IWT) (PHIL(K,J),K=1,MESH)
        READ(IWT,*) (PHIL(K,J),K=1,MESH)
        endif
        call MPI_Bcast(PHIL(1,J),MESH,MPI_DOUBLE_PRECISION,
     &    0,MPI_COMM_WORLD,ierr)
 3101 CONTINUE
C
C       READ PSEUDO POTENTITALS
C
      DO 3201 J=1,NVST
        if ( my_rank.eq.0 ) then
c        READ(IWT) (PSPOT(K,J),K=1,MESH)
c         write(6,*)' READ PPOT J=',J
        READ(IWT,*) (PSPOT(K,J),K=1,MESH)
        endif
        call MPI_Bcast(PSPOT(1,J),MESH,MPI_DOUBLE_PRECISION,
     &    0,MPI_COMM_WORLD,ierr)
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
cccc        WRITE(81) WORK3
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
cc        WRITE(83) WORK3
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
c      DATA FF1  ,FF2  ,FF3  ,FF4  /
c     &     .2D1,.4D1,.0D1,.3D1 /
      FF1=.2D1
      FF2=.4D1
      FF3=.0D1
      FF4=.3D1
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
c
      subroutine nkin(velo,atmss,ntauq,Ekin)
      implicit double precision(a-h,o-z)
      include 'mpif.h'
      dimension velo(3,ntauq),atmss(ntauq)
      data amass/1836.15152d0/ ! atomic unit of mass of nucleus
c *** calculate nucleus kinetic energy
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      if ( my_rank.eq.0 ) then
      Ekin=0
      do 3 it=1,ntauq
      velo2=velo(1,it)**2+velo(2,it)**2+velo(3,it)**2
      Ekin=Ekin+0.5d0*amass*atmss(it)*velo2
    3 continue
      endif
      return
      end
c
      subroutine md(tau,fold,velo,atmss,ntauq,dt
     &             ,tau1,tau2,tau3,tau4,tau5)
      implicit double precision(a-h,o-z)
      include 'mpif.h'
      dimension tau(3,ntauq),fold(3,ntauq)
     &         ,velo(3,ntauq),atmss(ntauq)
     &         ,tau1(3,ntauq),tau2(3,ntauq),tau3(3,ntauq)
     &         ,tau4(3,ntauq),tau5(3,ntauq)
      data amass/1836.15152d0/ ! atomic unit of mass of nucleus
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      if ( my_rank.eq.0 ) then
        m=2
        pm=1.d0/( 4.d0 - 4.d0**(1.d0/dfloat(2*m-1) ) )
        pr1=pm
        pr2=pm
        pr3=1.d0-4*pm
        pr4=pr2
        pr5=pr1
        dt1=(pr1*0.5d0 )*dt
        dt2=(pr1+pr2*0.5d0 )*dt
        dt3=(pr1+pr2+pr3*0.5d0 )*dt
        dt4=(pr1+pr2+pr3+pr4*0.5d0 )*dt
        dt5=(pr1+pr2+pr3+pr4+pr5*0.5d0 )*dt
c update the atomic positions
      do 1 i=1,3
      do 1 it=1,ntauq
c ** ATTENTION:  fold is a gradient actually !!
      delta=dt1*(velo(i,it)-fold(i,it)*dt1/(2*amass*atmss(it)))
      tau1(i,it)=tau(i,it)+delta
      delta=dt2*(velo(i,it)-fold(i,it)*dt2/(2*amass*atmss(it)))
      tau2(i,it)=tau(i,it)+delta
      delta=dt3*(velo(i,it)-fold(i,it)*dt3/(2*amass*atmss(it)))
      tau3(i,it)=tau(i,it)+delta
      delta=dt4*(velo(i,it)-fold(i,it)*dt4/(2*amass*atmss(it)))
      tau4(i,it)=tau(i,it)+delta
      delta=dt5*(velo(i,it)-fold(i,it)*dt5/(2*amass*atmss(it)))
      tau5(i,it)=tau(i,it)+delta
      delta=dt*(velo(i,it)-fold(i,it)*dt/(2*amass*atmss(it)))
      tau(i,it)=tau(i,it)+delta
    1 continue
      endif
c  **** Note ! tau,tau1-5 are used for electronic structure calculation.
c           Therefore, these values must be shared by slave CPUs. 
      call MPI_Bcast(tau ,3*ntauq,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(tau1,3*ntauq,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(tau2,3*ntauq,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(tau3,3*ntauq,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(tau4,3*ntauq,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
      call MPI_Bcast(tau5,3*ntauq,MPI_DOUBLE_PRECISION,
     &   0,MPI_COMM_WORLD,ierr)
      return
      end
c
      subroutine vd(force,fold,velo,atmss,ntauq,dt)
      implicit double precision(a-h,o-z)
      include 'mpif.h'
      dimension force(3,ntauq),fold(3,ntauq)
     &         ,velo(3,ntauq),atmss(ntauq)
      data amass/1836.15152d0/ ! atomic unit of mass of nucleus
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c update the velocities
      if ( my_rank.eq.0 ) then
      do 1 i=1,3
      do 1 it=1,ntauq
      delta=(force(i,it)+fold(i,it))*dt/(2*amass*atmss(it) )
c ** ATTENTION:  fold and force are gradients actually !!
      velo(i,it)=velo(i,it)-delta
    1 continue
c *** temp check
c      do it=1,ntauq
c       write(6,*)' V=',(velo(j,it),j=1,3)
c      enddo
c *** temp check ; end
      endif
      return
      end
c
      subroutine fsave(force,fold,ntauq)
      implicit double precision(a-h,o-z)
      include 'mpif.h'
      dimension force(3,ntauq),fold(3,ntauq)
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      if ( my_rank.eq.0 ) then
      do 1 j=1,3
       do 1 it=1,ntauq
        fold(j,it)=force(j,it)
    1 continue
c *** temp check
c      do it=1,ntauq
c       write(6,*)' frc=',(fold(j,it),j=1,3)
c      enddo
c *** temp check ; end
      endif
      return
      end
c
      subroutine wfwrit(coef,coef0,ng2q,ng2,mxbnd,mxbnd0,numkq,
     &                  numk,occ0,nbndq,nxyz
c
     &        ,nbegin,nend,ncpuq,ncpu )
      implicit double precision(a-h,o-z)
      include 'mpif.h'
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
      complex*16 coef(ng2q,mxbnd,numkq),coef0(ng2q,mxbnd,numkq)
      dimension occ0(nbndq,numkq)
      dimension ng2(numkq)
      integer status(MPI_STATUS_SIZE)
      integer tag
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      data tag/10/
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c *****
      if ( my_rank.eq.0 ) then
c      rewind 22
      rewind 23
      endif
c *******      
      do 450 ik=1,numk
       if ( my_rank.eq.0 ) then
c ******* gather all Wfs from slave CPUs
        do icpu=0,ncpu
        nbleng=nend(icpu)-nbegin(icpu)+1
        if ( icpu.ne.0 ) then
        call MPI_Recv(coef(1,1,ik),nxyz*nbleng,
     &       MPI_DOUBLE_COMPLEX,icpu,tag,MPI_COMM_WORLD,status,ierr)
        endif
c ******* gather end
c ******** then store to the disk
        do 452 ib=1,nbleng
c         write(22)( dreal( coef(ig,ib,ik) )
!        write(23)( dreal( coef(ig,ib,ik) )
!    &             ,aimag( coef(ig,ib,ik) ),ig=1,nxyz )
         write(23) (coef(ig,ib,ik),ig=1,nxyz)
  452   continue
        enddo  ! end of icpu loop
c ******** store end
       else 
c ******* send Wfs from slave to master CPUs
        nbleng=nend(my_rank)-nbegin(my_rank)+1
        call MPI_Send(coef(1,1,ik),nxyz*nbleng,
     &       MPI_DOUBLE_COMPLEX,0,tag,MPI_COMM_WORLD,ierr)
       endif
c ******* send end
  450 continue  ! end of k-loop
      return
      end
C***************************************************************
C     INITIALIZE CHRAGE DENSITY AND WAVEFUNCTION
C                     OSAMU SUGINO (1990-12-03)
C***************************************************************
      SUBROUTINE
     &     INITPW( MXBND,MBLK, NRX, NRY, NRZ, NXYZ, NGQ, NG,
     &             NG2Q, NG2, NBNDQ, NBND, NUMK,NUMKQ,
c     &             COEF, DCOEF, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
c     &      COEF,COEF0,DCOEF, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
     &      COEF,COEF0, VECK, G, G2, J2G, I2G, TPIBA, GCUT2,
     &      OMEGA, ZVAL, IOWF, RHO, RHOG, RHO1, RHO2, RHO3,
     &      WGT, OCC, OCC0,NTOT, S, NFL, NPFL, NKMESH, NEXPND,
c *** for Sugino FFT
c     &      RCOSIN, NSY, VINT,NBSEQ2, WSAVEX, WSAVEY, WSAVEZ, IFACX,
c     &      IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,MXBND0,NBSEQ,
c *** for Kokubo ASL FFT
c     &      RCOSIN, NSY, VINT,NBSEQ2,WSAVE_XYZ,IFAC_XYZ,MXBND0,NBSEQ,
c *** for Kokubo FFTW
     &      RCOSIN, NSY, VINT,NBSEQ2,plancfp,plancbp,MXBND0,NBSEQ,
     &      INDX,GG,J2GG,GDUMP,GMHF
c
     &     ,nbegin,nend,ncpuq,ncpu  )
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
C *******   TEMP   CARE!!    *************
      PARAMETER (IRLATQ=144,NAS=72)
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
C ****************************************
c      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,10),
c      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ),DCOEF(NG2Q,15),
      COMPLEX*16 COEF(NG2Q,MXBND,NUMKQ),
     &           COEF0(NG2Q,MXBND,NUMKQ),
     &           RHOG(NXYZ),RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ)
      DIMENSION G(4,NGQ),G2(4,NG2Q,NUMKQ),I2G(NGQ),J2G(NG2Q,NUMKQ),
     &          VECK(3,NUMKQ),NG2(NUMKQ),RHO(NXYZ),IOWF(MBLK,NUMKQ),
     &          WGT(NUMKQ),OCC(NBNDQ,NUMKQ),OCC0(NBNDQ,NUMKQ)
      INTEGER*4 S(3,3,48)
      DIMENSION GG(4,NGQ),INDX(NG2Q),J2GG(NG2Q),GDUMP(NG2Q,NUMKQ)
C     WORK ARRYS FOR FOURIER TRANSFORM
c *** for Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c +++ for Kokubo ASL FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c      DIMENSION IFAC_XYZ(60)
c +++ for Kokubo FFTW
      integer*8 plancfp,plancbp
      DIMENSION RCOSIN(NAS,IRLATQ), VINT(NBNDQ,IRLATQ), NSY(IRLATQ)
      DIMENSION NBSEQ(NUMKQ)
c ***  local array
      dimension VINT0(nas,irlatq)
c *** for Sugino FFT
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      COMPLEX*16 CTEMP
      COMMON/COMOPT/IOPT(10,5)
      COMMON/COMINI/MAXG2
      COMMON/AVEC/A1(3),A2(3),A3(3),B1(3),B2(3),B3(3), COVA, ALAT
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
c ************
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c ** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in sub INITPW: point 1'
c      endif
c ** temp check : end
C
c *** for Sugino FFT
c      CALL PREFFT(NRX,NRY,NRZ,NXYZ,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo FFT
c      CALL PREFFT_ASL(NRX,NRY,NRZ,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c       call PREFFT_fftw(NRX,NRY,NRZ,rhog,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      call prof_start(16)
      CALL PREFFT_fftwASL(NRX,NRY,NRZ,RHOG,plancfp,plancbp)
      call prof_stop(16)
c ** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in sub INITPW: point 2'
c      endif
c ** temp check : end
C
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA*TPIBA
      EKIN=0.D0
      SUM=0.D0
      DO 10 IK=1,NUMK
      IG2=1
c      DO 1 I=1,NG
      DO 1 I=1,NXYZ
      IF(IG2.GT.NG2Q) GOTO 100
c      G2(1,IG2,IK)=VECK(1,IK)+G(1,I)
c      G2(2,IG2,IK)=VECK(2,IK)+G(2,I)
c      G2(3,IG2,IK)=VECK(3,IK)+G(3,I)
c      G2(4,IG2,IK)=G2(1,IG2,IK)**2 + G2(2,IG2,IK)**2 + G2(3,IG2,IK)**2
ccc      GDIF= G2(4,IG2,IK)*TPIBA2
c      GG(1,IG2)=VECK(1,IK)+G(1,I)
c      GG(2,IG2)=VECK(2,IK)+G(2,I)
c      GG(3,IG2)=VECK(3,IK)+G(3,I)
c      GG(4,IG2)=GG(1,IG2)**2 + GG(2,IG2)**2 + GG(3,IG2)**2
      GG(1,I)=VECK(1,IK)+G(1,I)
      GG(2,I)=VECK(2,IK)+G(2,I)
      GG(3,I)=VECK(3,IK)+G(3,I)
      GG(4,I)=GG(1,I)**2 + GG(2,I)**2 + GG(3,I)**2
c      GDIF= GG(4,IG2)*TPIBA2
      GDIF= GG(4,I)*TPIBA2
ccc      IF(GDIF.GT.GCUT2) GOTO 1 
c      J2G(IG2,IK)=I2G(I)
c      J2GG(IG2)=I2G(I)
      J2GG(I)=I2G(I)
c      if (GDIF.LE.GCUT2) IG2=IG2+1
      IG2=IG2+1
    1 CONTINUE
      IG2=IG2-1
c      CALL INDEXX(IG2,GG,INDX)
      CALL INDEXX(NXYZ,GG,INDX)
c      DO IG=1,IG2
      DO IG=1,NXYZ
      G2(1,IG,IK)=GG(1,INDX(IG))
      G2(2,IG,IK)=GG(2,INDX(IG))
      G2(3,IG,IK)=GG(3,INDX(IG))
      G2(4,IG,IK)=GG(4,INDX(IG))
      J2G(IG,IK)=J2GG(INDX(IG))
      ENDDO
c **** define GDUMP as damping factor
      GFAC=GCUT2/TPIBA2
      DO IG=1,NXYZ
      IF ( G2(4,IG,IK).LE.GFAC ) then
       GDUMP(IG,IK)=G2(4,IG,IK)
      else
       GDUMP(IG,IK)=GFAC
      endif
      ENDDO
      GMHF=GFAC*0.5d0
c *****
c      WRITE(6,200) IK, GCUT2,IG2
c  200 FORMAT(' PLANE WAVE BASIS SET FOR K = ',I3,': GCUT2= ',F9.3,' RY'
      if ( my_rank.eq.0 ) then
      WRITE(6,200) IK, IG2
  200 FORMAT(' PLANE WAVE BASIS SET FOR K = ',I3,'  NG2= ',I8)
      endif
      NG2(IK)=IG2
c **  temp check
c      write(6,*)' in sub INITPW G2: 1 to NG2 '
c      write(6,*)( G2(4,ig,ik),ig=1,ng2(ik),100 )
c      write(6,*)' beyond NG2 '
c      write(6,*)( G2(4,ig,ik),ig=ng2(ik)+1,nxyz,500 )
c **  temp check : end
C
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
   10 CONTINUE  ! end of k-loop
C
c ** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in sub INITPW: point 3'
c      endif
c ** temp check : end
c      write(6,*)' Before calling WFREAD '
c      write(6,*)'   OCC '
c      do ik=1,numk
c       write(6,*)' IK = ',ik
c       write(6,*) ( OCC(ib,ik),ib=1,nbnd )
c      enddo
c use VINT as work area : later defined from file 25
       CALL WFREAD(OCC,OCC0,MXBND0,MXBND, MBLK, NUMK, NUMKQ,
     &  NBND, COEF,COEF0,NG2,NXYZ,
     &  MAXG2, IOWF, NG2Q, RHO1, RHO2,NBNDQ,NBSEQ,VINT
c
     &  ,nbegin,nend,ncpuq,ncpu  )
      if ( my_rank.eq.0 ) then
      write(6,*)' After reading wavefunctions '
      do ik=1,numk
       write(6,*)' ik = ',ik
       write(6,*)' Number of necessary bands = ',nbseq(ik)
        if (nbseq(ik).gt.nend(ncpu) ) then
          write(6,*)' MXBND should be ',nbseq(ik)
          stop
        endif
c       write(6,*)' OCC = ',(OCC(ib,ik),ib=1,nbseq(ik) )
       write(6,*)' OCC = '
       write(6,2525)(OCC(ib,ik),ib=1,nbseq(ik) )
      enddo
c  **  temp check
       write(6,*)' in sub. INITPW : mxbnd0 = ',mxbnd0
c       miya=13
c       if ( miya.eq.13 ) then
c        write(6,*)'my_rank',my_rank,'sub. WFREAD ended'
c       stop
c       endif
c  **  temp check : end
      endif
 2525 format(7F12.6)
c
c         REWIND 25
c         READ(25) VINT
c *** temp check
c         write(6,*)' After reading from file25'
c         write(6,*)'    VINT '
c         do ib=1,mxbnd0
c           write(6,*)( vint(ib,ir),ir=1,irlatq)
c         enddo
c *** temp check : end
c ****  reorder VINT
         if ( nas.lt.mxbnd0 .and. NPFL.ne.0 ) then
          if ( my_rank.eq.0 ) then
          write(6,*)' Metaillic !!:NAS should be ',mxbnd0,'STOPPING...'
          endif
          stop
         endif
c         nbseq2=0
c         do ib=1,mxbnd0
c         if (vint(ib,1).gt.1.d-08 ) then
c          nbseq2=nbseq2+1
c          do ir=1,irlatq
c          vint0(nbseq2,ir)=vint(ib,ir)
c          enddo
c         endif
c         enddo
c
c         write(6,*)' Numbers of necessary bands for VINT = ',nbseq2
c         write(6,*)' in case of metal calculation: not zero '
cc         nbseq1=0
cc         do ik=1,numk
cc         nbseq1=max( nbseq(ik),nbseq1 )
cc         enddo
cc         if ( nbseq1+nbseq2.gt.mxbnd ) then
cc          write(6,*)' MXBND should be ',nbseq2
cc          stop
cc         endif
c         do ib=1,nbseq2
c          do ir=1,irlatq
c          vint(ib,ir)=vint0(ib,ir)
c          enddo
c         enddo
c **  temp check
c         miya=13
c         if ( miya.eq.13 ) stop ' checking '
c **  temp check : end
c ***** reorder VINT: end
C
      IF(IOPT(3,1).EQ.1) THEN
         if ( my_rank.eq.0 ) then
         REWIND 20
         READ(20) RHO
         endif
         call MPI_Bcast(RHO,nxyz,MPI_DOUBLE_PRECISION,
     &     0,MPI_COMM_WORLD,ierr)
         DO 464 IG=1,NXYZ
  464    RHOG(IG)=DCMPLX(RHO(IG),0.D0)
c **** for Sugino FFT
c         CALL FFT3FX( NRX, NRY, NRZ, NXYZ, RHOG, RHO1,
c     &                WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                LX1, LX2, LY1, LY2, LZ1, LZ2                 )
c *** for Kokubo ASL FFT
c         CALL FFT3FX_ASL( NRX, NRY, NRZ, NXYZ, RHOG, RHO1,
c     &                WSAVE_XYZ, IFAC_XYZ)
c *** for Kokubo FFTW
c         call FFT3FX_fftw(NXYZ,RHOG,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
         CALL FFT3FX_fftwASL( NRX, NRY, NRZ, NXYZ, RHOG, RHO1,
     &                plancfp,plancbp)
      ENDIF
c ***  temp check
c        write(6,*)' in sub. INITPW: RHOG '
c        write(6,*) ( rhog(ig),ig=1,1500,100 )
c ***  temp check : end
c
      RETURN
c  100 WRITE(6,110) GCUT2
c  110 FORMAT(' GCUT2=',1PE12.4,' IS TOO BIG. STOPPING')
  100 if ( my_rank.eq.0) WRITE(6,110) IG2
  110 FORMAT(' NG2Q should be',I10,' STOPPING')
      if ( my_rank.eq.0 ) WRITE(6,*) ' TPIBA ',TPIBA,I,NG2Q
      STOP
      END
C
      SUBROUTINE WFREAD( OCC,occ0,MXBND ,MXBNDQ,MBLK, NUMK,
     &    NUMKQ, NBND, COEF, COEF0, NG2, NXYZ,
     &    MAXG2, IOWF, NG2Q, RHO1, RHO2,NBNDQ,NBSEQ,VINT
c
     &   ,nbegin,nend,ncpuq,ncpu)
      implicit double precision (a-h,o-z)
      include 'mpif.h'
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
!     REAL*8     RHO1(NG2Q), RHO2(NG2Q)
      COMPLEX*16 RHO1(NG2Q)
      COMPLEX*16 COEF(NG2Q,MXBNDQ,NUMKQ),COEF0(NG2Q,MXBNDQ,NUMKQ)
      DIMENSION IOWF(MBLK,NUMKQ),NG2(NUMKQ),NBSEQ(NUMKQ)
      DIMENSION OCC(NBNDQ,NUMKQ),VINT(NBNDQ)
      DIMENSION OCC0(NBNDQ,NUMKQ)
      integer status(MPI_STATUS_SIZE),tag
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      data tag/22/
C
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      if ( my_rank.eq.0 ) then
      REWIND 22
      endif
c ****  temp check
      if ( my_rank.eq.0 ) then
      write(6,*)'  check in sub. WFREAD '
      write(6,*)' MXBND = ',MXBND,'  NUMK = ',NUMK
      endif
c *****
      do ik=1,numk
c       if ( my_rank.eq.0 ) then
c       write(6,*)' IK = ',ik
c       write(6,*) ( OCC(ib,ik),ib=1,nbnd )
c       endif
       do ib = 1,nbnd
        occ0(ib,ik)=occ(ib,ik)  ! store occupation #s
       enddo
      nbseq(ik)=nbnd
      enddo
c
c ****  temp check end
C
      DO 450 IK = 1, NUMK
c ****  temp check
c      if ( my_rank.eq.0 ) then
c      write(6,*)' IK = ',ik,' NG2(IK) = ',NG2(IK)
c      endif
c ****  temp check end
      if ( my_rank.eq.0 ) then
       do icpu=0,ncpu
       nbleng=nend(icpu)-nbegin(icpu)+1
c       do 451 ib=1,mxbnd
       do 451 ib=1,nbleng
!      read(22)( rho1(ig),rho2(ig),ig=1,nxyz )
       read(22) (rho1(ig),ig=1,nxyz)
        do ig=1,nxyz
!        coef0(ig,ib,ik)=dcmplx( rho1(ig),rho2(ig) )
         coef0(ig,ib,ik)=rho1(ig)
        enddo
  451  continue
       if ( icpu.eq.0 ) then
        do ib=1,nbleng
         do ig=1,nxyz
          coef(ig,ib,ik)=coef0(ig,ib,ik)
         enddo
        enddo
       else
        call MPI_Send(coef0(1,1,ik),nxyz*nbleng,
     &  MPI_DOUBLE_COMPLEX,icpu,tag,MPI_COMM_WORLD,ierr)
       endif
c
       enddo  ! end of icpu loop
      else
       nbleng=nend(my_rank)-nbegin(my_rank)+1
       call MPI_Recv(coef0(1,1,ik),nxyz*nbleng
     & ,MPI_DOUBLE_COMPLEX,0,tag,MPI_COMM_WORLD,status,ierr)
       do ib=1,nbleng
        do ig=1,nxyz
         coef(ig,ib,ik)=coef0(ig,ib,ik)
        enddo
       enddo
      endif
  450 CONTINUE      ! ik roop
C
c **** temp check
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c      if ( my_rank.eq.0 ) then
c       miya=13
c       if ( miya.eq.13 ) then
c        write(6,*)'my_rank',my_rank,' WFREAD ended'
c        stop
c       endif
c      endif
c **** temp check end
c 
      RETURN
      END
c234567
      subroutine reset(a)
      implicit double precision (a-h,o-z)
  100 continue
      if (a.ge. 0.5d0) then
       a=a-1.d0
      elseif (a.lt.-0.5d0) then
       a=a+1.d0
      else
       return
      endif
      goto 100
      end
