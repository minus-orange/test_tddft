C-------------------------------------------------------
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
C           ---TMEVL ---HLOCAL
C                    !
C                    ---NONLOC
C                    !
C
C*****************************************************************
      SUBROUTINE FRPRMN
     &           ( ISTRT, NRX, NRY, NRZ, NXYZ, NG, NGQ, NG2, NG2Q,
     &       NBNDQ, NBND,NBSEQ,NBSEQ2, NFL, NPFL, NDX, NDY, NDZ,
     &             NUMK, NUMKQ, COEF, DCOEF,COEF0,CMAT,
     &             YLM, G, G2,
c ***
     & RHO, RHO1, RHO2, RHO3,VGA,
     &             RHO4, RHOG, VECK, OCC, EE, WGT, TPIBA, VG, S,
c ***  attention !
     &             VG0,VG1,VG2,VG3,VG4,VG5,VGOLD,
     &             NTOT, I2G, J2G, WORK2, OUT, VPJ, VPP, IOWF, IOVP,
c *** attention !
     &             VPP2,
     &      MXBND,MXBND0, MBLK, OMEGA, ZVAL, NTAUQ, NTYQ, NTYPE, LREQ,
     &             TAU, NUMTY, NIDN, ZV, RC0, COR, NUMC, NCRQ,
c ***  attention !
     &             TAU0,TAU1,TAU2,TAU3,TAU4,TAU5,Vloc,
     &             NKMESH, NEXPND, EBNDW, EW, PE, VINT, RCOSIN,
c *** for Sugino FFT
c     &             SK, NSY, KZ, WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY,
c     &             IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL,dt
c *** for Kokubo ASL FFT
c  **** LY2,LZ1,LZ2 are still necessary for ROTRA
c     &             LY2,LZ1,LZ2,
c     &             SK, NSY, KZ, WSAVE_XYZ, IFAC_XYZ, MXOFL,dt
c *** for Kokubo FFTW
c  **** LY2,LZ1,LZ2 are still necessary for ROTRA
     &             LY2,LZ1,LZ2,
     &             SK, NSY, KZ, plancfp,plancbp, MXOFL,dt
     &  ,itstep,ntstep
     &  ,itmod,EXTAU,EXTBF,recvcnts,displs,NTAUQ2,GDUMP
     & ,GMHF,fdump,NGNL
     &  ,VEXT,ft,ft1,ft2,ft3,ft4,ft5,Efieldp,Efieldm,CWORK,Vplt,time
c +++ for A-vec : GDUMP1 to GDUMP5
     & ,GDUMP1,GDUMP2,GDUMP3,GDUMP4,GDUMP5
     &    ,GG2,G21,G22,G23,G24,G25,YLM1,YLM2,YLM3,YLM4,YLM5,
     &    VPJWORK,VPJ1,VPJ2,VPJ3,VPJ4,VPJ5,
     &    VPP21,VPP22,VPP23,VPP24,VPP25
     &   ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,
     &   AVX1,AVY1,AVZ1,AVX2,AVY2,AVZ2,AVX3,AVY3,AVZ3,
     &   AVX4,AVY4,AVZ4,AVX5,AVY5,AVZ5
c
     &   ,NGcont
c
     &  ,nbegin,nend,nbegint,nendt,nbegintt,nendtt,mshbegin,mshend
     &  ,ncpuq,ncpu
c
     &  ,NVIRTQ)
C
      IMPLICIT REAL*8(A-H,O-Z)
      include 'mpif.h'
C
      PARAMETER (IRLATQ=144,NAS=72)
C *********** <<<<<< CAUTION >>>>>> *************
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC      PARAMETER( KBSQ=18 )
c *** NVIRTQ must be equal to that in pspw_tm11_Vext.f !!
c      PARAMETER( NDXQ=10 ,NDYQ=10 ,NDZQ=10, NVIRTQ =1)
      PARAMETER( NDXQ=10 ,NDYQ=10 ,NDZQ=10)
CC  *****  CARE ****
c      PARAMETER( NB21Q= NVIRTQ - 1              )
CC  *****  CARE END ****
c      PARAMETER( IRLQ=1  ,IILQ=1          )
c      PARAMETER(IQ1 =IRLQ*(2*NDXQ+1)*(2*NDYQ+1)*(  NDZQ+1)*(NB21Q+1))
c      PARAMETER(IQ2 =IRLQ*(4*NDXQ+1)*(4*NDYQ+1)*(2*NDZQ+1)*(NB21Q+1))
c      PARAMETER(IQ3 =(IILQ*IRLATQ-1)/2+1                            )
c      PARAMETER(IQ4 =(IILQ*3*IRLATQ-1)/2+1                          )
c      PARAMETER(IQ5 =IRLQ*(NB21Q+1)*IRLATQ                          )
c      PARAMETER(IQ6 =IRLQ*(NB21Q+1)*IRLATQ                          )
c      PARAMETER(IQ7 =(IILQ*IRLATQ-1)/2+1                            )
c      PARAMETER(IQ8 =IRLQ*(4*NDXQ+1)*(4*NDYQ+1)*IRLATQ*2            )
c      PARAMETER(IQ9 =IRLQ*(4*NDXQ+1)*(4*NDYQ+1)*IRLATQ*2            )
c      PARAMETER(IQ10=IILQ*( 8*(NDXQ+NDYQ) + 2 )*6                   )
c      PARAMETER(IDIMQ=IQ1+IQ2+IQ3+IQ4+IQ5+IQ6+IQ7+IQ8+IQ9+IQ10  )
cc      parameter ( ncpuq=30 )
cc      include 'ncpuq.h'
cC
c      DIMENSION YY(IDIMQ)
C
c *** in this routine we use only DCOEF(NG2Q,1) +++
c ******  while in electf we use DCOEF(NG2Q,21).
      COMPLEX*16  COEF(NG2Q,MXBND,NUMKQ), DCOEF(NG2Q,1),
c +++++++++++
     &  CWORK(NXYZ,10),
C +++++++++++
c      COMPLEX*16  COEF(NG2Q,MXBND,NUMKQ), DCOEF(NG2Q,15),
     &            COEF0(NG2Q,MXBND,NUMKQ)
      COMPLEX*16 CMAT(NBNDQ,NBNDQ)
C
c      REAL*8 RHO(NXYZ),YLM(NG2Q,4),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
c      REAL*8 RHO(NXYZ),YLM(NG2Q,9),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
      REAL*8 RHO(NXYZ),YLM(NGcont,16),OUT(NBNDQ,3,NUMKQ),VECK(3,NUMKQ)
c *** for P-A formalisms
      dimension YLM1(NGcont,16,NUMKQ),YLM2(NGcont,16,NUMKQ),
     &          YLM3(NGcont,16,NUMKQ),
     &          YLM4(NGcont,16,NUMKQ),YLM5(NGcont,16,NUMKQ)
C
      dimension VGA(NGQ,NTYQ)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),RHO4(NXYZ),RHOG(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3)
c     &           VG(NXYZ),WORK2(NG2Q,5)
     &           VG(NXYZ),WORK2(NG2Q,7)
cc  attention !
c     &    ,VG0(NXYZ),VG1(NXYZ),VG2(NXYZ),VG3(NXYZ),VG4(NXYZ),
c     &     VG5(NXYZ),VGPST(NXYZ),VGOLD(NXYZ)
c  attention !
      dimension  VG0(NXYZ),VG1(NXYZ),VG2(NXYZ),VG3(NXYZ),VG4(NXYZ),
     &           VG5(NXYZ),VGOLD(NXYZ)
ccc      complex*16 DVG0,DVG6,VGA3,VGA4,VGB3,VGB4
      INTEGER*4 S(3,3,48)
C   WORKING ARRAYS FOR FOURIER TRANSFORM -> Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
C   WORKING ARRAYS FOR FOURIER TRANSFORM -> Kokubo ASL FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
C   WORKING ARRAYS FOR FOURIER TRANSFORM -> Kokubo FFTW
      integer*8 plancfp,plancbp
c *** attenstion !
c      COMPLEX*16 EXTAU(NXYZ,NTAUQ,5)
c      COMPLEX*16 EXTAU(NXYZ/6,NTAUQ,5)
      COMPLEX*16 EXTAU(NGcont,5,NTAUQ),EXTBF(NGcont,5,NTAUQ2)
      integer*4 recvcnts,displs
      dimension recvcnts(ncpuq),displs(ncpuq)
c *** for Sugino FFT
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c *** for Kokubo ASL FFT
c   *** LY2,LZ1,LZ2 are still necessary for ROTRA
c      DIMENSION LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c      DIMENSION IFAC_XYZ(60)
c *** for Kokubo FFTW
c   *** LY2,LZ1,LZ2 are still necessary for ROTRA
      DIMENSION LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      DIMENSION I2G(NGQ),J2G(NG2Q,NUMKQ),NG2(NUMKQ)
c *** 
      dimension NGNL(NTYQ,NUMKQ)
c
      DIMENSION G(4,NGQ),G2(4,NG2Q,NUMKQ),WGT(NUMKQ)
c *** for P-A (YLM EXTAY)
      dimension GG2(4,NG2Q,NUMKQ)
      dimension G21(4,NG2Q,NUMKQ),G22(4,NG2Q,NUMKQ),
     &          G23(4,NG2Q,NUMKQ),G24(4,NG2Q,NUMKQ),
     &          G25(4,NG2Q,NUMKQ)
c *** Attention !
      DIMENSION GDUMP(NG2Q,NUMKQ)
c *** for A-vec : GDUMP1 to GDUMP5
      DIMENSION GDUMP1(NG2Q,NUMKQ),GDUMP2(NG2Q,NUMKQ)
     &         ,GDUMP3(NG2Q,NUMKQ),GDUMP4(NG2Q,NUMKQ)
     &         ,GDUMP5(NG2Q,NUMKQ)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
c  attention !
     &  TAU0(3,ntauq),tau1(3,ntauq),tau2(3,ntauq),tau3(3,ntauq),
     &  tau4(3,ntauq),tau5(3,ntauq),Vloc(NXYZ,5),
     &          ZV(NTYQ),RC0(NCRQ,NTYQ),
     &          COR(NCRQ,NTYQ),NUMC(NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ),IOWF(MBLK,NUMKQ),
c      DIMENSION VPJ(NG2Q/3,3,2,NTYQ,NUMKQ),VPP(3,2,NTYQ),
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ,NUMKQ),VPP(3,3,NTYQ),
      DIMENSION VPJ(NGcont,3,4,NTYQ,NUMKQ),VPP(3,4,NTYQ),
     &          IOWF(MBLK,NUMKQ),
     &          IOVP(2,NTYQ,NUMKQ),OCC(NBNDQ,NUMKQ),EE(NBNDQ,NUMKQ)
c +++ for P-A VPJ is updated!
      dimension VPJWORK(NGcont,3) ! for parallel mesh intg
      dimension VPJ1(NGcont,3,4,NTYQ,NUMKQ),VPJ2(NGcont,3,4,NTYQ,NUMKQ)
     &         ,VPJ3(NGcont,3,4,NTYQ,NUMKQ),VPJ4(NGcont,3,4,NTYQ,NUMKQ)
     &         ,VPJ5(NGcont,3,4,NTYQ,NUMKQ)
      dimension RAD(MESHQ,NTYQ),PSPOT(MESHQ,ISPD,NTYQ),
     &    PSPOT2(MESHQ,ISPD,NTYQ),PHIL(MESHQ,4,NTYQ)
c ***  attention
c      dimension VPP2(4,3,NTYQ,NUMKQ)
c      dimension VPP2(9,3,NTYQ,NUMKQ)
      dimension VPP2(16,3,NTYQ,NUMKQ)
c ++++ for P-A
     & ,VPP21(16,3,NTYQ,NUMKQ),VPP22(16,3,NTYQ,NUMKQ)
     & ,VPP23(16,3,NTYQ,NUMKQ)
     & ,VPP24(16,3,NTYQ,NUMKQ),VPP25(16,3,NTYQ,NUMKQ)
      dimension NBSEQ(NUMKQ)
c
      COMMON/COMOPT/IOPT(10,5)
      COMMON/COMFRP/RMIX,TR2,ITCMAX,ITMAX,ITC1,ITC7
C
      DIMENSION EBNDW(NBNDQ,IRLATQ),PE(NBNDQ*IRLATQ),RCOSIN(NAS,IRLATQ)
      DIMENSION EW(NBNDQ),VINT(NBNDQ,IRLATQ),SK(3,NAS),KZ(3,IRLATQ,48),
     &          NSY(IRLATQ)
      dimension fdump(NXYZ)
c ***  work area for orthogonization
c      complex*16  sig(nbndq,nbndq),x0(nbndq,nbndq),
c     &    x1(nbndq,nbndq),work1(nbndq,nbndq),work20(nbndq,nbndq)
ccc
      complex*16 ctemp
c ***  work area for orthogonization
c      complex*16  sig(nbndq*numkq*nbndq*numkq),
c     &    x0(nbndq*numkq*nbndq*numkq),
c     &    x1(nbndq*numkq*nbndq*numkq),
c     &    work1(nbndq*numkq*nbndq*numkq),
c     &    work20(nbndq*numkq*nbndq*numkq)
c **** for external potential
      complex*16 VEXT(NXYZ)
      dimension Vplt(NXYZ)
      integer status(MPI_STATUS_SIZE)
      COMMON /AVEC/  A1(3), A2(3), A3(3), B1(3), B2(3), B3(3)
     &             , COVA, ALAT
      COMMON/SMOOTH/ADUMP
      integer tag
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
c      common/cputask2/nbegint(0:ncpuq),nendt(0:ncpuq),ncpu2
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      dimension nbegint(0:ncpuq),nendt(0:ncpuq)
      dimension nbegintt(0:ncpuq),nendtt(0:ncpuq)
      dimension mshbegin(0:ncpuq),mshend(0:ncpuq)
      logical VPJGENdo
      common/ExtDyn/VPJGENdo
