C------------PROGRAM UNIT TMEVL-------------------------
C********************************************************
c  Time evolution of the wavefunction: P --> P:restored
c    using Suzuki-Trotter expansion of exp( -i/h * H * dt )
c
C                                (1990-11-28) OSAMU SUGINO
C          TO ADAPT YAMAUCHI PRG (1992-04-27) OSAMU SUGINO
C                NOTE THAT NBNDQ=NBND
C
C          TMEVL--1
C                 --HLOCAL
C                 1
C                 --NONLOC
C**************************************************************
      SUBROUTINE TMEVL(itstep, OSHI,ITCF,NRX,NRY,NRZ,NXYZ,NG2,NG2Q,
c     &               NBNDQ,NBSEQ, NBND, P, HP, PJ,
     &               NBNDQ,NBSEQ, NBND, P, HP, 
     &                   YLM, G2, RHO1, RHO2, RHO3,
c     &                   TPIBA, VG, J2G, WORK2, OUT, VPJ,
     &   TPIBA, VG,VG1,VG2,VG3,VG4,VG5, J2G, WORK2, OUT, VPJ,
c
     &                   VPP,
     &                   IOWF, IOVP, MXBND, MBLK,
     &                   OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &                   NIDN, EE, WSAVEX, WSAVEY, WSAVEZ, IFACX,
c     &                   IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
c *** for Kokubo ASL FFT
c     &                   NIDN, EE, WSAVE_XYZ, IFAC_XYZ,
c *** for Kokubo FFTW
     &                   NIDN, EE, plancfp,plancbp,
c
     &    MXOFL,dt,IK,NUMK,VPP2,EXTAU
     &   ,GDUMP
     &   ,GMHF,fdump,Vloc,NGNL
c *** for P-A formalism
     &         ,YLM1,YLM2,YLM3,YLM4,YLM5,GG2,G21,G22,G23,G24,G25,
c +++++ for P-A VPJ is updated
     &   VPJWORK,VPJ1,VPJ2,VPJ3,VPJ4,VPJ5
c ++++ P-A  
     &   ,VPP21,VPP22,VPP23,VPP24,VPP25
c  +++ for A-vector GDUMP1 to GDUMP5  
     &   ,GDUMP1,GDUMP2,GDUMP3,GDUMP4,GDUMP5
     &   ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD
c
     &   ,NGcont
c
     &   ,nbegin,nend,mshbegin,mshend,ncpuq,ncpu )
C
      IMPLICIT REAL*8(A-H,O-Z)
      include 'mpif.h'
c      parameter ( ncpuq=30 )
c      include 'ncpuq.h'
      COMPLEX*16  P(NG2Q,MXBND), HP(NG2Q,1)
c      COMPLEX*16  P(NG2Q,MXBND), HP(NG2Q,3)
c     &            PJ(NG2Q,MXBND)
      DIMENSION IOWF(MBLK),IOVP(2,NTYQ)
C
c      REAL*8 YLM(NG2Q,4),OUT(NBNDQ,3),EE(NBNDQ)
c      REAL*8 YLM(NG2Q,9),OUT(NBNDQ,3),EE(NBNDQ)
      REAL*8 YLM(NGcont,16),OUT(NBNDQ,3),EE(NBNDQ)
c *** for P-A formalisms
      dimension YLM1(NGcont,16),YLM2(NGcont,16),YLM3(NGcont,16),
     &          YLM4(NGcont,16),YLM5(NGcont,16)
c
c      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3)
c     &           VG(NXYZ),WORK2(NG2Q,5)
     &           VG(NXYZ),WORK2(NG2Q,7)
c     & VG(NXYZ),VG1(NXYZ),VG2(NXYZ),VG3(NXYZ),VG4(NXYZ),
c     & VG5(NXYZ),WORK2(NG2Q,3)
      dimension VG1(NXYZ),VG2(NXYZ),VG3(NXYZ),VG4(NXYZ),
     & VG5(NXYZ)
c ***  attention !!
c      COMPLEX*16 EXTAU(NXYZ,NTAUQ)
c      COMPLEX*16 EXTAU(NXYZ,NTAUQ,5)
c      COMPLEX*16 EXTAU(NXYZ/6,NTAUQ,5)
      COMPLEX*16 EXTAU(NGcont,5,NTAUQ)
c *** for Sugino FFT
c      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
c *** for Kokubo ASL FFT
c      COMPLEX*16 WSAVE_XYZ(NRX+NRY+NRZ)
c *** for Kokubo FFTW
      integer*8 plancfp,plancbp
      DIMENSION RHO3(NXYZ)
c ** for Sugino FFT
c      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
c      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
c     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
c ** for Kokubo ASL FFT
c      DIMENSION IFAC_XYZ(60)
c ** for Kokubo FFTW -- nothing is needed for IFAC
      DIMENSION J2G(NG2Q),G2(4,NG2Q),GDUMP(NG2Q)
c +++ for P-A formalisms
      DIMENSION GG2(4,NG2Q)
      DIMENSION G21(4,NG2Q),G22(4,NG2Q),G23(4,NG2Q),
     &          G24(4,NG2Q),G25(4,NG2Q)
c +++ for A-vec GDUMP1 to GDUMP5
      DIMENSION GDUMP1(NG2Q),GDUMP2(NG2Q),GDUMP3(NG2Q)
     &         ,GDUMP4(NG2Q),GDUMP5(NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ)
c +++ for P-A VPJ is updated!! 
      dimension VPJWORK(NGcont,3),
     &          VPJ1(NGcont,3,4,NTYQ),VPJ2(NGcont,3,4,NTYQ),
     &          VPJ3(NGcont,3,4,NTYQ),VPJ4(NGcont,3,4,NTYQ),
     &          VPJ5(NGcont,3,4,NTYQ)
c
      dimension RAD(MESHQ,NTYQ),PSPOT(MESHQ,ISPD,NTYQ),
     &    PSPOT2(MESHQ,ISPD,NTYQ),PHIL(MESHQ,4,NTYQ)
c
c      dimension VPP2(4,3,NTYQ)
c      dimension VPP2(9,3,NTYQ)
      dimension VPP2(16,3,NTYQ)
c +++ for P-A +++
     &  ,VPP21(16,3,NTYQ),VPP22(16,3,NTYQ),VPP23(16,3,NTYQ)
     &  ,VPP24(16,3,NTYQ),VPP25(16,3,NTYQ)
      dimension fdump(NXYZ)
c      complex*16 RHO4(NXYZ)  ! but used as real
      dimension Vloc(NXYZ,5)
      dimension NGNL(NTYQ)
C
      complex*16 dtex,cone
C
      integer tag,status(MPI_STATUS_SIZE)
c
      common/tmod/itmod
      common/Suzuki/ioption
c      common/cputask/nbegin(0:ncpuq),nend(0:ncpuq),ncpu
      dimension nbegin(0:ncpuq),nend(0:ncpuq)
      dimension mshbegin(0:ncpuq),mshend(0:ncpuq)
      logical VPJGENdo
      common/ExtDyn/VPJGENdo
c
c ***  temp check
c      write(6,*)' in sub. VG in real space '
c      write(6,*)( VG(ig),ig=1,1500,100 )
c ***  temp check : end
c      ioption=2     ! choise of second order decomposition
c      ioption=3     ! choise of 4-th order decomposition ver.1
c      ioption=4     ! choise of 4-th order decomposition ver.2
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      call prof_start(8)
c
c  *** temp check
c      if (my_rank.eq.0) then
c       write(6,*)' GDUMP '
c       write(6,'(4F22.16)')( GDUMP(IG),IG=1,NXYZ,50000)
c       write(6,*)' GDUMP1'
c       write(6,'(4F22.16)')( GDUMP1(IG),IG=1,NXYZ,50000)
c       write(6,*)' GDUMP2'
c       write(6,'(4F22.16)')( GDUMP2(IG),IG=1,NXYZ,50000)
c       write(6,*)' GDUMP3'
c       write(6,'(4F22.16)')( GDUMP3(IG),IG=1,NXYZ,50000)
c       write(6,*)' GDUMP4'
c       write(6,'(4F22.16)')( GDUMP4(IG),IG=1,NXYZ,50000)
c       write(6,*)' GDUMP5'
c      endif
c
      cone=dcmplx( 0.d0, 1.d0)
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
C
      if ( MBLK.ne.1 ) then
      if ( my_rank.eq.0 ) write(6,*) 'in sub. TMEVL:  MBLK = ',MBLK
      stop
      endif
c 
c      NJ=MXBND
      NJ=NBSEQ
c
         DO 588 IG=1,NG2
c         DO 588 IG=1,NXYZ
          GX=GG2(1,IG)
          GY=GG2(2,IG)
          GZ=GG2(3,IG)
  588    RHO3(IG)=DSQRT(GG2(4,IG))*TPIBA
c
c +++++++++
         NGNLMX=1
         do ity=1,NTYPE
          NGNLMX=MAX(NGNL(ity),NGNLMX)
         enddo
c +++++++++ now GG2 depends P-A, thus YLM VPJ VPP2 are, too
c         CALL GETYLM(NG2Q,NG2,G2,RHO3,YLM,TPIBA)
         CALL GETYLM(NG2Q,NGNLMX,GG2,RHO3,YLM,TPIBA,NGcont)
         if (VPJGENdo) then
         CALL VPJ_GEN(G2,GG2,NG2Q,NG2,RHO3,VPJ,VPJWORK,VPP2,
     &    TPIBA,NTYQ,ntype,GMHF,MXOFL
     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
     &    ,mshbegin,mshend,ncpuq,0,0 )
#else
     &    ,mshbegin,mshend,ncpuq,0 )
#endif
         endif
c *** temp check
c         if (my_rank.eq.0) then
c           write(6,*)' after DO 588 VPJ_GEN ended'
c           do ity=1,NTYPE
c           write(6,*)' ity = ',ity
c           write(6,'(4F22.16)')(VPJ(IG,1,1,ity),IG=1,NGNL(ITY),1000)
c           enddo
c         endif
c *** temp check end
c *** for P-A
c     *** part 1 ***
c         do ig=1,NG2Q/6
c          GX=G21(1,IG)
c          GY=G21(2,IG)
c          GZ=G21(3,IG)
c          RHO3(IG)=DSQRT(G21(4,IG))*TPIBA
c         enddo
c         CALL GETYLM(NG2Q,NGNLMX,G21,RHO3,YLM1,TPIBA)
c         CALL VPJ_GEN(G21,NG2Q,NG2,RHO3,VPJ1,VPJWORK,VPP21,
c     &               TPIBA,NTYQ,ntype,GMHF,MXOFL
c     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA)
c *** temp check
c         if (my_rank.eq.0) then
c           write(6,*)' part 1   VPJ_GEN ended'
c           do ity=1,NTYPE
c           write(6,*)' ity = ',ity
c           write(6,'(4F22.16)')(VPJ1(IG,1,1,ity),IG=1,NGNL(ITY),1000)
c           enddo
c         endif
c *** temp check end
c     *** part 2 ***
c         do ig=1,NG2Q/6
c          GX=G22(1,IG)
c          GY=G22(2,IG)
c          GZ=G22(3,IG)
c          RHO3(IG)=DSQRT(G22(4,IG))*TPIBA
c         enddo
c         CALL GETYLM(NG2Q,NGNLMX,G22,RHO3,YLM2,TPIBA)
c         CALL VPJ_GEN(G22,NG2Q,NG2,RHO3,VPJ2,VPJWORK,VPP22,
c     &               TPIBA,NTYQ,ntype,GMHF,MXOFL
c     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA)
c *** temp check
c         if (my_rank.eq.0) then
c           do ity=1,NTYPE
c           write(6,*)' ity = ',ity
c           write(6,*)' part 2   VPJ_GEN ended'
c           write(6,'(4F22.16)')(VPJ2(IG,1,1,ity),IG=1,NGNL(ITY),1000)
c           enddo
c         endif
c *** temp check end
c     *** part 3 ***
c         do ig=1,NG2Q/6
c          GX=G23(1,IG)
c          GY=G23(2,IG)
c          GZ=G23(3,IG)
c          RHO3(IG)=DSQRT(G23(4,IG))*TPIBA
c         enddo
c         CALL GETYLM(NG2Q,NGNLMX,G23,RHO3,YLM3,TPIBA)
c         CALL VPJ_GEN(G23,NG2Q,NG2,RHO3,VPJ3,VPJWORK,VPP23,
c     &               TPIBA,NTYQ,ntype,GMHF,MXOFL
c     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA)
c *** temp check
c         if (my_rank.eq.0) then
c           do ity=1,NTYPE
c           write(6,*)' ity = ',ity
c           write(6,*)' part 3   VPJ_GEN ended'
c           write(6,'(4F22.16)')(VPJ3(IG,1,1,ity),IG=1,NGNL(ITY),1000)
c           enddo
c         endif
c *** temp check end
c     *** part 4 ***
c         do ig=1,NG2Q/6
c          GX=G24(1,IG)
c          GY=G24(2,IG)
c          GZ=G24(3,IG)
c          RHO3(IG)=DSQRT(G24(4,IG))*TPIBA
c         enddo
c         CALL GETYLM(NG2Q,NGNLMX,G24,RHO3,YLM4,TPIBA)
c         CALL VPJ_GEN(G24,NG2Q,NG2,RHO3,VPJ4,VPJWORK,VPP24,
c     &               TPIBA,NTYQ,ntype,GMHF,MXOFL
c     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA)
c *** temp check
c         if (my_rank.eq.0) then
c           do ity=1,NTYPE
c           write(6,*)' ity = ',ity
c           write(6,*)' part 4   VPJ_GEN ended'
c           write(6,'(4F22.16)')(VPJ4(IG,1,1,ity),IG=1,NGNL(ITY),1000)
c           enddo
c         endif
c *** temp check end
c     *** part 5 ***
c         do ig=1,NG2Q/6
c          GX=G25(1,IG)
c          GY=G25(2,IG)
c          GZ=G25(3,IG)
c          RHO3(IG)=DSQRT(G25(4,IG))*TPIBA
c         enddo
c         CALL GETYLM(NG2Q,NGNLMX,G25,RHO3,YLM5,TPIBA)
c         CALL VPJ_GEN(G25,NG2Q,NG2,RHO3,VPJ5,VPJWORK,VPP25,
c     &               TPIBA,NTYQ,ntype,GMHF,MXOFL
c     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISDP,NGNL,OMEGA)
c *** temp check
c         if (my_rank.eq.0) then
c           write(6,*)' part 5   VPJ_GEN ended'
c           do ity=1,NTYPE
c           write(6,*)' ity = ',ity
c           write(6,'(4F22.16)')(VPJ5(IG,1,1,ity),IG=1,NGNL(ITY),1000)
c           enddo
c         endif
c *** temp check end
c
c
c ****  Suzuki-Trotter decomposition of time-evolution operator
c
      if ( ioption.eq.2 ) then
c ***********************************************************
c *    Masuo Suzuki
c *     create second order decomposition
c ***********************************************************
c      do ib=1,nj
cc **      if ( my_rank.ne.0 ) then
      do ib=nbegin(my_rank),nend(my_rank)
      iib=ib-nbegin(my_rank)+1
