c
      subroutine VPJ_GEN(Gold,G2,NG2Q,NG2,SPB,VPJ,VPJWORK,VPP2
     &                 ,TPIBA,NTYQ,ntype,GMHF,MXOFL
     &    ,RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NGNL,OMEGA,NGcont
c
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
     &    ,mshbegin,mshend,ncpuq,IACC,IPROF )
#else
     &    ,mshbegin,mshend,ncpuq,IACC )
#endif
      implicit double precision(a-h,o-z)
      include 'mpif.h'
      dimension SPB(NG2Q),G2(4,NG2Q),Gold(4,NG2Q)
c  *** for G-A version PSDATA need to be common!
c      PARAMETER(MESHQ=1000, ISPD=8, NTYQ2=4)
c      COMMON/PSDATA/RAD(MESHQ,NTYQ2),PSPOT(MESHQ,ISPD,NTYQ2),
c     &    PSPOT2(MESHQ,ISPD,NTYQ2),PHIL(MESHQ,4,NTYQ2)
      dimension RAD(MESHQ,NTYQ),PSPOT(MESHQ,ISPD,NTYQ),
     &    PSPOT2(MESHQ,ISPD,NTYQ),PHIL(MESHQ,4,NTYQ)
      dimension MXOFL(ntype),NGNL(ntype)
      dimension VPJ(NGcont,3,4,NTYQ),VPJWORK(NGcont,3),VPP2(16,3,NTYQ)
c      include 'ncpuq.h'
c      common/cputask4/mshbegin(0:ncpuq),mshend(0:ncpuq),ncpu4
      dimension mshbegin(0:ncpuq),mshend(0:ncpuq)
      call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
c ****  for smoothing !!!!
c *** temp check
c      if (my_rank.eq.0 ) then
c      write(6,*) 'in VPJ_GEN mshbegin mshend'  
c       do icpu=1,ncpuq
c        write(6,*)icpu,mshbegin(icpu),mshend(icpu)
c       enddo
c      endif
c *** temp check : endk
c *** ADUMP: Smoothing factor for RHO & VHXC
      PI=dacos(-1.d0)
      FPI=4.D0*PI
      pi8=8.d0*pi
      pi16=16.d0*pi
      pi32=32.d0*pi
      GCUT=GMHF*2
      ADUMP= GCUT
      ATEMP= ADUMP/10.d0
c
c *** temp check
c      if (my_rank.eq.0 ) then
c      write(6,*)' check smoothing '
c      do ity=1,ntype
c        write(6,*)' NGNL = ',NGNL(ITY),' MXOFL = ',MXOFL(ITY)
c        if ( MXOFL(ITY).ge.1 ) then
c         do ig=1,NGNL(ITY)
c         wari=dexp( ( G2(4,ig)-ADUMP )/ATEMP ) + 1.d0
c         fac=1.d0/dsqrt(wari )
c         enddo
c         write(6,*)' loop ig for fac ended normally'
c        endif
c      enddo
c        write(6,*)' in VPJ_GEN '
c        write(6,*)' FPI = ',FPI
c        write(6,*)' GCUT= ',GCUT
cccc        stop
c      endif
c *** temp check end
c
c *** temp check
c      if (my_rank.eq.0) then
c       write(6,*)' VPJ_GEN: G2 '
c       do ig=1,NG2Q/6,1000
c        write(6,'(4F22.16)')(G2(J,IG),J=1,4)
c       enddo
c      endif
c *** temp check :  end
      do ity=1,ntype
c *** temp check
c      if (my_rank.eq.0 ) then
c       write(6,*)' VPJ_GEN: RAD  ITY=',ITY
c       write(6,'(4F22.16)')(RAD(K,ITY),K=1,MESHQ,100)
c       do il=1,MXOFL(ity)
c        write(6,*)' il=',il
c        write(6,*)' PHIL '
c        write(6,'(4F22.16)')(PHIL(IR,IL,ITY),IR=1,MESHQ,100)
c        write(6,*)' PSPOT '
c        write(6,'(4F22.16)')(PSPOT(IR,IL,ITY),IR=1,MESHQ,100)
c       enddo
c      endif
c *** temp check end
c
      if (MXOFL(ity).ge.1 ) then
      do LI=1,MXOFL(ity)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_start(50)
#endif
      L=LI-1
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_start(73)
#endif
cc ** clean up VPJWORK for parallel mesh integration
      DO IG=1,NGNL(ity)
       VPJWORK(IG,1)=0
       VPJWORK(IG,2)=0
       VPJWORK(IG,3)=0
      ENDDO