ccc
ccc
      data tag/11/
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' nbegin nend '
c       do icpu=0,ncpuq
c        write(6,*) nbegin(icpu),nend(icpu)
c       enddo
c       write(6,*)' nbegint nendt '
c       do icpu=0,ncpuq
c        write(6,*) nbegint(icpu),nendt(icpu)
c       enddo
c       write(6,*)' nbegintt nendtt '
c       do icpu=0,ncpuq
c        write(6,*) nbegintt(icpu),nendtt(icpu)
c       enddo
c       write(6,*)' mshbegin mshend '
c       do icpu=0,ncpuq
c        write(6,*) mshbegin(icpu),mshend(icpu)
c       enddo
c      endif
c *** temp check : end
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' in FRPRMN : itstep =',itstep
c       do ity=1,ntype
c        write(6,*)' VGA ity =',ity
c        write(6,'(4f22.16)')(VGA(ig,ity),ig=1,NXYZ,1000)
c       enddo
c      endif
c *** temp check : end
c      if (my_rank.eq.0 ) then
c       write(6,*)' in FRPRMN ! itstep=',itstep
c       write(6,*)' GG2 '
c       do ik=1,numk
c        write(6,*)' IK=',ik
c        do ig=1,NG2Q,500
c        write(6,'(4f22.16)')( GG2(IJ,IG,ik),IJ=1,4 )
c        enddo
c       enddo
cc       write(6,*)' VPP2 '
c        do ity=1,NTYPE
c        write(6,*)' RAD '
c        write(6,*)' ity = ',ity
c        write(6,'(4f22.16)')( RAD(K,ITY),K=1,MESHQ,100)
c        do il=1,MXOFL(ity)
c         write(6,*)' PHIL IL=',il
c         write(6,'(4F22.16)')(PHIL(K,IL,ity),K=1,MESHQ,100)
c         write(6,*)' PSPOT IL=',il
c         write(6,'(4F22.16)')(PSPOT(K,IL,ity),K=1,MESHQ,100)
c        enddo
c       enddo
c      endif
c *** temp check: end
c +++ temp monitor VGA
c       if (my_rank.eq.0  ) then
c        write(6,*)' checkin VGA in FRPRMN itstep=',itstep
c        do ity=1,NTYPE
c         write(6,*)' VGA ITY = ',ITY
c         write(6,'(4F22.16)')(VGA(IG,ITY),IG=1,NG2Q,1000)
c        enddo
c       endif
c +++ temp end
C
C *****
              IF( NPFL .EQ. 0 ) GO TO 4321
C
       IF(NDX.LE.NDXQ .AND. NDX.GT.0) GO TO 4321
       IF(NDY.LE.NDYQ .AND. NDY.GT.0) GO TO 4321
       IF(NDZ.LE.NDZQ .AND. NDZ.GT.0) GO TO 4321
       if ( my_rank.eq.0 ) then
       WRITE(6,4322) NDX, NDXQ, NDY, NDYQ, NDZ, NDZQ
       endif
       STOP
 4322  FORMAT(
     &  '   **** FRPRMN: WRONG!!!: NDX NDXQ NDY NDYQ NDZ NDZQ = ',6I4)
 4321  CONTINUE
C *****
      RDIF0 = 0.1D-08
c      WRITE(6,6020) ITMAX, ITC7, ITC1, ITCMAX,
c     &              ( I, (TAU(J,I), J=1,3), I=1, NTAUQ )
c 6020 FORMAT(/' ******** FRPRMN: ITMAX(SCF) = ',I3,
c     &        ' ITC7 ITC1 ITCMAX (CG) = ',3I3/
c     &        '                      TAU:'/
c     &                         (18X,I4,3D13.5) )
c      WRITE(6,*) ' '
C
      IOK=0   ! FLAG of the selfconsistency
c
      PI=4.D0*ATAN(1.D0)
      PI2=PI*2.D0
      TPIBA2=TPIBA**2
C
c ** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' Before calling PREFFT ! itstep=',itstep
c       stop
c      endif
c ** temp check end
c      if ( itstep.eq.0 ) then
cc *** for Sugino FFT
cc      CALL PREFFT(NRX,NRY,NRZ,NXYZ,
cc     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
cc *** for Kokubo ASL FFT
c      CALL PREFFT_ASL(NRX,NRY,NRZ,WSAVE_XYZ,IFAC_XYZ)
cc *** for Kokubo FFTW
cc      call PREFFT_fftw(NRX,NRY,NRZ,rhog,plancfp,plancbp)
c      endif
cc *** for Kokubo fftw ASL compatible but not used!
c      CALL PREFFT_fftwASL(NRX,NRY,NRZ,plancfp,plancbp)
C
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c       write(6,*)'my_rank=',my_rank,' in FRPRMN : PREFFT finished!'
c       stop
c      endif
c *** temp check ;  end
C
C
C     CALL CLOCK(TIM)
C6000 FORMAT(23X,'****  FRPRMN: AFT LOCPOT: ',F15.7,' SEC')
C     WRITE(6,6000) TIM
C
      if (itstep.eq.0 ) then
      nscf=1
      else 
c      nscf=10  ! but not 10, actually.
      nscf=ITMAX  ! but not 10, actually.
      endif
      icoef_host_current=1
c
      do 9898 iscf=1,nscf  ! start Predictor Corrector loop
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(53)
#endif
c ***
      if ( iscf.eq.1 ) then 
c ***
c
        m=2
        pm=1.d0/( 4.d0 - 4.d0**(1.d0/dfloat(2*m-1) ) )
        pr1=pm
        pr2=pm
        pr3=1.d0-4*pm
        pr4=pr2
        pr5=pr1
        eps=1.d-16
        if ( dabs( pr1+pr2+pr3+pr4+pr5-1.d0).gt.eps ) then
         if ( my_rank.eq.0 ) then
          write(6,*)' pr1 to pr5 are wrong . STOPPING !!'
          write(6,*)' sum pr1 to pr5 = ',pr1+pr2+pr3+pr4+pr5
         endif
        stop
        endif
c
c   ** Tau interpolation for local & non-local pseudopotentials
      if ( itstep.eq.0 ) then
       do it=1,ntauq
        do j=1,3
        tau0(j,it)=tau(j,it)
        enddo
       enddo
      elseif ( itstep.ge.1 ) then
ccc  ****  linear interpolation !!!
       do it=1,ntauq
        do j=1,3
c        tau1(j,it)=        (1.d0-0.5d0*pr1)*tau0(j,it)
c     &                           +0.5d0*pr1*tau (j,it)
c        tau2(j,it)=    (1.d0-0.5d0*pr2-pr1)*tau0(j,it)
c     &                     +(pr1+0.5d0*pr2)*tau (j,it)
c        tau3(j,it)=(1.d0-0.5d0*pr3-pr2-pr1)*tau0(j,it)
c     &                 +(pr1+pr2+0.5d0*pr3)*tau (j,it)
c        tau4(j,it)=         (0.5d0*pr4+pr5)*tau0(j,it)
c     &                +(1.d0-0.5d0*pr4-pr5)*tau (j,it)
c        tau5(j,it)=               0.5d0*pr5*tau0(j,it)
c     &                    +(1.d0-0.5d0*pr5)*tau (j,it)
        tau0(j,it)=tau(j,it)  ! prepare for the next time step
        enddo
       enddo
      endif
c
c ****
      endif
c ****
C
c  **  RHO1,RHO2: work area for local potential ***
C
C
      if (iscf.le.1 ) then
c ** temp check
c      miya=13
c      if (miya.eq.13.and.my_rank.eq.0 ) then
c       write(6,*)' before calling LOCPOT'
c       stop
c      endif
c ** temp check : end
c  ***** part 1 **********
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' before LOCPOT itstep=',itstep
c       do ity=1,NTYPE
c        write(6,*)' ity =',ity
c        write(6,*)' ZV =',ZV(ity),' RC0 =',RC0(1,ity),RC0(2,ity)
c        write(6,*)' COR =',COR(1,ity),COR(2,ity)
c        write(6,*)' NUMC=',NUMC(ITY),' MXOFL=',MXOFL(ITY)
c       enddo
c      endif
c *** temp check end
      CALL LOCPOT(NXYZ,NG,NGQ,G,TPIBA,RHO4,RHO1,
c     & I2G,RHO2,OMEGA,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU1,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,itstep
c
     & ,nbegint,nendt,ncpuq )
c *** Make Vloc(*,1) in real space !!!!
c *** potential smoothing !!
*VDIR NODEP(rho1,rho4)
!ocl norecurrence(rho1,rho4)
      do ig=1,nxyz
      jg=i2g(ig)
      rho1(jg)=rho4(jg)*fdump(ig)
      enddo
      do ig=1,nxyz
      rho4(ig)=rho1(ig)
      enddo
c *** for Sugino FFT
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO4,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1,WSAVE_XYZ,IFAC_XYZ)
c +++ for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO4,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1
     & ,plancfp,plancbp)
      call vlocgen(Vloc(1,1),rho4,nxyz,VEXT,ft1)
c  ***** part 2 **********
      CALL LOCPOT(NXYZ,NG,NGQ,G,TPIBA,RHO4,RHO1,
c     & I2G,RHO2,OMEGA,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU2,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,itstep
c
     & ,nbegint,nendt,ncpuq )
c *** Make Vloc(*,2) in real space !!!!
c *** potential smoothing !!
*VDIR NODEP(rho1,rho4)
!ocl norecurrence(rho1,rho4)
      do ig=1,nxyz
      jg=i2g(ig)
      rho1(jg)=rho4(jg)*fdump(ig)
      enddo
      do ig=1,nxyz
      rho4(ig)=rho1(ig)
      enddo
c **** for Sugino FFT
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO4,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c **** for Kokubo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1, WSAVE_XYZ,IFAC_XYZ)
c **** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO4,plancfp,plancbp)
c **** for Kokubo fftw ASL compatible
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1
     & ,plancfp,plancbp)
      call vlocgen(Vloc(1,2),rho4,nxyz,VEXT,ft2)
c  ***** part 3 **********
      CALL LOCPOT(NXYZ,NG,NGQ,G,TPIBA,RHO4,RHO1,
c     & I2G,RHO2,OMEGA,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU3,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,itstep
c
     & ,nbegint,nendt,ncpuq )
c *** Make Vloc(*,3) in real space !!!!
c *** potential smoothing !!
*VDIR NODEP(rho1,rho4)
!ocl norecurrence(rho1,rho4)
      do ig=1,nxyz
      jg=i2g(ig)
      rho1(jg)=rho4(jg)*fdump(ig)
      enddo
      do ig=1,nxyz
      rho4(ig)=rho1(ig)
      enddo
c *** for Sugino FFT
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO4,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1, WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO4,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1
     & ,plancfp,plancbp)
      call vlocgen(Vloc(1,3),rho4,nxyz,VEXT,ft3)
c  ***** part 4 **********
      CALL LOCPOT(NXYZ,NG,NGQ,G,TPIBA,RHO4,RHO1,
c     & I2G,RHO2,OMEGA,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU4,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,itstep
c
     & ,nbegint,nendt,ncpuq )
c *** Make Vloc(*,4) in real space !!!!
c *** potential smoothing !!
*VDIR NODEP(rho1,rho4)
!ocl norecurrence(rho1,rho4)
      do ig=1,nxyz
      jg=i2g(ig)
      rho1(jg)=rho4(jg)*fdump(ig)
      enddo
      do ig=1,nxyz
      rho4(ig)=rho1(ig)
      enddo
c **** for Sugino FFT
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO4,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c **** for Kokubo FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1, WSAVE_XYZ,IFAC_XYZ)
c **** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO4,plancfp,plancbp)
c **** for Kokubo fftw ASL compativle
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1
     &  ,plancfp,plancbp)
      call vlocgen(Vloc(1,4),rho4,nxyz,VEXT,ft4)
c  ***** part 5 **********
      CALL LOCPOT(NXYZ,NG,NGQ,G,TPIBA,RHO4,RHO1,
c     & I2G,RHO2,OMEGA,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU5,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,itstep
c
     & ,nbegint,nendt,ncpuq )
c *** Make Vloc(*,5) in real space !!!!
c *** potential smoothing !!
*VDIR NODEP(rho1,rho4)
!ocl norecurrence(rho1,rho4)
      do ig=1,nxyz
      jg=i2g(ig)
      rho1(jg)=rho4(jg)*fdump(ig)
      enddo
      do ig=1,nxyz
      rho4(ig)=rho1(ig)
      enddo
c *** for Sugino FFT
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO4,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1, WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO4,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1
     &   ,plancfp,plancbp)
      call vlocgen(Vloc(1,5),rho4,nxyz,VEXT,ft5)
c
c  ***** part 6!! **********
      CALL LOCPOT(NXYZ,NG,NGQ,G,TPIBA,RHO4,RHO1,
c     & I2G,RHO2,OMEGA,
     & I2G,VGA,OMEGA,
     & NTAUQ,NTYQ,NTYPE,TAU ,NUMTY,NIDN
     & ,NCRQ,ZV,RC0,COR,NUMC,itstep
c
     & ,nbegint,nendt,ncpuq )
c *** Make rho4 for advanced step in real space !!!!
c *** potential smoothing !!
*VDIR NODEP(rho1,rho4)
!ocl norecurrence(rho1,rho4)
      do ig=1,nxyz
      jg=i2g(ig)
      rho1(jg)=rho4(jg)*fdump(ig)
      enddo
      do ig=1,nxyz
      rho4(ig)=rho1(ig)
      enddo
c *** for Sugino FFT
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO4,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1, WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO4,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO4,RHO1
     &  ,plancfp,plancbp)
c ***  RHO4 at t+dt on real space
c  ***
c **** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c       write(6,*)'my_rank=',my_rank,' locpots have been generated!'
c      stop
c      endif
c **** temp check : end
      endif
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(53)
      call prof_start(54)
      call prof_start(64)
#endif
C     CALL CLOCK(TIM)
C6000 FORMAT(23X,'****  FRPRMN: AFT LOCPOT: ',F15.7,' SEC')
C     WRITE(6,6000) TIM
C
c ***  temp check
c      write(6,*)' 9898 iscf = ',iscf
c ***  temp check end
c       if ( iscf.eq.1 .and. my_rank.ne.0 ) then
       if ( iscf.eq.1 ) then
         nblng=nend(my_rank)-nbegin(my_rank)+1
c         nbgn=nbegin(my_rank)
         do ik0=1,numkq
c         call coefcp(coef(1,nbgn,ik0),coef0(1,nbgn,ik0),ng2q*nblng)
         call coefcp(coef(1,1,ik0),coef0(1,1,ik0),ng2q*nblng)
         enddo
       endif
        if ( iscf.gt.ITMAX ) then
         if ( my_rank.eq.0 ) then
         write(6,*)' TOO MANY SCF LOOP at itstep = ',itstep
         write(6,*)' CONVERGENCE = ',RDIF
         endif
         stop
        endif
c
c ***  temp check
c      write(6,*)' itstep = ',itstep,' iscf = ',iscf
c      write(6,*)' before calling VOFRHO '
c      write(6,*)'  RHO '
c      write(6,*)( rho(ig),ig=1,1500,100 )
c ***  temp check ; end
c
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(64)
      call prof_start(62)
#endif
      CALL VOFRHO(NRX,NRY,NRZ,NXYZ,NG,NGQ,G,TPIBA,
     & RHO1,RHO2,RHO3,RHO,RHOG,I2G,
c *** for Sugino FFT
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2
c *** for Kokubo ASL FFT
c     & WSAVE_XYZ,IFAC_XYZ
c *** for Kokubo FFTW
     & plancfp,plancbp
c     & ,DCOEF(1,1),DCOEF(1,2),DCOEF(1,3),DCOEF(1,4),DCOEF(1,5)
c     & ,DCOEF(1,6),DCOEF(1,7),DCOEF(1,8),DCOEF(1,9),DCOEF(1,10) )
     &  ,CWORK(1,1),CWORK(1,2),CWORK(1,3),CWORK(1,4),CWORK(1,5)
     &  ,CWORK(1,6),CWORK(1,7),CWORK(1,8),CWORK(1,9),CWORK(1,10) )
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(62)
      call prof_start(63)