c      call exkin(dt,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
      call exkin(dt,nxyz,ng2q,P(1,iib),G2,TPIBA2,GDUMP,GMHF)
c
      call S2(dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     & P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     & IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2,VG,VG3,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,IFAC_XYZ,VG,VG3,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG3,
     & fdump,Vloc(1,3),EXTAU(1,1,1),3,NGNL,NGcont)
C
c      call exkin(dt,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
      call exkin(dt,nxyz,ng2q,P(1,iib),G2,TPIBA2,GDUMP,GMHF)
      enddo   ! end of band loop
cc **      endif ! end of if my_rank.e.0 loop
      elseif ( ioption.eq.3 ) then 
c ***********************************************************
c *    Masuo Suzuki ( J. Phys. Soc. Jpn. Vol.61, p3015, '92)
c *     create fourth-order decomposition
c *       from first-order decompositions
c ***********************************************************
c    parameters for third order decomposition
       pr1= 0.2683300957817599D0
       pr2= 0.6513314272356399d0
       pr3=-0.8393230460347997d0
c      do ib=1,nbseq ! band loop
cc ***      if ( my_rank.ne.0 ) then
      do ib=nbegin(my_rank),nend(my_rank) ! band loop
       iib=ib-nbegin(my_rank)+1
c
c    At first, make the third-order decomposition by S1
c    S1: first order deconposition
c
      call S1(0.5d0*pr1*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &  P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG1,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,VG,VG1,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG1,
     &     fdump,Vloc(1,1),TPIBA2,EXTAU(1,1,1),1,NGNL,NGcont)
C
      call S1(0.5d0*pr2*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &  P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG2,
c *** for Kokubo ASK FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,VG,VG2,
c *** for Kokubo ASK FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG2,
     &     fdump,Vloc(1,2),TPIBA2,EXTAU(1,1,1),2,NGNL,NGcont)
C
      call S1(0.5d0*pr3*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &  P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG3,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,  IFAC_XYZ,VG,VG3,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG3,
     &     fdump,Vloc(1,3),TPIBA2,EXTAU(1,1,1),3,NGNL,NGcont)
C
      call S1(0.5d0*pr2*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &  P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG4,
c *** for Kokubo ASK FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,    IFAC_XYZ,VG,VG4,
c *** for Kokubo ASK FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG4,
     &     fdump,Vloc(1,4),TPIBA2,EXTAU(1,1,1),4,NGNL,NGcont)
C
      call S1(0.5d0*pr1*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &  P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG5,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,   IFAC_XYZ,VG,VG5,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG5,
     &     fdump,Vloc(1,5),TPIBA2,EXTAU(1,1,1),5,NGNL,NGcont)
C*** start tilda operation
c    Second, make the tilda of the third-order decomposition by S1
c
      call S1T(0.5d0*pr1*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     & P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG5,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,   IFAC_XYZ,VG,VG5,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG5,
     &     fdump,Vloc(1,5),TPIBA2,EXTAU(1,1,1),5,NGNL,NGcont)
C
      call S1T(0.5d0*pr2*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     & P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG4,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,VG,VG4,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG4,
     &     fdump,Vloc(1,4),TPIBA2,EXTAU(1,1,1),4,NGNL,NGcont)
C
      call S1T(0.5d0*pr3*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     & P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG3,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,VG,VG3,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG3,
     &     fdump,Vloc(1,3),TPIBA2,EXTAU(1,1,1),3,NGNL,NGcont)
C
      call S1T(0.5d0*pr2*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     & P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG2,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,  IFAC_XYZ,VG,VG2,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG2,
     &     fdump,Vloc(1,2),TPIBA2,EXTAU(1,1,1),2,NGNL,NGcont)
C
      call S1T(0.5d0*pr1*dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     & P(1,iib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,VG,VG1,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,  IFAC_XYZ,VG,VG1,
c *** for Kokubo ASL FFT
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG1,
     &     fdump,Vloc(1,1),TPIBA2,EXTAU(1,1,1),1,NGNL,NGcont)
C
c     Then the fourth-order decomposition is made.
c
      enddo          ! band loop end
cc ***      endif  ! end of if my_rank.ne.0 loop
      elseif ( ioption.eq.4 ) then
c ***********************************************************
c *   Masuo Suzuki ( J. Math. Phys. Vol.32(2), p400, '91)
c *     create fourth-order decomposition
c *       from second-order decompositions
c ***********************************************************
       m=2
       pm=1.d0/( 4.d0 - 4.d0**(1.d0/dfloat(2*m-1) ) )
       pr1=pm
       pr2=pm
       pr3=1.d0-4*pm
c +++  check : parameters
        if ( abs(pr3+2*(pr1+pr2)-1.d0).gt.1.d-08 ) then
         write(6,*)' sum of pr-s is not one WRONG !! '
         stop
        elseif ( abs(pr3**3+2*( pr1**3+pr2**3)).gt.1.d-08 ) then
         write(6,*)' sum of pr-cubes is not zero WRONG !! '
         stop
        endif
c +++  check : end
c      do ib=1,nbseq   ! band loop
ccc **      if (my_rank.ne.0 ) then
c **** for the case of 4-th order decomposition
c  S2:       second order decomposition
c
c *****  temp check : orthonormality
c      if ( mod(itstep,itmod).eq.0 ) then
c      write(6,*)' before ekin ! ib =',ib
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG,ib))*P(IG,ib) )
c        enddo
c        write(6,*)' norm = ',temp
c      endif
c *** temp check:end
      nbndloc=nend(my_rank)-nbegin(my_rank)+1
      call prof_start(35)
c     P is owned by FRPRMN across the predictor-corrector sequence.
c     Keep its mapping after this call and only synchronize the host result.
      call prof_stop(35)
      dt1=pr1*dt
c      call exkin(dt1,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
      call exkin_(dt1,nxyz,ng2q,P,G2,TPIBA2,GDUMP1,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c *****  temp check : orthonormality
c      if ( mod(itstep,itmod).eq.0 ) then
c      write(6,*)' after ekin and before S2 ! ib =',ib
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG,ib))*P(IG,ib) )
c        enddo
c        write(6,*)' norm = ',temp
c      endif
c *** temp check:end
c
      call S2_(dt1, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
c     &     P, HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     P, HP, YLM1, G21,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ1,
     &     VPP,VPP21, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     & IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2,VG,VG1,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,IFAC_XYZ,VG,VG1,
c *** for Kokubo ASL FFT
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG1,
     & fdump,Vloc(1,1),EXTAU(1,1,1),1,NGNL,
     &            mxbnd,nbegin(my_rank),nend(my_rank),NGcont)
C
c *****  temp check : orthonormality
c      if ( mod(itstep,itmod).eq.0 .and. my_rank.eq.0 ) then
c      write(6,*)' after S2 !  ib =',ib
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG,iib))*P(IG,iib) )
c        enddo
c        write(6,*)' norm = ',temp
c      endif
c *** temp check:end
c
c      dt12=(pr1+pr2)*dt
cc      call exkin(dt12,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
c      call exkin_(dt12,nxyz,ng2q,P,G2,TPIBA2,GDUMP2,GMHF,
c     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
      call exkin_(dt1,nxyz,ng2q,P,G2,TPIBA2,GDUMP1,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
      dt2=pr2*dt
      call exkin_(dt2,nxyz,ng2q,P,G2,TPIBA2,GDUMP2,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
      call S2_(dt2, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
c     &   P, HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &   P, HP, YLM2, G22,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ2,
     &     VPP,VPP22, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &  IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2,VG,VG2,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,IFAC_XYZ,VG,VG2,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG2,
     &  fdump,Vloc(1,2),EXTAU(1,1,1),2,NGNL,
     &            mxbnd,nbegin(my_rank),nend(my_rank),NGcont)
c
      call exkin_(dt2,nxyz,ng2q,P,G2,TPIBA2,GDUMP2,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
c      dt23=(pr2+pr3)*dt
cc      call exkin(dt23,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
c      call exkin_(dt23,nxyz,ng2q,P,G2,TPIBA2,GDUMP3,GMHF,
c     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
      dt3=pr3*dt
      call exkin_(dt3,nxyz,ng2q,P,G2,TPIBA2,GDUMP3,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
      call S2_(dt3, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
c     &     P, HP, YLM, G2,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     P, HP, YLM3, G23,J2G, RHO1, RHO2, TPIBA, WORK2, VPJ3,
     &     VPP,VPP23, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &  IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2,VG,VG3,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,IFAC_XYZ,VG,VG3,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG3,
     &  fdump,Vloc(1,3),EXTAU(1,1,1),3,NGNL,
     &            mxbnd,nbegin(my_rank),nend(my_rank),NGcont)
c
      call exkin_(dt3,nxyz,ng2q,P,G2,TPIBA2,GDUMP3,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
c      dt32=(pr3+pr2)*dt
cc      call exkin(dt32,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
c      call exkin_(dt32,nxyz,ng2q,P,G2,TPIBA2,GDUMP4,GMHF,
c     &            mxbnd,nbegin(my_rank),nend(my_rank))
C
      dt2=pr2*dt
      call exkin_(dt2,nxyz,ng2q,P,G2,TPIBA2,GDUMP4,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
C
      call S2_(dt2, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
c     &     P, HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     P, HP, YLM4, G24,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ4,
     &     VPP,VPP24, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     & IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2,VG,VG4,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,IFAC_XYZ,VG,VG4,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG4,
     & fdump,Vloc(1,4),EXTAU(1,1,1),4,NGNL,
     &            mxbnd,nbegin(my_rank),nend(my_rank),NGcont)
C
      call exkin_(dt2,nxyz,ng2q,P,G2,TPIBA2,GDUMP4,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c
c      dt21=(pr2+pr1)*dt
cc      call exkin(dt21,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
c      call exkin_(dt21,nxyz,ng2q,P,G2,TPIBA2,GDUMP5,GMHF,
c     &            mxbnd,nbegin(my_rank),nend(my_rank))
C
      dt1=pr1*dt
      call exkin_(dt1,nxyz,ng2q,P,G2,TPIBA2,GDUMP5,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
C
      call S2_(dt1, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
c     &     P, HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     P, HP, YLM5, G25,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ5,
     &     VPP,VPP25, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &  IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2,VG,VG5,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ,IFAC_XYZ,VG,VG5,
c *** for Kokubo ASL FFT
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,VG,VG5,
     &  fdump,Vloc(1,5),EXTAU(1,1,1),5,NGNL,
     &            mxbnd,nbegin(my_rank),nend(my_rank),NGcont)
c
c *****  temp check : orthonormality
c      if ( mod(itstep,itmod).eq.0 .and. my_rank.eq.0 ) then
c      write(6,*)' after S2 5  ib =',ib
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG,iib))*P(IG,iib) )
c        enddo
c        write(6,*)' norm = ',temp
c      endif
c *** temp check:end
      dt1=pr1*dt
c      call exkin(dt1,nxyz,ng2q,P(1,ib),G2,TPIBA2,GDUMP,GMHF)
      call exkin_(dt1,nxyz,ng2q,P,G2,TPIBA2,GDUMP5,GMHF,
     &            mxbnd,nbegin(my_rank),nend(my_rank))
c ***
ccc ***      endif ! end of if my_rank.ne.0 loop
c *****  temp check : orthonormality
c      if ( mod(itstep,itmod).eq.0 ) then
c      do ib=1,nbseq
c       do jb=1,ib
c        temp=0
c        write(6,*)' ib = ',ib,' jb = ',jb
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG,jb))*P(IG,ib) )
c        enddo
c        write(6,*)' overlap = ',temp
c       enddo
c      enddo
c      endif
c ***
c     P remains device-authoritative until a verified host consumer or the
c     end of the caller-owned predictor-corrector sequence.
      endif  ! end of if (ioption.eq...)  loop
c      WRITE(71,REC=IOWF(JJB)) PJ
c
c      do ib=1,mxbnd
c      call eqp(pj(1,ib),p(1,ib),ng2,ng2q) ! update p for next time step
c      enddo
c
c  ****  Orthogonalization here ! ( if necessary )
c
c      call nrmlz(p,nbnd,mxbnd,NG2,NG2Q)   !  normalization first
c      call ortho(mxbnd,ng2q,pj,p,mxbnd,ng2q,
c     &           sig,x0,x1,work1,work20)
c      do ib=1,mxbnd
c      call eqp(pj(1,ib),p(1,ib),ng2,ng2q) ! update p for next time step
c      enddo
c
c
c Calculation of the expectation values.
c
       if ( mod(itstep,itmod).eq.0 ) then
        call prof_start(13)
        tag=11
ccc ***        if ( my_rank.ne.0 ) then
c         do ib=1,nbseq
         iylm_reuse=0
         do ib=nbegin(my_rank),nend(my_rank)
          iib=ib-nbegin(my_rank)+1
          CALL HLOCAL( NRX, NRY, NRZ, NXYZ, NG2, NG2Q, NJ,
c *** for Sugino FFT
c     &   P(1,iib),HP(1,1), RHO1, RHO2, VG, J2G, WSAVEX, WSAVEY, WSAVEZ,
c     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2  )
c *** for Kokubo ASL FFT
c     &   P(1,iib),HP(1,1), RHO1, RHO2, VG, J2G, WSAVE_XYZ,IFAC_XYZ  )
c *** for Kokubo FFTW
     &   P(1,iib),HP(1,1), RHO1, RHO2, VG, J2G, plancfp,plancbp  )
C
          CALL NONLOC( NXYZ, NG2, NG2Q, NJ,
c     &     P(1,ib), HP(1,1), YLM, G2, RHO2, RHO3, TPIBA, WORK2, VPJ,
     &    P(1,iib), HP(1,1), YLM, GG2, RHO2, RHO3, TPIBA, WORK2, VPJ,
     &             VPP, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
     &             NIDN, IOVP, MXOFL,GDUMP,NGNL,NGcont,iylm_reuse )
          iylm_reuse=1
          temp=0
          do ig=1,ng2
c           temp=temp + dble( dconjg( P(ig,ib) )*HP(ig,1)  ) 
           temp=temp + dble( dconjg( P(ig,iib) )*HP(ig,1)  ) 
          enddo
         EE(ib)=temp
c *** temp check
c        write(6,*)'my_rank=',my_rank,'EE(',ib,')=',EE(IB)*27.212d0
c *** temp check ; end
         enddo  ! ib loop: end
        if ( my_rank.ne.0 ) then
         nbleng=nend(my_rank)-nbegin(my_rank)+1
         call MPI_Send(EE(nbegin(my_rank)),nbleng,
     &       MPI_DOUBLE_PRECISION,0,tag,MPI_COMM_WORLD,ierr)
        else
         do icpu=1,ncpu
         nbleng=nend(icpu)-nbegin(icpu)+1
         call MPI_Recv(EE(nbegin(icpu)),nbleng,
     &    MPI_DOUBLE_PRECISION,icpu,tag,MPI_COMM_WORLD,status,ierr)
         enddo   ! icpu loop : end
c *** temp check
c        do ib=1,nbseq
c        write(6,*)'my_rank=',my_rank,'EE(',ib,')=',EE(IB)*27.212d0
c        enddo
c *** temp check ; end
        endif   ! if my_rank.ne.o loop:  end
        call prof_stop(13)
       endif ! if mod(itstep,itmod).eq.0 loop: end
c ***  temp check
c       if ( my_rank.eq.0 ) then
c       write(6,*)' in sub, TMEVL: Expectation values.' 
c       write(6,*)( EE(ib)*27.212d0,ib=1,nbseq ) 
c       endif
c ***  temp check : end
c ***  temp check
c      write(6,*)' in sub. TMEVL : VG !! '
c      write(6,*)( vg(ig),ig=1,1500,100 )
c ***  temp check : end
C
      call prof_stop(8)
      RETURN
      END
c
      subroutine eqp(p,pj,ng2,ng2q)
      complex*16 p(ng2q),pj(ng2q)
       do 2 ig=1,ng2
       pj(ig)=p(ig)
    2  continue
      return
      end
c      subroutine addp(pj,dtex,hp,ng2,ng2q)
c      complex*16 pj(ng2q),hp(ng2q),dtex
c       do 2 ig=1,ng2
c       pj(ig)=pj(ig)+dtex*hp(ig)
c    2  continue
c      return
c      end
c **************************************************************
c
c  First order decomposition of exp( idt*H )
c
c **************************************************************
      subroutine S1(dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
     &     P, HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2,OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
c *** for Kokubo FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,
     &     VG,VGG ,fdump,Vloc,TPIBA2,EXTAU,NP,NGNL,NGcont)
      implicit double precision(a-h,o-z)
c      COMPLEX*16  P(NG2Q), HP(NG2Q,3)
      COMPLEX*16  P(NG2Q), HP(NG2Q)
cc      DIMENSION IOWF(MBLK),IOVP(2,NTYQ)
C
c      REAL*8 YLM(NG2Q,4),OUT(NBNDQ,3),EE(NBNDQ)
c      REAL*8 YLM(NG2Q,4)
c      REAL*8 YLM(NG2Q,9)
      REAL*8 YLM(NGcont,16)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),
c     &    VG(NXYZ),VGG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ/6,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,5),EXTAU(NXYZ/6,5,NTAUQ)
     &    VG(NXYZ),WORK2(NG2Q),EXTAU(NGcont,5,NTAUQ)
      dimension VGG(NXYZ)
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
      integer idx
      DIMENSION J2G(NG2Q),G2(4,NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,2,NTYQ),VPP(3,3,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ),VPP2(9,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ),VPP2(16,3,NTYQ)
      dimension fdump(NXYZ)
c      complex*16 rho4(NXYZ)
      dimension Vloc(NXYZ)
      dimension NGNL(NTYQ)
      parameter ( ntyq2=4 )
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
c *** first: operate kinetic energy term
c      do ig=1,ng2
      do ig=1,nxyz
       fac=dt*0.5d0*g2(4,ig)*TPIBA2  ! 0.5d0*g2(4,ig) = Ekin (Hr)
       P(ig)=dcmplx( dcos(fac),-dsin(fac) )*P(ig)
      enddo
c *** second: operate  nonlocal pseudopotential terms
      do 1 ity=1,ntype
       if ( numty(ity).lt.0 ) goto 1 ! skip Hydrogen
       do 2 it=1,numty(ity)
       itseq=nidn(it,ity)  ! seq # of atomic site
        do 3 il=1,mxofl(ity)
        call zero(hp,ng2q)
        if ( IBUN(il,ity).eq.0 ) then
c NON PARTITIONING !
c         call exnlp( dt,NG2Q, NG2, G2,
         if (il.eq.1 ) then 
         l=il
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(1,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq),NGNL(ity),Ngcont )
         elseif ( il.eq.2 ) then
         do l=2,4
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM,EXTAU(1,itseq),WORK2(1,1), WORK2(1,2),WORK2(1,3),
c     &   l,YLM,EXTAU(1,NP,itseq),WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM,EXTAU(1,NP,itseq),WORK2, 
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq),NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=5,9
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM,EXTAU(1,itseq),WORK2(1,1), WORK2(1,2),WORK2(1,3),
cc     &   l,YLM,EXTAU(1,NP,itseq),WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM,EXTAU(1,NP,itseq),WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq),NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=10,16
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM,EXTAU(1,itseq),WORK2(1,1), WORK2(1,2),WORK2(1,3),
cc     &   l,YLM,EXTAU(1,NP,itseq),WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM,EXTAU(1,NP,itseq),WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq),NGNL(ity),NGcont )
         enddo
         endif
        else
