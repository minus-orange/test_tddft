      subroutine orbanly(my_rank,iband,ik,coef,rho1,rho2,ng2q,ng2
     & ,g2,cwk,tau,ntauq,numty,ntyq,ntype,tpiba,mxofl,omega)
      implicit double precision (a-h,o-z)
c      PARAMETER(MESHQ=1000,ISPD=5,NCRQ=2,ntypq=4,eps=1.d-08)
      PARAMETER(MESHQ=1000,ISPD=8,NCRQ=2,ntypq=4,eps=1.d-08) ! see main
      dimension g2(4,ng2q),tau(3,ntauq),numty(ntyq)
      DIMENSION RAD(MESHQ),PSPOT(MESHQ,ISPD),PSPOT2(MESHQ,ISPD)
c      DIMENSION PHIL(MESHQ,2),WORK(MESHQ),RC0(NCRQ),COR(NCRQ)
      DIMENSION PHIL(MESHQ,4),WORK(MESHQ),RC0(NCRQ),COR(NCRQ)
c      dimension pssum(3),psrsum(9)
      dimension pssum(4),psrsum(16)
c      dimension rho1(ng2q),rho2(ng2q),rc(3,ntypq),zo(3,ntypq)
      dimension rho1(ng2q),rho2(ng2q),rc(4,ntypq),zo(4,ntypq)
     &         ,mxofl(ntyq)
c      complex*16 coef(ng2q),covl(9),cwk(ng2q)
      complex*16 coef(ng2q),covl(16),cwk(ng2q)
c **** temp check
c      write(6,*)' in sub. orbanly :  omega = ',omega
c ****  check end
      if ( ntypq.lt.ntyq ) then
      if (my_rank.eq.0 ) then
      write(6,*)' in sub. orbanly: ntypq should be ',ntyq
      endif
      stop
      end if
c Wavefucntion's projection on each atom
c ****  psrsum( 1) -  s component
c ****  psrsum( 2) - Px component
c ****  psrsum( 3) - Py component
c ****  psrsum( 4) - Pz component
c ****  psrsum( 5) - D3z^2-1 component
c ****  psrsum( 6) - Dx^2-y^2 component
c ****  psrsum( 7) - Dxy component
c ****  psrsum( 8) - Dyz component
c ****  psrsum( 9) - Dzx component
c ****  psrsum(10) - Fz^3          component
c ****  psrsum(11) - Fx*(x^2-3y^2) component
c ****  psrsum(12) - Fy*(3x^2-y^2) component
c ****  psrsum(13) - Fz*(x^2-y-2 ) component
c ****  psrsum(14) - Fx*y*z        component
c ****  psrsum(15) - Fx*(5z^2-r^2) component
c ****  psrsum(16) - Fy*(5z^2-r^2) component
c
c   followings are up to you
c **** temp check for G-vectors
c      write(6,*)' G-vector check !!! '
c      gx=0
c      gy=0
c      gz=0
c      do ig=1,ng2
c      gx=gx+g2(1,ig)
c      gy=gy+g2(2,ig)
c      gz=gz+g2(3,ig)
c      enddo
c      write(6,*)' sum Gx Gy Gz = ',gx,gy,gz
c **** temp check end
c
c   rc : radial limitation for orbital analysis
c                  (a.u.)
      rc(1,1)=5.0d0     ! for type 1  Ce  -- s-orbital
      rc(2,1)=5.5d0     ! for type 1  Ce  -- p-orbital
      rc(3,1)=5.5d0     ! for type 1  Ce  -- d-orbital
      rc(4,1)=5.5d0     ! for type 1  Ce  -- f-orbital
      rc(1,2)=5.0d0     ! for type 2  V   -- s-orbital
      rc(2,2)=5.5d0     ! for type 2  V   -- p-orbital
      rc(3,2)=5.5d0     ! for type 2  V   -- d-orbital
      rc(1,3)=5.0d0     ! for type 3  Al  -- s-orbital
      rc(2,3)=5.5d0     ! for type 3  Al  -- p-orbital
      rc(1,4)=3.0d0     ! for type 4  O   -- s-orbital
      rc(2,4)=3.5d0     ! for type 4  O   -- p-orbital
c ****  We will ignore followings !!
c
c   zo : occupation of electrons for atomic orbitals
c   zo(l,ity)  : l=1,2  for s and P orbotals, ity  atomic type
c ***  for Si
c      zo(1,1)=2.d0
c      zo(2,1)=2.d0
c ***  for O
c      zo(1,2)=2.d0
c      zo(2,2)=4.d0
c ***  for H 
c      zo(1,3)=1.d0
c      zo(2,3)=0.d0
c
c ***  Instead of above, we do followings:
      do ityp=1,ntypq
      zo(1,ityp)=2.d0
      zo(2,ityp)=6.d0
      zo(3,ityp)=10.d0
      zo(4,ityp)=14.d0
      enddo