#endif
C
c *** Smoothing of potential : rho1 as work area
*VDIR NODEP(rho1,rho3)
!ocl norecurrence(rho1,rho3)
      do ig=1,nxyz
      jg=i2g(ig)
      rho1(jg)=rho3(jg)*fdump(ig)
      enddo
      do ig=1,nxyz
      rho3(ig)=rho1(ig)
      enddo
c *** for Sugino FFT
c      CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO3,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Koukbo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO3,RHO1, WSAVE_XYZ,IFAC_XYZ)
c *** for Koukbo FFTW
c      call FFT3BX_fftw(NXYZ,RHO3,plancfp,plancbp)
c *** for Koukbo fftw ASL compatible
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO3,RHO1,plancfp,plancbp)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(63)
      call prof_start(64)
#endif
c
c ****  NOW RHO3 is in R-space
c  *** and need of add Vext
c      do ig=1,nxyz
cc       RHO3(IG)=RHO3(IG)+VEXT(IG)    !  then move to Predictor corrector loop
c       RHO3(IG)=RHO3(IG)+ft*VEXT(IG)    !  then move to Predictor corrector loop
c      enddo
c
        m=2
        pm=1.d0/( 4.d0 - 4.d0**(1.d0/dfloat(2*m-1) ) )
        pr1=pm
        pr2=pm
        pr3=1.d0-4*pm
        pr4=pr2
        pr5=pr1
        eps=1.d-16
        if ( dabs( pr1+pr2+pr3+pr4+pr5-1.d0).gt.eps ) then
         if ( my_rank.eq.0 ) then
          write(6,*)' pr1 to pr5 are wrong . STOPPING !!'
          write(6,*)' sum pr1 to pr5 =',pr1+pr2+pr3+pr4+pr5
         endif
        stop
        endif
c
c  ***  extrapolate VG(t+dt/2) from past VG's ***
      if ( iscf.eq.1 ) then
       if ( itstep.ne.0 ) then
c ***
        if ( itstep.eq.1 ) then
         do ig=1,nxyz
          rr3=dreal( RHO3(IG) )
          VG0(IG)=rr3
          VG1(IG)=rr3
          VG2(IG)=rr3
          VG3(IG)=rr3
          VG4(IG)=rr3
          VG5(IG)=rr3
         enddo
        elseif(itstep.ge.2) then
c
c  for extrapolation
c * for vg1 ***
         pf=pr1+0.5d0*pr2
         pi=0.d0
         call extvgen(a3v1,a4v1,b3v1,b4v1,pf,pi)
c * for vg2 ***
         pf=pr1+pr2+0.5d0*pr3
         pi=0.5d0*pr1
         call extvgen(a3v2,a4v2,b3v2,b4v2,pf,pi)
c * for vg3 ***
         pf=pr1+pr2+pr3+0.5d0*pr4
         pi=pr1+0.5d0*pr2
         call extvgen(a3v3,a4v3,b3v3,b4v3,pf,pi)
c * for vg4 ***
         pf=pr1+pr2+pr3+pr4+0.5d0*pr5
         pi=pr1+pr2+0.5d0*pr3
         call extvgen(a3v4,a4v4,b3v4,b4v4,pf,pi)
c * for vg5 ***
         pf=1.d0
         pi=pr1+pr2+pr3+0.5d0*pr4
         call extvgen(a3v5,a4v5,b3v5,b4v5,pf,pi)
c
         thrd=1.d0/3.d0
         do ig=1,nxyz
          rr3=dreal( RHO3(IG) )
          rr0=VG0(IG)
          DVG0=thrd*( 4*VG3(IG) + rr3 - 5*rr0 )
          DVG6=thrd*( 5*rr3 - 4*VG3(IG) - rr0 )
          VGA3=       rr0+DVG0*thrd
          VGA4= 0.5d0*rr0+DVG0*0.25d0
          VGB3=       rr3-DVG6*thrd
          VGB4= 0.5d0*rr3-DVG6*0.25d0
          VG1(IG)= VGA3*a3v1+VGA4*a4v1+VGB3*b3v1-VGB4*b4v1
          VG2(IG)= VGA3*a3v2+VGA4*a4v2+VGB3*b3v2-VGB4*b4v2
          VG3(IG)= VGA3*a3v3+VGA4*a4v3+VGB3*b3v3-VGB4*b4v3
          VG4(IG)= VGA3*a3v4+VGA4*a4v4+VGB3*b3v4-VGB4*b4v4
          VG5(IG)= VGA3*a3v5+VGA4*a4v5+VGB3*b3v5-VGB4*b4v5
ccc          VGPST(IG)=VG0(IG)
          VG0(IG)=rr3  ! for the next SCF step
         enddo
        endif ! if itsetp.eq.1 or ge.2 loop end:
       endif  ! if iscf.eq.1 loop end
      do ig=1,nxyz
       VGOLD(ig)=VG3(ig) ! store 
      enddo
      endif
c  ***  interpolate VG(t+dt/2) from new and past VG's ***
      if ( iscf.ge.2 ) then
cc *** 
c
       if ( itstep.ne.0 ) then
         a10=0.5d0*pr1+pr2+pr3+pr4+pr5
         a16=0.5d0*pr1
         a20=0.5d0*pr2+pr3+pr4+pr5
         a26=pr1+0.5d0*pr2
         a30=0.5d0*pr3+pr4+pr5
         a36=pr1+pr2+0.5d0*pr3
         a40=0.5d0*pr4+pr5
         a46=pr1+pr2+pr3+0.5d0*pr4
         a50=0.5d0*pr5
         a56=pr1+pr2+pr3+pr4+0.5d0*pr5
c
        if ( itstep.eq.1 .and. iscf.eq.2 ) then
cc        if ( itstep.ge.1 ) then
         do ig=1,nxyz
c            linear interpolation !!!
         rr3=dreal( RHO3(IG) )
         VG1(IG)=a10*VG0(IG)+a16*rr3
         VG2(IG)=a20*VG0(IG)+a26*rr3
         VG3(IG)=a30*VG0(IG)+a36*rr3
         VG4(IG)=a40*VG0(IG)+a46*rr3
         VG5(IG)=a50*VG0(IG)+a56*rr3
         enddo
         elseif(itstep.ge.1) then
c         elseif(itstep.ge.2) then
c ***  for interpolation
c * for vg1 ***
         pf=pr1+0.5d0*pr2
         pi=0.d0
         call intvgen(a3v1,a4v1,b3v1,b4v1,pf,pi)
c * for vg2 ***
         pf=pr1+pr2+0.5d0*pr3
         pi=0.5d0*pr1
         call intvgen(a3v2,a4v2,b3v2,b4v2,pf,pi)
c * for vg3 ***
         pf=pr1+pr2+pr3+0.5d0*pr4
         pi=pr1+0.5d0*pr2
         call intvgen(a3v3,a4v3,b3v3,b4v3,pf,pi)
c * for vg4 ***
         pf=pr1+pr2+pr3+pr4+0.5d0*pr5
         pi=pr1+pr2+0.5d0*pr3
         call intvgen(a3v4,a4v4,b3v4,b4v4,pf,pi)
c * for vg5 ***
         pf=1.d0
         pi=pr1+pr2+pr3+0.5d0*pr4
         call intvgen(a3v5,a4v5,b3v5,b4v5,pf,pi)
c
         THRD=1.d0/3.d0
         do ig=1,nxyz
         rr3=dreal( RHO3(IG) )
         rr0=VG0(IG)
          DVG0=thrd*( 4*VG3(IG) + rr3 - 5*rr0 )
          DVG6=thrd*( 5*rr3 - 4*VG3(IG) - rr0 )
          VGA3=      rr0+DVG0*thrd
          VGA4=0.5d0*rr0+DVG0*0.25d0
          VGB3=      rr3-DVG6*thrd
          VGB4=0.5d0*rr3-DVG6*0.25d0
          VG1(IG)= VGA3*a3v1+VGA4*a4v1+VGB3*b3v1-VGB4*b4v1
          VG2(IG)= VGA3*a3v2+VGA4*a4v2+VGB3*b3v2-VGB4*b4v2
          VG3(IG)= VGA3*a3v3+VGA4*a4v3+VGB3*b3v3-VGB4*b4v3
          VG4(IG)= VGA3*a3v4+VGA4*a4v4+VGB3*b3v4-VGB4*b4v4
          VG5(IG)= VGA3*a3v5+VGA4*a4v5+VGB3*b3v5-VGB4*b4v5
         enddo
        endif
       endif
       call vgconv(VG3,VGOLD,NXYZ,TR2,RDIF,IOK)
cc  ***  temp check
c       write(6,*)' iscf = ',iscf,' Convergence = ',RDIF
cc  ***  temp check end
      if ( iscf.ge.3 .and. my_rank.eq.0 ) then
       write(6,*)' itstep=',itstep,' iscf=',iscf,' Convergence=',RDIF
      endif
c ***
c       if (IOK.eq.1) goto 9899 ! Quit the SCF loop 
       if (IOK.eq.1) goto 9799 ! Goto Off diagonal and quit the SCF loop 
       if (IOK.eq.0 .and.iscf.eq.nscf ) then
        if (my_rank.eq.0 ) then
         write(6,*)' SCF loop exceeded without conservation!!'
         stop
        endif
       endif
c ***
cc       if (my_rank.ne.0 ) then
       nblng=nend(my_rank)-nbegin(my_rank)+1
c       nbgn=nbegin(my_rank)
       do ik0=1,numkq
c       call coefcp(coef0(1,nbgn,ik0),coef(1,nbgn,ik0),ng2q*nblng)
       call coefcp(coef0(1,1,ik0),coef(1,1,ik0),ng2q*nblng)
       enddo
       do ig=1,nxyz
        VGOLD(ig)=VG3(ig) ! store 
       enddo
      endif
c
 9799 continue
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(64)
      call prof_stop(54)
      call prof_start(55)
#endif
C
C#################################################################
C
c      if ( itstep.eq.0 .or. itstep.eq.ntstep) then
c      do ig=1,nxyz
c      jg=i2g(ig)
c      vg(jg)=rho3(jg)+rho4(jg)*fdump(ig)
c      enddo
cc
cc     POTENTIAL VG: G -> real space
cc
c
       do ig=1,nxyz
c       VG(IG)=RHO3(IG)+RHO4(IG)
       VG(IG)=RHO3(IG)+RHO4(IG)+ft*VEXT(IG)
       enddo
c
c *** compute E-field from VG when (itstep mode itmod) = 0
      if ( mod(itstep,itmod).eq.0 .and. my_rank.eq.0
     &     .and. IOK.eq.1 ) then
cc       call Efieldgen(VG,nrx,nry,nrz,nxyz,Efieldp,Efieldm)  ! store E-field at particular point and t
cccc
cc     POTENTIAL VG: G -> real space
cc
c +++ compute E-field from VG : real space
        do ig=1,nxyz
c       VG(IG)=RHO3(IG)+RHO4(IG)
        Vplt(IG)=RHO3(IG)+RHO4(IG)+ft*VEXT(IG)
        enddo
        call Efield(Vplt,nrx,nry,nrz,nxyz,time,92)
c
        do ig=1,nxyz
        Vplt(IG)=ft*VEXT(IG)
        enddo
        call Efield(Vplt,nrx,nry,nrz,nxyz,time,93)
      endif
c
c *** The final-step expectation path below reads COEF on the host for
c *** every correction, including corrections that have not converged.
      if (itstep.eq.ntstep .and. icoef_host_current.eq.0) then
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
       call prof_stop(55)
#endif
       call prof_start(44)
!$acc update self(COEF(1:NG2Q,1:MXBND,1:NUMKQ))
       call prof_stop(44)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
       call prof_start(55)
#endif
       icoef_host_current=1
      endif
c
c *** store all potential in file 90
      if ( itstep.eq.ntstep .and. my_rank.eq.0 .and. IOK.eq.1) then
      rewind 90
      efac=13.6d0*2
      write(90)(efac*dreal(VG(ig)),ig=1,nxyz)  ! for all potential
c       miya=13
c       if ( miya.eq.13 ) then
c        write(6,*)' for check!!!'
c        stop
c       endif
      endif
c
c **** temp check !
c       miya=13
c       if ( miya.eq.13 ) then
c       write(6,*)'my_rank=',my_rank,' POTENTIAL VG has been made!'
c       stop
c       endif
c **** temp check : end !
c
      if ( itstep.eq.0 .or. itstep.eq.ntstep) then
c ********************
c Calculation of the expectation values.
c ********************
c ***  temp check
c      write(6,*)' itstep = ',itstep
c      write(6,*)' Before calculating the expectation values '
c      write(6,*)'     VG in real space '
c      write(6,*)( vg(ig),ig=1,1500,100 )
c ***  temp check : end
      do ik=1,numk
       if ( itstep.eq.ntstep .and. IOK.eq.1 ) then
       if ( my_rank.eq.0 ) write(6,1818)ik
       endif
ccc      if ( my_rank.ne.0 ) then
cc      do ib=1,nbseq(ik)
c *** temp check
       if ( my_rank.eq.0 .and. IOK.eq.1 ) then
         write(6,*)' Now calling HLOCAL and NONLOC'
       endif
c *** temp check : end
      do ib=nbegin(my_rank),nend(my_rank)
      iib=ib-nbegin(my_rank)+1
      call zero(dcoef,ng2q )
      CALL HLOCAL( NRX, NRY, NRZ, NXYZ, NG2(IK), NG2Q, mxbnd,
c     & COEF(1,ib,ik),DCOEF(1,1),
     & COEF(1,iib,ik),DCOEF(1,1),
c *** for Sugino FFT
c     & RHO1, RHO2, VG, J2G(1,ik), WSAVEX, WSAVEY, WSAVEZ,
c     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2  )
c *** for Kokubo ASL FFT
c     & RHO1, RHO2, VG, J2G(1,ik), WSAVE_XYZ,   IFAC_XYZ  )
c *** for Kokubo FFTW
     & RHO1, RHO2, VG, J2G(1,ik), plancfp,plancbp  )
C
      CALL NONLOC( NXYZ, NG2(IK), NG2Q, mxbnd,
c     & COEF(1,ib,ik), DCOEF(1,1),
     & COEF(1,iib,ik), DCOEF(1,1),
c     & YLM, G2(1,1,ik), RHO2, RHO3, TPIBA, WORK2, VPJ(1,1,1,1,ik),
     & YLM, GG2(1,1,ik), RHO2, RHO3, TPIBA, WORK2, VPJ(1,1,1,1,ik),
     &             VPP, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
     &             NIDN, IOVP(1,1,ik), MXOFL,GDUMP(1,IK),NGNL(1,IK)
     &     ,NGcont )
       temp=0
        do ig=1,ng2(ik)
c        temp=temp + dble( dconjg( coef(ig,ib,ik) )*dcoef(ig,1) )
        temp=temp + dble( dconjg( coef(ig,iib,ik) )*dcoef(ig,1) )
        enddo
       EE(ib,ik)=temp
       enddo  ! end of ib loop
c *** temp check
      if ( my_rank.eq.0 ) then
       write(6,*)' Exepctation values: end'