c PARTITIONING !
         do ip=2,3
c         call exnlp( dt,NG2Q, NG2, G2,
         if (il.eq.1 ) then 
         l=il
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(1,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         elseif ( il.eq.2 ) then
         do l=2,4
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=5,9
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
c     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=10,16
         call exnlp( dt,NG2Q, Nxyz, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
c     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         endif
         enddo
        endif
    3   continue
    2  continue
    1 continue
c ** Last: operate local potential term
         DO 101 JG=1,NXYZ
  101    RHO1(JG)=(0.D0,0.D0)
*VDIR NODEP(RHO1)
!ocl norecurrence(RHO1)
c         DO 100 IG=1,NG2
         DO 100 IG=1,NXYZ
         JG=J2G(IG)
  100    RHO1(JG)=P(IG)
C From G-space to R-space
c *** for Sugino FFT
c         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c         CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c         call FFT3BX_fftw(NXYZ,RHO1,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
         CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2
     &    ,plancfp,plancbp)
C
C        RHO2:WAVEFN IN REAL SPACE
C        VG:POTENTIAL IN REAL SPACE
C       VGG:POTENTIAL IN R-  SPACE
C        RHO4:LOCAL PSEUDOPOTENTIAL in R- SPACE
      do ig=1,nxyz
c      jg=i2g(ig)
c      VG(jg)=VGG(jg)+rho4(jg)*fdump(ig)
c      VG(ig)=VGG(ig)+rho4(ig)
      VG(ig)=VGG(ig)+Vloc(ig)
      enddo
C
         DO 300 I=1,NXYZ
         fac=dt*dreal( vg(i) )
  300    RHO2(I)=dcmplx( dcos(fac),-dsin(fac) )*RHO1(I)
C From R-space to G-space
c *** for Sugino FFT
c         CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c         CALL FFT3FX_ASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c         call FFT3FX_fftw(NXYZ,RHO2,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
         CALL FFT3FX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1
     &   ,plancfp,plancbp)
C
c         DO 110 IG=1,NG2
*VDIR NODEP(RHO2)
!ocl norecurrence(RHO2)
         DO 110 IG=1,NXYZ
         JG=J2G(IG)
  110    P(IG)=RHO2(JG)
C
      return
      end
c **************************************************************
c
c  S1T: Tilda operator of S1
c
c **************************************************************
      subroutine S1T(dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
     &     P, HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2,OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,
     &     VG,VGG,fdump,Vloc,TPIBA2,EXTAU,NP,NGNL,NGcont) 
      implicit double precision(a-h,o-z)
c      COMPLEX*16  P(NG2Q), HP(NG2Q,3)
      COMPLEX*16  P(NG2Q), HP(NG2Q)
cc      DIMENSION IOWF(MBLK),IOVP(2,NTYQ)
C
c      REAL*8 YLM(NG2Q,4),OUT(NBNDQ,3),EE(NBNDQ)
c      REAL*8 YLM(NG2Q,4)
c      REAL*8 YLM(NG2Q,9)
      REAL*8 YLM(NGcont,16)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),
c     &    VG(NXYZ),VGG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ/6,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,5),EXTAU(NXYZ/6,5,NTAUQ)
     &    VG(NXYZ),WORK2(NG2Q),EXTAU(NGcont,5,NTAUQ)
      dimension VGG(NXYZ)
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
      DIMENSION J2G(NG2Q),G2(4,NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,2,NTYQ),VPP(3,3,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ),VPP2(9,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ),VPP2(16,3,NTYQ)
      dimension fdump(NXYZ)
c      complex*16 rho4(NXYZ) ! but used as real
      dimension Vloc(NXYZ)
      dimension NGNL(NTYQ)
      parameter ( ntyq2=4 )
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
c
c ** First: operate local potential term
         DO 101 JG=1,NXYZ
  101    RHO1(JG)=(0.D0,0.D0)
*VDIR NODEP(RHO1)
!ocl norecurrence(RHO1)
c         DO 100 IG=1,NG2
         DO 100 IG=1,NXYZ
         JG=J2G(IG)
  100    RHO1(JG)=P(IG)
C From G-space to R-space
c *** for Sugino FFT
c         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c       CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c       call FFT3BX_fftw(NXYZ,RHO1,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
       CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2
     &  ,plancfp,plancbp)
C
C        RHO2:WAVEFN IN REAL SPACE
C        VG:POTENTIAL IN REAL SPACE
C       VGG:POTENTIAL IN R-  SPACE
C        RHO4:LOCAL PSEUDOPOTENTIAL in R- SPACE
      do ig=1,nxyz
c      jg=i2g(ig)
c      VG(jg)=VGG(jg)+rho4(jg)*fdump(ig)
c      VG(ig)=VGG(ig)+rho4(ig)
      VG(ig)=VGG(ig)+Vloc(ig)
      enddo
C
C
C
         DO 300 I=1,NXYZ
         fac=dt*dreal( vg(i) )
  300    RHO2(I)=dcmplx( dcos(fac),-dsin(fac) )*RHO1(I)
C From R-space to G-space
c *** for Sugino FFT
c         CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c       CALL FFT3FX_ASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c       call FFT3FX_fftw(NXYZ,RHO2,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
       CALL FFT3FX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1
     & ,plancfp,plancbp)
C
c         DO 110 IG=1,NG2
*VDIR NODEP(RHO2)
!ocl norecurrence(RHO2)
         DO 110 IG=1,NXYZ
         JG=J2G(IG)
  110    P(IG)=RHO2(JG)
C
c *** second: operate  nonlocal pseudopotential terms
      do 1 ity=ntype,1,-1
       if ( numty(ity).lt.0 ) goto 1 ! skip Hydrogen
       do 2 it=numty(ity),1,-1
       itseq=nidn(it,ity)  ! seq # of atomic site
        do 3 il=mxofl(ity),1,-1
        call zero(hp,ng2q)
        if ( IBUN(il,ity).ne.1 ) then
c NON PARTITIONING !
c         call exnlp( dt,NG2Q, NG2, G2,
         if ( il.eq.1 ) then
         l=il
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(1,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
c     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
cc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         elseif ( il.eq.2 ) then
         do l=4,2,-1
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=9,5,-1
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=16,10,-1
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         endif
        else
c PARTITIONING !
         do ip=3,2,-1
c         call exnlp( dt,NG2Q, NG2, G2,
         if ( il.eq.1 ) then
         l=il
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(1,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         elseif ( il.eq.2 ) then
         do l=4,2,-1
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=9,5,-1
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=16,10,-1
         call exnlp( dt,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         endif
         enddo
        endif
    3   continue
    2  continue
    1 continue
c *** Last: operate kinetic energy term
c      do ig=1,ng2
      do ig=1,nxyz
       fac=dt*0.5d0*g2(4,ig)*TPIBA2  ! 0.5d0*g2(4,ig) = Ekin (Hr)
       P(ig)=dcmplx( dcos(fac),-dsin(fac) )*P(ig)
      enddo
c
      return
      end
c *** exponential of 0.5*dt*(kinetic energy operator)
      subroutine exkin(dt,ng2,ng2q,P,G2,TPIBA2,GDUMP,GMHF)
      implicit double precision(a-h,o-z)
      COMPLEX*16  P(NG2Q)
      DIMENSION G2(4,NG2Q),GDUMP(NG2Q)
ccc      dthalf=0.5d0*dt
      call prof_start(9)
      dtqrt=0.25d0*dt*TPIBA2
      do ig=1,ng2
c      fac=dtqrt*( GDUMP(ig) - GMHF ) ! note:0.5d0*g2(4,ig)*TPIBA2=Ekin(Hr) 
      fac=dtqrt*GDUMP(ig) ! note:0.5d0*g2(4,ig)*TPIBA2=Ekin(Hr) 
      P(ig)=dcmplx( dcos(fac),-dsin(fac) )*P(ig)
      enddo
      call prof_stop(9)
      return
      end
      subroutine exkin_(dt,ng2,ng2q,P,G2,TPIBA2,GDUMP,GMHF,
     &                  mxbnd,nbegin,nend)
      implicit double precision(a-h,o-z)
      COMPLEX*16  P(NG2Q,mxbnd)
      COMPLEX*16  PHASE
      DIMENSION G2(4,NG2Q),GDUMP(NG2Q)
ccc      dthalf=0.5d0*dt
      call prof_start(9)
      dtqrt=0.25d0*dt*TPIBA2
      nbndloc=nend-nbegin+1
      call prof_start(37)
! Compute the band-independent kinetic phase once per G vector.
!$acc parallel loop gang vector present(P(1:NG2Q,1:nbndloc))
!$acc+ copyin(GDUMP(1:ng2)) private(iib,fac,phase)
      do ig=1,ng2
c      fac=dtqrt*( GDUMP(ig) - GMHF ) ! note:0.5d0*g2(4,ig)*TPIBA2=Ekin(Hr) 
      fac=dtqrt*GDUMP(ig) ! note:0.5d0*g2(4,ig)*TPIBA2=Ekin(Hr) 
      phase=dcmplx(dcos(fac),-dsin(fac))
!$acc loop seq
      do iib=1,nbndloc
      P(ig,iib)=phase*P(ig,iib)
      enddo
      enddo
      call prof_stop(37)
      call prof_stop(9)
      return
      end
c **************************************************************
c
c  M. Suzuki  J. Math. Phys. Vol26(4). 601 '85
c  Second order decomposition of exp( idt*H )
c
c **************************************************************
      subroutine S2(dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
     &     P, HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2,OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,
     &     VG,VGG,fdump,Vloc,EXTAU,NP,NGNL,NGcont)
      implicit double precision(a-h,o-z)
c      COMPLEX*16  P(NG2Q), HP(NG2Q,3)
      COMPLEX*16  P(NG2Q), HP(NG2Q)
cc      DIMENSION IOWF(MBLK),IOVP(2,NTYQ)
C
c      REAL*8 YLM(NG2Q,4),OUT(NBNDQ,3),EE(NBNDQ)
c      REAL*8 YLM(NG2Q,4)
c      REAL*8 YLM(NG2Q,9)
      REAL*8 YLM(NGcont,16)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),
c     &    VG(NXYZ),VGG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ/6,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,5),EXTAU(NXYZ/6,5,NTAUQ)
     &    VG(NXYZ),WORK2(NG2Q),EXTAU(NGcont,5,NTAUQ)
      dimension VGG(NXYZ)
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
      DIMENSION J2G(NG2Q),G2(4,NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,2,NTYQ),VPP(3,3,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ),VPP2(9,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ),VPP2(16,3,NTYQ)
      dimension fdump(NXYZ)
c      complex*16 rho4(NXYZ)  ! but used as real
      dimension Vloc(NXYZ)
      dimension NGNL(NTYQ)
      parameter ( ntyq2=4 )
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
c *** first: operate kinetic energy term
c      do ig=1,ng2
c       fac=dt*0.25d0*g2(4,ig)  ! 0.5d0*g2(4,ig) = Ekin (Hr) 
c       P(ig)=dcmplx( dcos(fac),-dsin(fac) )*P(ig)
c      enddo
c *** second: operate  nonlocal pseudopotential terms
c ***  temp check for G2 & YLM
c         write(6,*)' in sub. S2 G2 beyond NG2! '
c         write(6,*)( G2(4,ig),ig=ng2+1,nxyz,500 )
c         write(6,*)' in sub. S2 YLM beyond NG2! '
c         write(6,*)( YLM(ig,4),ig=ng2+1,nxyz,500 )
c         write(6,*)' in sub. S2 VPJ beyond NG2! '
c         write(6,*)( VPJ(ig,3,2,1),ig=ng2+1,nxyz,500 )
c ***  temp check for YLM : end
      dthalf=0.5d0*dt
      do 1 ity=ntype,1,-1
       if ( numty(ity).lt.0 ) goto 1 ! skip Hydrogen 
       do 2 it=numty(ity),1,-1
       itseq=nidn(it,ity)  ! seq # of atomic site
cc        call zero(hp,ng2q)
        do 3 il=mxofl(ity),1,-1
        if ( IBUN(il,ity).ne.1 ) then
c NON PARTITIONING !
c         call exnlp( dthalf,NG2Q, NG2, G2,
         if ( il.eq.1 ) then
         l=il
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
c     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         elseif ( il.eq.2 ) then
         do l=4,2,-1
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
c     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
c     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=9,5,-1
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=16,10,-1
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         endif
        else
c PARTITIONING !
         do ip=3,2,-1
c         call exnlp( dthalf,NG2Q, NG2, G2,
         if ( il.eq.1 ) then
         l=il
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         elseif ( il.eq.2 ) then
         do l=4,2,-1
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
c     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
cccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=9,5,-1
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=16,10,-1
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         endif
         enddo
        endif
    3   continue
    2  continue
    1 continue
c ****
c *****  temp check : orthonormality
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG))*P(IG) )
c        enddo
c        write(6,*)' in sub S2 after non-local:  norm = ',temp
c *** temp check:end 
c ** third: operate local potential term
         DO 101 JG=1,NXYZ
c  101    RHO1(JG)=(0.D0,0.D0)
  101    RHO2(JG)=(0.D0,0.D0)
*VDIR NODEP(RHO1)
!ocl norecurrence(RHO1)
c         DO 100 IG=1,NG2
         DO 100 IG=1,NXYZ
         JG=J2G(IG)
  100    RHO1(JG)=P(IG)
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO1(ig) )*RHO1(ig) )
c       enddo
c       write(6,*)' in sub. S2: before FFT : norm = ',sum
c **** temp check : end 
c ****  temp check
C
C
c ****  temp check : end
C From G-space to R-space
c *** for Sugino FFT
c         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO1,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2
     &,plancfp,plancbp)
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO1(ig) )*RHO1(ig) )
c       enddo
c       write(6,*)' in sub. S2: after FFT : norm = ',
c     & sum/dfloat(NXYZ)
c **** temp check : end
C
C        RHO1:WAVEFN IN REAL SPACE
C        VG:POTENTIAL IN REAL SPACE
C       VGG: HXC POTENTIAL IN R-  SPACE
C       RHO4:LOCAL PSEUDOPOTENTIAL in R- SPACE
      do ig=1,nxyz
