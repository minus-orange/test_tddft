c1234567
c***************************
c  This code has a restricted function of Pandy's code dmixp
c  only for a case of ID=3.
c  This code avoided 'GO TO' and 'CALL' commands
c  with no subroutines.          (Y. Miyamoto, 2021, July)
c
c  Original algorithms:
c  Donald G. Anderson, J. Assoc. Comp. Machinary, 12, 547 (1965).
c  Eqs. 4.1-4.9, and Eqs. 4.15-4.18
c
c *** input A : old potential
c           B : old potential by previous iteration
c           BETA : mixing parameter
c           TR2  : convergence criterion
C *** output B: new potential 
c *** C, D, V1, V2, working array for extrapolation
c***************************
      subroutine potextr(A,B,BETA,raa,TR2,ITN,nmesh,C,D
     &              ,V1,V2)
      implicit double precision (a-h,o-z)
      dimension A(nmesh),B(nmesh),C(nmesh),D(nmesh)
      dimension V1(nmesh,2),V2(nmesh,2)
      data epr/1.d-09/
      wari=dfloat(nmesh)
c *** temp check
c      write(6,*)' in sub potextr: iteration # =',ITN
c *** temp check : end
cc
      do ir=1,nmesh
       A(ir)=A(ir)-B(ir)
      enddo
      raa=0
      do ir=1,nmesh
       raa=raa+A(ir)*A(ir)
      enddo
      raa=raa/wari
      if (raa.lt.TR2) then
       write(6,1010)ITN,raa*2
 1010 format(' In sub potextl: at iteration', I4
     &  /'convergence achieved R2=',d24.16,
     &',  with no output potential')
       do ir=1,nmesh
        A(ir)=A(ir)+B(ir)
       enddo
       return
c      else
c       write(6,*)' ITN=',ITN,' raa=',raa*2
      endif
cc
      if (ITN.eq.1) then
       do ir=1,nmesh
        v1(ir,1)=a(ir)
        v2(ir,1)=b(ir)
       enddo
       do ir=1,nmesh
        B(ir)=B(ir) + BETA*A(ir)
       enddo
c *** temp check
c       write(6,*)' ITN=',ITN
c       write(6,*)' V1 '
c       write(6,*)( V1(ir,1),ir=1,10)
c       write(6,*)' V2 '
c       write(6,*)( V2(ir,1),ir=1,10)
c *** temp check : end
       return
c
      elseif (ITN.eq.2) then
c  ** temp checkc
c       write(6,*)' ITN=',ITN
c       write(6,*)' V1 '
c       write(6,*)( V1(ir,1),ir=1,10)
c       write(6,*)' V2 '
c       write(6,*)( V2(ir,1),ir=1,10)
c  ** temp checkc : end
       do ir=1,nmesh
        c(ir)=v1(ir,1)
        v1(ir,1)=a(ir)
       enddo
       do ir=1,nmesh
        v1(ir,2)=c(ir)
       enddo
c  ** temp checkc
c       write(6,*)' ITN=',ITN,'  C  '
c       write(6,*)(C(ir),ir=1,10)
c  ** temp checkc : end
       do ir=1,nmesh
        C(ir)=C(ir)-A(ir)
       enddo
       rcc=0
       rac=0
       do ir=1,nmesh
        rcc=rcc + C(ir)*C(ir)
        rac=rac + A(ir)*C(ir)
       enddo
c
       T=-rac/rcc
c *** temp check
c       write(6,*)' rcc=',rcc
c       write(6,*)' rac=',rac
c       write(6,*)' potextr: T=',T
c *** temp check : end
       x=1.d0-T
       bt=BETA*t
       do ir=1,nmesh
        d(ir)=V2(ir,1)
       enddo
       do ir=1,nmesh
        A(ir)=beta*A(ir) + bt*C(ir) + T*D(ir)
       enddo
c *** temp check
c       write(6,*)' potextr:'
c       write(6,*)' modified A '
c       write(6,*)(A(ir),ir=1,10)
c *** temp check : end
       do ir=1,nmesh
        v2(ir,1)=b(ir)
       enddo
       do ir=1,nmesh
        v2(ir,2)=d(ir)
       enddo
       do ir=1,nmesh
        B(ir)=B(ir)*X + A(ir)
       enddo
       return
c
      else  ! ITN.GT.2
c
       do ir=1,nmesh
        c(ir)=v1(ir,1)
        v1(ir,1)=a(ir)
       enddo
       do ir=1,nmesh
        d(ir)=v1(ir,2)
        v1(ir,2)=c(ir)
       enddo
c
c
       do ir=1,nmesh
        c(ir)=c(ir)-a(ir)
        d(ir)=d(ir)-a(ir)
       enddo
c
       rcc=0
       rac=0
       rdd=0
       rcd=0
       rad=0
       do ir=1,nmesh
        rcc=rcc + C(ir)*C(ir)
        rac=rac + A(ir)*C(ir)
        rdd=rdd + D(ir)*D(ir)
        rcd=rcd + C(ir)*D(ir)
        rad=rad + A(ir)*D(ir)
       enddo
       rccrdd=rcc*rdd
       deno=rccrdd-rcd*rcd
       denot=deno/rccrdd
       if (dabs(denot).lt.epr) then
        T1=-rac/rcc
        T2=0
       else
        T1=(-rac*rdd+rad*rcd)/deno
        T2=( rac*rcd-rad*rcc)/deno
       endif
       bt1=BETA*T1
       bt2=BETA*T2
       X=1.d0-T1-T2
       do ir=1,nmesh
        A(ir)=beta*A(ir) + bt1*C(ir) + bt2*D(ir)
       enddo
       do ir=1,nmesh
        C(ir)=V2(ir,1)
       enddo
       do ir=1,nmesh
        D(ir)=V2(ir,2)
       enddo
       do ir=1,nmesh
        A(ir)=A(ir) + T1*C(ir) + T2*D(ir)
       enddo
       do ir=1,nmesh
        v2(ir,1)=B(ir)
       enddo
       do ir=1,nmesh
        v2(ir,2)=C(ir)
       enddo
       do ir=1,nmesh
        B(ir)=B(ir)*X + A(ir)
       enddo
       return
c
      endif  ! if loop ITN.EQ.1.or.GT.2: end
c
      end  