c *** temp check
c       write(6,*)' after NONLOC: ik = ',ik
c       do ib=nbegin(my_rank),nend(my_rank)
c        write(6,2828)EE(ib,ik)
c       enddo
c 2828 format(5f22.16)
c *** temp check: end
      endif
c *** temp check : end
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_begin("sendrecv01")
! ==============================================================================
      if ( my_rank.ne.0 ) then
      nbleng=nend(my_rank)-nbegin(my_rank)+1
      nbgn=nbegin(my_rank)
c **** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c       write(6,*)'my_rank=',my_rank,'ik=',ik,'nbleng=',nbleng,' Send EE'
cc      stop
c      endif
c **** temp check :  edn
      call MPI_Send(EE(nbgn,ik),nbleng,MPI_DOUBLE_PRECISION,
     &        0,tag,MPI_COMM_WORLD,ierr)
      else
       do icpu=1,ncpu
       nbleng=nend(icpu)-nbegin(icpu)+1
       nbgn=nbegin(icpu)
c **** temp check
c       miya=13
c       if ( miya.eq.13 ) then
c        write(6,*)'my_rank=',my_rank,' Receiving EE; ik='
c     &    ,ik,'icpu=',icpu,'nbleng=',nbleng
c        write(6,*)' icpu=',icpu,'nbgn=',nbgn
c       endif
       call MPI_Recv(EE(nbgn,ik),nbleng,MPI_DOUBLE_PRECISION,
     &        icpu,tag,MPI_COMM_WORLD,status,ierr)
c *** temp check
c       miya=13
c       if ( miya.eq.13 ) then
c        write(6,*)'my_rank=',my_rank,' EE; received ik='
c     &    ,'icpu=',icpu
c       endif
c *** temp check :end
       enddo
c **** temp check
c       miya=13
c       if ( miya.eq.13 ) then
c        write(6,*)' Recv of EE; end  ik=',ik
c        do ib=1,nbseq(ik)
c         write(6,*)' EE = ',EE(ib,ik)*27.212d0
c        enddo
cc       stop
c       endif
c **** temp check
      endif   ! if my_rank.ne.0 loop end!
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_end("sendrecv01")
! ==============================================================================
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)' my_rank=',my_rank,' Expectation values !'
c      stop
c      endif
c *** temp check : end
c      endif   ! if itstep.eq.ntstep loop: end 
c
c
c
c ***************************************************
c  This part should be reconsidered later !!!!!
c ***************************************************
c
c
c
c
c ***  checking off-diagonal elements of H(Kohn-Sham)
c
c       if ( itstep.eq.ntstep .and. ib.lt.nbseq(ik) ) then
cc 9799 continue
       if ( itstep.eq.ntstep .and. IOK.eq.1 ) then
c *** temp check
        if ( my_rank.eq.0 ) then
         write(6,*)' call HLOCAL and NONLOC for Off-diagonal'
        endif
c *** temp check  : end
c **** calculate matrix elements without communication
        nbleng=nend(my_rank)-nbegin(my_rank)+1
c        do ib=1,nbleng
c         do ig=1,nxyz
c          coef0(ig,ib,ik)=coef(ig,ib,ik)
c         enddo
c        enddo
        do ib2=nbegin(my_rank),nend(my_rank)
         iib2=ib2-nbegin(my_rank)+1
          call zero(dcoef,ng2q )
          CALL HLOCAL( NRX, NRY, NRZ, NXYZ, NG2(IK), NG2Q, mxbnd,
     &    COEF(1,iib2,ik),DCOEF(1,1),
c *** for Sugino FFT
c     &   RHO1, RHO2, VG, J2G(1,ik), WSAVEX, WSAVEY, WSAVEZ,
c     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2  )
c *** for Kokubo ASL FFT
c     &   RHO1, RHO2, VG, J2G(1,ik), WSAVE_XYZ,   IFAC_XYZ  )
c *** for Kokubo FFTW
     &   RHO1, RHO2, VG, J2G(1,ik), plancfp,plancbp  )
C
         CALL NONLOC( NXYZ, NG2(IK), NG2Q, mxbnd,
     &   COEF(1,iib2,ik), DCOEF(1,1),
c     &   YLM, G2(1,1,ik), RHO2, RHO3, TPIBA, WORK2, VPJ(1,1,1,1,ik),
     &   YLM, GG2(1,1,ik), RHO2, RHO3, TPIBA, WORK2, VPJ(1,1,1,1,ik),
     &             VPP, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
     &             NIDN, IOVP(1,1,ik), MXOFL,GDUMP(1,IK),NGNL(1,IK)
     &  ,NGcont )
c
c          do ib1=nbegin(my_rank),nend(my_rank)
          do ib1=ib2+1,nend(my_rank)
           iib1=ib1-nbegin(my_rank)+1
           cmat(ib1,ib2)=0.d0
            do ig=1,nxyz
              cmat(ib1,ib2)=cmat(ib1,ib2)+
     &         dconjg( coef(ig,iib1,ik) )* dcoef(ig,1)
            enddo
c *** temp check
c          write(6,*)'my_rank',my_rank,'ik',ik,'<',ib1,'|H|'
c     &      ,ib2,'>=',cmat(ib1,ib2)
c *** temp check : end
          enddo ! end of ib1 loop
        enddo  ! end of ib2 loop
c *** temp check
        if ( my_rank.eq.0 ) then
         write(6,*)' Off-diagonal elements: computed!'
        endif
c *** temp check : end
c **** temp check
c       miya=13
c       if ( miya.eq.13 ) then
c        write(6,*)'my_rank',my_rank,' Before do 2200 '
c        stop
c       endif
c **** temp check : end
cc         if ( icpu1+1.gt.ncpu ) goto 2201
c *** calculate matrix elements with communication
c        if ( my_rank.eq.0 ) goto 2301
c         do 2300 icpu2=0,my_rank-1
c         nbleng=nend(my_rank)-nbegin(my_rank)+1
c          do ib=1,nbleng
c           do ig=1,nxyz
c            coef0(ig,ib,ik)=coef(ig,ib,ik)
c           enddo
c          enddo 
c         call MPI_Send(coef0(1,1,ik),nxyz*nbleng,
c     &    MPI_DOUBLE_COMPLEX,icpu2,tag+1,MPI_COMM_WORLD,ierr)
c 2300    continue
c 2301  continue
cc       if (my_rank.eq.ncpu ) goto 2201
c *** temp check
c         write(6,*)'my_rank',my_rank,' in do 2200: Recv end'
c         miya=13
c         if ( miya.eq.13.and.icpu2.eq.ncpu ) then
c          write(6,*)'my_rank',my_rank,' icpu2',icpu2
c          stop
c         endif
c *** temp check end
c         do 2200 icpu2=my_rank+1,ncpu
c *** temp check
         if ( my_rank.eq.0 ) then
         write(6,*)' Now before do 2200 - for Off-diagonal'
         endif
c *** temp check : end
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_begin("sendrecv02")
! ==============================================================================
         do 2200 icpu2=0,ncpu
         if ( my_rank.gt.icpu2 ) then
          nbleng=nend(my_rank)-nbegin(my_rank)+1
          do ib=1,nbleng
           do ig=1,nxyz
            coef0(ig,ib,ik)=coef(ig,ib,ik)
           enddo
          enddo
          call MPI_Send(coef0(1,1,ik),nxyz*nbleng,
     &    MPI_DOUBLE_COMPLEX,icpu2,tag+1,MPI_COMM_WORLD,status,ierr)
         elseif ( my_rank.lt.icpu2 ) then
          nbleng=nend(icpu2)-nbegin(icpu2)+1
          call MPI_Recv(coef0(1,1,ik),nxyz*nbleng,
     &    MPI_DOUBLE_COMPLEX,icpu2,tag+1,MPI_COMM_WORLD,status,ierr)
         endif
        do ib2=nbegin(icpu2),nend(icpu2)
         iib2=ib2-nbegin(icpu2)+1
         call zero(dcoef,ng2q )
         CALL HLOCAL( NRX, NRY, NRZ, NXYZ, NG2(IK), NG2Q, mxbnd,
     &   COEF0(1,iib2,ik),DCOEF(1,1),
c *** for Sugino FFT
c     &   RHO1, RHO2, VG, J2G(1,ik), WSAVEX, WSAVEY, WSAVEZ,
c     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2  )
c *** for Kokubo ASL FFT
c     &   RHO1, RHO2, VG, J2G(1,ik), WSAVE_XYZ, IFAC_XYZ  )
c *** for Kokubo FFTW
     &   RHO1, RHO2, VG, J2G(1,ik), plancfp,plancbp  )
C
         CALL NONLOC( NXYZ, NG2(IK), NG2Q, mxbnd,
     &   COEF0(1,iib2,ik), DCOEF(1,1),
c     &   YLM, G2(1,1,ik), RHO2, RHO3, TPIBA, WORK2, VPJ(1,1,1,1,ik),
     &   YLM,GG2(1,1,ik), RHO2, RHO3, TPIBA, WORK2, VPJ(1,1,1,1,ik),
     &             VPP, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
     &             NIDN, IOVP(1,1,ik), MXOFL,GDUMP(1,IK),NGNL(1,IK)
     &   ,NGcont )
c
c ** temp check
c         miya=13
c         if ( miya.eq.13.and.my_rank.lt.3) then
c          write(6,*)'my_rank',my_rank,' H*coef ended !'
c          if (my_rank.eq.3 ) stop
c         endif
c ** temp check end
           do ib1=nbegin(my_rank),nend(my_rank)
           iib1=ib1-nbegin(my_rank)+1
c           cmat(ib1,ib2)=0
           cmat(ib2,ib1)=0
            do ig=1,nxyz
c             cmat(ib1,ib2)=cmat(ib1,ib2)+
             cmat(ib2,ib1)=cmat(ib2,ib1)+
c     &        dconjg( coef(ig,iib1,ik) )*dcoef(ig,1)
     &        coef(ig,iib1,ik)*dconjg( dcoef(ig,1) )
            enddo  ! end of ig loop
c *** temp check
cc          cmat(ib2,ib1)=dconjg( cmat(ib1,ib2) )
c          write(6,*)'my_rank',my_rank,'ik',ik,'<',ib2,'|H|'
c     &      ,ib1,'>=',cmat(ib2,ib1)
c *** temp check : end
         enddo ! end of ib1 loop
       enddo ! end of ib2 loop
 2200   continue   ! end of icpu2 loop
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_end("sendrecv02")
! ==============================================================================
c
c ** temp check
c         miya=13
c         if ( miya.eq.13.and.my_rank.lt.3) then
c          write(6,*)'my_rank',my_rank,' cmat cal ended !'
c          if (my_rank.eq.2 ) stop
c         endif
c ** temp check end
 2201    continue   ! to avoid 'do 2200' when icpu1+1 bigger than ncpu
c ****** recompute dcoef on my_rank=0
c *** temp check
         if ( my_rank.eq.0 ) then
         write(6,*)' Now after do 2200-2201 '
         endif
c *** temp check : end
c *** Gather cmat on my_rank=0
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_begin("sendrecv03")
! ==============================================================================
        if ( my_rank.eq.0 ) then
         do icpu=1,ncpu
          ib1=nbegin(icpu)
          nbleng=mxbnd0-nbegin(icpu)+1
          do ib2=nbegin(icpu),nend(icpu)
           call MPI_Recv(cmat(ib1,ib2),nbleng,MPI_DOUBLE_COMPLEX
     &      ,icpu,tag+2,MPI_COMM_WORLD,status,ierr)
          enddo   ! end of ib2 loop
         enddo    ! end of icpu loop
        else   ! if my_rank.ne.0
         ib1=nbegin(my_rank)
         nbleng=mxbnd0-nbegin(my_rank)+1
         do ib2=nbegin(my_rank),nend(my_rank)
          call MPI_Send(cmat(ib1,ib2),nbleng,MPI_DOUBLE_COMPLEX
     &       ,0,tag+2,MPI_COMM_WORLD,ierr)
         enddo  !  end of ib2 loop
        endif    !  end of if my_rank.eq.0
! ==============================================================================
!     call MPI_Barrier(MPI_COMM_WORLD,ierr)
!     call ftrace_region_end("sendrecv03")
! ==============================================================================
c ** Gather end
        if ( my_rank.eq.0 ) then
           do ib2=1,mxbnd0
            do ib1=ib2+1,mxbnd0
             if ( abs(cmat(ib1,ib2)).ge.0.01d0 ) then
              write(6,*)' Watch this element !!!!! '
             endif
             write(6,1212)ib1,ib2,cmat(ib1,ib2)
            enddo   ! end of ib1 loop
           enddo    ! end of ib2 loop
       endif ! end of if my_rank.eq.0
c **************
       endif  ! end of if  itstep.eq.ntstep .and... loop
      enddo   ! end of ik loop
 1212 format( '<',i4,'| H |',i4,'>=',2F24.16,' HR ')
 1818 format(' Off-diagonal elements at the',i4,'-th k-point')
c **** temp check
c      miya=13
c      if ( miya.eq.13 .and. my_rank.eq.0 ) then
c      stop
c      endif
c **** temp check : end
c ********************
c Calculation of the expectation values.  END
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c       write(6,*)'my_rank=',my_rank,' Off diagonal elements!'
c      stop
c      endif
c *** temp check ! end
c ********************
C
      endif
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(55)
#endif
      if (IOK.eq.1 ) goto 9899  ! quit the Predictor-correcter loop
      if ( itstep.eq.0 ) then
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(56)
#endif
c  **** for accuracy of inital EH ELOCAL energies
c *** temp check
cd      if (my_rank.eq.0 ) then
c      do ik=1,numk
c       write(6,*)' OCC for IK=',IK
c       write(6,*)( OCC(j,IK),J=1,NBNDQ)
c      enddo
c      endif
c *** temp check: end
      do ig=1,NXYZ
       RHO(ig)=0
       RHOG(ig)=0
      enddo
      DO 631 IK=1,NUMK
      CALL RHOOFK( MXBND, 1, NRX, NRY, NRZ, NXYZ, NG2(IK), NG2Q,
     &             NBNDQ, NBND, NFL, RHO, RHO1, RHO2, RHO3,
     &             COEF(1,1,IK),
     &             WGT(IK), J2G(1,IK), IOWF(1,IK), OCC(1,IK),NBSEQ(IK)
c *** for Sugino FFT
c     &            ,WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &             LX1, LX2, LY1, LY2, LZ1, LZ2 ,itstep,itmod       )
c *** for Kokubo ASL FFT
c     &            ,WSAVE_XYZ, IFAC_XYZ,itstep,itmod       )
c *** for Kokubo FFTW
     &            ,plancfp,plancbp,itstep,itmod 
c
     &            ,nbegin,nend,ncpuq   )
  631 CONTINUE