c      jg=i2g(ig)
c      VG(jg)=VGG(jg)+rho4(jg)*fdump(ig)
c      VG(ig)=VGG(ig)+rho4(ig)
      VG(ig)=VGG(ig)+Vloc(ig)
      enddo
C
C
c *** temp check
c       write(6,*)' VG in sub. S2 '
c       write(6,*)( VG(ig),ig=1,1500,100 )
c *** temp check ; end
C
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO1(ig) )*RHO1(ig) )
c       enddo
c       write(6,*)' in sub. S2: before exp(Vlocal) : norm = ',
c     & sum/dfloat(NXYZ)
c **** temp check : end
         DO 300 I=1,NXYZ
         fac=dt*dreal( vg(i) )
  300    RHO2(I)=dcmplx( dcos(fac),-dsin(fac) )*RHO1(I)
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO2(ig) )*RHO2(ig) )
c       enddo
c       write(6,*)' in sub. S2: after exp(Vlocal) : norm = ',
c     & sum/dfloat(NXYZ)
c **** temp check : end
C From R-space to G-space
c *** for Sugino FFT
c         CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3FX_ASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3FX_fftw(NXYZ,RHO2,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      CALL FFT3FX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1
     &  ,plancfp,plancbp)
C
c         DO 110 IG=1,NG2
*VDIR NODEP(RHO2)
!ocl norecurrence(RHO2)
         DO 110 IG=1,NXYZ
         JG=J2G(IG)
  110    P(IG)=RHO2(JG)
c ****
c *****  temp check : orthonormality
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG))*P(IG) )
c        enddo
c        write(6,*)' in sub S2 after local pot:  norm = ',temp
c *** temp check:end
C
c ** fourth: operate nonlocal potential terms
      do 4 ity=1,ntype
       if ( numty(ity).lt.0 ) goto 4 ! skip Hydrogen
       do 5 it=1,numty(ity)
       itseq=nidn(it,ity)  ! seq # of atomic site
        do 6 il=1,mxofl(ity)
cc        call zero(hp,ng2q)
        if ( IBUN(il,ity).ne.1 ) then
c NON PARTITIONING !
c         call exnlp( dthalf,NG2Q, NG2, G2,
         if ( il.eq.1 ) then
         l=il
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         elseif ( il.eq.2 ) then
         do l=2,4
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=5,9
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
cccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=10,16
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,1,il,ity), VPP(1,il,ity), VPP2(l,1,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
cccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         endif
        else
c PARTITIONING !
         do ip=2,3
c         call exnlp( dthalf,NG2Q, NG2, G2,
         if ( il.eq.1 ) then
         l=il
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
cccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         elseif ( il.eq.2 ) then
         do l=2,4
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.3 ) then
         do l=5,9
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         elseif ( il.eq.4 ) then
         do l=10,16
         call exnlp( dthalf,NG2Q, NXYZ, G2,
     &   VPJ(1,ip,il,ity), VPP(ip,il,ity), VPP2(l,ip,ity),
c     &   l,YLM, EXTAU(1,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
ccc     &   l,YLM, EXTAU(1,NP,itseq), WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   l,YLM, EXTAU(1,NP,itseq), WORK2,
ccc     &   WORK2(1,4),WORK2(1,5),
     &   P, HP, TPIBA,  OMEGA, TAU(1,itseq) ,NGNL(ity),NGcont )
         enddo
         endif
         enddo
        endif
    6   continue
    5  continue
    4 continue
c ****
c *****  temp check : orthonormality
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG))*P(IG) )
c        enddo
c        write(6,*)' in sub S2 after non-local again:  norm = ',temp
c *** temp check:end
c ** last: operate kinetic energy term
c      do ig=1,ng2
c       fac=dt*0.25d0*g2(4,ig)  ! 0.5d0*g2(4,ig) = Ekin (Hr)
c       P(ig)=dcmplx( dcos(fac),-dsin(fac) )*P(ig)
c      enddo
c *******
c ***  check norm
c      write(6,*)' in sub. S2 : check norm of WF '
c      snorm=0
c      do ig=1,ng2
c      snorm=snorm+dble( dconjg( p(ig) )*p(ig)  )
c      enddo
c      write(6,*)' norm = ',snorm
c ***  check norm :end
      return
      end
      subroutine S2_(dt, NXYZ,NRX,NRY,NRZ, NG2, NG2Q, NJ,
     &     P, HP, YLM, G2,J2G,RHO1, RHO2, TPIBA, WORK2, VPJ,
     &     VPP,VPP2,OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c *** for Sugino FFT
c     &     NIDN, IOVP, MXOFL, WSAVEX, WSAVEY, WSAVEZ,
c     &     IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
c *** for Kokubo ASL FFT
c     &     NIDN, IOVP, MXOFL, WSAVE_XYZ, IFAC_XYZ,
c *** for Kokubo FFTW
     &     NIDN, IOVP, MXOFL, plancfp,plancbp,
     &     VG,VGG,fdump,Vloc,EXTAU,NP,NGNL,
     &     mxbnd,nbegin,nend,NGcont)
      implicit double precision(a-h,o-z)
c      COMPLEX*16  P(NG2Q), HP(NG2Q,3)
      COMPLEX*16  P(NG2Q,mxbnd), HP(NG2Q)
cc      DIMENSION IOWF(MBLK),IOVP(2,NTYQ)
C
c      REAL*8 YLM(NG2Q,4),OUT(NBNDQ,3),EE(NBNDQ)
c      REAL*8 YLM(NG2Q,4)
c      REAL*8 YLM(NG2Q,9)
      REAL*8 YLM(NGcont,16)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),
c     &    VG(NXYZ),VGG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,3),EXTAU(NXYZ/6,NTAUQ)
c     &    VG(NXYZ),WORK2(NG2Q,5),EXTAU(NXYZ/6,5,NTAUQ)
     &    VG(NXYZ),WORK2(NG2Q),EXTAU(NGcont,5,NTAUQ)
      dimension VGG(NXYZ)
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
      DIMENSION J2G(NG2Q),G2(4,NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,2,NTYQ),VPP(3,3,NTYQ),VPP2(4,3,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ),VPP2(9,3,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ),VPP2(16,3,NTYQ)
      dimension fdump(NXYZ)
c      complex*16 rho4(NXYZ)  ! but used as real
      dimension Vloc(NXYZ)
      dimension NGNL(NTYQ)
      parameter ( ntyq2=4 )
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
      COMPLEX*16 RHO1_(NXYZ,mxbnd),RHO2_(NXYZ,mxbnd)
      complex*16, allocatable, save, dimension(:,:) :: work2_
      complex*16, allocatable, save, dimension(:) :: cfac_
      integer, allocatable, save, dimension(:) :: ngnl_
      integer, save :: ngwork = 0
      logical, save :: first = .true.
      call prof_start(10)
c *** first: operate kinetic energy term
c      do ig=1,ng2
c       fac=dt*0.25d0*g2(4,ig)  ! 0.5d0*g2(4,ig) = Ekin (Hr) 
c       P(ig)=dcmplx( dcos(fac),-dsin(fac) )*P(ig)
c      enddo
c *** second: operate  nonlocal pseudopotential terms
c ***  temp check for G2 & YLM
c         write(6,*)' in sub. S2 G2 beyond NG2! '
c         write(6,*)( G2(4,ig),ig=ng2+1,nxyz,500 )
c         write(6,*)' in sub. S2 YLM beyond NG2! '
c         write(6,*)( YLM(ig,4),ig=ng2+1,nxyz,500 )
c         write(6,*)' in sub. S2 VPJ beyond NG2! '
c         write(6,*)( VPJ(ig,3,2,1),ig=ng2+1,nxyz,500 )
c ***  temp check for YLM : end
! ==============================================================================
      if(first) then
         loopcnt = 0
         ngwork = 0
         do ity = ntype, 1, -1
            if(numty(ity) .lt. 0) cycle
            ngwork = max(ngwork,ngnl(ity))
            do it = numty(ity), 1, -1
               do il = mxofl(ity), 1, -1
                  if(ibun(il,ity) .ne. 1) then
                     if(il .eq. 1) then
                        loopcnt = loopcnt + 1
                     else if(il .eq. 2) then
                        do l = 4, 2, -1
                           loopcnt = loopcnt + 1
                        end do
                     else if(il .eq. 3) then
                        do l = 9, 5, -1
                           loopcnt = loopcnt + 1
                        end do
                     else if(il .eq. 4) then
                        do l =16,10, -1
                           loopcnt = loopcnt + 1
                        end do
                     end if
                  else
                     do ip = 3, 2, -1
                        if(il .eq. 1) then
                          loopcnt = loopcnt + 1
                        else if(il .eq. 2) then
                           do l = 4, 2, -1
                              loopcnt = loopcnt + 1
                           end do
                        else if(il .eq. 3) then
                           do l = 9, 5, -1
                              loopcnt = loopcnt + 1
                           end do
                        else if(il .eq. 4) then
                           do l =16,10, -1
                              loopcnt = loopcnt + 1
                           end do
                        end if
                     end do
                  end if
               end do
            end do
         end do
         allocate(work2_(ngwork,loopcnt))
         allocate(cfac_(loopcnt))
         allocate(ngnl_(loopcnt))
! Keep the nonlocal staging buffers allocated on the device.  Their host
! Values are regenerated for each phase and synchronized before the
! present-input GEMM path below.
!$acc enter data create(work2_(1:ngwork,1:loopcnt),
!$acc& cfac_(1:loopcnt),ngnl_(1:loopcnt))
         first = .false.
      endif
! ==============================================================================
      nbndloc=nend-nbegin+1
      call prof_start(11)
      call prof_start(25)
      loopcnt = 0
      dthalf=0.5d0*dt
      do 1 ity=ntype,1,-1
       if ( numty(ity).lt.0 ) goto 1 ! skip Hydrogen 
       do 2 it=numty(ity),1,-1
       itseq=nidn(it,ity)  ! seq # of atomic site
        do 3 il=mxofl(ity),1,-1
        if ( IBUN(il,ity).ne.1 ) then
         if ( il.eq.1 ) then
         l=il
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,1,il,ity),vpp(1,il,ity),vpp2(l,1,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         elseif ( il.eq.2 ) then
         do l=4,2,-1
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,1,il,ity),vpp(1,il,ity),vpp2(l,1,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         enddo
         elseif ( il.eq.3 ) then
         do l=9,5,-1
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,1,il,ity),vpp(1,il,ity),vpp2(l,1,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         enddo
         elseif ( il.eq.4 ) then
         do l=16,10,-1
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,1,il,ity),vpp(1,il,ity),vpp2(l,1,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         enddo
         endif
        else
         do ip=3,2,-1
         if ( il.eq.1 ) then
         l=il
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,ip,il,ity),vpp(ip,il,ity),vpp2(l,ip,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         elseif ( il.eq.2 ) then
         do l=4,2,-1
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,ip,il,ity),vpp(ip,il,ity),vpp2(l,ip,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         enddo
         elseif ( il.eq.3 ) then
         do l=9,5,-1
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,ip,il,ity),vpp(ip,il,ity),vpp2(l,ip,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         enddo
         elseif ( il.eq.4 ) then
         do l=16,10,-1
         loopcnt = loopcnt + 1
         call exnlp_only_make(dthalf,ng2q,nxyz,g2,
     &   vpj(1,ip,il,ity),vpp(ip,il,ity),vpp2(l,ip,ity),
     &   l,ylm,extau(1,np,itseq),work2_(1,loopcnt),
     &   tpiba,omega,tau(1,itseq),ngnl(ity),cfac_(loopcnt),
     &   NGcont,ngwork)
         ngnl_(loopcnt) = ngnl(ity)
         enddo
         endif
         enddo
        endif
    3   continue
    2  continue
    1 continue
      call prof_stop(25)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call exnlp_reuse_observe(np,work2_,cfac_,ngnl_,
     &                         ngwork,loopcnt)
#endif
      call prof_start(26)
      call prof_start(38)
!$acc update device(work2_(1:ngwork,1:loopcnt))
      call prof_stop(38)
      call prof_start(39)
!$acc update device(cfac_(1:loopcnt),ngnl_(1:loopcnt))
      call prof_stop(39)
      call exnlp_gemm_present_inputs(ng2q,work2_,p,omega,ngnl_,
     &     mxbnd,nbegin,nend,loopcnt,cfac_,ngwork,.false.)
      call prof_stop(26)
      call prof_stop(11)
c ****
c *****  temp check : orthonormality
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG))*P(IG) )
c        enddo
c        write(6,*)' in sub S2 after non-local:  norm = ',temp
c *** temp check:end 
c ** third: operate local potential term
      call prof_start(12)
      nbndloc=nend-nbegin+1
!$acc data present(P(1:NXYZ,1:nbndloc),J2G(1:NXYZ))
!$acc& copyin(VGG(1:NXYZ),Vloc(1:NXYZ))
!$acc& create(RHO1_(1:NXYZ,1:nbndloc),
!$acc& RHO2_(1:NXYZ,1:nbndloc),VG(1:NXYZ))
! ==============================================================================
      call prof_start(18)
      call prof_start(19)