c
c *** clean up VPJ for mesh integration
       do ig=1,NGNL(ity)
        VPJ(ig,1,li,ity)=0.d0
        VPJ(ig,2,li,ity)=0.d0
       VPJ(ig,3,li,ity)=0.d0
       enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_stop(73)
      if (IPROF.eq.1) call prof_start(74)
#endif
c
       do j=1,3
        if ( LI.eq.1 ) then
        VPP2(LI,J,ity)=0.D0
        elseif (LI.eq.2) then
        VPP2(LI  ,J,ity)=0.D0
        VPP2(LI+1,J,ity)=0.D0
        VPP2(LI+2,J,ity)=0.D0
        elseif (LI.eq.3) then
        VPP2(LI+2,J,ity)=0.D0
        VPP2(LI+3,J,ity)=0.D0
        VPP2(LI+4,J,ity)=0.D0
        VPP2(LI+5,J,ity)=0.D0
        VPP2(LI+6,J,ity)=0.D0
        elseif (LI.eq.4) then
        VPP2(LI+6,J,ity)=0.D0
        VPP2(LI+7,J,ity)=0.D0
        VPP2(LI+8,J,ity)=0.D0
        VPP2(LI+9,J,ity)=0.D0
        VPP2(LI+10,J,ity)=0.D0
        VPP2(LI+11,J,ity)=0.D0
        VPP2(LI+12,J,ity)=0.D0
       endif
       enddo
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_stop(74)
#endif
c
#ifdef _OPENACC
      if (IACC.eq.1) then
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_start(75)
#endif
       call VPJ_GEN_ACC_INTEGRAL(G2,VPJWORK,TPIBA,FPI,ITY,LI,
     &  RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NTYQ,NGNL(ITY),NGcont,
     &  mshbegin(my_rank),mshend(my_rank))
!$acc update self(VPJWORK(1:NGcont,1:3))
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_stop(75)
#endif
      else
#endif
C*****LOOP OVER MESH
      SUM=0.D0
c      DO 50 I=1,MESH
      DO 50 I=mshbegin(my_rank),mshend(my_rank)  ! mesh intergal is MPI para
C*****CONSTRUCT THE SPHERICAL BESSEL FUNCTION J_L(Q1*R)
      IF(L.EQ.0) THEN
ccc         IF(G2(4,1).EQ.0.D0) THEN
         TEMP=SQRT(G2(4,1))*RAD(I,ity)*TPIBA
         IF(TEMP.LE.1.D-7) THEN
            SPB(1)=1.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
c         DO 42 IG=ISTA,NG2(IK)
c         DO 42 IG=ISTA,NG2
c *** temp
c       if (my_rank.eq.0.and.ISTA.eq.1 ) then
c        write(6,*)' G2*RAD=',G2(4,ISTA)*RAD(I,ITY)
c       endif
c *** temp end
         DO 42 IG=ISTA,NGNL(ITY)
         TEMP=SQRT(G2(4,IG))*RAD(I,ity)*TPIBA