c
                 IF( NPFL .EQ. 0 ) GO TO 8501
      DO 635 IK=1,NUMK
        CALL SUMCHR( MXBND, 1, NFL, NPFL, NRX, NRY, NRZ, NXYZ,
     &               RHO, RHO1, RHO2, RHO3, IOWF(1,IK), NG2Q,
     &               NG2(IK), J2G(1,IK), COEF(1,1,IK),
     &               NKMESH, NEXPND, RCOSIN, NSY, IK, NBNDQ, NBND,
c *** for Sugino FFT
c     &         VINT,NBSEQ2, OMEGA, WSAVEX, WSAVEY, WSAVEZ,
c     &               IFACX, IFACY, IFACZ, LX1, LX2,
c     &               LY1, LY2, LZ1, LZ2 ,itstep,itmod       )
c *** for Kokubo ASL FFT
c     &         VINT,NBSEQ2, OMEGA,WSAVE_XYZ,IFAC_XYZ,itstep,itmod )
c *** for Kokubo FFTW
     &         VINT,NBSEQ2, OMEGA,plancfp,plancbp,itstep,itmod 
c
     &            ,nbegin,nend,ncpuq   )
  635 CONTINUE
C ****
 8501            CONTINUE
c****
      CALL RHOGET( NRX, NRY, NRZ, NXYZ, RHO, RHO1, RHOG,
     &             NTOT, S, OMEGA, ZVAL,RHO2,I2G,G,
c *** for Sugino FFT
c     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &      LX1, LX2, LY1, LY2, LZ1, LZ2,fdump,itstep,itmod   )
c *** for Kokubo FFT -- LY2,LZ1,LZ2 are still necessary for ROTRA
c     &    WSAVE_XYZ, IFAC_XYZ,LY2, LZ1, LZ2,fdump,itstep,itmod   )
c *** for Kokubo FFT -- LY2,LZ1,LZ2 are still necessary for ROTRA
     &    plancfp,plancbp, LY2, LZ1, LZ2,fdump,itstep,itmod   )
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(56)
#endif
      return
      endif
c
c *** Keep the time-evolution coefficients resident for the complete
c *** predictor-corrector sequence.  COEF0 is the unchanged wavefunction
c *** used to restart every correction.  The host coefcp above remains the
c *** CPU/FFTW path; on OpenACC the correction restart below is device-local.
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(45)
#endif
      if (iscf.eq.1) then
!$acc enter data copyin(COEF(1:NG2Q,1:MXBND,1:NUMKQ),
!$acc& COEF0(1:NG2Q,1:MXBND,1:NUMKQ))
      else
!$acc parallel loop collapse(3)
!$acc& present(COEF(1:NG2Q,1:MXBND,1:NUMKQ),
!$acc& COEF0(1:NG2Q,1:MXBND,1:NUMKQ))
       do ik0=1,numkq
        do ib=1,nblng
         do ig=1,ng2q
          COEF(ig,ib,ik0)=COEF0(ig,ib,ik0)
         enddo
        enddo
       enddo
       icoef_host_current=0
      endif
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(45)
      call prof_start(57)
#endif
c
      DO 600 I=1,NXYZ
  600 RHO(I)=0.D0
C
C
      ENL=0.D0
      EKINE=0.D0
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(57)
#endif
      DO 2000 IK=1,NUMK
c *****
      if (iscf.eq.1 ) then
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(46)
#endif
c *****
      GFAC=GMHF*2
c **** G21 for YLM1 and GDUMP1
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX1
         GAY=G2(2,IG,IK)-AVY1
         GAZ=G2(3,IG,IK)-AVZ1
         G21(1,IG,IK)=GAX
         G21(2,IG,IK)=GAY
         G21(3,IG,IK)=GAZ
         G21(4,IG,IK)=GAX*GAX + GAY*GAY + GAZ*GAZ
        ENDDO
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX1
         GAY=G2(2,IG,IK)-AVY1
         GAZ=G2(3,IG,IK)-AVZ1
         GAvec=GAX*GAX + GAY*GAY + GAZ*GAZ
         IF ( GAvec.LE.GFAC ) then
          GDUMP1(IG,IK)=GAvec
         else
          GDUMP1(IG,IK)=GFAC
         endif
        ENDDO
c **** G22 for YLM2 and GDUMP2
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX2
         GAY=G2(2,IG,IK)-AVY2
         GAZ=G2(3,IG,IK)-AVZ2
         G22(1,IG,IK)=GAX
         G22(2,IG,IK)=GAY
         G22(3,IG,IK)=GAZ
         G22(4,IG,IK)=GAX*GAX + GAY*GAY + GAZ*GAZ
        ENDDO
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX2
         GAY=G2(2,IG,IK)-AVY2
         GAZ=G2(3,IG,IK)-AVZ2
         GAvec=GAX*GAX + GAY*GAY + GAZ*GAZ
         IF ( GAvec.LE.GFAC ) then
          GDUMP2(IG,IK)=GAvec
         else
          GDUMP2(IG,IK)=GFAC
         endif
        ENDDO
c **** G23 for YLM3
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX3
         GAY=G2(2,IG,IK)-AVY3
         GAZ=G2(3,IG,IK)-AVZ3
         G23(1,IG,IK)=GAX
         G23(2,IG,IK)=GAY
         G23(3,IG,IK)=GAZ
         G23(4,IG,IK)=GAX*GAX + GAY*GAY + GAZ*GAZ
        ENDDO
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX3
         GAY=G2(2,IG,IK)-AVY3
         GAZ=G2(3,IG,IK)-AVZ3
         GAvec=GAX*GAX + GAY*GAY + GAZ*GAZ
         IF ( GAvec.LE.GFAC ) then
          GDUMP3(IG,IK)=GAvec
         else
          GDUMP3(IG,IK)=GFAC
         endif
        ENDDO
c **** G24 for YLM4
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX4
         GAY=G2(2,IG,IK)-AVY4
         GAZ=G2(3,IG,IK)-AVZ4
         G24(1,IG,IK)=GAX
         G24(2,IG,IK)=GAY
         G24(3,IG,IK)=GAZ
         G24(4,IG,IK)=GAX*GAX + GAY*GAY + GAZ*GAZ
        ENDDO
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX4
         GAY=G2(2,IG,IK)-AVY4
         GAZ=G2(3,IG,IK)-AVZ4
         GAvec=GAX*GAX + GAY*GAY + GAZ*GAZ
         IF ( GAvec.LE.GFAC ) then
          GDUMP4(IG,IK)=GAvec
         else
          GDUMP4(IG,IK)=GFAC
         endif
        ENDDO
c **** G25 for YLM5
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX5
         GAY=G2(2,IG,IK)-AVY5
         GAZ=G2(3,IG,IK)-AVZ5
         G25(1,IG,IK)=GAX
         G25(2,IG,IK)=GAY
         G25(3,IG,IK)=GAZ
         G25(4,IG,IK)=GAX*GAX + GAY*GAY + GAZ*GAZ
        ENDDO
        DO IG=1,NXYZ
         GAX=G2(1,IG,IK)-AVX5
         GAY=G2(2,IG,IK)-AVY5
         GAZ=G2(3,IG,IK)-AVZ5
         GAvec=GAX*GAX + GAY*GAY + GAZ*GAZ
         IF ( GAvec.LE.GFAC ) then
          GDUMP5(IG,IK)=GAvec
         else
          GDUMP5(IG,IK)=GFAC
         endif
        ENDDO
c *** temp check
c      if (my_rank.eq.0 .and. mod(itstep,itmod).eq.0 ) then
cc       write(6,*)' in frprmn itstep=',itstep
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
c       write(6,*)' GDUMP  '
c       write(6,'(4F22.16)')(GDUMP(IG,1),IG=1,NXYZ,5000)
c      endif
c *** temp check : end
c ** for P-A: nonlocal part 
c +++++++++
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(46)
      call prof_start(47)
#endif
         NGNLMX=1
         do ity=1,NTYPE
          NGNLMX=MAX(NGNL(ity,IK),NGNLMX)
         enddo
         if( VPJGENdo) then         
c *** temp check
c          if (my_rank.eq.0 ) then
c           write(6,*)' Before Part1to5 mshbegin mshend '
c           do icpu=0,ncpuq
c            write(6,*) icpu, mshbegin(icpu),mshend(icpu)
c           enddo
c          endif
c *** temp check end
c +++++++++ for P-A ++ 5 parts interporation used in TIMEVL
      call Part1to5(NG2Q,G21(1,1,IK),G22(1,1,IK),G23(1,1,IK)
     &    ,G24(1,1,IK),G25(1,1,IK),G2(1,1,IK)
     &    ,YLM1(1,1,IK),YLM2(1,1,IK),YLM3(1,1,IK)
     &    ,YLM4(1,1,IK),YLM5(1,1,IK)
     &    ,VPJ1(1,1,1,1,IK),VPJ2(1,1,1,1,IK),VPJ3(1,1,1,1,IK)
     &    ,VPJ4(1,1,1,1,IK),VPJ5(1,1,1,1,IK),VPJWORK
     &    ,VPP21(1,1,1,IK),VPP22(1,1,1,IK),VPP23(1,1,1,IK)
     &    ,VPP24(1,1,1,IK),VPP25(1,1,1,IK),NGNLMX
     &    ,RHO3,TPIBA,NTYQ,NTYPE,GMHF,MXOFL
     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL(1,IK),OMEGA,NGcont
c
     &    ,mshbegin,mshend, ncpuq )
         endif
c
c **** 
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(47)
#endif
      endif
c **** iscf=1 loop end
c
c *** prepare EXTAU !!!
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(48)
#endif
c ****** part 1 ********
! ==============================================================================
!     ITBF=0
! ==============================================================================
      do ity=1,ntype
       do it=1,abs( numty(ity) )
        itseq=NIDN(it,ity)
c ****
! ==============================================================================
!       if ( itseq.ge.nbegint(my_rank)
!    &  .and. itseq.le.nendt(my_rank) ) then
! ==============================================================================
        t1=tau1(1,itseq)
        t2=tau1(2,itseq)
        t3=tau1(3,itseq)
! ==============================================================================
!       ITBF=ITBF+1
! ==============================================================================
c        do ig=1,nxyz
        do ig=1,NGcont
c         TEMP=TPIBA*(G2(1,IG,IK)*T1+G2(2,IG,IK)*T2+G2(3,IG,IK)*T3)
         TEMP=TPIBA*(G21(1,IG,IK)*T1+G21(2,IG,IK)*T2+G21(3,IG,IK)*T3)