!$acc parallel loop present(RHO2_(1:NXYZ,1:nbndloc)) private(iib,JG)
      do ib=nbegin,nend
       iib=ib-nbegin+1
! ==============================================================================
         DO 101 JG=1,NXYZ
c  101    RHO1(JG)=(0.D0,0.D0)
  101    RHO2_(JG,iib)=(0.D0,0.D0)
! ==============================================================================
      enddo
      call prof_stop(19)
! ==============================================================================
! ==============================================================================
      call prof_start(20)
!$acc parallel loop present(P(1:NXYZ,1:nbndloc),
!$acc& RHO1_(1:NXYZ,1:nbndloc),J2G(1:NXYZ)) private(iib,IG,JG)
      do idx=1,NXYZ*nbndloc
         IG=mod(idx-1,NXYZ)+1
         iib=(idx-1)/NXYZ+1
         JG=J2G(IG)
         RHO1_(JG,iib)=P(IG,iib)
      enddo
      call prof_stop(20)
      call prof_stop(18)
! ==============================================================================
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO1(ig) )*RHO1(ig) )
c       enddo
c       write(6,*)' in sub. S2: before FFT : norm = ',sum
c **** temp check : end 
c ****  temp check
C
C
c ****  temp check : end
C From G-space to R-space
c *** for Sugino FFT
c         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
! ==============================================================================
c    batched FFTW/cuFFT-compatible path over all local bands
      CALL FFT3BX_fftwASL_ACC_BATCH(NRX,NRY,NRZ,NXYZ,nbndloc,
     &                RHO1_,RHO2_,plancfp,plancbp)
! ==============================================================================
c *** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO1,plancfp,plancbp)
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO1(ig) )*RHO1(ig) )
c       enddo
c       write(6,*)' in sub. S2: after FFT : norm = ',
c     & sum/dfloat(NXYZ)
c **** temp check : end
C
C        RHO1:WAVEFN IN REAL SPACE
C        VG:POTENTIAL IN REAL SPACE
C       VGG: HXC POTENTIAL IN R-  SPACE
C       RHO4:LOCAL PSEUDOPOTENTIAL in R- SPACE
      call prof_start(18)
      call prof_start(21)
! Build the band-independent local phase once per grid point.
! The band loop then multiplies by it instead of repeating COS/SIN.
!$acc parallel loop present(VG(1:NXYZ),VGG(1:NXYZ),Vloc(1:NXYZ))
!$acc& private(fac)
      do ig=1,nxyz
c      jg=i2g(ig)
c      VG(jg)=VGG(jg)+rho4(jg)*fdump(ig)
c      VG(ig)=VGG(ig)+rho4(ig)
      VG(ig)=VGG(ig)+Vloc(ig)
      fac=dt*dreal(VG(ig))
      VG(ig)=dcmplx(dcos(fac),-dsin(fac))
      enddo
      call prof_stop(21)
C
C
c *** temp check
c       write(6,*)' VG in sub. S2 '
c       write(6,*)( VG(ig),ig=1,1500,100 )
c *** temp check ; end
C
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO1(ig) )*RHO1(ig) )
c       enddo
c       write(6,*)' in sub. S2: before exp(Vlocal) : norm = ',
c     & sum/dfloat(NXYZ)
c **** temp check : end
! ==============================================================================
      call prof_start(22)
!$acc parallel loop present(RHO1_(1:NXYZ,1:nbndloc),
!$acc& RHO2_(1:NXYZ,1:nbndloc),VG(1:NXYZ)) private(iib,I)
      do ib=nbegin,nend
       iib=ib-nbegin+1
! ==============================================================================
         DO 300 I=1,NXYZ
  300    RHO2_(I,iib)=VG(I)*RHO1_(I,iib)
! ==============================================================================
      enddo
      call prof_stop(22)
      call prof_stop(18)
! ==============================================================================
c **** temp check
c       sum=0
c       do ig=1,nxyz
c       sum=sum+dreal( dconjg( RHO2(ig) )*RHO2(ig) )
c       enddo
c       write(6,*)' in sub. S2: after exp(Vlocal) : norm = ',
c     & sum/dfloat(NXYZ)
c **** temp check : end
C From R-space to G-space
c *** for Sugino FFT
c         CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
! ==============================================================================
c    batched FFTW/cuFFT-compatible path over all local bands
      CALL FFT3FX_fftwASL_ACC_BATCH(NRX,NRY,NRZ,NXYZ,nbndloc,
     &                RHO2_,RHO1_,plancfp,plancbp)
! ==============================================================================
c *** for Kokubo FFTW
c      call FFT3FX_fftw(NXYZ,RHO2,plancfp,plancbp)
C
c         DO 110 IG=1,NG2
! ==============================================================================
      call prof_start(18)
      call prof_start(23)
!$acc parallel loop present(P(1:NXYZ,1:nbndloc),
!$acc& RHO2_(1:NXYZ,1:nbndloc),J2G(1:NXYZ)) private(iib,IG,JG)
      do ib=nbegin,nend
       iib=ib-nbegin+1
! ==============================================================================
*VDIR NODEP(RHO2)
!ocl norecurrence(RHO2)
         DO 110 IG=1,NXYZ
         JG=J2G(IG)
  110    P(IG,iib)=RHO2_(JG,iib)
! ==============================================================================
      enddo
      call prof_stop(23)
      call prof_stop(18)
! ==============================================================================
!$acc end data
      call prof_stop(12)
c ****
c *****  temp check : orthonormality
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG))*P(IG) )
c        enddo
c        write(6,*)' in sub S2 after local pot:  norm = ',temp
c *** temp check:end
C
c ** fourth: operate nonlocal potential terms
      call prof_start(11)
      call prof_start(25)
! The second traversal is the exact reverse of the first traversal over
! ity/it/il/ip/l.  Reuse the read-only staging columns and reverse their
! lookup; this preserves the original sequential projector order.
      call prof_stop(25)
      call prof_start(26)
      call exnlp_gemm_present_inputs(ng2q,work2_,p,omega,ngnl_,
     &     mxbnd,nbegin,nend,loopcnt,cfac_,ngwork,.true.)
      call prof_stop(26)
      call prof_stop(11)
c ****
c *****  temp check : orthonormality
c        temp=0
c        do ig=1,nxyz
c        temp=temp+dble( dconjg(P(IG))*P(IG) )
c        enddo
c        write(6,*)' in sub S2 after non-local again:  norm = ',temp
c *** temp check:end
c ** last: operate kinetic energy term
c      do ig=1,ng2
c       fac=dt*0.25d0*g2(4,ig)  ! 0.5d0*g2(4,ig) = Ekin (Hr)
c       P(ig)=dcmplx( dcos(fac),-dsin(fac) )*P(ig)
c      enddo
c *******
c ***  check norm
c      write(6,*)' in sub. S2 : check norm of WF '
c      snorm=0
c      do ig=1,ng2
c      snorm=snorm+dble( dconjg( p(ig) )*p(ig)  )
c      enddo
c      write(6,*)' norm = ',snorm
c ***  check norm :end
      call prof_stop(10)
      return
      end
c ******************************************
c *  exponential of separable non-local pseudopotentias
c *   suitable for potential-partitioning by M. Saito
c ******************************************
      subroutine exnlp(dt, NG2Q, NG2, G2, VPJ, VPP, VPP2,
c     &   l,YLM, EXTAU, WORK1,WORK2,WORK3,WORK4,WORK5,
     &   l,YLM, EXTAU, WORK1,
     &   COEF, DCOEF, TPIBA,  OMEGA, TAU ,NGNL,NGcont)
      implicit double precision(a-h,o-z)
      include 'mpif.h'
c      dimension G2(4,ng2q),vpj(ng2q),ylm(ng2q,4),
c      dimension G2(4,ng2q),vpj(ng2q),ylm(ng2q,9),
      dimension G2(4,ng2q),vpj(NGcont),ylm(NGcont,16),
c     &          tau(3),VPP2(4)
     &          tau(3)
c      complex*16 coef(ng2q),dcoef(ng2q,3),EXTAU(ng2q)
c      complex*16 coef(ng2q),dcoef(ng2q,3),EXTAU(ng2q/6)
      complex*16 coef(ng2q),dcoef(ng2q),EXTAU(NGcont)
c     & ,work1(ng2q),work2(ng2q),work3(ng2q),work4(ng2q),work5(ng2q)
     & ,work1(ng2q)
c     &  ,cfac,cfac1,cfac2,cfac3,ct1,ct2,ct3,y00,y11,y12,y13
c     &  ,cfac,cfac1,cfac2,cfac3,ct1,ct2,ct3
     &  ,cfac,ct1
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      IF ( L.gt.16 ) THEN
       if ( my_rank.eq.0 ) then
        write(6,*)' in sub. exnlp !!! '
        write(6,*)'ILL-ORBITAL IS INDICATED OR MORE THAN TWO PARTIONING'
        write(6,*)'   ------> STOPPING'
       endif
       STOP
      ENDIF
c
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      FPISQ=FPI**2
c  ***  lth - orbital **
      fac=dt*vpp2/vpp
      cfac=1.d0/vpp2*( dcmplx( dcos(fac),-dsin(fac) )
     &                -dcmplx(      1.d0, 0.d0     ) )
C           
       fac=1.d0
       if ( l.eq.2 .or. l.eq.3 ) fac=dsqrt(2.d0)
       if ( l.eq.1 )  lylm=1
       if ( l.eq.2 )  lylm=3
       if ( l.eq.3 )  lylm=4
       if ( l.eq.4 )  lylm=2
       if ( l.ge.5 )  lylm=l  !  this is NOT 1 but l!!
c *** temp check
c       if (my_rank.eq.0 ) then
c         write(6,*)' l = ',l
c         if (l.ge.5 ) then
c           write(6,*)' YLM '
c           write(6,*)(YLM(ig,l),ig=1,100,10)
c         endif
c       endif
c *** temp check : end
c       if ( l.ge.6 .and. I.le.9) fac=dsqrt(2.d0)
c ****************
       CT1=(0.D0,0.D0)
       DO IG=1,NGNL
        WORK1(IG)=fac*YLM(IG,lylm)*EXTAU(IG)*VPJ(IG)
        CT1=CT1+COEF(IG)*WORK1(IG)
       enddo
       CT1=cfac*CT1/OMEGA
c       DO IG=1,NGNL
c        DCOEF(IG,1)=CT1*DCONJG(WORK1(IG))
c        coef(ig)=coef(ig)+dcoef(ig)
c       enddo
       DO IG=1,NGNL
        coef(ig)=coef(ig)+CT1*DCONJG(WORK1(IG))
       enddo
c *** temp check
c       if (my_rank.eq.0 ) then
c        if (l.ge.5 ) then
c          sum=0
c          do ig=1,NGNL
c           sum=sum+ dreal( dconjg(coef(ig))*coef(ig) )
c          enddo
c         write(6,*)' l=',l,'norm=',sum
c        endif
c       endif
c *** temp check : end
c
      return
      end
      subroutine exnlp_(dt, NG2Q, NG2, G2, VPJ, VPP, VPP2,
c     &   l,YLM, EXTAU, WORK1,WORK2,WORK3,WORK4,WORK5,
     &   l,YLM, EXTAU, WORK1,
     &   COEF, DCOEF, TPIBA,  OMEGA, TAU ,NGNL,
     &   mxbnd,nbegin,nend,NGcont)
      implicit double precision(a-h,o-z)
      include 'mpif.h'
c      dimension G2(4,ng2q),vpj(ng2q),ylm(ng2q,4),
c      dimension G2(4,ng2q),vpj(ng2q),ylm(ng2q,9),
      dimension G2(4,ng2q),vpj(NGcont),ylm(NGcont,16),
c     &          tau(3),VPP2(4)
     &          tau(3)
c      complex*16 coef(ng2q),dcoef(ng2q,3),EXTAU(ng2q)
c      complex*16 coef(ng2q),dcoef(ng2q,3),EXTAU(ng2q/6)
      complex*16 coef(ng2q,mxbnd),dcoef(ng2q),EXTAU(NGcont)
c     & ,work1(ng2q),work2(ng2q),work3(ng2q),work4(ng2q),work5(ng2q)
     & ,work1(ng2q)
c     &  ,cfac,cfac1,cfac2,cfac3,ct1,ct2,ct3,y00,y11,y12,y13
c     &  ,cfac,cfac1,cfac2,cfac3,ct1,ct2,ct3
     &  ,cfac,ct1
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
      IF ( L.gt.16 ) THEN
       if ( my_rank.eq.0 ) then
        write(6,*)' in sub. exnlp !!! '
        write(6,*)'ILL-ORBITAL IS INDICATED OR MORE THAN TWO PARTIONING'
        write(6,*)'   ------> STOPPING'
       endif
       STOP
      ENDIF
c
      PI=4.D0*ATAN(1.D0)
      FPI=4.D0*PI
      FPISQ=FPI**2
c  ***  lth - orbital **
      fac=dt*vpp2/vpp
      cfac=1.d0/vpp2*( dcmplx( dcos(fac),-dsin(fac) )
     &                -dcmplx(      1.d0, 0.d0     ) )
C           
       fac=1.d0
       if ( l.eq.2 .or. l.eq.3 ) fac=dsqrt(2.d0)
       if ( l.eq.1 )  lylm=1
       if ( l.eq.2 )  lylm=3
       if ( l.eq.3 )  lylm=4
       if ( l.eq.4 )  lylm=2
       if ( l.ge.5 )  lylm=l  ! This is NOT 1 but l!!
c *** temp check
c       if (my_rank.eq.0 ) then
c         write(6,*)' l = ',l
c         if (l.ge.5 ) then
c           write(6,*)' YLM '
c           write(6,*)(YLM(ig,l),ig=1,100,10)
c         endif
c       endif
c *** temp check : end
c       if ( l.ge.6 .and. I.le.9) fac=dsqrt(2.d0)
c ****************
       DO IG=1,NGNL
        WORK1(IG)=fac*YLM(IG,lylm)*EXTAU(IG)*VPJ(IG)
       enddo
! ==============================================================================
      do ib=nbegin,nend
       iib=ib-nbegin+1
! ==============================================================================
       CT1=(0.D0,0.D0)
       DO IG=1,NGNL
        CT1=CT1+COEF(IG,iib)*WORK1(IG)
       enddo
       CT1=cfac*CT1/OMEGA
c       DO IG=1,NGNL
c        DCOEF(IG,1)=CT1*DCONJG(WORK1(IG))
c        coef(ig)=coef(ig)+dcoef(ig)
c       enddo
       DO IG=1,NGNL
        coef(ig,iib)=coef(ig,iib)+CT1*DCONJG(WORK1(IG))
       enddo
! ==============================================================================
      enddo
! ==============================================================================
c *** temp check
c       if (my_rank.eq.0 ) then
c        if (l.ge.5 ) then
c          sum=0
c          do ig=1,NGNL
c           sum=sum+ dreal( dconjg(coef(ig))*coef(ig) )
c          enddo
c         write(6,*)' l=',l,'norm=',sum
c        endif
c       endif
c *** temp check : end
c
      return
      end

      subroutine exnlp_only_make(dt, ng2q, ng2, g2, vpj, vpp, vpp2,
     &   l, ylm, extau, work1, tpiba, omega, tau, ngnl, cfac,
     &   NGcont,ngwork)
      implicit double precision(a-h,o-z)