c *** temp check
c         if (my_rank.eq.0 ) then 
c          write(6,*)' TEMP=',TEMP
c         endif
c *** temp check: end
   42    SPB(IG)=SIN(TEMP)/TEMP
      ELSEIF(L.EQ.1) THEN
         IF(G2(4,1).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
c         DO 44 IG=ISTA,NG2(IK)
c         DO 44 IG=ISTA,NG2
         DO 44 IG=ISTA,NGNL(ITY)
         TEMP=SQRT(G2(4,IG))*RAD(I,ity)*TPIBA
   44    SPB(IG)=(SIN(TEMP)-TEMP*COS(TEMP))/TEMP**2
      ELSEIF(L.EQ.2) THEN ! d-orbital
         IF(G2(4,1).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
         DO 46 IG=ISTA,NGNL(ITY)
         TEMP=SQRT(G2(4,IG))*RAD(I,ity)*TPIBA
   46    SPB(IG)=( (3.d0-TEMP**2)*SIN(TEMP)-3.d0*TEMP*COS(TEMP) )
     &           /TEMP**3
      ELSEIF(L.EQ.3) THEN ! f-orbital
         IF(G2(4,1).EQ.0.D0) THEN
            SPB(1)=0.D0
            ISTA=2
         ELSE
            ISTA=1
         ENDIF
         DO 47 IG=ISTA,NGNL(ITY)
         TEMP=SQRT(G2(4,IG))*RAD(I,ity)*TPIBA
         TEMP2=TEMP*TEMP
         TEMP3=TEMP*TEMP2
         TEMP4=TEMP2*TEMP2
         SPB(IG)=( (15.d0-6*TEMP2)*SIN(TEMP)+(TEMP3-15.d0*TEMP)
     &     *COS(TEMP) )  /TEMP4
   47    CONTINUE
      ENDIF
c *** Smoothing !!
c
c *** temp check 
c      if (my_rank.eq.0) then
c       write(6,*)' check SPB '
c       write(6,'(4F22.16)')(SPB(IG),IG=1,NGNL(ity),1000)
c      endif
c *** temp check: end
c      do ig=1,NGNL(ITY)
c       wari=dexp( (G2(4,ig)-ADUMP)/ATEMP ) + 1.d0
c       fac=1.d0/dsqrt(wari)
c       SPB(ig)=fac*SPB(ig)
c      enddo
c *** temp check 
c      if (my_rank.eq.0) then
c       write(6,*)' check SPB after smoothing '
c       write(6,'(4F22.16)')(SPB(IG),IG=1,NGNL(ity),1000)
c      endif
c *** temp check: end
c
      DO 52 IG=1,NGNL(ITY)
c      VPJ(IG,1,li,ity)=VPJ(IG,1,li,ity)
      VPJWORK(IG,1)=VPJWORK(IG,1)
     &   +FPI*PSPOT (I,LI   ,ity )*PHIL(I,LI,ity)*RAD(I,ity)*SPB(IG)
c      VPJ(IG,2,li,ity)=VPJ(IG,2,li,ity)
      VPJWORK(IG,2)=VPJWORK(IG,2)
     &   +FPI*PSPOT2(I,LI*2-1,ity)*PHIL(I,LI,ity)*RAD(I,ity)*SPB(IG)
c      VPJ(IG,3,li,ity)=VPJ(IG,3,li,ity)
      VPJWORK(IG,3)=VPJWORK(IG,3)
     &   +FPI*PSPOT2(I,LI*2  ,ity)*PHIL(I,LI,ity)*RAD(I,ity)*SPB(IG)
   52 CONTINUE
c *** temp check
c      if (my_rank.eq.0) then
c       write(6,*)' check VPJWORK '
c       write(6,'(4F22.16)')(VPJWORK(IG,1),IG=1,NGNL(ity),1000)
c      endif
c *** temp check
c
   50 CONTINUE
#ifdef _OPENACC
      endif
#endif
c      
c +++ 2020 begin insert
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_stop(50)
      if (IPROF.eq.1) call prof_start(51)
#endif
      LngthDat=3*(NGcont)
      call MPI_ALLReduce(VPJWORK(1,1),VPJ(1,1,li,ity),LngthDat,
     &  MPI_DOUBLE_PRECISION,MPI_SUM, MPI_COMM_WORLD,ierr)
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_stop(51)
      if (IPROF.eq.1) call prof_start(52)
#endif
c +++ 2020 end insert
c *** prepare smoothing !! Here cause of the trap!!
c       if (my_rank.eq.0 ) then
c        write(6,*)' in VPJ_GEN '
c        write(6,*)'smoothing exponent factor at ity =',ity
c        write(6,*)' ADUMP ATEMP =',ADUMP,ATEMP
c        write(6,'(4F22.16)')
c     &  ( ((G2(4,ig)-ADUMP)/ATEMP),ig=1,NGNL(ITY),500)
c       endif
        do ig=1,NGNL(ITY)
         wari=dexp( ( Gold(4,ig)-ADUMP )/ATEMP ) + 1.d0
         VPJWORK(IG,1)=1.d0/dsqrt(wari )
        enddo
c       *** smoothing of VPJ !!
       do IP=1,3
        do IG=1,NGNL(ITY)
        VPJ(IG,IP,li,ITY)=VPJWORK(IG,1)*VPJ(IG,IP,li,ITY)
        enddo
       enddo
c ** smoothing end
c
       if ( li.eq.1 ) then  ! s-component
       do ip=1,3
         do ig=1,NGNL(ITY)
         VPP2(li,ip,ity)=VPP2(li,ip,ity)
     &  +VPJ(ig,ip,li,ity)**2
         enddo
         VPP2(li,ip,ity)=VPP2(li,ip,ity)/fpi/OMEGA
       enddo
       elseif( li.eq.2 ) then ! p-components
        if ( G2(4,1).eq.0.D0 ) then
         ISTA=2
        else
         ISTA=1
        endif
       do ip=1,3
         do ig=ISTA,NGNL(ITY)
         VPP2(li  ,ip,ity)=VPP2(li  ,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*G2(1,ig) )**2/G2(4,ig)
         VPP2(li+1,ip,ity)=VPP2(li+1,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*G2(2,ig) )**2/G2(4,ig)
         VPP2(li+2,ip,ity)=VPP2(li+2,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*G2(3,ig) )**2/G2(4,ig)
         enddo
         VPP2(li  ,ip,ity)=VPP2(li  ,ip,ity)*3.d0/fpi/OMEGA
         VPP2(li+1,ip,ity)=VPP2(li+1,ip,ity)*3.d0/fpi/OMEGA
         VPP2(li+2,ip,ity)=VPP2(li+2,ip,ity)*3.d0/fpi/OMEGA
c *** comments: factors of VPP2(3,ip) VPP2(4,ip) are corrected in exnlp  by 1/sqr2
       enddo
      elseif( li.eq.3 ) then ! d-components
        if ( G2(4,1).eq.0.D0 ) then
         ISTA=2
        else
         ISTA=1
        endif
       do ip=1,3
c *** attention! (tentative!)
         if (G2(4,1).eq.0.d0 ) then
         VPP2(li+2,ip,ity)=( VPJ(1,ip,li,ity)*2.d0 )**2
         endif
c *** attention end:
         do ig=ISTA,NGNL(ITY)
         GG2=G2(4,ig)
         VPP2(li+2,ip,ity)=VPP2(li+2,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*( 3.D0*G2(3,ig)**2/GG2-1.d0 ) )**2
         VPP2(li+3,ip,ity)=VPP2(li+3,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*(G2(1,ig)**2-G2(2,ig)**2)/GG2 )**2
         VPP2(li+4,ip,ity)=VPP2(li+4,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*G2(1,ig)*G2(2,ig)/GG2 )**2
         VPP2(li+5,ip,ity)=VPP2(li+5,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*G2(3,ig)*G2(1,ig)/GG2 )**2
         VPP2(li+6,ip,ity)=VPP2(li+6,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*G2(2,ig)*G2(3,ig)/GG2 )**2
         enddo
         VPP2(li+2,ip,ity)=VPP2(li+2,ip,ity)* 5.d0/pi16/OMEGA
         VPP2(li+3,ip,ity)=VPP2(li+3,ip,ity)*15.d0/pi16/OMEGA
         VPP2(li+4,ip,ity)=VPP2(li+4,ip,ity)*15.d0/fpi/OMEGA
         VPP2(li+5,ip,ity)=VPP2(li+5,ip,ity)*15.d0/fpi/OMEGA
         VPP2(li+6,ip,ity)=VPP2(li+6,ip,ity)*15.d0/fpi/OMEGA
       enddo
       elseif( li.eq.4 ) then ! f-components
        if ( G2(4,1).eq.0.D0 ) then
         ISTA=2
        else
         ISTA=1
        endif
       do ip=1,3
c         do ig=ISTA,ng2(ik)
c         do ig=ISTA,ng2
c *** attention! (tentative!)
         if (G2(4,1).eq.0.d0 ) then
         VPP2(li+6,ip,ity)=( VPJ(1,ip,li,ity)*2.d0 )**2
         endif
c *** attention end:
         do ig=ISTA,NGNL(ITY)
         GX=G2(1,IG)
         GY=G2(2,IG)
         GZ=G2(3,IG)
         GG=dsqrt( G2(4,ig) )
         GG2=G2(4,ig)
         GG3=GG2*GG
         VPP2(li+ 6,ip,ity)=VPP2(li+ 6,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*(5*GZ**2/GG2 -3.D0)*GZ/GG )**2
         VPP2(li+ 7,ip,ity)=VPP2(li+ 7,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*GX*( GX**2 -3*GY**2 )/GG3 )**2
         VPP2(li+ 8,ip,ity)=VPP2(li+ 8,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*GY*( 3*GX**2 -GY**2 )/GG3 )**2
         VPP2(li+ 9,ip,ity)=VPP2(li+ 9,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*GZ*( GX**2 - GY**2  )/GG3 )**2
         VPP2(li+10,ip,ity)=VPP2(li+10,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*2*GZ*GX*GY/GG3 )**2
         VPP2(li+11,ip,ity)=VPP2(li+11,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*GX*(5*GZ**2 - GG2)/GG3 )**2
         VPP2(li+12,ip,ity)=VPP2(li+12,ip,ity)
     &  +( VPJ(ig,ip,li,ity)*GY*(5*GZ**2 - GG2)/GG3 )**2
         enddo
         VPP2(li+ 6,ip,ity)=VPP2(li+ 6,ip,ity)*  7.d0/pi16/OMEGA
         VPP2(li+ 7,ip,ity)=VPP2(li+ 7,ip,ity)* 35.d0/pi32/OMEGA
         VPP2(li+ 8,ip,ity)=VPP2(li+ 8,ip,ity)* 35.d0/pi32/OMEGA
         VPP2(li+ 9,ip,ity)=VPP2(li+ 9,ip,ity)*105.d0/pi16/OMEGA
         VPP2(li+10,ip,ity)=VPP2(li+10,ip,ity)*105.d0/pi16/OMEGA
         VPP2(li+11,ip,ity)=VPP2(li+11,ip,ity)* 21.d0/pi32/OMEGA
         VPP2(li+12,ip,ity)=VPP2(li+12,ip,ity)* 21.d0/pi32/OMEGA
       enddo
       endif
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
      if (IPROF.eq.1) call prof_stop(52)
#endif
      enddo  ! end of LI loop
      endif
      enddo  ! end of ity loop
c      
      return
      end
c
      subroutine VPJ_GEN_ACC_INTEGRAL(G2,VPJWORK,TPIBA,FPI,ITY,LI,
     & RAD,PSPOT,PSPOT2,PHIL,MESHQ,ISPD,NTYQ,NGNL0,NGcont,
     & IBEGIN,IEND)
      implicit double precision(a-h,o-z)
      dimension G2(4,NGcont),VPJWORK(NGcont,3)
      dimension RAD(MESHQ,NTYQ),PSPOT(MESHQ,ISPD,NTYQ),
     & PSPOT2(MESHQ,ISPD,NTYQ),PHIL(MESHQ,4,NTYQ)
c
!$acc parallel loop gang vector vector_length(256)
!$acc& present(G2(1:4,1:NGcont),VPJWORK(1:NGcont,1:3),
!$acc& RAD(1:MESHQ,1:NTYQ),PSPOT(1:MESHQ,1:ISPD,1:NTYQ),
!$acc& PSPOT2(1:MESHQ,1:ISPD,1:NTYQ),
!$acc& PHIL(1:MESHQ,1:4,1:NTYQ))
!$acc& private(I,TEMP,TEMP2,TEMP3,TEMP4,SPBV,S1,S2,S3)
      do IG=1,NGcont
       S1=0.D0
       S2=0.D0
       S3=0.D0
       if (IG.le.NGNL0) then
!$acc loop seq
       do I=IBEGIN,IEND
        TEMP=DSQRT(G2(4,IG))*RAD(I,ITY)*TPIBA
        if (LI.eq.1) then
         if (IG.eq.1 .and. TEMP.le.1.D-7) then
          SPBV=1.D0
         else
          SPBV=DSIN(TEMP)/TEMP
         endif
        elseif (LI.eq.2) then
         if (IG.eq.1 .and. G2(4,1).eq.0.D0) then
          SPBV=0.D0
         else
          SPBV=(DSIN(TEMP)-TEMP*DCOS(TEMP))/TEMP**2
         endif
        elseif (LI.eq.3) then
         if (IG.eq.1 .and. G2(4,1).eq.0.D0) then
          SPBV=0.D0
         else
          SPBV=((3.D0-TEMP**2)*DSIN(TEMP)
     &         -3.D0*TEMP*DCOS(TEMP))/TEMP**3
         endif
        else
         if (IG.eq.1 .and. G2(4,1).eq.0.D0) then
          SPBV=0.D0
         else
          TEMP2=TEMP*TEMP
          TEMP3=TEMP*TEMP2
          TEMP4=TEMP2*TEMP2
          SPBV=((15.D0-6.D0*TEMP2)*DSIN(TEMP)
     &         +(TEMP3-15.D0*TEMP)*DCOS(TEMP))/TEMP4
         endif
        endif
        S1=S1+FPI*PSPOT(I,LI,ITY)*PHIL(I,LI,ITY)
     &        *RAD(I,ITY)*SPBV
        S2=S2+FPI*PSPOT2(I,LI*2-1,ITY)*PHIL(I,LI,ITY)
     &        *RAD(I,ITY)*SPBV
        S3=S3+FPI*PSPOT2(I,LI*2,ITY)*PHIL(I,LI,ITY)
     &        *RAD(I,ITY)*SPBV
       enddo
       endif
       VPJWORK(IG,1)=S1
       VPJWORK(IG,2)=S2
       VPJWORK(IG,3)=S3
      enddo
      return
      end