c         EXTAU(IG,ITSEQ,1)=DCMPLX(COS(TEMP),SIN(TEMP))
c         EXTAU(IG,1,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
!        EXTBF(IG,1,ITBF)=DCMPLX(COS(TEMP),SIN(TEMP))
         EXTAU(IG,1,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
        enddo
c ****
! ==============================================================================
!       endif  ! end if my_rank is within nbegint to nendt
! ==============================================================================
       enddo 
      enddo
c      do icpu=0,ncpu
c      ntleng=nendt(icpu)-nbegint(icpu)+1
c      call MPI_Bcast(EXTAU(1,nbegint(icpu),1),ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX, icpu,MPI_COMM_WORLD,ierr)
c      enddo
c ****** part 2 ********
! ==============================================================================
!      ITBF=0
! ==============================================================================
      do ity=1,ntype
       do it=1,abs( numty(ity) )
        itseq=NIDN(it,ity)
c ***
! ==============================================================================
!       if ( itseq.ge.nbegint(my_rank)
!    &  .and. itseq.le.nendt(my_rank) ) then
! ==============================================================================
        t1=tau2(1,itseq)
        t2=tau2(2,itseq)
        t3=tau2(3,itseq)
! ==============================================================================
!       ITBF=ITBF+1
! ==============================================================================
c        do ig=1,nxyz
        do ig=1,NGcont
c         TEMP=TPIBA*(G2(1,IG,IK)*T1+G2(2,IG,IK)*T2+G2(3,IG,IK)*T3)
         TEMP=TPIBA*(G22(1,IG,IK)*T1+G22(2,IG,IK)*T2+G22(3,IG,IK)*T3)
c         EXTAU(IG,ITSEQ,2)=DCMPLX(COS(TEMP),SIN(TEMP))
c         EXTAU(IG,2,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
!        EXTBF(IG,2,ITBF)=DCMPLX(COS(TEMP),SIN(TEMP))
         EXTAU(IG,2,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
        enddo
c ***
! ==============================================================================
!       endif
! ==============================================================================
       enddo
      enddo
c      do icpu=0,ncpu
c      ntleng=nendt(icpu)-nbegint(icpu)+1
c      call MPI_Bcast(EXTAU(1,nbegint(icpu),2),ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX, icpu,MPI_COMM_WORLD,ierr)
c      enddo      
c ****** part 3 ********
! ==============================================================================
!     ITBF=0
! ==============================================================================
      do ity=1,ntype
       do it=1,abs( numty(ity) )
        itseq=NIDN(it,ity)
c ****
! ==============================================================================
!       if ( itseq.ge.nbegint(my_rank)
!    &  .and. itseq.le.nendt(my_rank) ) then
! ==============================================================================
        t1=tau3(1,itseq)
        t2=tau3(2,itseq)
        t3=tau3(3,itseq)
! ==============================================================================
!       ITBF=ITBF+1
! ==============================================================================
c        do ig=1,nxyz
        do ig=1,NGcont
c         TEMP=TPIBA*(G2(1,IG,IK)*T1+G2(2,IG,IK)*T2+G2(3,IG,IK)*T3)
         TEMP=TPIBA*(G23(1,IG,IK)*T1+G23(2,IG,IK)*T2+G23(3,IG,IK)*T3)
c         EXTAU(IG,ITSEQ,3)=DCMPLX(COS(TEMP),SIN(TEMP))
c         EXTAU(IG,3,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
!        EXTBF(IG,3,ITBF)=DCMPLX(COS(TEMP),SIN(TEMP))
         EXTAU(IG,3,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
        enddo
c ****
! ==============================================================================
!       endif
! ==============================================================================
       enddo
      enddo
c      do icpu=0,ncpu
c      ntleng=nendt(icpu)-nbegint(icpu)+1
c      call MPI_Bcast(EXTAU(1,nbegint(icpu),3),ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX, icpu,MPI_COMM_WORLD,ierr)
c      enddo
c ****** part 4 ********
! ==============================================================================
!     ITBF=0
! ==============================================================================
      do ity=1,ntype
       do it=1,abs( numty(ity) )
        itseq=NIDN(it,ity)
c ****
! ==============================================================================
!       if ( itseq.ge.nbegint(my_rank)
!    &  .and. itseq.le.nendt(my_rank) ) then
! ==============================================================================
        t1=tau4(1,itseq)
        t2=tau4(2,itseq)
        t3=tau4(3,itseq)
! ==============================================================================
!       ITBF=ITBF+1
! ==============================================================================
c        do ig=1,nxyz
        do ig=1,NGcont
c         TEMP=TPIBA*(G2(1,IG,IK)*T1+G2(2,IG,IK)*T2+G2(3,IG,IK)*T3)
         TEMP=TPIBA*(G24(1,IG,IK)*T1+G24(2,IG,IK)*T2+G24(3,IG,IK)*T3)
c         EXTAU(IG,ITSEQ,4)=DCMPLX(COS(TEMP),SIN(TEMP))
c         EXTAU(IG,4,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
!        EXTBF(IG,4,ITBF)=DCMPLX(COS(TEMP),SIN(TEMP))
         EXTAU(IG,4,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
        enddo
c ****
! ==============================================================================
!       endif
! ==============================================================================
       enddo
      enddo
c      do icpu=0,ncpu
c      ntleng=nendt(icpu)-nbegint(icpu)+1
c      call MPI_Bcast(EXTAU(1,nbegint(icpu),4),ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX, icpu,MPI_COMM_WORLD,ierr)
c      enddo
c ****** part 5 ********
! ==============================================================================
!     ITBF=0
! ==============================================================================
      do ity=1,ntype
       do it=1,abs( numty(ity) )
        itseq=NIDN(it,ity)
c ****
! ==============================================================================
!       if ( itseq.ge.nbegint(my_rank)
!    &  .and. itseq.le.nendt(my_rank) ) then
! ==============================================================================
        t1=tau5(1,itseq)
        t2=tau5(2,itseq)
        t3=tau5(3,itseq)
! ==============================================================================
!       ITBF=ITBF+1
! ==============================================================================
c        do ig=1,nxyz
        do ig=1,NGcont
c         TEMP=TPIBA*(G2(1,IG,IK)*T1+G2(2,IG,IK)*T2+G2(3,IG,IK)*T3)
         TEMP=TPIBA*(G25(1,IG,IK)*T1+G25(2,IG,IK)*T2+G25(3,IG,IK)*T3)
c         EXTAU(IG,ITSEQ,5)=DCMPLX(COS(TEMP),SIN(TEMP))
c         EXTAU(IG,5,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
!        EXTBF(IG,5,ITBF)=DCMPLX(COS(TEMP),SIN(TEMP))
         EXTAU(IG,5,ITSEQ)=DCMPLX(COS(TEMP),SIN(TEMP))
! ==============================================================================
        enddo
c ****
! ==============================================================================
!       endif
! ==============================================================================
       enddo
      enddo
c      do icpu=0,ncpu
c      ntleng=nendt(icpu)-nbegint(icpu)+1
c      call MPI_Bcast(EXTAU(1,nbegint(icpu),5),ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX, icpu,MPI_COMM_WORLD,ierr)
c      enddo
c **
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(48)
      call prof_start(58)
#endif
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c       write(6,*)'my_rank=',my_rank,' jest before TMEVL'
c      stop
c      endif
c *** temp check : end
c *** all to all communication for EXTAU !!!!
c *** temp check
      if ( itstep.eq.itmod ) then
       call clock(t00)
      endif
c *** temp check: end
c      do icpu=0,ncpu
c      ntleng=nendt(icpu)-nbegint(icpu)+1
c      call MPI_Bcast(EXTAU(1,1,nbegint(icpu)),5*ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX, icpu,MPI_COMM_WORLD,ierr)
c      enddo
c
c      do icpu=0,ncpu
c       ntleng=nendt(icpu)-nbegint(icpu)+1
c       call MPI_Gather(EXTBF,5*ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX,EXTAU,5*ntleng*(nxyz/6)
c     & ,MPI_DOUBLE_COMPLEX,icpu,MPI_COMM_WORLD,ierr)
c      enddo
c    **temp check
c      if ( my_rank.eq.0 ) then
c       write(6,*)' in sub frprmn !!!! '
c       do icpu=0,ncpu
c        iicpu=icpu+1
c        write(6,2777)iicpu,recvcnts(iicpu),iicpu,displs(iicpu)
c       enddo
c 2777  format('recvcnts(',i3,')=',i10,' displs(',i3,')=',i12 )
c      endif
c    ** temp check end
c
! ==============================================================================
!      ntleng=nendt(my_rank)-nbegint(my_rank)+1
! ==============================================================================
c ***
c       if ( my_rank.eq.0 ) then
c        write(6,*)' ntleng = ',ntleng,' ITBF = ',ITBF
c       endif
c ***
! ==============================================================================
!       isndcnt=5*ntleng*(NGcont)
!! ==============================================================================
!      call MPI_Barrier(MPI_COMM_WORLD,ierr)
!      call ftrace_region_begin("allgatherv")
!! ==============================================================================
!       call MPI_Allgatherv(EXTBF,isndcnt,MPI_DOUBLE_COMPLEX,
!     &            EXTAU,recvcnts,displs,MPI_DOUBLE_COMPLEX,
!     &            MPI_COMM_WORLD,ierr )
!! ==============================================================================
!      call MPI_Barrier(MPI_COMM_WORLD,ierr)
!      call ftrace_region_end("allgatherv")
!! ==============================================================================
! ==============================================================================
c
c ** temp check
c       ntleng=nendt(my_rank)-nbegint(my_rank)+1
c       do it=1,ntleng
c       itbf=it
c       iit=nbegint(my_rank)-1+it
c        do ipart=1,5
c         diff=0.d0
c         do ig=1,nxyz/6
c          diff=diff+dcabs( EXTAU(ig,ipart,iit)-EXTBF(ig,ipart,itbf) )
c         enddo
c         if ( diff.gt.1.d-06 ) then
c          write(6,*)' my_rank',my_rank,' itbf iit = ',itbf,iit,
c     &   ' ipart = ',ipart
c         endif
c        enddo
c       enddo
c ** temp end
c ** temp check
      if ( itstep.eq.itmod ) then
       call clock(t01)
       if ( my_rank.eq.0 ) then
        write(6,*)' AllGatherv took ',t01-t00,' sec'
       endif
      endif
C ** temp check  : end
c **
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(58)
#endif
      CALL TMEVL(itstep,RDIF0,ITCF,NRX,NRY,NRZ,NXYZ,NG2(IK),NG2Q,
c     &             NBNDQ, NBSEQ,NBND, COEF(1,1,ik), DCOEF(1,1), CWK1,
     &          NBNDQ, NBSEQ(ik),NBND, COEF(1,1,ik), DCOEF(1,1), 
     &             YLM, G2(1,1,IK), RHO1, RHO2, RHO3,
c
c     &  TPIBA, VG, J2G(1,IK), WORK2, OUT(1,1,IK), VPJ(1,1,1,1,ik),
     &  TPIBA, VG,VG1,VG2,VG3,VG4,VG5,
     &  J2G(1,IK), WORK2, OUT(1,1,IK), VPJ(1,1,1,1,ik),
     &             VPP,
     &             IOWF(1,IK), IOVP(1,1,IK), MXBND, 1,
     &             OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &             NIDN, EE(1,IK), WSAVEX, WSAVEY, WSAVEZ, IFACX,
c     &             IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2, MXOFL
c *** for Kokubo ASL FFT
c     &             NIDN, EE(1,IK), WSAVE_XYZ, IFAC_XYZ, MXOFL
c *** for Kokubo FFTW
     &             NIDN, EE(1,IK), plancfp,plancbp, MXOFL
c
     &  ,dt,IK,NUMK,VPP2(1,1,1,IK),EXTAU
     &  ,GDUMP(1,IK)
     & ,GMHF,fdump,Vloc,NGNL(1,IK)
c *** for P-A
     &   ,YLM1(1,1,IK),YLM2(1,1,IK),YLM3(1,1,IK),
     &    YLM4(1,1,IK),YLM5(1,1,IK),
     &    GG2(1,1,IK),
     &    G21(1,1,IK),G22(1,1,IK),G23(1,1,IK),
     &    G24(1,1,IK),G25(1,1,IK),
c ++++ for P-A : vpj is updated
     &    VPJWORK,
     &    VPJ1(1,1,1,1,IK),VPJ2(1,1,1,1,IK),VPJ3(1,1,1,1,IK),
     &    VPJ4(1,1,1,1,IK),VPJ5(1,1,1,1,IK)
c ++++ for P-A 
     & ,VPP21(1,1,1,IK),VPP22(1,1,1,IK),VPP23(1,1,1,IK),
     &  VPP24(1,1,1,IK),VPP25(1,1,1,IK)
c +++ for A-vec GDUMP1 to GDUMP5
     & ,GDUMP1(1,IK),GDUMP2(1,IK),GDUMP3(1,IK)
     & ,GDUMP4(1,IK),GDUMP5(1,IK)
c *** for P-A pseudopotentials
     &   ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD
c
     &   ,NGcont
c
     &   ,nbegin,nend,mshbegin,mshend,ncpuq,ncpu  )
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(59)
#endif
      icoef_host_current=0
c **** temp check
c       miya=13
c       if ( miya.eq.13 ) then
c       write(6,*)' my_rank=',my_rank,' TMEVL has been finished!'
c       stop
c       endif
c **** temp check :  end
c ** temp check
c      write(6,*)' after calling TMEVL itstep = ',itstep
c      sum=0
c      do ig=1,nxyz
c      sum=sum+dconjg( coef(ig,1,ik) )* coef(ig,1,ik)
c      enddo
c      write(6,*)' After TMEVL : norm of the first WF = ',sum
c ** temp check end
C     CALL CLOCK(TIM)
C6004 FORMAT(23X,'****  FRPRMN: AFT CGDIAG: ',F15.7,' SEC')
C     WRITE(6,6004) TIM
C
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(59)
#endif
 2000 CONTINUE  ! end of IK loop
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(60)
#endif
c
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c
c *** temp check
c      if ( my_rank.eq.0 ) then
c      do ik=1,numk
c       do ib=1,nbseq(ik)
c        write(6,*)' EE(',ib,',',ik,')=',EE(ib,ik)*27.212d0
c       enddo
c      enddo
c      endif
c *** temp check ; end
C
C     END OF TIME EVOLUTION-LOOP
c
C     GENERATE NEW CHARGE DENSITY
C
c ****  temp check
c      write(6,*)' Occupation #s for timestep = ',itstep
c      do ik=1,numk
c       write(6,*)' IK = ',ik
c       write(6,1911)( occ(ib,ik),ib=1,nbnd )
c      enddo
c 1911 format(4f20.12)
c ****  temp check end
cccc      NBND1 = NFL + 1
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(60)
#endif
      call prof_start(41)
      DO 630 IK=1,NUMK
c *** temp check
c      write(6,*)'my_rank=',my_rank,' IK=',ik
c       do ib=1,nbseq(ik)
c        write(6,*)'my_rank=',my_rank,
c     & ' EE(',ib,',',ik,')=',EE(ib,ik)*27.212d0
c       enddo
c *** temp check
c      CALL RHOOFK(ik, MXBND, 1, NRX, NRY, NRZ, NXYZ, NG2(IK), NG2Q,
      CALL RHOOFK_ACC_BATCH( MXBND, 1, NRX, NRY, NRZ, NXYZ,
     &             NG2(IK), NG2Q,
     &             NBNDQ, NBND, NFL, RHO, RHO1, RHO2, RHO3,
     &             COEF(1,1,IK),
     &             WGT(IK), J2G(1,IK), IOWF(1,IK), OCC(1,IK),NBSEQ(IK)
c *** for Sugino FFT
c     &            ,WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &             LX1, LX2, LY1, LY2, LZ1, LZ2 ,itstep,itmod       )
c *** for Kokubo ASL FFT
c     &            ,WSAVE_XYZ, IFAC_XYZ,itstep,itmod       )
c *** for Kokubo FFTW
     &            ,plancfp,plancbp,itstep,itmod
c
     &            ,nbegin,nend,ncpuq)
  630 CONTINUE
      call prof_stop(41)
c *** temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)'my_rank=',my_rank,' end of RHOOFK'
c      stop
c      endif
c *** temp check
C ****
                 IF( NPFL .EQ. 0 ) GO TO 8500
C ****
      if (icoef_host_current.eq.0) then
       call prof_start(44)
!$acc update self(COEF(1:NG2Q,1:MXBND,1:NUMKQ))
       call prof_stop(44)
       icoef_host_current=1
      endif
      call prof_start(42)
      DO 634 IK=1,NUMK
        CALL SUMCHR( MXBND, 1, NFL, NPFL, NRX, NRY, NRZ, NXYZ,
     &               RHO, RHO1, RHO2, RHO3, IOWF(1,IK), NG2Q,
     &               NG2(IK), J2G(1,IK), COEF(1,1,IK),
     &               NKMESH, NEXPND, RCOSIN, NSY, IK, NBNDQ, NBND,
c *** for Sugino FFT
c     &         VINT,NBSEQ2, OMEGA, WSAVEX, WSAVEY, WSAVEZ,
c     &               IFACX, IFACY, IFACZ, LX1, LX2,
c     &               LY1, LY2, LZ1, LZ2 ,itstep,itmod       )
c *** for Kokubo ASL FFT
c     &         VINT,NBSEQ2, OMEGA,WSAVE_XYZ,IFAC_XYZ,itstep,itmod )
c *** for Kokubo FFTW
     &         VINT,NBSEQ2, OMEGA,plancfp,plancbp,itstep,itmod
c
     &        ,nbegin,nend,ncpuq )
  634 CONTINUE
      call prof_stop(42)
C ****
 8500            CONTINUE
C ****
      call prof_start(43)
      CALL RHOGET( NRX, NRY, NRZ, NXYZ, RHO, RHO1, RHOG,
     &             NTOT, S, OMEGA, ZVAL,RHO2,I2G,G,
c *** for Sugino FFT
c     &             WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &      LX1, LX2, LY1, LY2, LZ1, LZ2,fdump,itstep,itmod   )
c *** for Kokubo FFT -- LY2,LZ1,LZ2 are still necessary for ROTRA
c     &    WSAVE_XYZ, IFAC_XYZ,LY2, LZ1, LZ2,fdump,itstep,itmod   )
c *** for Kokubo FFT -- LY2,LZ1,LZ2 are still necessary for ROTRA
     &    plancfp,plancbp, LY2, LZ1, LZ2,fdump,itstep,itmod   )
      call prof_stop(43)
C
c ****  temp check
c      write(6,*)' After calling RHOGET ! -- RHO '
c      write(6,*)( RHO(i),i=1,1500,100 )
c ****  temp check : end
C
 9898 continue   ! finish of Predictor Correcter loop 
C
 9899 continue
      if (icoef_host_current.eq.0) then
       call prof_start(44)
!$acc update self(COEF(1:NG2Q,1:MXBND,1:NUMKQ))
       call prof_stop(44)
       icoef_host_current=1
      endif
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(61)
#endif
!$acc exit data delete(COEF(1:NG2Q,1:MXBND,1:NUMKQ),
!$acc& COEF0(1:NG2Q,1:MXBND,1:NUMKQ))
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(61)
#endif
c *** 
 1999 CONTINUE
c ** temp check
C   ***
      RETURN
      END
C*****************************************************************
c      SUBROUTINE RHOOFK(IK, MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NG2, NG2Q,
      SUBROUTINE RHOOFK( MXBND, MBLK, NRX, NRY, NRZ, NXYZ, NG2, NG2Q,
     &                   NBNDQ, NBND, NFL, RHO, RHO1, RHO2, RHO3,
c *** for Sugino FFT
c     &             COEF, WGT, J2G, IOWF, OCC,NBSEQ, WSAVEX, WSAVEY,
c     &                   WSAVEZ, IFACX, IFACY, IFACZ,
c     &                   LX1, LX2, LY1, LY2, LZ1, LZ2 , itstep,itmod   )
c *** for Kokubo ASL FFT
c     &             COEF, WGT, J2G, IOWF, OCC,NBSEQ, WSAVE_XYZ,
c     &                   IFAC_XYZ, itstep,itmod   )
c *** for Kokubo FFTW
     &             COEF, WGT, J2G, IOWF, OCC,NBSEQ, plancfp,plancbp,
     &                   itstep,itmod
c
     &          ,nbegin,nend,ncpuq )
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
      include 'mpif.h'
      REAL*8 RHO(NXYZ)
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),COEF(NG2Q,MXBND)
      DIMENSION J2G(NG2Q),OCC(NBNDQ),IOWF(MBLK)
C     WORK ARRAYS FOR FOURIER TRANSFORM
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
      integer status(MPI_STATUS_SIZE),tag
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c *** temp check
c      write(6,*)'my_rank=',my_rank,'IK=',IK,' in sub. RHOOFK'
c *** temp check ; end
C
C        GET RHOG
C
      DO 10 I=1,NXYZ
   10 RHO3(I)=(0.D0,0.D0)
c ****  sum with respect to new band indecis which skip empty bands
cc **     if ( my_rank.ne.0 ) then
c      do ib=1,nbseq
      do ib=nbegin(my_rank),nend(my_rank)
      iib=ib-nbegin(my_rank)+1
          DO 21 I=1,NXYZ
   21     RHO2(I)=(0.D0,0.D0)
c            DO 23 I=1,NG2
            DO 23 I=1,NXYZ
            II=J2G(I)
            RHO2(II)=COEF(I,IIB)
   23       CONTINUE
c *** for Sugino FFT
c            CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
c     &                   WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                   LX1, LX2, LY1, LY2, LZ1, LZ2               )
c *** for Kokubo ASL FFT
c            CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
c     &                   WSAVE_XYZ, IFAC_XYZ              )
c *** for Kokubo FFTW
c            call FFT3BX_fftw(NXYZ,RHO2,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
            CALL FFT3BX_fftwASL( NRX, NRY, NRZ, NXYZ, RHO2, RHO1,
     &                   plancfp,plancbp          )
            DO 24 I=1,NXYZ
   24       RHO2(I)=DCONJG(RHO2(I))*RHO2(I)
            DO 22 I=1,NXYZ
   22       RHO3(I)=RHO3(I)+RHO2(I)*OCC(IB)
      enddo
C
       do ig=1,nxyz
        rho2(ig)=0.0d0
       enddo
cc **      else
c      write(6,*)'my_rank=',my_rank,'IK=',IK,'RHOOFK: before Reduce'
c *** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) call clock(t00)
      endif