c      dimension g2(4,ng2q), vpj(ng2q), ylm(ng2q,9), tau(3)
      dimension g2(4,ng2q), vpj(NGcont), ylm(NGcont,16), tau(3)
      complex*16 extau(NGcont), work1(ngwork), cfac
      pi = 4.d0*atan(1.d0)
      fpi = 4.d0*pi
      fpisq = fpi**2
      fac = dt*vpp2/vpp
      cfac = 1.d0/vpp2*(dcmplx(dcos(fac),-dsin(fac))
     &                 -dcmplx( 1.d0,    0.d0      ))
      fac = 1.d0
      if (l .eq. 2 .or. l .eq. 3) fac = dsqrt(2.d0)
      if (l .eq. 1)  lylm =1
      if (l .eq. 2)  lylm =3
      if (l .eq. 3)  lylm =4
      if (l .eq. 4)  lylm =2
      if (l .ge. 5)  lylm = l  ! This is not 1 but l !!
      do ig = 1, ngnl
         work1(ig) = fac*ylm(ig,lylm)*extau(ig)*vpj(ig)
      end do
      return
      end subroutine exnlp_only_make

#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      subroutine exnlp_reuse_observe(np,work1,cfac,ngnl,
     &                               ngwork,loopcnt)
      implicit double precision(a-h,o-z)
      integer np,ngwork,loopcnt,ngnl(loopcnt)
      integer exobs,exsame,exchanged
      integer exngsame,excfsame,exwksame
      integer prev_loopcnt(5),prev_ngwork(5)
      integer, allocatable, save :: prev_ngnl(:,:)
      complex*16 work1(ngwork,loopcnt),cfac(loopcnt)
      complex*16, allocatable, save :: prev_work(:,:,:)
      complex*16, allocatable, save :: prev_cfac(:,:)
      logical cache_valid(5),same,sameng,samecf,samewk,sameshape
      logical, save :: initialized = .false.
      save cache_valid,prev_loopcnt,prev_ngwork
      common /exnlpreuse/ exobs(5),exsame(5),exchanged(5)
      common /exnlpparts/ exngsame(5),excfsame(5),exwksame(5)

      if (np.lt.1 .or. np.gt.5) return
      if (.not.initialized) then
         allocate(prev_work(ngwork,loopcnt,5))
         allocate(prev_cfac(loopcnt,5))
         allocate(prev_ngnl(loopcnt,5))
         do iphase=1,5
            cache_valid(iphase)=.false.
            prev_loopcnt(iphase)=0
            prev_ngwork(iphase)=0
         enddo
         initialized=.true.
      endif

      sameshape=cache_valid(np)
      if (sameshape) then
         if (prev_loopcnt(np).ne.loopcnt .or.
     &       prev_ngwork(np).ne.ngwork) sameshape=.false.
      endif
      sameng=sameshape
      samecf=sameshape
      samewk=sameshape
      if (sameshape) then
         do ia=1,loopcnt
            if (prev_ngnl(ia,np).ne.ngnl(ia)) sameng=.false.
            if (prev_cfac(ia,np).ne.cfac(ia)) samecf=.false.
            do ig=1,ngnl(ia)
               if (prev_work(ig,ia,np).ne.work1(ig,ia)) then
                  samewk=.false.
               endif
            enddo
         enddo
      endif
      same=sameng.and.samecf.and.samewk

      exobs(np)=exobs(np)+1
      if (cache_valid(np)) then
         if (sameng) exngsame(np)=exngsame(np)+1
         if (samecf) excfsame(np)=excfsame(np)+1
         if (samewk) exwksame(np)=exwksame(np)+1
         if (same) then
            exsame(np)=exsame(np)+1
         else
            exchanged(np)=exchanged(np)+1
         endif
      endif
      prev_loopcnt(np)=loopcnt
      prev_ngwork(np)=ngwork
      do ia=1,loopcnt
         prev_ngnl(ia,np)=ngnl(ia)
         prev_cfac(ia,np)=cfac(ia)
         do ig=1,ngnl(ia)
            prev_work(ig,ia,np)=work1(ig,ia)
         enddo
      enddo
      cache_valid(np)=.true.
      return
      end

      subroutine exnlp_reuse_report()
      implicit double precision(a-h,o-z)
      integer exobs,exsame,exchanged,ncomp
      integer exngsame,excfsame,exwksame
      common /exnlpreuse/ exobs(5),exsame(5),exchanged(5)
      common /exnlpparts/ exngsame(5),excfsame(5),exwksame(5)
      write(6,*)'FPSEID_EXNLP_REUSE_BEGIN'
      write(6,*)' phase observations equal changed equal_pct'
      do iphase=1,5
         ncomp=exsame(iphase)+exchanged(iphase)
         pct=0.d0
         if (ncomp.gt.0) pct=100.d0*dfloat(exsame(iphase))
     &                         /dfloat(ncomp)
         write(6,100)iphase,exobs(iphase),exsame(iphase),
     &              exchanged(iphase),pct
      enddo
      write(6,*)'FPSEID_EXNLP_REUSE_END'
      write(6,*)
      write(6,*)'FPSEID_EXNLP_COMPONENT_BEGIN'
      write(6,*)' phase compares ngnl_pct cfac_pct work2_pct all_pct'
      do iphase=1,5
         ncomp=exsame(iphase)+exchanged(iphase)
         png=0.d0
         pcf=0.d0
         pwk=0.d0
         pall=0.d0
         if (ncomp.gt.0) then
            png=100.d0*dfloat(exngsame(iphase))/dfloat(ncomp)
            pcf=100.d0*dfloat(excfsame(iphase))/dfloat(ncomp)
            pwk=100.d0*dfloat(exwksame(iphase))/dfloat(ncomp)
            pall=100.d0*dfloat(exsame(iphase))/dfloat(ncomp)
         endif
         write(6,110)iphase,ncomp,png,pcf,pwk,pall
      enddo
      write(6,*)'FPSEID_EXNLP_COMPONENT_END'
      write(6,*)
  100 format(1x,i5,3(1x,i12),1x,f10.3)
  110 format(1x,i5,1x,i12,4(1x,f10.3))
      return
      end
#endif

      subroutine exnlp_gemm(ng2q, work1, coef, omega, ngnl,
     &   mxbnd, nbegin, nend, loopcnt, cfac,NGcont)
      implicit double precision(a-h,o-z)
      complex*16 coef(ng2q,mxbnd), work1(NGcont,loopcnt),
     &           cfac(loopcnt), ct1(mxbnd)
      integer ngnl(loopcnt)
      integer nbndloc
      nbndloc = nend-nbegin+1
      call prof_start(27)
      call prof_start(30)
      call prof_start(38)
!$acc enter data copyin(work1(1:NGcont,1:loopcnt))
      call prof_stop(38)
      call prof_start(39)
!$acc enter data copyin(cfac(1:loopcnt),ngnl(1:loopcnt))
      call prof_stop(39)
      call prof_start(40)
!$acc enter data create(ct1(1:nbndloc))
      call prof_stop(40)
      call prof_stop(30)
      call exnlp_gemm_body(ng2q,work1,coef,omega,ngnl,
     &     mxbnd,nbegin,nend,loopcnt,cfac,NGcont,ct1)
      call prof_start(32)
!$acc exit data delete(work1(1:NGcont,1:loopcnt),cfac(1:loopcnt),
!$acc& ngnl(1:loopcnt),ct1(1:nbndloc))
      call prof_stop(32)
      call prof_stop(27)
      return
      end

      subroutine exnlp_gemm_present_inputs(ng2q, work1, coef, omega,
     &   ngnl, mxbnd, nbegin, nend, loopcnt, cfac,ngwork,reverse_order)
      implicit double precision(a-h,o-z)
      complex*16 coef(ng2q,mxbnd), work1(ngwork,loopcnt),
     &           cfac(loopcnt)
      integer ngnl(loopcnt)
      logical reverse_order
      call prof_start(27)
      call exnlp_gemm_body_fused(ng2q,work1,coef,omega,ngnl,
     &     mxbnd,nbegin,nend,loopcnt,cfac,ngwork,reverse_order)
      call prof_stop(27)
      return
      end

      subroutine exnlp_gemm_body_fused(ng2q, work1, coef, omega,
     &   ngnl, mxbnd, nbegin, nend, loopcnt, cfac,ngwork,reverse_order)
      implicit double precision(a-h,o-z)
      complex*16 coef(ng2q,mxbnd), work1(ngwork,loopcnt),
     &           cfac(loopcnt)
      integer ngnl(loopcnt)
      integer nbndloc, ja
      logical reverse_order
      real*8 sr,si,ar,ai,br,bi,cr,ci,ctr,cti
      nbndloc = nend-nbegin+1
      call prof_start(28)
!$acc parallel loop gang vector_length(256)
!$acc& present(coef(1:ng2q,1:nbndloc),
!$acc& work1(1:ngwork,1:loopcnt),cfac(1:loopcnt),
!$acc& ngnl(1:loopcnt)) private(ia,ja,sr,si,ar,ai,br,bi,
!$acc& cr,ci,ctr,cti)
      do iib = 1, nbndloc
!$acc loop seq
         do ia = 1, loopcnt
            ja = ia
            if (reverse_order) ja = loopcnt-ia+1
            sr = 0.d0
            si = 0.d0
!$acc loop vector reduction(+:sr,si)
            do ig = 1, ngnl(ja)
               ar = dble(coef(ig,iib))
               ai = dimag(coef(ig,iib))
               br = dble(work1(ig,ja))
               bi = dimag(work1(ig,ja))
               sr = sr + ar*br - ai*bi
               si = si + ar*bi + ai*br
            end do
            cr = dble(cfac(ja))
            ci = dimag(cfac(ja))
            ctr = (cr*sr-ci*si)/omega
            cti = (cr*si+ci*sr)/omega
!$acc loop vector
            do ig = 1, ngnl(ja)
               br = dble(work1(ig,ja))
               bi = dimag(work1(ig,ja))
               coef(ig,iib) = coef(ig,iib)
     &         + dcmplx(ctr*br + cti*bi, cti*br - ctr*bi)
            end do
         end do
      end do
      call prof_stop(28)
      return
      end

      subroutine exnlp_gemm_body(ng2q, work1, coef, omega, ngnl,
     &   mxbnd, nbegin, nend, loopcnt, cfac,NGcont,ct1)
      implicit double precision(a-h,o-z)
      complex*16 coef(ng2q,mxbnd), work1(NGcont,loopcnt),
     &           cfac(loopcnt), ct1(mxbnd)
      integer ngnl(loopcnt)
      integer nbndloc
      real*8 sr,si,ar,ai,br,bi,cr,ci
      nbndloc = nend-nbegin+1
      do ia = 1, loopcnt
         call prof_start(28)
!$acc parallel loop gang present(coef(1:ng2q,1:nbndloc),
!$acc& work1(1:NGcont,1:loopcnt),cfac(1:loopcnt),
!$acc& ngnl(1:loopcnt),ct1(1:nbndloc))
         do iib = 1, nbndloc
            sr = 0.d0
            si = 0.d0
!$acc loop vector reduction(+:sr,si)
            do ig = 1, ngnl(ia)
               ar = dble(coef(ig,iib))
               ai = dimag(coef(ig,iib))
               br = dble(work1(ig,ia))
               bi = dimag(work1(ig,ia))
               sr = sr + ar*br - ai*bi
               si = si + ar*bi + ai*br
            end do
            cr = dble(cfac(ia))
            ci = dimag(cfac(ia))
            ct1(iib) = dcmplx((cr*sr-ci*si)/omega,
     &                         (cr*si+ci*sr)/omega)
         end do
         call prof_stop(28)
         call prof_start(29)
!$acc parallel loop gang present(coef(1:ng2q,1:nbndloc),
!$acc& work1(1:NGcont,1:loopcnt),ngnl(1:loopcnt),
!$acc& ct1(1:nbndloc))
         do iib = 1, nbndloc
!$acc loop vector
            do ig = 1, ngnl(ia)
               coef(ig,iib) = coef(ig,iib)
     &         + ct1(iib)*dconjg(work1(ig,ia))
            end do
         end do
         call prof_stop(29)
      end do
      return
      end
C*****************************************************************
      SUBROUTINE HLOCAL( NRX, NRY, NRZ, NXYZ, NG2, NG2Q, NBND,
     &                   COEF, DCOEF, RHO1, RHO2, VG, J2G,
c *** for Sugino FFT
c     &                   WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
c     &                   LX1, LX2, LY1, LY2, LZ1, LZ2                )
c *** for Kokubo ASL FFT
c     &                   WSAVE_XYZ, IFAC_XYZ              )
c *** for Kokubo FFTW
     &                   plancfp,plancbp              )
C
      IMPLICIT REAL*8 (A-H,O-Z)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),
c     &           COEF(NG2Q,NBND),DCOEF(NG2Q,NBND),
     &           COEF(NG2Q),DCOEF(NG2Q),
     &           VG(NXYZ)
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
      DIMENSION J2G(NG2Q)
C
#ifdef _OPENACC
C     Keep both FFTs and their surrounding loops on one temporary device
C     allocation.  The host fallback below remains the reference path.
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(107)
#endif
!$acc data copyin(COEF(1:NG2),VG(1:NXYZ),J2G(1:NG2))
!$acc& copyout(DCOEF(1:NG2))
!$acc& create(RHO1(1:NXYZ),RHO2(1:NXYZ))
!$acc parallel loop present(RHO1(1:NXYZ))
         DO JG=1,NXYZ
           RHO1(JG)=(0.D0,0.D0)
         ENDDO
!$acc parallel loop present(RHO1(1:NXYZ),COEF(1:NG2),
!$acc& J2G(1:NG2))
         DO IG=1,NG2
           JG=J2G(IG)
           RHO1(JG)=COEF(IG)
         ENDDO
      CALL FFT3BX_fftwASL_ACC(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
     &                        plancfp,plancbp)
!$acc parallel loop present(RHO1(1:NXYZ),RHO2(1:NXYZ),
!$acc& VG(1:NXYZ))
         DO I=1,NXYZ
           RHO2(I)=VG(I)*RHO1(I)
         ENDDO
      CALL FFT3FX_fftwASL_ACC(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
     &                        plancfp,plancbp)
!$acc parallel loop present(RHO2(1:NXYZ),DCOEF(1:NG2),
!$acc& J2G(1:NG2))
         DO IG=1,NG2
           JG=J2G(IG)
           DCOEF(IG)=RHO2(JG)
         ENDDO
!$acc end data
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(107)
#endif
#else
C     MAIN LOOP
C
c      DO 1010 IB=1,NBND
C
         call prof_start(101)
         DO 101 JG=1,NXYZ
  101    RHO1(JG)=(0.D0,0.D0)
         call prof_stop(101)
*VDIR NODEP(RHO1)
!ocl norecurrence(RHO1)
         call prof_start(102)
         DO 100 IG=1,NG2
         JG=J2G(IG)
c  100    RHO1(JG)=COEF(IG,IB)
  100    RHO1(JG)=COEF(IG)
         call prof_stop(102)
C
c *** for Sugino FFT
c         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3BX_ASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3BX_fftw(NXYZ,RHO1,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      call prof_start(103)
      CALL FFT3BX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,plancfp,plancbp)
      call prof_stop(103)
C
C        RHO1:WAVEFN IN REAL SPACE
C        VG:POTENTIAL IN REAL SPACE
C
         call prof_start(104)
         DO 300 I=1,NXYZ
  300    RHO2(I)=VG(I)*RHO1(I)
         call prof_stop(104)
