C
C------------PROGRAM UNIT SDDIAG-------------------------
C********************************************************
C                                (1990-11-28) OSAMU SUGINO
C          TO ADAPT YAMAUCHI PRG (1992-04-27) OSAMU SUGINO
C                NOTE THAT NBNDQ=NBND
C
C          SDDIAG---HLOCAL
C                 1
C                 --NONLOC
C                 1
C                 --ortho
C                 1
C                 --diag--zheevvl (by Prof. Y. Yoshimoto
C
C**************************************************************
      SUBROUTINE SDDIAG( OSHI,ITCF,NRX,NRY,NRZ, NXYZ, NG2, NG2Q,
c     &                   NBNDQ, NBND, P, HP, PJ, HPJ, CL1, CL2,
c     &                   NBNDQ, NBND, P, HP, CL1,
     &                   NBNDQ, NBND, P, HP, 
c     &                   CL3, HD, HDO, YLM, G2, RHO1, RHO2, RHO3,
     &      YLM, G2,GDUMP, RHO1, RHO2, RHO3,
     &                   TPIBA, VG, J2G, WORK2, OUT, VPJ,
     &                   VPP,
     &                   IOWF, IOVP, MXBND, MBLK,
     &               OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c     &                   NIDN, EE, WSAVEX, WSAVEY, WSAVEZ, IFACX,
     &  NIDN, EE,EE2,EE3,EE4, WSAVEX, WSAVEY, WSAVEZ, IFACX,
     &               IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2,
     &  MXOFL,sig,x0,x1,work1,work20 ,isd,NGNL)
C
      IMPLICIT REAL*8(A-H,O-Z)
      COMPLEX*16  P(NG2Q,MXBND), HP(NG2Q,MXBND)
c     &            ,PJ(NG2Q,MXBND), HPJ(NG2Q,MXBND)
c      COMPLEX*16 CL1(NG2Q,MXBND),CL2(NG2Q,MXBND),CL3(NG2Q,MXBND)
c      COMPLEX*16 HD(NG2Q,MXBND),HDO(NG2Q,MXBND)
c      COMPLEX*16 CL1(NG2Q,MXBND)
      COMPLEX*16 CTEMP
      DIMENSION IOWF(MBLK),IOVP(2,NTYQ)
C
c      REAL*8 YLM(NG2Q,4),OUT(NBNDQ,3),EE(NBNDQ)
c      REAL*8 YLM(NG2Q,9),OUT(NBNDQ,3),EE(NBNDQ)
      REAL*8 YLM(NG2Q,16),OUT(NBNDQ,3),EE(NBNDQ)
      REAL*8 EE2(NBNDQ),EE3(NBNDQ),EE4(NBNDQ)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),
c     &           VG(NXYZ),WORK2(NG2Q,3)
c     &           VG(NXYZ),WORK2(NG2Q,5)
     &           VG(NXYZ),WORK2(NG2Q,7)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      DIMENSION J2G(NG2Q),G2(4,NG2Q),GDUMP(NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ)
c      DIMENSION VPJ(NG2Q,3,3,NTYQ),VPP(3,3,NTYQ)
      DIMENSION VPJ(NG2Q,3,4,NTYQ),VPP(3,4,NTYQ)
      dimension NGNL(NTYQ)
ccc
c     work area for orthogonization
      complex*16  sig(mxbnd,mxbnd),x0(mxbnd,mxbnd),
     &    x1(mxbnd,mxbnd),work1(mxbnd,mxbnd),work20(mxbnd,mxbnd)
C
      DATA IFIL2,IFIL3,IFIL4,IFIL5,IFIL6,IFIL7
     &     /  30,   32,   33,   34,   35,   36/
CCC      CALL CLOCK(TIM0)
      PI=4.D0*ATAN(1.D0)
      TPIBA2=TPIBA**2
C
      NJ=MXBND
c 
C     CG LOOP BEGINS HERE
C
c      isd=0
      DO 2000 ITC=1,ITCF
c *** temp 
      write(6,*)' ITC = ',ITC,' isd = ',isd
c *** temp ; end 
c  ***  reset HP
      do ib=1,nj
       do ig=1,ng2
       HP(ig,ib)=dcmplx(0.d0,0.d0)
       enddo
      enddo 