c
c
c    ik1 ik2 :  The first and the last k-point 
c                   of your interest
      ik1=1
      ik2=4
      if ( ik.lt.ik1 .or. ik.gt.ik2 ) then
      return
      endif
c
c   nb1 nb2 : bottom and top bands of your interest
c *** Ce doped YAG
      nb1=320
      nb2=423   ! for a two-layer slab
c *** Ce atom
c      nb1=1
c      nb2=20   ! for a two-layer slab
c      nb1=128   ! for 64-cell
c      nb2=160
c      nb1=106   ! for 54-cell
c      nb2=120
      if ( iband.lt.nb1 .or. iband.gt.nb2 ) then
      return
      end if
c
      if (my_rank.eq.0 ) then
      write(6,*)
      write(6,*) '  Orbital analysis for BAND = ',iband
      write(6,*)
      endif
c    re-store coef into rho1 rho2
      do 100 ig=1,ng2
      rho1(ig)=real(coef(ig))
      rho2(ig)=imag(coef(ig))
  100 continue
c **** temp check
c      write(6,*)' check norm of the Bloch wave function '
c      wnorm=0
c      do 99 ig=1,ng2
c   99 wnorm=wnorm+rho1(ig)**2+rho2(ig)**2
c      wnorm=dsqrt(wnorm)
c      write(6,*)' norm = ',wnorm
c **** temp check end
c
      itseq=0
      do 1 ity=1,ntype
      if (my_rank.eq.0 ) then
      write(6,*)
      write(6,*)'  --- start type ',ity,' atoms ---'
      endif
        do 56 il=1,mxofl(ity)
        do 56 ir=1,meshq
   56   phil(ir,il)=0
       IF( NUMTY(ITY).LT.0 .OR. MXOFL(ITY).EQ.1 ) THEN
       if (my_rank.eq.0 ) then
       write(6,*)'  Up to p-orbitals are considered '
       endif
        CALL PSREAD2(ITY,ISPD,MESHQ,MESH,RAD,PSPOT
     &            ,PHIL,WORK
     &            ,NCRQ,ZV,RC0,COR,NUMC)
        else
        call PSREAD(ITY,ISPD,MESHQ,MESH,RAD,PSPOT,PSPOT2,PHIL,WORK,
     &  NCRQ,ZV,RC0,COR,NUMC)
       end if
c ***** integrate the norm of the pseudowavefunction up to rad=rc
c ****  temp check
c      do 18 i=1,mesh
c      if ( rad(i).gt.rc(2,ity) ) then
c      irmax=i-1
c      goto 19
c      end if
c   18 continue
c   19 continue
c      write(6,*)' Pseudo wavefunction for type',ity
c      write(6,1119)rad(irmax),phil(irmax,1),phil(irmax,2)
c 1119 format(' r=',f12.6,' Wf s-orbital =',d14.6,
c     &                   ' Wf P-orbital =',d14.6 )
c ****  temp check end
      lmax=MXOFL(ITY)
      do 13 l=1,lmax
      do 2 i=1,mesh
    2 work(i)=phil(i,l)**2
   13 call normint(my_rank,rc(l,ity),rad,work,mesh,meshq,pssum(l),l
     &            ,H,zo(l,ity))
c ****** calculate Bloch wavefunction's projection on each atom
      nnmtyy=abs( numty(ity) )
c **** temp check
c      write(6,*)'  *****  in sub. psirgen  ****** '
c      write(6,*)' check norm of the Bloch wave function '
      wnorm=0
      do 99 ig=1,ng2
   99 wnorm=wnorm+rho1(ig)**2+rho2(ig)**2
      wnorm=dsqrt(wnorm)
      if ( abs(wnorm-1.d0).gt.1.d-08 ) then
      if (my_rank.eq.0 ) then
      write(6,*)' WARNING!!! wrong norm of the wavefunction !!! '
      write(6,*)' norm = ',wnorm
      endif
      end if
c **** temp check end
      do 3 it=1,nnmtyy
      itseq=itseq+1
c ***  check special atoms only *** PART OF ATOMS !!!!
       if ( itseq.eq.1 ) then
cccc
      call psirgen(tau(1,itseq),rho1,rho2,cwk
     &    ,g2(1,1),ng2q,ng2
     &    ,rad,meshq,mesh,psrsum,H,rc(1,ity),tpiba,omega
c ****  added !!
     &    ,phil,covl,mxofl(ity) )
      if (my_rank.eq.0 ) then
      write(6,*)
      write(6,*)' atomic site # = ',itseq
      write(6,9000)
      write(6,1000)(tau(i,itseq),i=1,3)