c *** for Sugino FFT
c         CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
c     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
c *** for Kokubo ASL FFT
c      CALL FFT3FX_ASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,WSAVE_XYZ,IFAC_XYZ)
c *** for Kokubo FFTW
c      call FFT3FX_fftw(NXYZ,RHO2,plancfp,plancbp)
c *** for Kokubo fftw ASL compatible
      call prof_start(105)
      CALL FFT3FX_fftwASL(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,plancfp,plancbp)
      call prof_stop(105)
C
*VDIR NODEP(RHO2)
!ocl norecurrence(RHO2)
         call prof_start(106)
         DO 110 IG=1,NG2
         JG=J2G(IG)
c  110    DCOEF(IG,IB)=RHO2(JG)
  110    DCOEF(IG)=RHO2(JG)
         call prof_stop(106)
C
c 1010 CONTINUE
C
C      CALL CLOCK(TIM1)
C     WRITE(6,*) ' NBND = ',NBND
C     WRITE(6,*) ' HLOCAL: CPTIME=',TIM1
C     WRITE(6,*) ' REAL CPU_TIME : ',(TIM1-TIM0)/DBLE(NBND)
#endif
      RETURN
      END
C*****************************************************************
      SUBROUTINE NONLOC( NXYZ, NG2, NG2Q, NBND,
     &                   COEF, DCOEF, YLM, G2, RHO2, RHOA, TPIBA,
     &                   WORK2, VPJ, VPP, OMEGA, NTAUQ, NTYQ,
     &     NTYPE, LREQ, TAU, NUMTY, NIDN, IOVP, MXOFL,GDUMP,NGNL,
     &     NGcont,IYLM_REUSE)
C
C                                   (1990-04-12) OSAMU SUGINO
C        INPUT  COEF
C
      IMPLICIT REAL*8 (A-H,O-Z)
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,4)
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,9)
      REAL*8 RHOA(NXYZ),YLM(NGcont,16)
      COMPLEX*16 RHO2(NXYZ),
     &           COEF(NG2Q),DCOEF(NG2Q),
c     &           WORK2(NG2Q,3)
c     &           WORK2(NG2Q,5)
     &           WORK2(NG2Q,7)
      DIMENSION G2(4,NG2Q),GDUMP(NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ), MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ)
c      DIMENSION VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ),IOVP(2,NTYQ)
      DIMENSION VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ),IOVP(2,NTYQ)
      dimension NGNL(NTYQ)
      PI=4.D0*ATAN(1.D0)
      TPI=2.D0*PI
      FPI=4.D0*PI
      TPIBA2=TPIBA**2
C
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(108)
#endif
         DO 581 IG=1,NG2
c         RHOA(IG)=G2(4,IG)*0.5D0*TPIBA2
         RHOA(IG)=GDUMP(IG)*0.5D0*TPIBA2
  581    CONTINUE
         DO 584 IG=1,NG2
  584    DCOEF(IG)=DCOEF(IG)+RHOA(IG)*COEF(IG)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(108)
      call prof_start(109)
#endif
C
c **  temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)' in sub. NONLOC before calling get YLM '
c      write(6,*)' TPIBA = ',TPIBA
c      write(6,*)' G2(4,ig ) '
c      write(6,*) ( G2(4,ig),ig=1,1500,100 )
c      stop ' check end '
c      endif
c **  temp check : end 
         IF (IYLM_REUSE.EQ.0) THEN
          DO 588 IG=1,NG2
  588     RHOA(IG)=SQRT(G2(4,IG))*TPIBA
          NG26=NGcont
          CALL GETYLM(NG2Q,NG26,G2,RHOA,YLM,TPIBA,NGcont)
         ENDIF
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(109)
      call prof_start(110)
#endif
c  ************************************
         CALL SEPPOT( NG2Q, NG2, NBND, G2,
     &   VPJ, VPP, YLM, RHO2, WORK2(1,1), WORK2(1,2),WORK2(1,3),
     &   WORK2(1,4),WORK2(1,5),WORK2(1,6),WORK2(1,7),
     &   COEF, DCOEF, TPIBA, IOVP, OMEGA,
     &                NTAUQ, NTYQ, LREQ, TAU, NTYPE, NUMTY, NIDN,
     &                MXOFL,NGNL,NGcont                       )
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(110)
#endif
  580 CONTINUE
C     CALL CLOCK(TIM1)
C     WRITE(6,*) ' NBND = ',NBND
C     WRITE(6,*) ' NONLOC CPTIME:',TIM1-TIM0
C     WRITE(6,*) ' REAL CPU_TIME : ',(TIM1-TIM0)/DBLE(NBND)
      RETURN
      END
C***********************************************************
      SUBROUTINE GETYLM(NG2Q,NG2,G2K,RHOA,YLM,TPIBA,NGcont)
      IMPLICIT REAL*8(A-H,O-Z)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,4),RHOA(NG2Q)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,9),RHOA(NG2Q)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,16),RHOA(NG2Q)
      DIMENSION G2K(4,NG2Q),YLM(NGcont,16),RHOA(NG2Q)
C                                      __
c *** temp check
c      if (NG2.gt.NG2Q/6 ) then
c       write(6,*)' *** WARN in GETYLM !!! NG2 =',NG2
cc       stop
c      endif
c *** temp check : end
cC   note: F20,F21,F22 are xsqr(2) of those in cg and sd codes
      PI=4.D0*ATAN(1.D0)
      F00=SQRT( 1.D0 / ( 4.D0*PI) )
      F10=SQRT( 3.D0 / ( 4.D0*PI) )
      F11=SQRT( 3.D0 / ( 8.D0*PI) )
      F20=SQRT( 5.d0 / (16.d0*PI) )
      F22=SQRT(15.d0 / (16.d0*PI) ) ! x sqr2
      F21=SQRT(15.d0 / ( 4.d0*PI) ) ! x sqr2
      F30=SQRT( 7.D0 / (16.d0*PI) )
      F31=SQRT(21.d0 / (32.D0*PI) ) ! x sqr2
      F32=SQRT(105.D0/ (16.D0*PI) ) ! x sqr2
      F33=SQRT(35.D0 / (32.D0*PI) ) ! x sqr2
c ***
c      PI=4.D0*ATAN(1.D0)
c      F00=SQRT( 1.D0 / ( 4.D0*PI) )
c      F10=SQRT( 3.D0 / ( 4.D0*PI) )
c      F11=SQRT( 3.D0 / ( 8.D0*PI) )
c      F20=SQRT( 5.d0 / (16.d0*PI) ) 
c      F22=SQRT(15.d0 / (32.d0*PI) )
c      F21=SQRT(15.d0 / ( 8.d0*PI) ) 
c      F30=SQRT( 7.D0 / (16.d0*PI) )
c      F31=SQRT(21.d0 / (64.D0*PI) )
c      F32=SQRT(105.D0/ (32.D0*PI) )
c      F33=SQRT(35.D0 / (64.D0*PI) )
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
c **  temp check
c      miya=13
c      if ( miya.eq.13 ) then
c      write(6,*)' in sub. GETYLM ISTA = ',ISTA
c      write(6,*)' TPIBA = ',TPIBA
c      write(6,*)' RHOA '
c      write(6,*)( RHOA(ig),ig=1,1500,100 )
cccc      stop  'checking '
c      endi
c **  temp check : end
      DO 10 IG=ISTA,NG2
      R=RHOA(IG)/TPIBA
      R2=R*R
      R3=R2*R
c***  temp check
c     G2LEN=G2k(1,IG)**2+G2k(2,ig)**2+G2k(3,ig)**2 !This gives the same answer
c     R=dsqrt(G2LEN)
c **  temp check : end
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
      RETURN
      END
C****************************************************************
      SUBROUTINE SEPPOT( NG2Q, NG2, NBND, G2K, VPJ, VPP,
c     &                   YLM, EXTAU, WORK1, WORK2, WORK3, COEF, DCOEF,
     &  YLM, EXTAU, WORK1, WORK2, WORK3, WORK4, WORK5,WORK6,WORK7,
     & COEF, DCOEF,
     &                   TPIBA, IOVP, OMEGA, NTAUQ, NTYQ, LREQ,
     &                   TAU, NTYPE, NUMTY, NIDN, MXOFL,NGNL,NGcont )
C
C               PARTITIONED POTENTIAL (1992-02-28) OSAMU SUGINO
C
      IMPLICIT REAL*8(A-H,O-Z)
      include 'mpif.h'
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,4)
c      DIMENSION G2K(4,NG2Q),YLM(NG2Q,9)
      DIMENSION G2K(4,NG2Q),YLM(NGcont,16)
c      COMPLEX*16 COEF(NG2Q,NBND),DCOEF(NG2Q,NBND),
      COMPLEX*16 COEF(NG2Q),DCOEF(NG2Q),