c  ***  reset CL1
c      do ib=1,nj
c       do ig=1,ng2
c       CL1(ig,ib)=dcmplx(0.d0,0.d0)
c       enddo
c      enddo 
C
      CALL HLOCAL( NRX, NRY, NRZ, NXYZ, NG2, NG2Q, NJ,
     &             P, HP, RHO1, RHO2, VG, J2G, WSAVEX, WSAVEY, WSAVEZ,
     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2  )
      CALL NONLOC( NXYZ, NG2, NG2Q, NJ,
     &     P, HP, YLM, G2,GDUMP, RHO2, RHO3, TPIBA, WORK2, VPJ,
     &             VPP, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
     &             NIDN, IOVP, MXOFL, 1,NGNL         )
c
c *** CALCULATE EXPECTATION VALUES
        DO JB=1,NJ
         TEMP=0.D0
          DO 68 IG=1,NG2
   68     TEMP=TEMP+DBLE(DCONJG(P(IG,JB))*HP(IG,JB))
         EE(JB)=TEMP
         OUT(JB,1)=TEMP*27.212D0
        ENDDO
c ***  temp check
c       write(6,*)' check just after HLOCAL NONLOC in sddiag 3'
c       write(6,*)' ITC = ',ITC
c       write(6,*)' expecation values EE '
c       write(6,'(5f12.6)')( EE(jb),jb=1,nj)
c ***  temp check: end
C
      if ( isd.eq.1 ) then
c  **** start the case of isd=1
C
c      CALL HLOCAL( NRX, NRY, NRZ, NXYZ, NG2, NG2Q, NJ,
c     &             HP,CL1, RHO1, RHO2, VG, J2G, WSAVEX, WSAVEY, WSAVEZ,
c     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2  )
cC
c      CALL NONLOC( NXYZ, NG2, NG2Q, NJ,
c     &       HP,CL1, YLM, G2,GDUMP, RHO2, RHO3, TPIBA, WORK2, VPJ,
c     &             VPP, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU, NUMTY,
c     &             NIDN, IOVP, MXOFL,0,NGNL                )
cC
c ***  guess step for Steepest Descent
C 
C
CC    CALCULATE  EE2  EE3  EE4
C
c        DO 69 JB=1,NJ
c        temp2=0
c        temp3=0
c        temp4=0
c         do ig=1,ng2
c         temp2=temp2+DBLE(DCONJG(HP(IG,JB))*HP(IG,JB))
c         temp3=temp3+DBLE(DCONJG(HP(IG,JB))*CL1(IG,JB))
c         temp4=temp4+DBLE(DCONJG(CL1(IG,JB))*CL1(IG,JB))
c         enddo
c        EE2(JB)=TEMP2
c        EE3(JB)=TEMP3
c        EE4(JB)=TEMP4
c   69   continue
c ***  temp check
       write(6,*)' ITC = ',ITC
       write(6,*)' expecation values '
       write(6,'(5f12.6)')( out(jb,1),jb=1,nj)
c ***  temp check: end
C
c ***  guess step : step for Steepest Descent
C 
c      anum=0
c      deno=0
c      do JB=1,NJ
c      anum=anum+EE3(JB)-2*EE(JB)*EE2(JB)
c     &         + EE(JB)**3
c      deno=deno+EE4(JB)-2*EE(JB)*EE3(JB)
c     &         + EE(JB)**2*EE2(JB)
c      enddo      
c      step=-anum/deno
      crite=-0.00001d0
C
c      if ( step.gt.0 .or. step.lt.crite) then
c       write(6,*)' WARNING : step = ',step
c       write(6,*)' Then step is set to ',crite
c       step=crite
c      else
c       write(6,*)' SD step = ',step
c      endif
      step=crite
c
C     CALCULATE UPDATED WAVEFUNCTIONS
C
        DO 109 IB=1,NJ
          DO 109 IG=1,NG2
  109     P(IG,IB)=P(IG,IB)+step*HP(IG,IB)
c ****
c       write(6,*)' check point 1: ended'
c
      elseif ( isd.eq.0 ) then
c *** Start the preconditioning approach
      do ib=1,nj
        SUM=0.D0
c        SUM1=0.D0
          DO 583 IG=1,NG2