c *** temp check : end
c
c **** next MPI_Reduce and MPI_Bcast are substituted with MPI_ALLReduce
c
      miya=13
      if ( miya.eq.13 ) goto 4040
      call MPI_Reduce(rho3,rho2,nxyz,MPI_DOUBLE_COMPLEX
     &    ,MPI_SUM, 0,MPI_COMM_WORLD,ierr)
c *** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) then
        call clock(t01)
        write(6,*)' MPI_Reduce took ',t01-t00,' sec'
       endif
      endif
c *** temp check end
c ***
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c ***
      if ( my_rank.eq.0 ) then 
      do ig=1,nxyz
        rho3(ig)=rho2(ig)
      enddo
      endif
c *** temp check
c      write(6,*)'my_rank=',my_rank,'IK=',IK,'RHOOFK: before Bcast'
c *** temp check ; end
c *** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) call clock(t00)
      endif
c *** temp check : end
      call MPI_Bcast(rho3,nxyz,MPI_DOUBLE_COMPLEX,
     &     0,MPI_COMM_WORLD,ierr)
c ***
c  MPI_ALLReduce
c
 4040 continue
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) call clock(t00)
      endif
      call MPI_ALLReduce(rho3,rho1,nxyz,MPI_DOUBLE_COMPLEX
     &    ,MPI_SUM, MPI_COMM_WORLD,ierr)
c ** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) then
        call clock(t01)
c        write(6,*)' B_cast of total charge took ',t01-t00,' sec'
        write(6,*)' MPI_ALLReduce for total charge took ',t01-t00,' sec'
       endif
      endif
c ** temp check end
C
c *** temp check
c      write(6,*)'my_rank=',my_rank,'IK=',IK,'RHOOFK: after Bcast'
c *** temp check ; end
      FWGT=WGT*2.D0   ! weight for each k-point
      DO 631 I=1,NXYZ
c  631 RHO(I)=RHO(I)+DBLE(RHO3(I))*FWGT
  631 RHO(I)=RHO(I)+DBLE(RHO1(I))*FWGT
C
c *** temp check
c      write(6,*)'my_rank=',my_rank,'IK=',IK,'RHOOFK: after DO 631'
c *** temp check ; end
c *** temp check
c      sum=0
c      do ig=1,nxyz
c      sum=sum+RHO(IG)
c      enddo
c      sum=sum*72.d0/dfloat(nxyz)
c      write(6,*)' my_rank=',my_rank,' sum=',sum
c      miya=13
c      if (miya.eq.13 ) stop
c *** temp check : end
      RETURN
      END
c
C*****************************************************************
      SUBROUTINE RHOOFK_ACC_BATCH( MXBND, MBLK, NRX, NRY, NRZ,
     &                   NXYZ, NG2, NG2Q, NBNDQ, NBND, NFL,
     &                   RHO, RHO1, RHO2, RHO3,
     &                   COEF, WGT, J2G, IOWF, OCC, NBSEQ,
     &                   plancfp, plancbp, itstep, itmod,
     &                   nbegin, nend, ncpuq )
C
C     Post-TMEVL charge-density path.  COEF is already resident for the
C     predictor-corrector sequence.  Scatter all local bands, execute one
C     batched transform, accumulate density on the device, and return only
C     the local density required by MPI_ALLReduce.
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
      REAL*8 RHO(NXYZ)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ)
      COMPLEX*16 COEF(NG2Q,MXBND)
      DIMENSION J2G(NG2Q),OCC(NBNDQ),IOWF(MBLK)
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      integer*8 plancfp,plancbp
      COMPLEX*16, ALLOCATABLE, SAVE :: RHO1_ACC(:,:),RHO2_ACC(:,:)
      COMPLEX*16, ALLOCATABLE, SAVE :: RHO3_ACC(:)
      LOGICAL, SAVE :: FIRST=.TRUE.
C
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      nbndloc=nend(my_rank)-nbegin(my_rank)+1
      ibfirst=nbegin(my_rank)
C
      if (FIRST) then
       allocate(RHO1_ACC(NXYZ,MXBND),RHO2_ACC(NXYZ,MXBND))
       allocate(RHO3_ACC(NXYZ))
!$acc enter data create(RHO1_ACC(1:NXYZ,1:MXBND),
!$acc& RHO2_ACC(1:NXYZ,1:MXBND),RHO3_ACC(1:NXYZ))
       FIRST=.FALSE.
      endif
C
!$acc data present(COEF(1:NG2Q,1:MXBND),
!$acc& RHO1_ACC(1:NXYZ,1:MXBND),
!$acc& RHO2_ACC(1:NXYZ,1:MXBND),RHO3_ACC(1:NXYZ),
!$acc& J2G(1:NG2Q),OCC(1:NBNDQ))
!$acc parallel loop collapse(2)
!$acc& present(RHO2_ACC(1:NXYZ,1:MXBND))
      do iib=1,nbndloc
       do i=1,NXYZ
        RHO2_ACC(i,iib)=(0.D0,0.D0)
       enddo
      enddo
C
!$acc parallel loop
!$acc& present(COEF(1:NG2Q,1:MXBND),J2G(1:NG2Q),
!$acc& RHO2_ACC(1:NXYZ,1:MXBND)) private(i,iib,ii)
      do idx=1,NXYZ*nbndloc
       i=mod(idx-1,NXYZ)+1
       iib=(idx-1)/NXYZ+1
       ii=J2G(i)
       RHO2_ACC(ii,iib)=COEF(i,iib)
      enddo
C
      CALL FFT3BX_fftwASL_ACC_BATCH(NRX,NRY,NRZ,NXYZ,nbndloc,
     &             RHO2_ACC,RHO1_ACC,plancfp,plancbp)
C
!$acc parallel loop collapse(2)
!$acc& present(RHO2_ACC(1:NXYZ,1:MXBND))
      do iib=1,nbndloc
       do i=1,NXYZ
        RHO2_ACC(i,iib)=DCONJG(RHO2_ACC(i,iib))*RHO2_ACC(i,iib)
       enddo
      enddo
C
!$acc parallel loop gang vector
!$acc& present(RHO2_ACC(1:NXYZ,1:MXBND),
!$acc& RHO3_ACC(1:NXYZ),OCC(1:NBNDQ))
      do i=1,NXYZ
       RHO3_ACC(i)=(0.D0,0.D0)
!$acc loop seq
       do iib=1,nbndloc
        RHO3_ACC(i)=RHO3_ACC(i)+RHO2_ACC(i,iib)
     &              *OCC(ibfirst+iib-1)
       enddo
      enddo
!$acc update self(RHO3_ACC(1:NXYZ))
!$acc end data
C
      do i=1,NXYZ
       RHO3(i)=RHO3_ACC(i)
       RHO2(i)=(0.D0,0.D0)
      enddo
C
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) call clock(t00)
      endif
      call MPI_ALLReduce(RHO3,RHO1,NXYZ,MPI_DOUBLE_COMPLEX,
     &    MPI_SUM,MPI_COMM_WORLD,ierr)
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) then
        call clock(t01)
        write(6,*)' MPI_ALLReduce for total charge took ',t01-t00,
     &             ' sec'
       endif
      endif
C
      FWGT=WGT*2.D0
      DO I=1,NXYZ
       RHO(I)=RHO(I)+DBLE(RHO1(I))*FWGT
      ENDDO
C
      RETURN
      END
c
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
c *** for Sugino FFT
c     &         VINT,nbseq, OMEGA, WSAVEX, WSAVEY, WSAVEZ,
c     &                   IFACX, IFACY, IFACZ, LX1, LX2,
c     &                   LY1, LY2, LZ1, LZ2   ,itstep,itmod       )
c *** for Kokubo ASL FFT
c     &         VINT,nbseq, OMEGA, WSAVE_XYZ,IFAC_XYZ,itstep,itmod )
c *** for Kokubo FFTW
     &         VINT,nbseq, OMEGA, plancfp,plancbp,itstep,itmod
c
     &   ,nbegin,nend,ncpuq)
C
      IMPLICIT REAL*8 (A-H,O-Z)
      include 'mpif.h'
      COMPLEX*16 RHO1(NXYZ),RHO3(NXYZ),P(NG2Q,MXBND)
      DIMENSION RHO(NXYZ),RHO2(NXYZ),J2G(NG2Q)
c ** for Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c ** for Kokubo ASL FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c      DIMENSION IFAC_XYZ(60)
c ** for Kokubo  FFTW
      integer*8 plancfp,plancbp
      DIMENSION IOWF(MBLK)
      PARAMETER (IRLATQ=144,NAS=72)
      DIMENSION RCOSIN(NAS,IRLATQ),VINT(NBNDQ,IRLATQ),NSY(IRLATQ)
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c ** temp check
      miya=13
      if (miya.eq.13) then
       write(6,*)'my_rank=',my_rank,' just in SUMCHR'
      stop
      endif
c ** temp check : end
C
      YMFAC=1.D0/DBLE(NKMESH)
c *** sum with respect to new band indecis which skip empty bands
ccc ***        if ( my_rank.ne.0 ) then
c        do ib=1,nbseq
        do ib=nbegin(my_rank),nend(my_rank)
         iib=ib-nbegin(my_rank)+1
          DO 20 JG=1,NXYZ
   20     RHO1(JG)=0.D0
c          DO 21 IG=1,NG2
*VDIR NODEP(RHO1)
!ocl norecurrence(RHO1)
          DO 21 IG=1,NXYZ
          JG=J2G(IG)
          RHO1(JG)=P(IG,IIB)
   21     CONTINUE
c ** for Sugino FFT
c          CALL FFT3BX( NRX, NRY, NRZ, NXYZ, RHO1, RHO3,
c     &                 WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                 LX1, LX2, LY1, LY2, LZ1, LZ2                )
c ** for Kokubo ASL FFT
c          CALL FFT3BX_ASL( NRX, NRY, NRZ, NXYZ, RHO1, RHO3,
c     &                 WSAVE_XYZ, IFAC_XYZ            )
c ++ for Kokubo FFTW
c          call FFT3BX_fftw(NXYZ,RHO1,plancfp,plancbp)
c ** for Kokubo fftw ASL compatible
          CALL FFT3BX_fftwASL( NRX, NRY, NRZ, NXYZ, RHO1, RHO3,
     &                 plancfp,plancbp          )
          DO 30 JG=1,NXYZ
   30     RHO2(JG)=DBLE(DCONJG(RHO1(JG))*RHO1(JG))
          do ig=1,nxyz
           rho1(ig)=0.0d0
           rho3(ig)=0.0d0
          enddo
          DO 40 I=1,NEXPND
cc          FAC=2.D0*RCOSIN(IK,I)*YMFAC*VINT(KBND,I)*DBLE(NSY(I))/OMEGA
          FAC=2.D0*RCOSIN(IK,I)*YMFAC*VINT(IB,I)*DBLE(NSY(I))/OMEGA
            DO 50 JG=1,NXYZ
c   50       RHO(JG)=RHO(JG)+FAC*RHO2(JG)
   50       RHO3(JG)=RHO3(JG)+FAC*RHO2(JG)
   40     CONTINUE
        enddo  ! end of ib loop
ccc ***        endif  ! if my_rank.ne.0 loop: end
      do ig=1,nxyz
       rho1(ig)=0.0d0
      enddo
c *** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) call clock(t00)
      endif
c *** temp check : end
      call MPI_Reduce(rho3,rho1,nxyz,MPI_DOUBLE_COMPLEX
     & ,MPI_SUM,0,MPI_COMM_WORLD,ierr)
c *** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) then
        call clock(t01)
        write(6,*)' Redude the charge took ',t01-t00,' sec'
       endif
      endif
c *** temp check : end
c      call MPI_Barrier(MPI_COMM_WORLD,ierr)
c *** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) call clock(t00)
      endif
c *** temp check : end
      call MPI_Bcast(rho1,nxyz,MPI_DOUBLE_COMPLEX,
     &    0,MPI_COMM_WORLD,ierr)
c *** temp check
      if ( itstep.eq.itmod ) then
       if ( my_rank.eq.0 ) then
        call clock(t01)
        write(6,*)' Bcast of total charge took ',t01-t00,' sec'
       endif
      endif
c *** temp check : end
c   12   CONTINUE
c   10 CONTINUE
C
  100 CONTINUE
      RETURN
      END
c
c
      subroutine vgconv(VG,VGOLD,NXYZ,TR2,RDIF,IOK)
      implicit double precision(a-h,o-z)
c      complex*16 VG(NXYZ),VGOLD(NXYZ)
      dimension VG(NXYZ),VGOLD(NXYZ)
      RDIF=0
      do 1 ig=1,nxyz
