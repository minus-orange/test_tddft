c
      subroutine nrmlz(coef,nbnd,nbndq,NG2,NG2Q)
      implicit double precision(a-h,o-z)
      complex*16 coef(NG2Q,NBNDQ)
      do 1 ib=1,nbnd
       snorm=0
       do 2 ig=1,ng2
        snorm=snorm+dreal( dconjg( coef(ig,ib) )*coef(ig,ib) )
    2  continue
        snorm=1.d0/dsqrt(snorm)
       do 3 ig=1,ng2
        coef(ig,ib)=snorm*coef(ig,ib)
    3  continue
    1 continue
      return
      end
c
c
c     inputs :  c0
c     outputs:  cp
c
      subroutine ortho(nx,ngwx,cp,c0,n,ngw,sig,x0,x1,work1,work2)
      implicit real*8(a-h,o-z)
ceeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
      complex*16 cp(ngwx,nx),c0(ngwx,nx)
ceeeeeee local variables eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
      complex*16 sig(nx,nx),x0(nx,nx),x1(nx,nx)
     &          ,work1(nx,nx),work2(nx,nx)
      complex*16 sumc
      data eps/1.d-12/,maxort/20/
c ***  temp check
c      write(6,*)' in sub. ortho:'
c      do i=1,n
c       write(6,*)' ib = ',i
c       write(6,*)' coef '
c       write(6,*)( c0(ig,i),ig=1,ngw,100 )
c      enddo
c ***  temp check : end
c...make sigma matrix
      do i=1,n
      do j=1,i
      call wfmult(ngw,c0(1,i),c0(1,j),xr,xi)
      if(i.eq.j) then
c ***  temp check
c        write(6,'(a,2i3,e15.7)') 'ortho:',i,j,xr
c ***  temp check end
        do ig=1,ngw
        c0(ig,i)=c0(ig,i)/sqrt(xr)
        enddo
        sig(i,j)=dcmplx(0.d0,0.d0)
c       sig(i,j)=-dcmplx(xr,xi)+dcmplx(1.d0,0.d0)
      else
c        write(6,'(a,2i3,2e15.7)') ' ortho:',i,j,xr,xi
        sig(i,j)=-dcmplx(xr, xi)
        sig(j,i)=-dcmplx(xr,-xi)
      endif
      enddo
      enddo
c...initial lambda
      do i=1,n
      do j=1,n
        x0(i,j)=sig(i,j)/2.d0
      enddo
      enddo
c...iterative solution
      iter=0
  100 continue
      iter = iter+1
c     write(6,*) ' iter ',iter
c...lambda*sigma-->work1
      do i=1,n
      do j=1,n
        work1(i,j)=dcmplx(0.d0,0.d0)
        do k=1,n
        work1(i,j)=work1(i,j)+x0(i,k)*sig(k,j)
        enddo
      enddo
      enddo
c...sigma*lambda+lambda*sigma-->work2
      do i=1,n
      do j=1,n
        work2(j,i)=work1(j,i)+dconjg(work1(i,j))
      enddo
      enddo
c...lambda*(1-sigma)-->work1
      do i=1,n
      do j=1,n
        work1(i,j)=x0(i,j)-work1(i,j)
      enddo
      enddo
c...lambda*(1-sigma)*lambda add to work2
      do i=1,n
      do j=1,n
        do k=1,n
c        work2(i,j)=work2(i,j)+work1(i,k)*x0(k,j)
        work2(i,j)=work2(i,j)-work1(i,k)*x0(k,j) ! correction by Sugino
        enddo
      enddo
      enddo
c...new lambda
      do i=1,n
      do j=1,n
c       x1(i,j)=(sig(i,j)+work2(i,j))/2.d0
        x1(i,j)=(sig(i,j)+work2(i,j)-(sig(i,i)+sig(j,j))*x0(i,j))
     &         /(2.d0-sig(i,i)-sig(j,j))
      enddo
      enddo
c...difference
      diff=0.d0
      do i=1,n
      do j=1,n
      if(abs(x1(i,j)-x0(i,j)).gt.diff) diff=abs(x1(i,j)-x0(i,j))
      enddo
      enddo
c
      do i=1,n
      do j=1,n
        x0(i,j)=x1(i,j)
      enddo
      enddo
c
c     write(*,*) ' ortho ',diff,iter
      if((diff.gt.0.5*eps).and.(iter.le.maxort)) goto 100
      if (iter.gt.5) write(*,*) ' ortho ',diff,iter
      if (iter.gt.maxort) then
        print *,' ortho: diff= ',diff,' iter= ',iter,' max ',maxort
        print *,' maximum number of iterations exceeded ' 
        stop
      endif
c
      do i=1,n
      do ig=1,ngw
        cp(ig,i)=c0(ig,i)
      enddo
      enddo
      do i=1,n
      do j=1,n
      do ig=1,ngw
        cp(ig,i)=cp(ig,i)+c0(ig,j)*x0(j,i)
      enddo
      enddo
      enddo
c_debug
c     write(6,*) ' debug ortho ',n
c     do i=1,n
c     do j=1,n
c       call wfmult(ngw,cp(1,i),cp(1,j),xr,xi)
c       if(i.eq.j) then
c         sumc=dcmplx(xr-1.d0,xi)
c         if(abs(sumc).gt.1.e-10) write(6,*) i,sumc
c       else
c         sumc=dcmplx(xr,xi)
c         if(abs(sumc).gt.1.e-10) write(6,*) i,j,sumc
c       endif
c     enddo
c     enddo
c
      return
      end
      subroutine wfmult(ngw,ci,cj,xr,xi)
      implicit double precision(a-h,o-z)
      complex*16 ci(ngw),cj(ngw),cij
      cij=dcmplx(0.d0,0.d0)
      do ig=1,ngw
      cij=cij+dconjg( ci(ig) )*cj(ig) 
      enddo
      xr=dreal(cij)
c      xi=imag(cij)   ! for workstation
      xi=dimag(cij)  ! for sx3
      return
      end
