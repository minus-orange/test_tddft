c234567            
      subroutine dipole(rho,nxyz,nrx,nry,nrz,alat,a1,a2,a3,omega,time)
      implicit double precision (a-h,o-z)
      dimension rho(nxyz),a1(3),a2(3),a3(3)
      az=alat*a3(3)
      dz=az/dfloat(nrz)
      ay=alat*a2(2)
      dy=ay/dfloat(nry)
      ax=alat*a1(1)
      dx=ax/dfloat(nrx)
      sumx=0
      sumy=0
      sumz=0
      nzhlf=(nrz+1)/2
      nyhlf=(nry+1)/2
      nxhlf=(nrx+1)/2
      do ii=1,nxyz
       K=1+(II-1)/(NRX*NRY)
       I=II-(K-1)*NRX*NRY
       J=1+(I-1)/NRX
       I=I-(J-1)*NRX
       LX=I
       LY=J
       LZ=K
       if ( lz.le.nzhlf ) then
        z=dz*(lz-1)
       else
        z=-dz*(nrz-lz+1)
       endif
       sumz=sumz+z*rho(ii)
       if ( ly.le.nyhlf ) then
        y=dy*(ly-1)
       else
        y=-dy*(nry-ly+1)
       endif
       sumy=sumy+y*rho(ii)
       if ( lx.le.nxhlf ) then
        x=dx*(lx-1)
       else
        x=-dx*(nrx-lx+1)
       endif
       sumx=sumx+x*rho(ii)
      enddo
      sumx=sumx*omega/dfloat(nxyz)
      sumy=sumy*omega/dfloat(nxyz)
      sumz=sumz*omega/dfloat(nxyz)
      write(91,1000)time,sumx,sumy,sumz
 1000 format(4f22.16)
      return
      end