c      sss=abs(  ( VG(IG)-VGOLD(IG) ) ) 
      sss=VG(IG)-VGOLD(IG) 
      RDIF=RDIF+sss**2
    1 continue
c      RDIF=RDIF/dfloat(NXYZ) !
      if (RDIF.lt.TR2) then
       IOK=1
      else
       IOK=0
      endif
      return
      end
c
      subroutine coefcp(a,b,n)
      complex*16 a(n),b(n)
      do 1 i=1,n
    1 b(i)=a(i)
      return
      end
c
c      subroutine ortho2(mxbnd,ng2q,coef0,coef,nbnd,ng2,
c     &           sig,x0,x1,work1,work20) 
c      implicit double precision(a-h,o-z)
c ***  work area for orthogonization
c      complex*16  sig(mxbnd,mxbnd),x0(mxbnd,mxbnd),
c     & x1(mxbnd,mxbnd),work1(mxbnd,mxbnd),work20(mxbnd,mxbnd)
c      complex*16 coef(ng2q,mxbnd),coef0(ng2q,mxbnd)
c      call ortho(mxbnd,ng2q,coef0,coef,nbnd,ng2,
c     &           sig,x0,x1,work1,work20)
c      return
c      end
       subroutine extvgen(a3v,a4v,b3v,b4v,pf,pi)
       implicit double precision(a-h,o-z)
       w=1.d0/(pf-pi)
       a3v=(        pf**3-       pi**3 ) * w
       a4v=(        pf**4-       pi**4 ) * w
       b3v=( (pf+1.d0)**3-(pi+1.d0)**3 ) * w
       b4v=( (pf+1.d0)**4-(pi+1.d0)**4 ) * w
       return
       end
c
       subroutine intvgen(a3v,a4v,b3v,b4v,pf,pi)
       implicit double precision(a-h,o-z)
       w=1.d0/(pf-pi)
       a3v=( (pf-1.d0)**3-(pi-1.d0)**3 ) * w
       a4v=( (pf-1.d0)**4-(pi-1.d0)**4 ) * w
       b3v=(        pf**3-      pi**3  ) * w
       b4v=(        pf**4-      pi**4  ) * w
       return
       end
      subroutine vlocgen(Vloc,rho4,nxyz,VEXT,ft)
      implicit double precision (a-h,o-z)
      dimension Vloc(NXYZ)
      complex*16 rho4(NXYZ),VEXT(NXYZ)
      do ig=1,nxyz
      Vloc(ig)=dreal( rho4(ig) +ft*Vext(ig) )
      enddo
      return
      end
c
      subroutine Efieldgen(VG,nrx,nry,nrz,nxyz,Efieldp,Efieldm)
      implicit double precision (a-h,o-z)
      COMMON /AVEC/  A1(3), A2(3), A3(3), B1(3), B2(3), B3(3)
     &             , COVA, ALAT
      complex*16 VG(nxyz)
c **** local array VGZ
      parameter(NRZZ=1000)
      dimension VGZ(NRZZ)
      if (NRZZ.LT.NRZ) then
       write(6,*)' in sub: Efieldgen, NRZZ is smaller than ',NRZ
       stop
      endif
      fac=13.6d0*2/0.529177d0
c
c *** compute averaged E-field at particular hight (z)
      zleng=a3(3)
c      zlenghlf=zleng*0.5d0
      zlenghlf=zleng*0.005d0 ! just cheat this value
      dz=zleng/dfloat(nrz)
      NRZhlf=(NRZ+1)/2
      do iz=1,NRZ
       VGZ(iz)=0
      enddo
      do ii=1,nxyz
       K=1+(II-1)/(NRX*NRY)
       I=II-(K-1)*NRX*NRY
       J=1+(I-1)/NRX
       I=I-(J-1)*NRX
       LX=I
       LY=J
       LZ=K
       VGZ(LZ)=VGZ(LZ)+dreal( VG(II) )
      enddo
      do iz=1,nrz
       VGZ(iz)=VGZ(iz)/dfloat(NRX*NRY)
      enddo
c +++ compute E-field by numerical derivative of VGZ
      do iz=1,NRZhlf 
       z=dz*(iz-1)
       if ( z.ge.zlenghlf ) then
        izmark=iz
        goto 100
       endif
      enddo
  100 continue
      Efieldp=( VGZ(izmark)-VGZ(izmark-1) )/dz*fac
      do iz=NRZhlf+1,NRZ 
       z=dz*(iz-1)-zleng
       if ( z.ge.-zlenghlf ) then
        izmark=iz
        goto 200
       endif
      enddo
  200 continue
      Efieldm=( VGZ(izmark)-VGZ(izmark-1) )/dz*fac
      return
      end
c

      subroutine Efield(Vplt,nrx,nry,nrz,nxyz,time,iwt)
c ****
c  This subroutine is not practically used
c ****
      implicit double precision (a-h,o-z)
      COMMON /AVEC/  A1(3), A2(3), A3(3), B1(3), B2(3), B3(3)
     &             , COVA, ALAT
      dimension Vplt(nxyz)
      parameter (nzlocal=1000)
      dimension Vz1(nzlocal),Vz2(nzlocal)  ! local dimension
      do izlocal=1,nzlocal
       Vz1(izlocal)=0
       Vz2(izlocal)=0
      enddo
c
      if (nzlocal.lt.nrz ) then
       write(6,*)' in sub. Efield, nzlocal < ',nrz
      stop
      endif
c
      axlen=A1(1)
      aylen=A2(2)
      azlen=A3(3)
      nxhlf=(nrx+1)/2
      nyhlf=(nry+1)/2
      nzhlf=(nrz+1)/2
      dx=axlen/dfloat(nrx)*0.529177d0  ! in angstrom
      dy=aylen/dfloat(nry)*0.529177d0  ! in angstrom
      dz=azlen/dfloat(nrz)*0.529177d0  ! in angstrom
c *** temp check;
c      write(6,*)' in sub. Efield: dx = ',dx
c      write(6,*)' in sub. Efield: dy = ',dy
c      write(6,*)' in sub. Efield: dz = ',dz
c      write(6,*)' in sub. Efield: nxhlf = ',nxhlf
c      write(6,*)' in sub. Efield: nyhlf = ',nyhlf
c      write(6,*)' in sub. Efield: nzhlf = ',nzhlf
c === temp check end
c
      do ii=1,nxyz
       K=1+(II-1)/(NRX*NRY)
       I=II-(K-1)*NRX*NRY
       J=1+(I-1)/NRX
       I=I-(J-1)*NRX
       LX=I
       LY=J
       LZ=K
       if (LX.eq.1 ) then
        Vz1(LZ)=Vz1(LZ)+Vplt(II)   ! on graphene
       endif
       if (LX.eq.nxhlf) then
        Vz2(LZ)=Vz2(LZ)+Vplt(II)  ! between graphene
       endif
      enddo
c
      fac=13.6d0*2
      do iz=1,nrz
      Vz1(iz)=fac*Vz1(iz)/dfloat(nry)
      Vz2(iz)=fac*Vz2(iz)/dfloat(nry)
      enddo
cc
c ** E-field at x=0 z= 3.34 A + H atom height =9.212 A
cc      nrzp=85  ! int( 7.948/(dz) )
c ** E-field at x=0 z= 3.34 A + H atom height =9.212 A
      nrzp=nrz/2  ! int( 7.948/(dz) )
c *** temp check
c      write(6,*)' in sub. Efield: Vz1(nrzp)=',Vz1(nrzp)
c *** temp check: end
      Ezp=( Vz1(nrzp+1)-Vz1(nrzp-1) )/(2*dz)
c ** E-field at x=0 z=-3.34 A - H atom height =-9.212 A
c      nrzm=nrz+1-nrzp
      nrzm=nrz+1-(nrzp-1)
c *** temp check
c      write(6,*)' in sub. Efield: Vz1(nrzm)=',Vz1(nrzm)
c *** temp check: end
      Ezm=( Vz1(nrzm+1)-Vz1(nrzm-1) )/(2*dz)
c ** E-field at x=3.34A z=0 A
c *** temp check
c      write(6,*)' in sub. Efield: Vz2(1)=',Vz2(1)
c *** temp check: end
      Ez2=( Vz2(2) - Vz2(nrz) )/(2*dz)  ! V/angstrom
c
c *** temp check
c      write(6,*)' in sub. Efield: time(fs)=',time
c *** temp check: end
      write(iwt,1000)time,Ezp,Ezm,Ez2
 1000 format(4f22.16)
      return
      end
c
      subroutine Part1to5(NG2Q,G21,G22,G23,G24,G25,G2
     &    ,YLM1,YLM2,YLM3,YLM4,YLM5
     &    ,VPJ1,VPJ2,VPJ3,VPJ4,VPJ5,VPJWORK
     &    ,VPP21,VPP22,VPP23,VPP24,VPP25,NGNLMX
     &    ,RHO3,TPIBA,NTYQ,NTYPE,GMHF,MXOFL
     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
c
     &    ,mshbegin,mshend,ncpuq )
      implicit double precision (a-h,o-z)
      dimension RHO3(NG2Q)
      dimension G21(4,NG2Q),G22(4,NG2Q),G23(4,NG2Q),G24(4,NG2Q),
     &          G25(4,NG2Q),G2(4,NG2Q)
      dimension VPJWORK(NGcont,3) ! for parallel mesh intg
      dimension VPJ1(NGcont,3,4,NTYQ),VPJ2(NGcont,3,4,NTYQ)
     &         ,VPJ3(NGcont,3,4,NTYQ),VPJ4(NGcont,3,4,NTYQ)
     &         ,VPJ5(NGcont,3,4,NTYQ)
      dimension RAD(MESHQ,NTYQ),PSPOT(MESHQ,ISPD,NTYQ),
     &    PSPOT2(MESHQ,ISPD,NTYQ),PHIL(MESHQ,4,NTYQ),NGNL(NTYQ)
      dimension VPP21(16,3,NTYQ),VPP22(16,3,NTYQ)
     &        ,VPP23(16,3,NTYQ),VPP24(16,3,NTYQ),VPP25(16,3,NTYQ)
c *** for P-A formalisms
      dimension YLM1(NGcont,16),YLM2(NGcont,16),YLM3(NGcont,16),
     &          YLM4(NGcont,16),YLM5(NGcont,16)
c
      dimension mshbegin(0:ncpuq),mshend(0:ncpuq)
c
c  temp check
c      do icpu=0,ncpuq
c       write(6,*)' in Part1to5 icpu mshbegin mshend=',
c     &     icpu,mshbegin(icpu),mshend(icpu)
c      enddo
c  temp check : end
c *** for P-A
c  note TIMEV calls GG2, YLM, VPJ, VPP2
c
!$acc data copyin(G21(1:4,1:NGcont),G22(1:4,1:NGcont),
!$acc& G23(1:4,1:NGcont),G24(1:4,1:NGcont),G25(1:4,1:NGcont))
!$acc& present(RAD(1:MESHQ,1:NTYQ),
!$acc& PSPOT(1:MESHQ,1:ISPD,1:NTYQ),
!$acc& PSPOT2(1:MESHQ,1:ISPD,1:NTYQ),
!$acc& PHIL(1:MESHQ,1:4,1:NTYQ))
!$acc& create(VPJWORK(1:NGcont,1:3))
c     *** part 1 ***
      do ig=1,NGcont
       GX=G21(1,IG)
       GY=G21(2,IG)
       GZ=G21(3,IG)
       RHO3(IG)=DSQRT(G21(4,IG))*TPIBA
      enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(49)
#endif
      CALL GETYLM(NG2Q,NGNLMX,G21,RHO3,YLM1,TPIBA,NGcont)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(49)
#endif
      CALL VPJ_GEN(G2,G21,NG2Q,NG2,RHO3,VPJ1
     &         ,VPJWORK,VPP21,
     &          TPIBA,NTYQ,ntype,GMHF,MXOFL
     & ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
     & ,mshbegin,mshend,ncpuq,1,1 )
#else
     & ,mshbegin,mshend,ncpuq,1 )
#endif
c
c     *** part 2 ***
      do ig=1,NGcont
       GX=G22(1,IG)
       GY=G22(2,IG)
       GZ=G22(3,IG)
       RHO3(IG)=DSQRT(G22(4,IG))*TPIBA
      enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(49)
#endif
      CALL GETYLM(NG2Q,NGNLMX,G22,RHO3,YLM2,TPIBA,NGcont)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(49)
#endif
      CALL VPJ_GEN(G2,G22,NG2Q,NG2,RHO3,VPJ2
     &         ,VPJWORK,VPP22,
     &          TPIBA,NTYQ,ntype,GMHF,MXOFL
     & ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
     & ,mshbegin,mshend,ncpuq,1,1 )
#else
     & ,mshbegin,mshend,ncpuq,1 )
#endif
c
c     *** part 3 ***
      do ig=1,NGcont
       GX=G23(1,IG)
       GY=G23(2,IG)
       GZ=G23(3,IG)
       RHO3(IG)=DSQRT(G23(4,IG))*TPIBA
      enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(49)
#endif
      CALL GETYLM(NG2Q,NGNLMX,G23,RHO3,YLM3,TPIBA,NGcont)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(49)
#endif
      CALL VPJ_GEN(G2,G23,NG2Q,NG2,RHO3,VPJ3
     &         ,VPJWORK,VPP23,
     &          TPIBA,NTYQ,ntype,GMHF,MXOFL
     & ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
     & ,mshbegin,mshend,ncpuq,1,1 )
#else
     & ,mshbegin,mshend,ncpuq,1 )
#endif
c
c     *** part 4 ***
      do ig=1,NGcont
       GX=G24(1,IG)
       GY=G24(2,IG)
       GZ=G24(3,IG)
       RHO3(IG)=DSQRT(G24(4,IG))*TPIBA
      enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(49)
#endif
      CALL GETYLM(NG2Q,NGNLMX,G24,RHO3,YLM4,TPIBA,NGcont)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(49)
#endif
      CALL VPJ_GEN(G2,G24,NG2Q,NG2,RHO3,VPJ4
     &         ,VPJWORK,VPP24,
     &          TPIBA,NTYQ,ntype,GMHF,MXOFL
     & ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
     & ,mshbegin,mshend,ncpuq,1,1 )
#else
     & ,mshbegin,mshend,ncpuq,1 )
#endif
c
c     *** part 5 ***
      do ig=1,NGcont
       GX=G25(1,IG)
       GY=G25(2,IG)
       GZ=G25(3,IG)
       RHO3(IG)=DSQRT(G25(4,IG))*TPIBA
      enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(49)
#endif
      CALL GETYLM(NG2Q,NGNLMX,G25,RHO3,YLM5,TPIBA,NGcont)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(49)
#endif
      CALL VPJ_GEN(G2,G25,NG2Q,NG2,RHO3,VPJ5
     &         ,VPJWORK,VPP25,
     &          TPIBA,NTYQ,ntype,GMHF,MXOFL
     & ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
     & ,mshbegin,mshend,ncpuq,1,1 )
#else
     & ,mshbegin,mshend,ncpuq,1 )
#endif
c
!$acc end data
      return
      end