c          SUM1=SUM1+DBLE(P(IG,IB)*DCONJG(P(IG,IB)))
  583     SUM=SUM+DBLE(G2(4,IG)*DCONJG(P(IG,IB))*P(IG,IB))
            IF( ABS(SUM).LE.1.D-13) THEN
              SUM=0.D0
            ELSE
              SUM=1.D0/SUM
            ENDIF
          DO 584 IG=1,NG2
          X=G2(4,IG)*SUM
          Y=(27.D0+18.D0*X+12.D0*X**2+8.D0*X**3)/
     &      (27.D0+18.D0*X+12.D0*X**2+8.D0*X**3+16.D0*X**4)
c  584     HP(IG,IB)=( HP(IG,IB)-EE(IB)*P(IG,IB) )*Y
  584     HP(IG,IB)=HP(IG,IB)*Y
c ****  Update the wavefunctions
        do ig=1,ng2
          P(IG,IB)=P(IG,IB)+HP(IG,IB)
        enddo
      enddo     ! end the ib loop
c
      endif     ! end the case of isd=0
C
c  ** normalization **
      do ib=1,nj
      pnor=0
       do ig=1,ng2
       pnor=pnor+DBLE( dconjg(p(ig,ib))*p(ig,ib) )
       enddo
c ***  temp check
c       write(6,*)' norm of ',ib,'-th state = ',pnor
c ***  temp check : end
       pnor=1.d0/dsqrt(pnor)
       do ig=1,ng2
       p(ig,ib)=pnor*p(ig,ib)
       enddo
      enddo
c ***  reset work arrays
      do ib=1,nj
       do ig=1,ng2
         HP(ig,ib)=dcmplx(0.d0,0.d0)
cc        CL1(ig,ib)=dcmplx(0.d0,0.d0)
       enddo
      enddo