c      write(6,*)' Orbital charge   in Crystal  Atomic     Ratio' 
c      write(6,1010)psrsum(1),pssum(1),psrsum(1)/pssum(1)
c      if ( numty(ity).lt.0 ) then
c       write(6,1020)psrsum(2),pssum(2),psrsum(2)
c       write(6,1030)psrsum(3),pssum(2),psrsum(3)
c       write(6,1040)psrsum(4),pssum(2),psrsum(4)
c      else
c       write(6,1020)psrsum(2),pssum(2),psrsum(2)/(pssum(2)+eps)
c       write(6,1030)psrsum(3),pssum(2),psrsum(3)/(pssum(2)+eps)
c       write(6,1040)psrsum(4),pssum(2),psrsum(4)/(pssum(2)+eps)
c      endif
c      if (lmax.ge.3) then
c      write(6,1050)psrsum(5),pssum(3),psrsum(5)/(pssum(3)+eps)
c      write(6,1060)psrsum(6),pssum(3),psrsum(6)/(pssum(3)+eps)
c      write(6,1070)psrsum(7),pssum(3),psrsum(7)/(pssum(3)+eps)
c      write(6,1080)psrsum(8),pssum(3),psrsum(8)/(pssum(3)+eps)
c      write(6,1090)psrsum(9),pssum(3),psrsum(9)/(pssum(3)+eps)
c      endif
c      if (lmax.eq.4) then
c      write(6,1100)psrsum(10),pssum(4),psrsum(10)/(pssum(4)+eps)
c      write(6,1110)psrsum(11),pssum(4),psrsum(11)/(pssum(4)+eps)
c      write(6,1120)psrsum(12),pssum(4),psrsum(12)/(pssum(4)+eps)
c      write(6,1130)psrsum(13),pssum(4),psrsum(13)/(pssum(4)+eps)
c      write(6,1140)psrsum(14),pssum(4),psrsum(14)/(pssum(4)+eps)
c      write(6,1150)psrsum(15),pssum(4),psrsum(15)/(pssum(4)+eps)
c      write(6,1160)psrsum(16),pssum(4),psrsum(16)/(pssum(4)+eps)
c       if ( mxofl(ity).eq.2 ) then
c        write(6,1050)psrsum(5)
c        write(6,1060)psrsum(6)
c        write(6,1070)psrsum(7)
c        write(6,1080)psrsum(8)
c        write(6,1090)psrsum(9)
c       endif
c      endif
      write(6,*)
      write(6,*)' overlap with atomic wavefunction  !!'
      write(6,2010)covl(1)/pssum(1)
      endif
      if ( numty(ity).lt.0 ) then
      if (my_rank.eq.0) then
      write(6,2020)covl(2)
      write(6,2030)covl(3)
      write(6,2040)covl(4)
      endif
      else
      if (my_rank.eq.0) then
      write(6,2020)covl(2)/(pssum(2)+eps)
      write(6,2030)covl(3)/(pssum(2)+eps)
      write(6,2040)covl(4)/(pssum(2)+eps)
      endif
      endif
      if (lmax.ge.3 ) then
      if (my_rank.eq.0) then
      write(6,2050)covl(5)/(pssum(3)+eps)
      write(6,2060)covl(6)/(pssum(3)+eps)
      write(6,2070)covl(7)/(pssum(3)+eps)
      write(6,2080)covl(8)/(pssum(3)+eps)
      write(6,2090)covl(9)/(pssum(3)+eps)
      endif
      endif
      if (lmax.eq.4 ) then
      if (my_rank.eq.0) then
      write(6,2100)covl(10)/(pssum(4)+eps)
      write(6,2110)covl(11)/(pssum(4)+eps)
      write(6,2120)covl(12)/(pssum(4)+eps)
      write(6,2130)covl(13)/(pssum(4)+eps)
      write(6,2140)covl(14)/(pssum(4)+eps)
      write(6,2150)covl(15)/(pssum(4)+eps)
      write(6,2160)covl(16)/(pssum(4)+eps)
      endif
      endif
ccc
      endif  ! if itseq branch: end
    3 continue
    1 continue
 9000 format(' Position(Cartesian)'
     &      ,'--- x ---   --- y ---   --- z ---   (a.u.)')
 1000 format(20x,3f12.6)