c     &           WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),EXTAU(NG2Q)
     & WORK1(NG2Q),WORK2(NG2Q),WORK3(NG2Q),WORK4(NG2Q),WORK5(NG2Q),
     & WORK6(NG2Q),WORK7(NG2Q),EXTAU(NG2Q)
      COMPLEX*16 Y00,Y11,Y12,Y13,Y21,Y22,Y23,Y24,Y25
     &  ,Y31,Y32,Y33,Y34,Y35,Y36,Y37
     &          ,CT1,CT2,CT3,CT4,CT5,CT6,CT7
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),
c     &          VPJ(NG2Q,3),VPP(3),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &  VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &  VPJ(NG2Q/3,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
c     &  VPJ(NG2Q/3,3,3,NTYQ),VPP(3,3,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
     &  VPJ(NGcont,3,4,NTYQ),VPP(3,4,NTYQ),IOVP(2,NTYQ), MXOFL(NTYQ)
      dimension NGNL(NTYQ)
      PARAMETER(NTYQ2=4)
c      COMMON/SAITO2/IBUN(3,NTYQ2)
      COMMON/SAITO2/IBUN(4,NTYQ2)
CC      CALL CLOCK(TIM1)
c
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c
c *** temp check
c      if ( my_ranl.eq.0 ) then
c       sum=0
c       do ig=1,ng2q
c        sum=sum+dreal( dconjg(coef(ig))*coef(ig))
c       enddo
c      write(6,*)'in sub. SEPPOT: coef norm = ',sum
c      endif
c *** temp check: end
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
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(111)
#endif
c        DO 22 IG=1,NG2
        DO 22 IG=1,NGNL(ITY)
        TEMP=TPIBA*(G2K(1,IG)*TAU(1,ITAU)+G2K(2,IG)*TAU(2,ITAU)
     &             +G2K(3,IG)*TAU(3,ITAU))
        EXTAU(IG)=DCMPLX(COS(TEMP),SIN(TEMP))
   22   CONTINUE
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(111)
#endif
C
      DO 30 LI=1,LMAX
      L=LI-1
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(112+L)
#endif
ccc      READ(82,REC=IOVP(LI,ITY)) VPP, VPJ
C
      IF(L.EQ.0.AND.IBUN(1,ITY).NE.1) THEN
C             NO PARTITIONING
c         DO 50 IG=1,NG2
         DO 50 IG=1,NGNL(ITY)
         Y00=DCMPLX(YLM(IG,1),0.D0)
   50    WORK1(IG)=Y00*EXTAU(IG)*VPJ(IG,1,LI,ITY)
c         DO 52 IB=1,NBND
            CT1=(0.D0,0.D0)
c            DO 54 IG=1,NG2
            DO 54 IG=1,NGNL(ITY)
c   54       CT1=CT1+COEF(IG,IB)*WORK1(IG)
   54       CT1=CT1+COEF(IG)*WORK1(IG)
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
c            DO 56 IG=1,NG2
            DO 56 IG=1,NGNL(ITY)
c   56       DCOEF(IG,IB)=DCOEF(IG,IB)+CT1*DCONJG(WORK1(IG))
   56       DCOEF(IG)=DCOEF(IG)+CT1*DCONJG(WORK1(IG))
c   52    CONTINUE
      ELSEIF(L.EQ.0) THEN
C             PARTITIONING
         DO 1200 IP=2,3
c         DO 1050 IG=1,NG2
         DO 1050 IG=1,NGNL(ITY)
           Y00=DCMPLX(YLM(IG,1),0.D0)
 1050      WORK1(IG)=Y00*EXTAU(IG)*VPJ(IG,IP,LI,ITY)
c         DO 1052 IB=1,NBND
            CT1=(0.D0,0.D0)
c            DO 1054 IG=1,NG2
            DO 1054 IG=1,NGNL(ITY)
c 1054       CT1=CT1+COEF(IG,IB)*WORK1(IG)
 1054       CT1=CT1+COEF(IG)*WORK1(IG)
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
c            DO 1056 IG=1,NG2
            DO 1056 IG=1,NGNL(ITY)
c 1056         DCOEF(IG,IB)=DCOEF(IG,IB)+CT1*DCONJG(WORK1(IG))
 1056         DCOEF(IG)=DCOEF(IG)+CT1*DCONJG(WORK1(IG))
c 1052    CONTINUE
 1200    CONTINUE
c +*** temp check for lowest band
c          if(my_rank.eq.0 ) then
c          write(6,*)'ity iatm li = ',ity,iatm,li
c          sum=0
c          do ig=1,NGNL(ITY)
c           sum=sum+dreal(DCONJG(DCOEF(IG))*COEF(IG))
c          enddo
c          write(6,*)'sum =',sum
c          endif
c *** temp check : end
      ELSEIF(L.EQ.1.AND.IBUN(2,ITY).NE.1) THEN
C             NO PARTITIONING
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(116)
#endif
c         DO 60 IG=1,NG2
         DO 60 IG=1,NGNL(ITY)
         Y11=DCMPLX( YLM(IG,2), 0.D0)
         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
         WORK1(IG)=EXTAU(IG)*Y11*VPJ(IG,1,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y12*VPJ(IG,1,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y13*VPJ(IG,1,LI,ITY)
   60    CONTINUE
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(116)
      call prof_start(117)
#endif
c         DO 62 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
c            DO 64 IG=1,NG2
            DO 64 IG=1,NGNL(ITY)
c            CT1=CT1+COEF(IG,IB)*WORK1(IG)
c            CT2=CT2+COEF(IG,IB)*WORK2(IG)
c            CT3=CT3+COEF(IG,IB)*WORK3(IG)
            CT1=CT1+COEF(IG)*WORK1(IG)
            CT2=CT2+COEF(IG)*WORK2(IG)
            CT3=CT3+COEF(IG)*WORK3(IG)
   64       CONTINUE
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
            CT2=CT2/VPP(1,LI,iTY)/OMEGA
            CT3=CT3/VPP(1,LI,ITY)/OMEGA
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(117)
      call prof_start(118)
#endif
c            DO 66 IG=1,NG2
            DO 66 IG=1,NGNL(ITY)
c            DCOEF(IG,IB)=DCOEF(IG,IB)
            DCOEF(IG)=DCOEF(IG)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
   66       CONTINUE
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(118)
#endif
c   62    CONTINUE
      ELSEIF(L.EQ.1) THEN
C             PARTITIONING
         DO 1261 IP=2,3
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_start(116)
#endif
c         DO 61 IG=1,NG2
         DO 61 IG=1,NGNL(ITY)
         Y11=DCMPLX( YLM(IG,2), 0.D0)
         Y12=DCMPLX(-YLM(IG,3),YLM(IG,4))
         Y13=DCMPLX( YLM(IG,3),YLM(IG,4))
         WORK1(IG)=EXTAU(IG)*Y11*VPJ(IG,IP,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y12*VPJ(IG,IP,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y13*VPJ(IG,IP,LI,ITY)
   61    CONTINUE
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(116)
      call prof_start(117)
#endif
c         DO 63 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
c            DO 65 IG=1,NG2
            DO 65 IG=1,NGNL(ITY)
c            CT1=CT1+COEF(IG,IB)*WORK1(IG)
c            CT2=CT2+COEF(IG,IB)*WORK2(IG)
c            CT3=CT3+COEF(IG,IB)*WORK3(IG)
            CT1=CT1+COEF(IG)*WORK1(IG)
            CT2=CT2+COEF(IG)*WORK2(IG)
            CT3=CT3+COEF(IG)*WORK3(IG)
   65       CONTINUE
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
            CT2=CT2/VPP(IP,LI,ITY)/OMEGA
            CT3=CT3/VPP(IP,LI,iTY)/OMEGA
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(117)
      call prof_start(118)
#endif
c            DO 67 IG=1,NG2
            DO 67 IG=1,NGNL(ITY)
c            DCOEF(IG,IB)=DCOEF(IG,IB)
            DCOEF(IG)=DCOEF(IG)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
   67       CONTINUE
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(118)
#endif
c   63    CONTINUE
c +*** temp check for lowest band
c          if (my_rank.eq.0 ) then
c          write(6,*)'ity iatm li = ',ity,iatm,li
c          sum=0
c          do ig=1,NGNL(ITY)
c           sum=sum+dreal(DCONJG(DCOEF(IG))*COEF(IG))
c          enddo
c          write(6,*)'sum =',sum
c          endif
c *** temp check : end
 1261    CONTINUE
      ELSEIF(L.EQ.2.AND.IBUN(3,ITY).NE.1) THEN
c *** temp check
c         if (my_rank.eq.0 ) then
c         write(6,*)' in SEPPOT'
c         write(6,*)' NGNL for d-',NGNL(ITY)
c         write(6,*)' YLM 5 '
c         write(6,*)(YLM(IG,5),IG=1,100,10)
c         write(6,*)' EXTAU '
c         write(6,*)(EXTAU(IG),IG=1,100,10)
c         write(6,*)' VPJ( partition 1'
c         write(6,*)( VPJ(IG,1,li,ity),IG=1,100,10)
c         endif
c *** temp check: end
C         NO PARTITIONING need 1/sq2 because of YLM definition
         wari=1.d0/dsqrt(2.d0) ! I am sceptical on this!
c         wari=1.d0
         DO 81 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0)
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7))*wari
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7))*wari
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9))*wari
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9))*wari
         WORK1(IG)=EXTAU(IG)*Y21*VPJ(IG,1,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y22*VPJ(IG,1,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y23*VPJ(IG,1,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y24*VPJ(IG,1,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y25*VPJ(IG,1,LI,ITY)
   81    CONTINUE
c *** temp check
c         if (my_rank.eq.0) then
c         write(6,*)' work1 '
c         write(6,*)(work1(ig),ig=1,100,10)
c         write(6,*)' work2 '
c         write(6,*)(work2(ig),ig=1,100,10)
c         write(6,*)' work3 '
c         write(6,*)(work3(ig),ig=1,100,10)
c         write(6,*)' work4 '
c         write(6,*)(work4(ig),ig=1,100,10)
c         write(6,*)' work4 '
c         write(6,*)(work5(ig),ig=1,100,10)
c         endif
c *** temp check : end
c *** temp check
c         write(6,*)'IN SEPPOT VPJ for d',VPJ(100,1,3,ITY)
c         write(6,*)'IN SEPPOT YLM 5',YLM(100,5)
c         write(6,*)'IN SEPPOT WORK 5',WORK5(100)
c *** temp check : end
cccc         DO 82 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            DO 83 IG=1,NGNL(ITY)
c            CT1=CT1+COEF(IG,IB)*WORK1(IG)
c            CT2=CT2+COEF(IG,IB)*WORK2(IG)
c            CT3=CT3+COEF(IG,IB)*WORK3(IG)
c            CT4=CT4+COEF(IG,IB)*WORK4(IG)
c            CT5=CT5+COEF(IG,IB)*WORK5(IG)
            CT1=CT1+COEF(IG)*WORK1(IG)
            CT2=CT2+COEF(IG)*WORK2(IG)
            CT3=CT3+COEF(IG)*WORK3(IG)
            CT4=CT4+COEF(IG)*WORK4(IG)
            CT5=CT5+COEF(IG)*WORK5(IG)
   83       CONTINUE
c *** temp check
c      if ( my_ranl.eq.0 ) then
c       sum=0
c       do ig=1,ng2q
c        sum=sum+dreal( dconjg(coef(ig))*coef(ig))
c       enddo
c      write(6,*)'again. SEPPOT: coef norm = ',sum
c      endif
c *** temp check: end
c *** temp check
c            if (my_rank.eq.0 ) then
c             write(6,*)' before dev. by VPP'
c             write(6,*)'CT1=',CT1
c             write(6,*)'CT2=',CT2
c             write(6,*)'CT3=',CT3
c             write(6,*)'CT4=',CT4
c             write(6,*)'CT5=',CT5
c            endif
c *** temp check : end
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
            CT2=CT2/VPP(1,LI,ITY)/OMEGA
            CT3=CT3/VPP(1,LI,ITY)/OMEGA
            CT4=CT4/VPP(1,LI,ITY)/OMEGA
            CT5=CT5/VPP(1,LI,ITY)/OMEGA
c *** temp check
c            if (my_rank.eq.0 ) then
c             write(6,*)' after dev. by VPP'
c             write(6,*)'CT1=',CT1
c             write(6,*)'CT2=',CT2
c             write(6,*)'CT3=',CT3
c             write(6,*)'CT4=',CT4
c             write(6,*)'CT5=',CT5
c            endif
c *** temp check : end
            DO 84 IG=1,NGNL(ITY)
c            DCOEF(IG,IB)=DCOEF(IG,IB)
            DCOEF(IG)=DCOEF(IG)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
   84       CONTINUE
cccc   82    CONTINUE
c +*** temp check for lowest band
c          if (my_rank.eq.0 ) then
c          write(6,*)'ity iatm li = ',ity,iatm,li
c          sum=0
c          do ig=1,NGNL(ITY)
c           sum=sum+dreal(DCONJG(DCOEF(IG))*COEF(IG))
c          enddo
c          write(6,*)'sum =',sum
c          endif
c *** temp check : end
      ELSEIF(L.EQ.2) THEN
C             PARTITIONING
c  **** need factor 1/sq2 because of YLM definition
         wari=1.d0/dsqrt(2.d0) ! I am sceptical on this
c         wari=1.d0
         DO 1262 IP=2,3
         DO 71 IG=1,NGNL(ITY)
         Y21=DCMPLX( YLM(IG,5), 0.D0)
         Y22=DCMPLX( YLM(IG,6), YLM(IG,7))*wari
         Y23=DCMPLX( YLM(IG,6),-YLM(IG,7))*wari
         Y24=DCMPLX(-YLM(IG,8),-YLM(IG,9))*wari
         Y25=DCMPLX( YLM(IG,8),-YLM(IG,9))*wari
         WORK1(IG)=EXTAU(IG)*Y21*VPJ(IG,IP,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y22*VPJ(IG,IP,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y23*VPJ(IG,IP,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y24*VPJ(IG,IP,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y25*VPJ(IG,IP,LI,ITY)
   71    CONTINUE
ccc         DO 72 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            DO 73 IG=1,NGNL(ITY)
c            CT1=CT1+COEF(IG,IB)*WORK1(IG)
c            CT2=CT2+COEF(IG,IB)*WORK2(IG)
c            CT3=CT3+COEF(IG,IB)*WORK3(IG)
c            CT4=CT4+COEF(IG,IB)*WORK4(IG)
c            CT5=CT5+COEF(IG,IB)*WORK5(IG)
            CT1=CT1+COEF(IG)*WORK1(IG)
            CT2=CT2+COEF(IG)*WORK2(IG)
            CT3=CT3+COEF(IG)*WORK3(IG)
            CT4=CT4+COEF(IG)*WORK4(IG)
            CT5=CT5+COEF(IG)*WORK5(IG)
   73       CONTINUE
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
            CT2=CT2/VPP(IP,LI,ITY)/OMEGA
            CT3=CT3/VPP(IP,LI,ITY)/OMEGA
            CT4=CT4/VPP(IP,LI,ITY)/OMEGA
            CT5=CT5/VPP(IP,LI,ITY)/OMEGA
            DO 74 IG=1,NGNL(ITY)
c            DCOEF(IG,IB)=DCOEF(IG,IB)
            DCOEF(IG)=DCOEF(IG)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
   74       CONTINUE
ccc   72    CONTINUE
 1262    CONTINUE
      ELSEIF(L.EQ.3.AND.IBUN(4,ITY).NE.1) THEN
C             NO PARTITIONING
         wari=1.d0/dsqrt(2.d0) 
c         DO 91 IG=1,NG2
         DO 91 IG=1,NGNL(ITY)
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))*wari
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))*wari
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))*wari
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))*wari
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))*wari
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))*wari
         WORK1(IG)=EXTAU(IG)*Y31*VPJ(IG,1,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y32*VPJ(IG,1,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y33*VPJ(IG,1,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y34*VPJ(IG,1,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y35*VPJ(IG,1,LI,ITY)
         WORK6(IG)=EXTAU(IG)*Y36*VPJ(IG,1,LI,ITY)
         WORK7(IG)=EXTAU(IG)*Y37*VPJ(IG,1,LI,ITY)
   91    CONTINUE
c         DO 92 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            CT6=(0.D0,0.D0)
            CT7=(0.D0,0.D0)
c            DO 93 IG=1,NG2
            DO 93 IG=1,NGNL(ITY)
            CT1=CT1+COEF(IG)*WORK1(IG)
            CT2=CT2+COEF(IG)*WORK2(IG)
            CT3=CT3+COEF(IG)*WORK3(IG)
            CT4=CT4+COEF(IG)*WORK4(IG)
            CT5=CT5+COEF(IG)*WORK5(IG)
            CT6=CT6+COEF(IG)*WORK6(IG)
            CT7=CT7+COEF(IG)*WORK7(IG)
   93       CONTINUE
            CT1=CT1/VPP(1,LI,ITY)/OMEGA
            CT2=CT2/VPP(1,LI,ITY)/OMEGA
            CT3=CT3/VPP(1,LI,ITY)/OMEGA
            CT4=CT4/VPP(1,LI,ITY)/OMEGA
            CT5=CT5/VPP(1,LI,ITY)/OMEGA
            CT6=CT6/VPP(1,LI,ITY)/OMEGA
            CT7=CT7/VPP(1,LI,ITY)/OMEGA
c            DO 94 IG=1,NG2
            DO 94 IG=1,NGNL(ITY)
            DCOEF(IG)=DCOEF(IG)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
     &           +CT6*DCONJG(WORK6(IG))
     &           +CT7*DCONJG(WORK7(IG))
   94       CONTINUE
c   92    CONTINUE
      ELSEIF(L.EQ.3) then
C             PARTITIONING
         wari=1.d0/dsqrt(2.d0)
         DO 2262 IP=2,3
c         DO 101 IG=1,NG2
         DO 101 IG=1,NGNL(ITY)
         Y31=DCMPLX( YLM(IG,10), 0.D0)
         Y32=DCMPLX(-YLM(IG,11),-YLM(IG,12))*wari
         Y33=DCMPLX( YLM(IG,11),-YLM(IG,12))*wari
         Y34=DCMPLX( YLM(IG,13), YLM(IG,14))*wari
         Y35=DCMPLX( YLM(IG,13),-YLM(IG,14))*wari
         Y36=DCMPLX(-YLM(IG,15),-YLM(IG,16))*wari
         Y37=DCMPLX( YLM(IG,15),-YLM(IG,16))*wari
         WORK1(IG)=EXTAU(IG)*Y31*VPJ(IG,IP,LI,ITY)
         WORK2(IG)=EXTAU(IG)*Y32*VPJ(IG,IP,LI,ITY)
         WORK3(IG)=EXTAU(IG)*Y33*VPJ(IG,IP,LI,ITY)
         WORK4(IG)=EXTAU(IG)*Y34*VPJ(IG,IP,LI,ITY)
         WORK5(IG)=EXTAU(IG)*Y35*VPJ(IG,IP,LI,ITY)
         WORK6(IG)=EXTAU(IG)*Y36*VPJ(IG,IP,LI,ITY)
         WORK7(IG)=EXTAU(IG)*Y37*VPJ(IG,IP,LI,ITY)
  101    CONTINUE
c         DO 102 IB=1,NBND
            CT1=(0.D0,0.D0)
            CT2=(0.D0,0.D0)
            CT3=(0.D0,0.D0)
            CT4=(0.D0,0.D0)
            CT5=(0.D0,0.D0)
            CT6=(0.D0,0.D0)
            CT7=(0.D0,0.D0)
c            DO 103 IG=1,NG2
            DO 103 IG=1,NGNL(ITY)
            CT1=CT1+COEF(IG)*WORK1(IG)
            CT2=CT2+COEF(IG)*WORK2(IG)
            CT3=CT3+COEF(IG)*WORK3(IG)
            CT4=CT4+COEF(IG)*WORK4(IG)
            CT5=CT5+COEF(IG)*WORK5(IG)
            CT6=CT6+COEF(IG)*WORK6(IG)
            CT7=CT7+COEF(IG)*WORK7(IG)
  103       CONTINUE
            CT1=CT1/VPP(IP,LI,ITY)/OMEGA
            CT2=CT2/VPP(IP,LI,ITY)/OMEGA
            CT3=CT3/VPP(IP,LI,ITY)/OMEGA
            CT4=CT4/VPP(IP,LI,ITY)/OMEGA
            CT5=CT5/VPP(IP,LI,ITY)/OMEGA
            CT6=CT6/VPP(IP,LI,ITY)/OMEGA
            CT7=CT7/VPP(IP,LI,ITY)/OMEGA
c            DO 104 IG=1,NG2
            DO 104 IG=1,NGNL(ITY)
            DCOEF(IG)=DCOEF(IG)
     &           +CT1*DCONJG(WORK1(IG))
     &           +CT2*DCONJG(WORK2(IG))
     &           +CT3*DCONJG(WORK3(IG))
     &           +CT4*DCONJG(WORK4(IG))
     &           +CT5*DCONJG(WORK5(IG))
     &           +CT6*DCONJG(WORK6(IG))
     &           +CT7*DCONJG(WORK7(IG))
  104    CONTINUE
c  102    CONTINUE
 2262 CONTINUE
      ELSE
       if ( my_rank.eq.0 ) then
       write(6,*)' in sub. SEPPOT '
       write(6,*)' ILL ORB IS INDICATED OR MORE THAN TWO PARTIONING '
       endif
      stop
      ENDIF
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      call prof_stop(112+L)
#endif
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' ITY IATM LI =',ITY,IATM,LI 
c        sum=0
c        do ig=1,ngnl(ity)
c         sum=sum+dreal( DCONJG( DCOEF(IG) )*COEF(IG) )
c        enddo
c      write(6,*)' sum = ',sum
c      endif
c *** temp check: end
   30 CONTINUE
   20 CONTINUE
   10 CONTINUE
C     CALL CLOCK(TIM2)
C     WRITE(6,*) ' SEPPOT USED TIME=',TIM2-TIM1
C     STOP
      RETURN
      END
c
c
      subroutine zero(a,m)
      complex*16 a(m)
      do 1 i=1,m
    1 a(i)=dcmplx(0.d0,0.d0)
      return
      end