c ** orthogonalization P -> CL1
c ** orthogonalization P -> HP
c      call ortho(mxbnd,ng2q,cl1,p,nj,ng2,
      call ortho(mxbnd,ng2q,hp,p,nj,ng2,
     &           sig,x0,x1,work1,work20)
      do ib=1,nj
       do ig=1,ng2
c        p(ig,ib)=cl1(ig,ib)
        p(ig,ib)=hp(ig,ib)
       enddo
      enddo
c ***  reset work arrays
      do ib=1,nj
       do ig=1,ng2
         HP(ig,ib)=dcmplx(0.d0,0.d0)
       enddo
      enddo
c +++++
c      write(6,*)' check point 2 after ortho: ended'
c
c  ***  NEXT : exact diagonalization
C
c   ***  Preperation for exact diagonalization
      CALL HLOCAL( NRX, NRY, NRZ, NXYZ, NG2, NG2Q, NJ,
     &             P, HP, RHO1, RHO2, VG, J2G, WSAVEX, WSAVEY, WSAVEZ,
     &             IFACX, IFACY, IFACZ, LX1, LX2, LY1, LY2, LZ1, LZ2  )
C
      CALL NONLOC( NXYZ, NG2, NG2Q, NJ,
     &     P, HP, YLM, G2,GDUMP, RHO2, RHO3, TPIBA, WORK2,
     &             VPJ, VPP, OMEGA, NTAUQ, NTYQ, NTYPE, LREQ, TAU,
     &             NUMTY, NIDN, IOVP, MXOFL,0,NGNL              )
c +++++
c      write(6,*)' check point 3 after HLOCAL NONLOC: ended'
c   ***  reset work arrays for exact diagonalization
      do ib=1,nj
       do jb=1,nj
          sig(ib,jb)=dcmplx(0.d0,0.d0)    ! matrix elements
           x0(ib,jb)=dcmplx(0.d0,0.d0)    ! eigen vectors VR
           x1(ib,jb)=dcmplx(0.d0,0.d0)    ! eigen vectors VI
        work1(ib,jb)=dcmplx(0.d0,0.d0)    ! work array wk1 
       work20(ib,jb)=dcmplx(0.d0,0.d0)    ! work array wk2
       enddo
      enddo
C
c   ***  calculation of the matrix element
      do ib=1,nj
        do jb=1,ib
        ctemp=dcmplx(0.d0,0.d0)
         do ig=1,ng2
         ctemp=ctemp+dconjg( p(ig,ib) )*hp(ig,jb)
         enddo
         sig(ib,jb)=ctemp
         sig(jb,ib)=dconjg( ctemp )
        enddo
      enddo
c +++++
c      write(6,*)' check point 4 after matrix gen (sig): ended'
c ** perform diagonalization
      do jb=1,mxbnd
      ee2(jb)=0   ! IFLG in diag
      ee3(jb)=0   ! IWK  in diag
      enddo
c      call diag(sig,x0,x1,work1,work20,ee,mxbnd,P,CL1,NG2Q,NG2
      call diag(sig,x0,x1,work1,work20,ee,mxbnd,P,HP,NG2Q,NG2
     &      ,ee2,ee3)
c
c +++++
c      write(6,*)' check point 5 r diag: ended'
CC    STORE EIGENVALUE
C ****
      do ib=1,mxbnd
       out(ib,2)=ee(ib)*27.212d0
      enddo
      do ib=1,mxbnd
       out(ib,3)=out(ib,1)-out(ib,2)
      enddo
      sum=0
      do ib=1,mxbnd
       sum=sum+abs( out(ib,3) )
      enddo
c *** change isd during ITC loop
      if ( isd.eq.0 .and. sum.lt.mxbnd*5.d-03 ) then
       isd=1
      endif
      if ( sum.lt.mxbnd*OSHI ) goto 2010
 2000 CONTINUE
      write(6,*) ' SD-convergence is not enough '
      do ib=1,mxbnd
       write(6,1919)ib,(out(ib,i),i=1,3)
      enddo
 1919 format(' BAND = ',i3/' Eold = ',f16.12,
     &       ' Enew = ',f16.12,' Ediff = ',f16.12)
      return
 2010 CONTINUE
      write(6,*)' SD-convergence is fairly good !'
C
      RETURN
      END
C*****************************************************************
      SUBROUTINE HLOCAL( NRX, NRY, NRZ, NXYZ, NG2, NG2Q, NBND,
     &                   COEF, DCOEF, RHO1, RHO2, VG, J2G,
     &                   WSAVEX, WSAVEY, WSAVEZ, IFACX, IFACY, IFACZ,
     &                   LX1, LX2, LY1, LY2, LZ1, LZ2                )
C
      IMPLICIT REAL*8 (A-H,O-Z)
      COMPLEX*16 RHO1(NXYZ),RHO2(NXYZ),
     &           COEF(NG2Q,NBND),DCOEF(NG2Q,NBND),
     &           VG(NXYZ)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
     &          LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
      DIMENSION J2G(NG2Q)
C
C     MAIN LOOP
C
      DO 1010 IB=1,NBND
C
         DO 101 JG=1,NXYZ
  101    RHO1(JG)=(0.D0,0.D0)
*VDIR NODEP(RHO1)
         DO 100 IG=1,NG2
         JG=J2G(IG)
  100    RHO1(JG)=COEF(IG,IB)
C
         CALL FFT3BX(NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
C        RHO1:WAVEFN IN REAL SPACE
C        VG:POTENTIAL IN REAL SPACE
C
         DO 300 I=1,NXYZ
  300    RHO2(I)=VG(I)*RHO1(I)
         CALL FFT3FX(NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
     & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C
         DO 110 IG=1,NG2
         JG=J2G(IG)
  110    DCOEF(IG,IB)=RHO2(JG)
C
 1010 CONTINUE
C
C      CALL CLOCK(TIM1)
C     WRITE(6,*) ' NBND = ',NBND
C     WRITE(6,*) ' HLOCAL: CPTIME=',TIM1
C     WRITE(6,*) ' REAL CPU_TIME : ',(TIM1-TIM0)/DBLE(NBND)
      RETURN
      END
C*****************************************************************
      SUBROUTINE NONLOC( NXYZ, NG2, NG2Q, NBND,
     &       COEF, DCOEF, YLM, G2,GDUMP, RHO2, RHOA, TPIBA,
     &                   WORK2, VPJ, VPP, OMEGA, NTAUQ, NTYQ,
     &      NTYPE, LREQ, TAU, NUMTY, NIDN, IOVP, MXOFL,IOPT,NGNL )
C
C                                   (1990-04-12) OSAMU SUGINO
C        INPUT  COEF
C
      IMPLICIT REAL*8 (A-H,O-Z)
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,4)
c      REAL*8 RHOA(NXYZ),YLM(NG2Q,9)
      REAL*8 RHOA(NXYZ),YLM(NG2Q,16)
      COMPLEX*16 RHO2(NXYZ),
     &           COEF(NG2Q,NBND),DCOEF(NG2Q,NBND),
c     &           WORK2(NG2Q,3)
c     &           WORK2(NG2Q,5)
     &           WORK2(NG2Q,7)
      DIMENSION G2(4,NG2Q),GDUMP(NG2Q)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ),MXOFL(NTYQ)
c      DIMENSION VPJ(NG2Q,3),VPP(3),IOVP(2,NTYQ)
c      DIMENSION VPJ(NG2Q,3,2,NTYQ),VPP(3,2,NTYQ),IOVP(2,NTYQ)
c      DIMENSION VPJ(NG2Q,3,3,NTYQ),VPP(3,3,NTYQ),IOVP(2,NTYQ)
      DIMENSION VPJ(NG2Q,3,4,NTYQ),VPP(3,4,NTYQ),IOVP(2,NTYQ)
      dimension NGNL(NTYQ)
      PI=4.D0*ATAN(1.D0)
      TPI=2.D0*PI
      FPI=4.D0*PI
      TPIBA2=TPIBA**2
C
         DO 581 IG=1,NG2
c         RHOA(IG)=G2(4,IG)*0.5D0*TPIBA2
         RHOA(IG)=GDUMP(IG)*0.5D0*TPIBA2
  581    CONTINUE
         DO 584 IB=1,NBND
         DO 584 IG=1,NG2
  584    DCOEF(IG,IB)=DCOEF(IG,IB)+RHOA(IG)*COEF(IG,IB)
         DO 588 IG=1,NG2
  588    RHOA(IG)=SQRT(G2(4,IG))*TPIBA
         CALL GETYLM(NG2Q,NG2,G2,RHOA,YLM,TPIBA)
         CALL SEPPOT( NG2Q, NG2, NBND, G2,
     &    VPJ, VPP, YLM, RHO2,WORK2(1,1),WORK2(1,2),WORK2(1,3),
     &    WORK2(1,4),WORK2(1,5),WORK2(1,6),WORK2(1,7),
     &    COEF,DCOEF,TPIBA, IOVP, OMEGA,
     &             NTAUQ, NTYQ, LREQ, TAU, NTYPE, NUMTY, NIDN,
     &             MXOFL  ,iopt,NGNL                  )
  580 CONTINUE
C     CALL CLOCK(TIM1)
C     WRITE(6,*) ' NBND = ',NBND
C     WRITE(6,*) ' NONLOC CPTIME:',TIM1-TIM0
C     WRITE(6,*) ' REAL CPU_TIME : ',(TIM1-TIM0)/DBLE(NBND)
      RETURN
      END
c
      subroutine diag(A,VR,VI,wk1,wk2,ee,mxbnd,P,CL1,NG2Q,NG2
     &          ,iflg,iwk)
      use eigsystm
      implicit double precision(a-h,o-z)
      complex*16 A(mxbnd,mxbnd),P(NG2Q,MXBND),CL1(NG2Q,MXBND)
      dimension VR(mxbnd,mxbnd),VI(mxbnd,mxbnd),wk1(MXBND,6)
     &         ,ee(mxbnd),iflg(mxbnd),iwk(mxbnd)
      complex*16 wk2(mxbnd),phase
c 
      if ( mxbnd.lt.6 ) then
       write(6,*)' in sub diag. mxbnd must be bigger than 6'
       stop
      endif
c +++
c +++
c
      ntsk=2
      call zheevvl(mxbnd,a,mxbnd,ee,ier,ntsk,icomm)
cc
      do nb=1,mxbnd
       do ig=1,ng2
        cl1(ig,nb)=dcmplx(0.d0,0.d0)
       enddo
      enddo
c
      do nb=1,mxbnd
       do ib=1,mxbnd
        do ig=1,ng2
         CL1(ig,nb)=cl1(ig,nb)
c     &     +dcmplx( VR(ib,nb),VI(ib,nb) )*P(ig,ib)
     &     +a(ib,nb)*P(ig,ib)
        enddo
       enddo
      enddo
c
      do ib=1,mxbnd
       phase=dconjg(CL1(1,IB))/abs(CL1(1,IB))
       do ig=1,ng2
        P(IG,IB)=CL1(IG,IB)*phase
       enddo
      enddo
c
      return
      end