c 1010 format(' for  s-orbital ',3f12.6)
c 1020 format(' for Px-orbital ',3f12.6)
c 1030 format(' for Py-orbital ',3f12.6)
c 1040 format(' for Pz-orbital ',3f12.6)
c 1050 format(' for D3*z^2-1 orbital ',3f12.6)
c 1060 format(' for Dx^2-y^2 orbital ',3f12.6)
c 1070 format(' for Dxy    - orbital ',3f12.6)
c 1080 format(' for Dyz    - orbital ',3f12.6)
c 1090 format(' for Dzx    - orbital ',3f12.6)
c 1100 format(' for Fz^3         - orbital ',3f12.6)
c 1110 format(' for Fx*(x^2-3y^2)- orbital ',3f12.6)
c 1120 format(' for Fy*(3x^2-y^2)- orbital ',3f12.6)
c 1130 format(' for Fz*( x^2-y^2)- orbital ',3f12.6)
c 1140 format(' for Fx*y*z       - orbital ',3f12.6)
c 1150 format(' for Fx*(5z^2-r^2)- orbital ',3f12.6)
c 1160 format(' for Fy*(5z^2-r^2)- orbital ',3f12.6)
 2010 format(' for  s-orbital ','Re:',f12.6,'    Im',f12.6)
 2020 format(' for Px-orbital ','Re:',f12.6,'    Im',f12.6)
 2030 format(' for Py-orbital ','Re:',f12.6,'    Im',f12.6)
 2040 format(' for Pz-orbital ','Re:',f12.6,'    Im',f12.6)
 2050 format(' for D3*z^2-1 orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2060 format(' for Dx^2-y^2 orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2070 format(' for Dxy    - orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2080 format(' for Dyz    - orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2090 format(' for Dzx    - orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2100 format(' for Fz^3         - orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2110 format(' for Fx*(x^2-3y^2)- orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2120 format(' for Fy*(3x^2-y^2)- orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2130 format(' for Fz*( x^2-y^2)- orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2140 format(' for Fx*y*z       - orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2150 format(' for Fx*(5z^2-r^2)- orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
 2160 format(' for Fy*(5z^2-r^2)- orbital '
     &  ,'Re:',f12.6,'    Im',f12.6)
      return
      end
c ****
      subroutine psirgen(tau,rho1,rho2,ccc,g2,ng2q,ng2,
     &           rad,meshq,mesh,psrsum,H,rc,tpiba,omega
c *** added !!
     &          ,phil,covl,mxofl )
      implicit double precision (a-h,o-z)
c      dimension tau(3),g2(4,ng2q),rad(meshq),psrsum(9)
      dimension tau(3),g2(4,ng2q),rad(meshq),psrsum(16)
c     &         ,rho1(ng2q),rho2(ng2q),rc(2)
     &         ,rho1(ng2q),rho2(ng2q),rc(4)
c      dimension phil(meshq,2)
      dimension phil(meshq,4)
      complex*16 crpsi1,crpsi2,crpsi3,crpsi4,ccc(ng2q)
      complex*16 crpsi5,crpsi6,crpsi7,crpsi8,crpsi9
     & ,crpsi10,crpsi11,crpsi12,crpsi13,crpsi14,crpsi15,crpsi16
c      complex*16 covl(4),cone
      complex*16 covl(16),cone
      data eps/1.d-08/
      cone=dcmplx( 0.d0, 1.d0 )
c **** temp check
c      write(6,*)'  *****  in sub. psirgen  ****** '
c      write(6,*)' check norm of the Bloch wave function '
c      wnorm=0
c      do 99 ig=1,ng2
c   99 wnorm=wnorm+rho1(ig)**2+rho2(ig)**2
c      wnorm=dsqrt(wnorm)
c      if ( abs(wnorm-1.d0).gt.1.d-08 ) then
c      write(6,*)' WARNING!!! wrong norm of the wavefunction !!! '
c      write(6,*)' norm = ',wnorm
c      end if
c **** temp check end
c ***  temp check
c      write(6,*)' check phil in sub. psirgen '
c      ssum=0
c      psum=0
c      do ir=1,mesh
c      ssum=ssum+rad(ir)*H*phil(ir,1)*phil(ir,1)
c      psum=psum+rad(ir)*H*phil(ir,2)*phil(ir,2)
c      enddo
c      write(6,*)' Norm of s-orbital ',ssum
c      write(6,*)' Norm of p-orbital ',psum
c ***  temp check end
      fpi=4*dacos(-1.d0)
      sfac=1.d0/fpi/omega
c      pfac=3.d0*fpi/omega
      pfac=3.d0/fpi/omega
      d5fac=5.d0/(4*fpi)/omega
      d6fac=15.d0/(4*fpi)/omega
      d7fac=15.d0/fpi/omega
      d8fac=15.d0/fpi/omega
      d9fac=15.d0/fpi/omega
      f30=7.d0/(4*fpi)/omega
      f31=21.d0/(16*fpi)/omega
      f32=105.d0/(8*fpi)/omega
      f33=35.d0/(16*fpi)/omega
      f10fac=f30
      f11fac=f33
      f12fac=f33
      f13fac=f32
      f14fac=f32
      f15fac=f31
      f16fac=f31
c      sfac=1.d0
c      pfac=3.d0
c ****  temp check
c      write(6,*)
c      write(6,*)' in sub. psirgen  rc = ',rc
c      write(6,*)'      irmax = ',irmax
c      write(6,*)' tpiba = ',tpiba
c ****  temp check end
      do 100 ig=1,ng2
      gt=g2(1,ig)*tau(1)+g2(2,ig)*tau(2)+g2(3,ig)*tau(3)
      gt=tpiba*gt
      ccc(ig)=dcmplx(dcos(gt),dsin(gt))
     &       *dcmplx(rho1(ig),rho2(ig))
  100 continue
      if ( g2(4,1).lt.eps ) then
      ngmin=2
      else
      ngmin=1
      end if
c      write(6,*)' in sub. psirgen : ngmin = ',ngmin
c ******  Start the radial integral uo tp r=rc
      H2=log( rad(mesh)/rad(1) )/dfloat(mesh-1)
      if ( abs(H2-H).gt.1.d-08 ) then
      write(6,*)' something wrong in H - Stopping !!'
      stop
      end if
      lmax=mxofl
      do 299 l=1,lmax
      do 200 ir=1,mesh
      if ( rad(ir).gt.rc(l) ) then
      irmax=ir-1
      goto 220
      end if
  200 continue
  220 continue
      if ( l.eq.1 ) irmax1=irmax
      if ( l.eq.2 ) irmax2=irmax
      if ( l.eq.3 ) irmax3=irmax
      if ( l.eq.4 ) irmax4=irmax
c *** temp check:
c      write(6,*)' in sub. psirgen ','l=',l,'irmax=',irmax 
c *** temp check: end
  299 continue
c ***** S-component
      psrsum(1)=0
      covl(1)=dcmplx(0.d0,0.d0)
      do 1 ir=1,irmax1
      if ( g2(4,1).lt.eps ) then
      crpsi1=ccc(1)*rad(ir)
      else
      crpsi1=0
      end if
      rrr=rad(ir)
c *** do 10:  from G-space to r-space
      do 10 ig=ngmin,ng2
      gr=g2(4,ig)*tpiba*rrr
      crpsi1=crpsi1+ccc(ig)*dsin(gr)/gr*rrr
   10 continue
      psrsum(1)=psrsum(1)+H*dconjg(crpsi1)*crpsi1/rrr
      covl(1)=covl(1)+H*phil(ir,1)*crpsi1
    1 continue
      psrsum(1)=sfac*psrsum(1)
      covl(1)=dsqrt(sfac)*covl(1)
c ***** P-components
      psrsum(2)=0
      psrsum(3)=0
      psrsum(4)=0
      covl(2)=dcmplx(0.d0,0.d0)
      covl(3)=dcmplx(0.d0,0.d0)
      covl(4)=dcmplx(0.d0,0.d0)
      do 2 ir=1,irmax2
      crpsi2=0
      crpsi3=0
      crpsi4=0
      rrr=rad(ir)
c *** do 20:  from G-space to r-space
      do 20 ig=ngmin,ng2
      gr=g2(4,ig)*tpiba*rrr
      rj1=(dsin(gr)-gr*dcos(gr) )/(gr*gr)*rrr
      crpsi2=crpsi2+ccc(ig)*rj1*g2(1,ig)/g2(4,ig)
      crpsi3=crpsi3+ccc(ig)*rj1*g2(2,ig)/g2(4,ig)
      crpsi4=crpsi4+ccc(ig)*rj1*g2(3,ig)/g2(4,ig)
   20 continue
      psrsum(2)=psrsum(2)+H*dconjg(crpsi2)*crpsi2/rrr
      psrsum(3)=psrsum(3)+H*dconjg(crpsi3)*crpsi3/rrr
      psrsum(4)=psrsum(4)+H*dconjg(crpsi4)*crpsi4/rrr
      covl(2)=covl(2)+H*phil(ir,2)*crpsi2
      covl(3)=covl(3)+H*phil(ir,2)*crpsi3
      covl(4)=covl(4)+H*phil(ir,2)*crpsi4
    2 continue
      psrsum(2)=pfac*psrsum(2)
      psrsum(3)=pfac*psrsum(3)
      psrsum(4)=pfac*psrsum(4)
      covl(2)=dsqrt(pfac)*covl(2)
      covl(3)=dsqrt(pfac)*covl(3)
      covl(4)=dsqrt(pfac)*covl(4)
      if (lmax.ge.3 ) then
      do l=3,lmax
c ***** D-components
      psrsum(5)=0
      psrsum(6)=0
      psrsum(7)=0
      psrsum(8)=0
      psrsum(9)=0
      covl(5)=dcmplx(0.d0,0.d0)
      covl(6)=dcmplx(0.d0,0.d0)
      covl(7)=dcmplx(0.d0,0.d0)
      covl(8)=dcmplx(0.d0,0.d0)
      covl(9)=dcmplx(0.d0,0.d0)
      do 3 ir=1,irmax3
      crpsi5=0
      crpsi6=0
      crpsi7=0
      crpsi8=0
      crpsi9=0
      rrr=rad(ir)
c *** do 30:  from G-space to r-space
      do 30 ig=ngmin,ng2
      gr=g2(4,ig)*tpiba*rrr
      gg2=g2(4,ig)**2
      gx=g2(1,ig)
      gy=g2(2,ig)
      gz=g2(3,ig)
      rj1=((3.d0-gr*gr)*dsin(gr)-3*gr*dcos(gr) )/(gr*gr*gr)*rrr
      crpsi5=crpsi5+ccc(ig)*rj1*( 3*gz**2/gg2-1.d0)
      crpsi6=crpsi6+ccc(ig)*rj1*( gx**2-gy**2 )/gg2
      crpsi7=crpsi7+ccc(ig)*rj1*( gx*gy )/gg2
      crpsi8=crpsi8+ccc(ig)*rj1*( gz*gx )/gg2
      crpsi9=crpsi9+ccc(ig)*rj1*( gy*gz )/gg2
   30 continue
c **** temp check
c      if ( ir.eq.irmax ) then
c      write(6,*)' Check  Px-orbital  '
c      write(6,1999)rad(irmax),crpsi
c      end if
c **** temp check end
      crpsi5=cone*crpsi5
      crpsi6=cone*crpsi6
      crpsi7=cone*crpsi7
      crpsi8=cone*crpsi8
      crpsi9=cone*crpsi9
      psrsum(5)=psrsum(5)+H*dconjg(crpsi5)*crpsi5/rrr
      psrsum(6)=psrsum(6)+H*dconjg(crpsi6)*crpsi6/rrr
      psrsum(7)=psrsum(7)+H*dconjg(crpsi7)*crpsi7/rrr
      psrsum(8)=psrsum(8)+H*dconjg(crpsi8)*crpsi8/rrr
      psrsum(9)=psrsum(9)+H*dconjg(crpsi9)*crpsi9/rrr
      phid=phil(ir,l)
      covl(5)=covl(5)+H*phid*crpsi5
      covl(6)=covl(6)+H*phid*crpsi6
      covl(7)=covl(7)+H*phid*crpsi7
      covl(8)=covl(8)+H*phid*crpsi8
      covl(9)=covl(9)+H*phid*crpsi9
    3 continue
      psrsum(5)=d5fac*psrsum(5)
      psrsum(6)=d6fac*psrsum(6)
      psrsum(7)=d7fac*psrsum(7)
      psrsum(8)=d8fac*psrsum(8)
      psrsum(9)=d9fac*psrsum(9)
      covl(5)=dsqrt(d5fac)*covl(5)
      covl(6)=dsqrt(d6fac)*covl(6)
      covl(7)=dsqrt(d7fac)*covl(7)
      covl(8)=dsqrt(d8fac)*covl(8)
      covl(9)=dsqrt(d9fac)*covl(9)
c ***** F-components
      if (lmax.eq.4) then
      psrsum(10)=0
      psrsum(11)=0
      psrsum(12)=0
      psrsum(13)=0
      psrsum(14)=0
      psrsum(15)=0
      psrsum(16)=0
      covl(10)=dcmplx(0.d0,0.d0)
      covl(11)=dcmplx(0.d0,0.d0)
      covl(12)=dcmplx(0.d0,0.d0)
      covl(13)=dcmplx(0.d0,0.d0)
      covl(14)=dcmplx(0.d0,0.d0)
      covl(15)=dcmplx(0.d0,0.d0)
      covl(16)=dcmplx(0.d0,0.d0)
      do 4 ir=1,irmax4
      crpsi10=0
      crpsi11=0
      crpsi12=0
      crpsi13=0
      crpsi14=0
      crpsi15=0
      crpsi16=0
      rrr=rad(ir)
c *** do 40:  from G-space to r-space
      do 40 ig=ngmin,ng2
      gr=g2(4,ig)*tpiba*rrr
      gg2=g2(4,ig)**2
      gg3=gg2*g2(4,ig)
      rj1=( (15.d0-6*gr*gr)*dsin(gr)+gr*(gr*gr-15.d0)*dcos(gr) )
     &   /(gr*gr*gr*gr)*rrr
      gx=g2(1,ig)
      gy=g2(2,ig)
      gz=g2(3,ig)
      crpsi10=crpsi10+ccc(ig)*rj1*(5*gz**2/gg2-3.d0)*gz/g2(4,ig)
      crpsi11=crpsi11+ccc(ig)*rj1*gx*(gx**2-3*gy**2)/gg3
      crpsi12=crpsi12+ccc(ig)*rj1*gy*(3*gx**2-gy**2)/gg3
      crpsi13=crpsi13+ccc(ig)*rj1*gz*(  gx**2-gy**2)/gg3
      crpsi14=crpsi14+ccc(ig)*rj1*gx*gy*gz/gg3
      crpsi15=crpsi15+ccc(ig)*rj1*gx*(5*gz**2-gg2)/gg3
      crpsi16=crpsi16+ccc(ig)*rj1*gy*(5*gz**2-gg2)/gg3
   40 continue
c **** temp check
c      if ( ir.eq.irmax ) then
c      write(6,*)' Check  Px-orbital  '
c      write(6,1999)rad(irmax),crpsi
c      end if
c **** temp check end
      crpsi10=cone*crpsi10
      crpsi11=cone*crpsi11
      crpsi12=cone*crpsi12
      crpsi13=cone*crpsi13
      crpsi14=cone*crpsi14
      crpsi15=cone*crpsi15
      crpsi16=cone*crpsi16
c *** temp check
c      if (ir.eq.1 ) then
c       write(6,*)' ngmin = ',ngmin
c       write(6,*)' check crpsi10-16 at ir=',ir
c       write(6,*)' crpsi10 =',crpsi10
c       write(6,*)' crpsi11 =',crpsi11
c       write(6,*)' crpsi12 =',crpsi12
c       write(6,*)' crpsi13 =',crpsi13
c       write(6,*)' crpsi14 =',crpsi14
c       write(6,*)' crpsi15 =',crpsi15
c       write(6,*)' crpsi16 =',crpsi16
c      endif
c *** temp check: end
      psrsum(10)=psrsum(10)+H*dconjg(crpsi10)*crpsi10/rrr
      psrsum(11)=psrsum(11)+H*dconjg(crpsi11)*crpsi11/rrr
      psrsum(12)=psrsum(12)+H*dconjg(crpsi12)*crpsi12/rrr
      psrsum(13)=psrsum(13)+H*dconjg(crpsi13)*crpsi13/rrr
      psrsum(14)=psrsum(14)+H*dconjg(crpsi14)*crpsi14/rrr
      psrsum(15)=psrsum(15)+H*dconjg(crpsi15)*crpsi15/rrr
      psrsum(16)=psrsum(16)+H*dconjg(crpsi16)*crpsi16/rrr
      phif=phil(ir,l)
      covl(10)=covl(10)+H*phif*crpsi10
      covl(11)=covl(11)+H*phif*crpsi11
      covl(12)=covl(12)+H*phif*crpsi12
      covl(13)=covl(13)+H*phif*crpsi13
      covl(14)=covl(14)+H*phif*crpsi14
      covl(15)=covl(15)+H*phif*crpsi15
      covl(16)=covl(16)+H*phif*crpsi16
    4 continue
      psrsum(10)=f10fac*psrsum(10)
      psrsum(11)=f11fac*psrsum(11)
      psrsum(12)=f12fac*psrsum(12)
      psrsum(13)=f13fac*psrsum(13)
      psrsum(14)=f14fac*psrsum(14)
      psrsum(15)=f15fac*psrsum(15)
      psrsum(16)=f16fac*psrsum(16)
      covl(10)=dsqrt(f10fac)*covl(10)
      covl(11)=dsqrt(f11fac)*covl(11)
      covl(12)=dsqrt(f12fac)*covl(12)
      covl(13)=dsqrt(f13fac)*covl(13)
      covl(14)=dsqrt(f14fac)*covl(14)
      covl(15)=dsqrt(f15fac)*covl(15)
      covl(16)=dsqrt(f16fac)*covl(16)
c
      endif  ! if imax.eq.4 branch: end
co
      enddo  ! l=3,lmax loop: end
c
      endif  ! if lmax.ge.3 branch: end
c
c 1999 format(' r=',f10.6,' psir= ',2d14.6)
c ***  temp check
c      write(6,*)' psrsum   in sub. psirgen '
c      write(6,1998)(psrsum(il),il=1,4)
c 1998 format(' s  =',d14.6/'Px =',d14.6
c     &      /'Py  =',d14.6/'Pz =',d14.6 )
c ***  temp check end
c
c      if ( mxofl.eq.2 ) then
cc  **  for D-components
c      psrsum(5)=0
c      psrsum(6)=0
c      psrsum(7)=0
c      psrsum(8)=0
c      psrsum(9)=0
c      do 4 ir=1,irmax2
c      crpsi5=0
c      crpsi6=0
c      crpsi7=0
c      crpsi8=0
c      crpsi9=0
c      rrr=rad(ir)
cc *** do 40:  from G-space to r-space
c      do 40 ig=ngmin,ng2
c      gr=g2(4,ig)*tpiba*rrr
c      rj2=( (3.d0-gr*gr)*dsin(gr)-3*gr*dcos(gr) )
c     &   /(gr*gr*gr)*rrr
c      x=g2(1,ig)/g2(4,ig)
c      y=g2(2,ig)/g2(4,ig)
c      z=g2(3,ig)/g2(4,ig)
c      crpsi5=crpsi5+ccc(ig)*rj2*( 3*z*z-1.d0 )
c      crpsi6=crpsi6+ccc(ig)*rj2*(x*x-y*y)
c      crpsi7=crpsi7+ccc(ig)*rj2*x*y
c      crpsi8=crpsi8+ccc(ig)*rj2*y*z
c      crpsi9=crpsi9+ccc(ig)*rj2*z*x
c   40 continue
c      psrsum(5)=psrsum(5)+rrr*H*dconjg(crpsi5)*crpsi5
c      psrsum(6)=psrsum(6)+rrr*H*dconjg(crpsi6)*crpsi6
c      psrsum(7)=psrsum(7)+rrr*H*dconjg(crpsi7)*crpsi7
c      psrsum(8)=psrsum(8)+rrr*H*dconjg(crpsi8)*crpsi8
c      psrsum(9)=psrsum(9)+rrr*H*dconjg(crpsi9)*crpsi9
c    4 continue
c      psrsum(5)=d5fac*psrsum(5)
c      psrsum(6)=d6fac*psrsum(6)
c      psrsum(7)=d7fac*psrsum(7)
c      psrsum(8)=d8fac*psrsum(8)
c      psrsum(9)=d9fac*psrsum(9)
c      endif
      return
      end
c ****
      subroutine normint(my_rank,rc,rad,work,mesh,meshq,sum2,l,H,zo)
      implicit double precision (a-h,o-z)
      dimension rad(meshq),work(meshq)
      sum=rint(rad,work,mesh,H)
      if ( l.eq.1 .and. my_rank.eq.0) write(6,1000)sum
      if ( l.eq.2 .and. my_rank.eq.0) write(6,2000)sum
      if ( l.eq.3 .and. my_rank.eq.0) write(6,3000)sum
      if ( l.eq.4 .and. my_rank.eq.0) write(6,4000)sum
      sum2=rcint(rc,rad,work,mesh,H)
      if (l.eq.1 .and. my_rank.eq.0) write(6,1100)sum2,rc
      if (l.eq.2 .and. my_rank.eq.0) write(6,1200)sum2,rc
      if (l.eq.3 .and. my_rank.eq.0) write(6,1300)sum2,rc
      if (l.eq.4 .and. my_rank.eq.0) write(6,1400)sum2,rc
 1000 format(' norm of s-orbital = ',d16.8)
 2000 format(' norm of p-orbital = ',d16.8)
 3000 format(' norm of d-orbital = ',d16.8)
 4000 format(' norm of f-orbital = ',d16.8)
 1100 format(' norm of s-orbital = ',d16.8,' up to r=',d16.8)
 1200 format(' norm of p-orbital = ',d16.8,' up to r=',d16.8)
 1300 format(' norm of d-orbital = ',d16.8,' up to r=',d16.8)
 1400 format(' norm of f-orbital = ',d16.8,' up to r=',d16.8)
c  ***** normalized by spin     
      if ( l.eq.1 ) then
      sum2=sum2*zo/2.d0
      elseif ( l.eq.2 ) then
      sum2=sum2*zo/2.d0/3.d0
      end if
      return
      end
c ***
      function rint(x,y,n,H)
      implicit double precision (a-h,o-z)
      dimension x(n),y(n)
      H=DLOG(X(N)/X(1))/dfloat(N-1)
      rint=0
      do 1 i=1,n
    1 rint=rint+x(i)*H*y(i)
      RETURN
      END
c
      FUNCTION RCINT(rc,X,Y,N,H)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION  X(N),Y(N)
      H=DLOG(X(N)/X(1))/dfloat(N-1)
      do 1 i=1,n
      if ( x(i).gt.rc ) then
      irmax=i-1
      goto 2
      end if
    1 continue
    2 continue
      rcint=0
      do 10 i=1,irmax
   10 rcint=rcint+x(i)*H*y(i)
      RETURN
      END
