c234567
      subroutine rexgen(nrx,nry,nrz,nxyz,rext,omega,A1,A2,A3,my_rank)
      implicit double precision (a-h,o-z)
      dimension A1(3),A2(3),A3(3)
      complex*16 rext(nxyz)
c
	if ( my_rank.eq.0 ) then
      write(6,*)' omega=',omega
	endif
c
c      vzlng=40.49999999634389403094128d0  ! in Bohr unit
      vxlng=A1(1)  ! in Bohr unit
      vylng=A2(2)  ! in Bohr unit
	vzlng=A3(3)  ! in Bohr unit
	if ( my_rank.eq.0 ) then
      write(6,*)' vzlength = ',vzlng
	endif
      dx=vxlng/dfloat(nrx)
      dy=vylng/dfloat(nry)
	dz=vzlng/dfloat(nrz)
      rc=0.5d0/0.529177d0  ! in Bohr unit
c      rc=1.5d0/0.529177d0  ! in Bohr unit
c
      nx0=(nrx-1)/2
      ny0=(nry-1)/2
      nz0=(nrz-1)/2
      do 10 ii=1,nxyz
       rext(ii)=0.d0
  10  continue
c
c      lzhlf=(nrz-1)/2
      dxhlf=0.0d0
      dyhlf=0.0d0
	dzhlf=0.0d0
c 
c        expogi=-0.271535d0    ! E=0.1765VpA
c        exnega= 0.271535d0
c
c        expogi=-0.0015383998615631d0    ! E=0.001VpA
c        exnega= 0.0015383998615631d0
c
c        expogi=-0.015383998615631d0    ! E=0.01VpA
c        exnega= 0.015383998615631d0
c
c        expogi=-0.046151995846893d0    ! E=0.03VpA
c        exnega= 0.046151995846893d0
c
c        expogi=-0.271535d0    ! E=0.321VpA (1x1)
c        exnega= 0.271535d0
c
c        expogi=-0.543070d0    ! E=0.643VpA (1x1)
c        exnega= 0.543070d0
c        expogi=-0.543070d0*(1.035d0**2)    ! E=0.643VpA (1x1) for GGA lattic
c        exnega= 0.543070d0*(1.035d0**2)
c
c        expogi=-1.08614d0    ! E=0.643VpA (1x2)
c        exnega= 1.08614d0
c         expogi=-1.08614d0*(1.035d0**2)  ! for GGA lattice constant
c         exnega= 1.08614d0*(1.035d0**2)
         expogi=0.0  ! for GGA lattice constant
         exnega=0.0
c *** for dia111 surface Emax=0.03VpA
c        expogi=-0.022710272278d0
c        exnega= 0.022710272278d0
c *** for dia111 surface Emax=0.10VpA
c        expogi=-0.075700907593d0
c        exnega= 0.075700907593d0
c *** for dia111 surface Emax=0.30VpA
c        expogi=-0.22710272278d0
c        exnega= 0.22710272278d0
c
c        expogi=-0.15383998615631d0    ! E=0.1VpA
c        exnega= 0.15383998615631d0
c
c        expogi=-1.5383998615631d0    ! E=1.0VpA
c        exnega= 1.5383998615631d0
c
c 
c ***
c	P_pogi=0.48d0*Vxlng
c	P_nega=0.52d0*Vxlng
c	P_neut=0.5d0*Vxlng
c ****
	P_pogi=0.48d0*Vzlng
	P_nega=0.52d0*Vzlng
	P_neut=0.5d0*Vzlng
c *** make factor
	sum=0
	do 90 II=1,nxyz
	 K=1+(II-1)/(NRX*NRY)
       I=II-(K-1)*NRX*NRY
       J=1+(I-1)/NRX
       I=I-(J-1)*NRX
       LX=I-1 + (nrx-1)/2 +1 -nx0
       LY=J-1 + (nry-1)/2 +1 -ny0
       LZ=K-1 + (nrz-1)/2 +1 -nz0
c	 x=dx*(LX-1)+dxhlf - P_neut
c	 XX=(x/rc)**2
c	 sum=sum+dexp(-XX)
c ***
	 z=dz*(Lz-1)+dzhlf - P_neut
	 zz=(z/rc)**2
	 sum=sum+dexp(-zz)
  90	continue
	sum=sum/dfloat(nxyz)
	fac=1.d0/(omega*sum)
	sumpogi=0
	sumnega=0
	do 92 II=1,nxyz
	 K=1+(II-1)/(NRX*NRY)
       I=II-(K-1)*NRX*NRY
       J=1+(I-1)/NRX
       I=I-(J-1)*NRX
       LX=I-1 + (nrx-1)/2 +1 -nx0
       LY=J-1 + (nry-1)/2 +1 -ny0
       LZ=K-1 + (nrz-1)/2 +1 -nz0
c	 x=dx*(LX-1)+dxhlf
c	 XX=( (x-P_pogi)/rc)**2
c	 sumpogi=sumpogi+expogi*fac*dexp(-XX)
c	 x=dx*(LX-1)+dxhlf
c	 XX=( (x-P_nega)/rc)**2
c	 sumnega=sumnega+exnega*fac*dexp(-XX)
c ***
	 z=dz*(Lz-1)+dzhlf
	 zz=( (z-P_pogi)/rc)**2
	 sumpogi=sumpogi+expogi*fac*dexp(-zz)
	 z=dz*(Lz-1)+dzhlf
	 zz=( (z-P_nega)/rc)**2
	 sumnega=sumnega+exnega*fac*dexp(-zz)
  92	continue
  	sumpogi=sumpogi/dfloat(nxyz)*omega
	sumnega=sumnega/dfloat(nxyz)*omega
	if ( my_rank.eq.0 ) then
	write(6,*)' Sum of Pogitive extra charge = ',sumpogi
	write(6,*)' Sum of Negative extra charge = ',sumnega
	endif
c
      DO 100 II=1,NXYZ
       K=1+(II-1)/(NRX*NRY)
       I=II-(K-1)*NRX*NRY
       J=1+(I-1)/NRX
       I=I-(J-1)*NRX
       LX=I-1 + (nrx-1)/2 +1 -nx0
       LY=J-1 + (nry-1)/2 +1 -ny0
       LZ=K-1 + (nrz-1)/2 +1 -nz0
       x=dx*(LX-1)+dxhlf
       y=dy*(LY-1)+dyhlf
	 z=dz*(LZ-1)+dzhlf
c	 xp=( x-P_pogi )/rc
c	 xn=( x-P_nega )/rc
c      rext(ii)=expogi*fac*dexp(-xp*xp)
c     &        +exnega*fac*dexp(-xn*xn)
c ***
	 zp=( z-P_pogi )/rc
	 zn=( z-P_nega )/rc
      rext(ii)=expogi*fac*dexp(-zp*zp)
     &        +exnega*fac*dexp(-zn*zn)
c *** Gaussian type charge :end
  100 continue
      sum=0
      do ig=1,nxyz
      sum=sum+dreal( rext(ig) )
      enddo
	sum=sum*omega/dfloat(nxyz)
	if ( my_rank.eq.0 ) then
      write(6,*)' total extra charge = ',sum
	endif
      return
      end
