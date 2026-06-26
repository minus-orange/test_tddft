!
! Copyright (c) 2000-2013,2016 Yoshihide Yoshimoto
!
! Permission is hereby granted, free of charge, to any person
! obtaining a copy of this software and associated documentation files
! (the "Software"), to deal in the Software without restriction,
! including without limitation the rights to use, copy, modify, merge,
! publish, distribute, sublicense, and/or sell copies of the Software,
! and to permit persons to whom the Software is furnished to do so,
! subject to the following conditions:
!
! The above copyright notice and this permission notice shall be
! included in all copies or substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED ¡ÈAS IS¡É, WITHOUT WARRANTY OF ANY KIND,
! EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
! MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
! NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
! BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
! ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
! CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
! SOFTWARE.
!
!
! Ref: G.H. Gloub and C.F. van Loan
!      Matrix Computations 1983, John Hopkins University Press
!
! using tri-diagonal decomposition by the Householder transformation
! and the implicit QR or QL algorithm.
!
!#define EIGSYSTM_PROF
!#define USE_MPI

module eigsystm
  private zhetrt, zhetrtp1, dstqre, dstqle, zstqrv, zstqlv, zhetru, hsort
  private dsytrt, dsytrtp1, dstqrv, dstqlv, dsytru
contains
  integer function getldm(c,n)
    implicit none
    character(len=1):: c
    integer,intent(in):: n

    integer:: p, q

    if (c .eq. 'Z') then
       p = n/128
       q = mod(n,128)
       if (q.lt.8) then
          getldm = 128*p+8+1
       else if (q.gt.120) then
          getldm = 128*(p+1)+8+1
       else
          getldm = n
       end if
    else if (c .eq. 'D') then
       p = n/256
       q = mod(n,256)
       if (q.lt.8) then
          getldm = 256*p+8+1
       else if (q.gt.248) then
          getldm = 256*(p+1)+8+1
       else
          getldm = n
       end if
    else
       write(6,*) 'getldm: unsupported type ', c
       stop
    end if
    return
  end function getldm

  subroutine zhegv1vu(n,a,b,ln,e,ntsk,comm,xinfo)
#ifdef EIGSYSTM_PROF
    use timeprof
#endif
#ifdef USE_MPI
    use mpi
#endif
    implicit none
    integer,intent(in):: n,ln,ntsk,comm
    integer,intent(out):: xinfo
    complex(kind=8):: a(ln,n),b(ln,n)
    real(kind=8),intent(out):: e(n)

#ifdef TMP_ON_STACK
    complex(kind=8):: y(ln,n),x(ln,n)
#else
    complex(kind=8),allocatable:: y(:,:),x(:,:)
#endif
    !integer:: info
    integer:: i,j,k
    real(kind=8):: sum
    complex(kind=8):: csum

    integer:: myrank,nproc,irnk,bn,en,ierr,nfor
    integer,allocatable:: count(:),displ(:)
    complex(kind=8),allocatable:: s(:,:),r(:,:)

#ifdef EIGSYSTM_PROF
    call tpf_begin_hc(tpf_eig)
#endif

    nfor = ntsk*2

#ifdef USE_MPI
    call MPI_COMM_RANK(comm,myrank,ierr)
    call MPI_COMM_SIZE(comm,nproc,ierr)
#else
    myrank = 0
    nproc = 1
#endif

    allocate(count(0:nproc-1),displ(0:nproc-1))

    count = n/nproc
    do irnk=0,mod(n,nproc)-1
       count(irnk) = count(irnk)+1
    end do
    displ(0) = 0
    do irnk=0,nproc-2
       displ(irnk+1) = displ(irnk) + count(irnk)
    end do
    bn = displ(myrank)+1
    en = displ(myrank)+count(myrank)

    allocate(s(ln,bn:en),r(ln,n))

    count = ln*count
    displ = ln*displ

#ifndef TMP_ON_STACK
    allocate(y(ln,n),x(ln,n))
#endif
    !
    ! Cholesky decomposition
    !
!cdir reserve
    do k=1,n
       sum = b(k,k)
       do j=1,k-1
          sum = sum - conjg(b(j,k))*b(j,k)
       end do
       if (sum.le.0.0d0) then
          xinfo = k
          return
       end if
       sum = sqrt(sum)
       b(k,k) = sum
       do j=k+1,n
          csum = b(k,j)
          do i=1,k-1
             csum = csum - conjg(b(i,k))*b(i,j)
          end do
          b(k,j) = csum/sum
       end do
    end do

!soption noloopinterchange
!cdir noloopchg
    do i=bn,en
       do j=1,n
          if (i.le.j) then
             csum = a(i,j)
          else
             csum = conjg(a(j,i))
          end if
          do k=1,j-1
             csum = csum - s(k,i)*b(k,j)
          end do
          s(j,i) = csum/b(j,j)
       end do
    end do
#ifdef USE_MPI
    call MPI_ALLGATHERV(s,count(myrank),MPI_DOUBLE_COMPLEX, &
         r,count,displ,MPI_DOUBLE_COMPLEX,comm,ierr)
#else
    r = s
#endif
    do i=1,n
       do j=1,n
          y(i,j) = r(j,i)
       end do
    end do

!soption noloopinterchange
!cdir noloopchg
    do j=bn,en
       do i=1,n
          csum = y(i,j)
          do k=1,i-1
             csum = csum - conjg(b(k,i))*s(k,j)
          end do
          s(i,j) = csum/conjg(b(i,i))
       end do
    end do
#ifdef USE_MPI
    call MPI_ALLGATHERV(s,count(myrank),MPI_DOUBLE_COMPLEX, &
         x,count,displ,MPI_DOUBLE_COMPLEX,comm,ierr)
#else
    x = s
#endif

    do i=1,n
       x(i,i) = dble(x(i,i))
    end do
!cdir release

#ifdef EIGSYSTM_PROF
    call tpf_end_hc(tpf_eig)
#endif
    call zheevvl(n,x,ln,e,xinfo,ntsk,comm)
#ifdef EIGSYSTM_PROF
    call tpf_begin_hc(tpf_eig)
#endif

!$omp parallel do private(i,j),schedule(static,1)
!poption cyclic
!cdir nosync,concur(for=nfor)
    do j=1,n
       do i=j+1,n
          b(i,j) = b(j,i)
       end do
    end do

!soption noloopinterchange
!cdir reserve
!cdir noloopchg
    do j=bn,en
       do i=n,1,-1
          csum = x(i,j)
          do k=i+1,n
             !
             ! to improve performance, b(k,i) is set to b(i,k).
             !
             csum = csum - b(k,i)*s(k,j)
          end do
          s(i,j) = csum/b(i,i)
       end do
    end do
!cdir release
#ifdef USE_MPI
    call MPI_ALLGATHERV(s,count(myrank),MPI_DOUBLE_COMPLEX, &
         a,count,displ,MPI_DOUBLE_COMPLEX,comm,ierr)
#else
    a = s
#endif

#ifndef TMP_ON_STACK
    deallocate(y,x)
#endif

    deallocate(s,r,count,displ)

#ifdef EIGSYSTM_PROF
    call tpf_end_hc(tpf_eig)
#endif
    return
  end subroutine zhegv1vu

  subroutine zhegv1vl(n,a,b,ln,e,ntsk,comm,xinfo)
#ifdef EIGSYSTM_PROF
    use timeprof
#endif
    implicit none
    integer,intent(in):: n,ln,ntsk,comm
    integer,intent(out):: xinfo
    complex(kind=8):: a(ln,n),b(ln,n)
    real(kind=8),intent(out):: e(n)
    integer:: i,j

    ! XXX
!cdir nosync
#ifdef EIGSYSTM_PROF
    call tpf_begin_hc(tpf_eig)
#endif
    do j=1,n
       do i=j+1,n
          a(j,i) = conjg(a(i,j))
          b(j,i) = conjg(b(i,j))
       end do
    end do
#ifdef EIGSYSTM_PROF
    call tpf_end_hc(tpf_eig)
#endif

    call zhegv1vu(n,a,b,ln,e,ntsk,comm,xinfo)

    return
  end subroutine zhegv1vl

  subroutine zheevvl(n,a,ln,eig,info,ntsk,comm)
#ifdef EIGSYSTM_PROF
    use timeprof
#endif
#ifdef USE_MPI
    use mpi
#endif
    implicit none
    integer,intent(in):: n,ln,ntsk,comm
    integer,intent(out):: info
    complex(kind=8):: a(ln,n)
    real(kind=8),intent(out):: eig(n)

    integer,parameter:: m = 5

    complex(kind=8),allocatable:: v(:,:),scl(:),z(:,:)
    real(kind=8),allocatable:: d(:),e(:),cv(:),sv(:)
    integer,allocatable:: rv(:,:),count(:),displ(:),idx(:)
    integer:: i,it,mt,ncs
    integer:: myrank,nproc,irnk,bn,en,ierr

#ifdef EIGSYSTM_PROF
    call tpf_begin(tpf_eig)
#endif

    info = 0

    mt = m*n
    ncs = n*mt/2
    allocate(d(n),e(0:n),cv(ncs),sv(ncs),rv(2,mt), &
         v(ln,n),scl(n), stat=ierr)
    if (ierr .ne. 0) then
       info = 101
       return
    end if

!cdir reserve=ntsk

    call zhetrt(n,a,ln,d,e,v,scl,ntsk,info)
    if (info .ne. 0) then
       return
    end if
    !call dstqre(n,d,e,ncs,mt,cv,sv,rv,it,info)
    call dstqle(n,d,e,ncs,mt,cv,sv,rv,it,info)
    if (info .ne. 0) then
       return
    end if

    eig = d

#ifdef USE_MPI
    call MPI_COMM_RANK(comm,myrank,ierr)
    call MPI_COMM_SIZE(comm,nproc,ierr)
#else
    myrank = 0
    nproc = 1
#endif

    allocate(count(0:nproc-1),displ(0:nproc-1),stat=ierr)
    if (ierr .ne. 0) then
       info = 102
       return
    end if

    count = n/nproc
    do irnk=0,mod(n,nproc)-1
       count(irnk) = count(irnk)+1
    end do
    displ(0) = 0
    do irnk=0,nproc-2
       displ(irnk+1) = displ(irnk) + count(irnk)
    end do
    bn = displ(myrank)+1
    en = displ(myrank)+count(myrank)

    allocate(z(ln,bn:en),stat=ierr)
    if (ierr .ne. 0) then
       info = 103
       return
    end if

    count = ln*count
    displ = ln*displ

    !call zstqrv(it,ncs,cv,sv,rv,z,ln,bn,en)
    call zstqlv(it,ncs,cv,sv,rv,z,ln,bn,en)
    call zhetru(n,v,ln,scl,z,bn,en)

#ifdef USE_MPI
    call MPI_ALLGATHERV(z,count(myrank),MPI_DOUBLE_COMPLEX, &
         v,count,displ,MPI_DOUBLE_COMPLEX,comm,ierr)
#else
    v = z
#endif

    deallocate(z)

    allocate(idx(n),stat=ierr)
    if (ierr .ne. 0) then
       info = 105
       return
    end if
    call hsort(n,eig,idx)
    do i=1,n
       a(:,i) = v(:,idx(i))
    end do
    deallocate(idx)

    deallocate(count,displ)

!cdir release

    deallocate(d,e,cv,sv,rv,v,scl)

#ifdef EIGSYSTM_PROF
    call tpf_end(tpf_eig)
#endif
    return
  end subroutine zheevvl

  subroutine zhetrt(n,a,ln,d,e,v,scl,ntsk,info)
    implicit none
    integer,intent(in):: n,ln,ntsk
    integer,intent(out):: info
    complex(kind=8):: a(ln,n)
    complex(kind=8),intent(out):: v(ln,n),scl(n)
    real(kind=8),intent(out):: d(n),e(0:n)

    integer:: i,j,k,ir,ierr,nfor
    real(kind=8):: tr,ti,tsq,tm
    complex(kind=8):: tz
    complex(kind=8),allocatable:: p(:),w(:)

    nfor = ntsk*2

    allocate(p(n),w(n),stat=ierr)
    if (ierr .ne. 0) then
       info = 104
       return
    end if

    do k=1,n-1
       d(k) = dble(a(k,k))
       tm = 0.0d0
       do i=k+1,n
          tr = dble(a(i,k))
          ti = aimag(a(i,k))
          tm = max(tm,abs(tr)+abs(ti))
       end do
       if (tm .eq. 0.0d0) then
          v(k+1:n,k) = (0.0d0, 0.0d0)
          e(k) = 0.0d0
          scl(k) = (0.0d0, 0.0d0)
          cycle
       end if
       tsq = 0.0d0
       do i=k+1,n
          v(i,k) = a(i,k)/tm
          tr = dble(v(i,k))
          ti = aimag(v(i,k))
          tsq = tsq + tr*tr + ti*ti
       end do
       e(k) = sign(sqrt(tsq),-dble(v(k+1,k)))
       scl(k) = tsq - e(k)*conjg(v(k+1,k))
       scl(k) = 0.5d0/scl(k)
       v(k+1,k) = v(k+1,k) - e(k)
       e(k) = tm*e(k)

       do i=k+1,n
          p(i) = dble(a(i,i))*v(i,k)
       end do
       call zhetrtp1(n,k,p,a,ln,v,nfor)

       !
       ! before unrolling
       !
       !do i=k+1,n
       !   do j=i+1,n
       !      p(i) = p(i) + conjg(a(j,i))*v(j,k)
       !   end do
       !end do
       !
       ir = mod(n-k,2)
       if (ir.eq.1) then
          do j=k+2,n
             p(k+1) = p(k+1) + conjg(a(j,k+1))*v(j,k)
          end do
       end if
!$omp parallel do private(i,j),schedule(static,1)
!cdir concur(for=nfor)
!poption cyclic
       do i=k+1+ir,n,2
          p(i) = p(i) + conjg(a(i+1,i))*v(i+1,k)
!cdir noloopchg
!soption noloopinterchange,unroll(2)
          do j=i+2,n
             p(i) = p(i) + conjg(a(j,i))*v(j,k)
             p(i+1) = p(i+1) + conjg(a(j,i+1))*v(j,k)
          end do
       end do

       p(k+1:n) = (2.0d0*scl(k))*p(k+1:n)

       tz = (0.0d0,0.0d0)
       do i=k+1,n
          tz = tz + conjg(p(i))*v(i,k)
       end do
       tz = scl(k)*tz

       w(k+1:n) = p(k+1:n) - tz*v(k+1:n,k)

!$omp parallel do private(i,j),schedule(static,1)
!cdir concur(for=nfor)
!poption cyclic
       do j=k+1,n
          do i=j,n
             a(i,j) = a(i,j) - v(i,k)*conjg(w(j)) - w(i)*conjg(v(j,k))
          end do
       end do

       scl(k) = 2.0d0*scl(k)
    end do
    d(n) = dble(a(n,n))

    deallocate(p,w)
    return
  end subroutine zhetrt

  subroutine zhetrtp1(n,k,p,a,ln,v,nfor)
    implicit none
    integer,intent(in):: n,k,ln,nfor
    complex(kind=8),intent(in):: a(ln,n),v(ln,n)
    complex(kind=8):: p(n)

    integer:: i,j

!$omp parallel do private(i,j),schedule(static,1)
    do i=k+2,n
       do j=k+1,i-1
          p(i) = p(i) + a(i,j)*v(j,k)
       end do
    end do

    return
  end subroutine zhetrtp1

  subroutine dstqre(n,d,e,ncs,mt,cv,sv,rv,it,info)
    implicit none

    integer,intent(in):: n,mt,ncs
    integer,intent(out):: it,info
    real(kind=8):: d(n),e(0:n)
    real(kind=8),intent(out):: cv(ncs),sv(ncs)
    integer,intent(out):: rv(2,mt)

    integer:: i,p,q,ics
    real(kind=8):: t,mu,x,z,dn,dp1,em1,en,ep1,c,s,sq

    info = 0

    q = n
    it = 0
    ics = 0
    e(n) = 0.0d0
    do while (q.gt.1)
       do i=1,q-1
          t = abs(d(i))+abs(d(i+1))
          if (t .eq. t + abs(e(i))) then
             e(i) = 0.0d0
          end if
       end do

       do while (q.gt.1)
          if (e(q-1) .ne. 0.0d0) then
             exit
          end if
          q = q - 1
       end do
       if (q.eq.1) then
          exit
       end if

       p = q
       do while (p.gt.1)
          if (e(p-1) .eq. 0.0d0) then
             exit
          end if
          p = p - 1
       end do

       t = 0.5d0*(d(q-1)-d(q))
       mu = d(q)-e(q-1)*e(q-1)/(t+sign(sqrt(t*t+e(q-1)*e(q-1)),t))
       x = d(p) - mu
       z = e(p)
       it = it + 1
       if (it .gt. mt) then
          info = 1
          return
       end if
       rv(1,it) = p
       rv(2,it) = q

       if (abs(z) .lt. abs(x)) then
          t = z/x
          sq = sqrt(1.0d0+t**2)
          c = 1.0d0/sq
          s = t*c
          c = -c
       else
          t = x/z
          sq = sqrt(1.0d0+t**2)
          s = 1.0d0/sq
          c = -t*s
       end if
       !sq = sqrt(z*z+x*x)
       !c = -x/sq
       !s = z/sq
       dn = c*d(p)*c - 2.0d0*c*e(p)*s + s*d(p+1)*s
       dp1 = s*d(p)*s + 2.0d0*c*e(p)*s + c*d(p+1)*c
       en = c*s*(d(p)-d(p+1)) + (c*c-s*s)*e(p)
       ep1 = c*e(p+1)
       z = -s*e(p+1)
       x = en
       d(p) = dn
       d(p+1) = dp1
       e(p) = en
       e(p+1) = ep1
       if (ics + q-p .gt. ncs) then
          info = 2
          return
       end if
       ics = ics + 1
       cv(ics) = c
       sv(ics) = s

       do i=p+1,q-1
          if (abs(z) .lt. abs(x)) then
             t = z/x
             sq = sqrt(1.0d0+t**2)
             c = 1.0d0/sq
             s = t*c
             c = -c
          else
             t = x/z
             sq = sqrt(1.0d0+t**2)
             s = 1.0d0/sq
             c = -t*s
          end if
          !sq = sqrt(z*z+x*x)
          !c = -x/sq
          !s = z/sq
          dn = c*d(i)*c - 2.0d0*c*e(i)*s + s*d(i+1)*s
          dp1 = s*d(i)*s + 2.0d0*c*e(i)*s + c*d(i+1)*c
          en = c*s*(d(i)-d(i+1)) + (c*c-s*s)*e(i)
          ep1 = c*e(i+1)
          em1 = c*e(i-1) - s*z
          z = -s*e(i+1)
          x = en
          d(i) = dn
          d(i+1) = dp1
          e(i-1) = em1
          e(i) = en
          e(i+1) = ep1
          ics = ics + 1
          cv(ics) = c
          sv(ics) = s
       end do
    end do
    return
  end subroutine dstqre

  subroutine dstqle(n,d,e,ncs,mt,cv,sv,rv,it,info)
    implicit none

    integer,intent(in):: n,mt,ncs
    integer,intent(out):: it,info
    real(kind=8):: d(n),e(0:n)
    real(kind=8),intent(out):: cv(ncs),sv(ncs)
    integer,intent(out):: rv(2,mt)

    integer:: i,p,q,ics
    real(kind=8):: t,mu,x,z,dn,dp1,em1,en,ep1,c,s,sq

    info = 0

    p = 1
    it = 0
    ics = ncs
    e(0) = 0.0d0
    do while (p.lt.n)
       do i=p,n-1
          t = abs(d(i))+abs(d(i+1))
          if (t .eq. t + abs(e(i))) then
             e(i) = 0.0d0
          end if
       end do

       do while (p.lt.n)
          if (e(p) .ne. 0.0d0) then
             exit
          end if
          p = p + 1
       end do
       if (p.eq.n) then
          exit
       end if

       q = p
       do while (q.lt.n)
          if (e(q) .eq. 0.0d0) then
             exit
          end if
          q = q + 1
       end do

       t = 0.5d0*(d(p+1)-d(p))
       mu = d(p)-e(p)*e(p)/(t+sign(sqrt(t*t+e(p)*e(p)),t))
       x = d(q) - mu
       z = e(q-1)
       it = it + 1
       if (it .gt. mt) then
          info = 1
          return
       end if
       rv(1,it) = p
       rv(2,it) = q

       if (abs(z) .lt. abs(x)) then
          t = z/x
          sq = sqrt(1.0d0+t**2)
          c = 1.0d0/sq
          s = t*c
          c = c
       else
          t = x/z
          sq = sqrt(1.0d0+t**2)
          s = 1.0d0/sq
          c = t*s
       end if
       !sq = sqrt(z*z+x*x)
       !c = x/sq
       !s = z/sq
       dn = c*d(q-1)*c - 2.0d0*c*e(q-1)*s + s*d(q)*s
       dp1 = s*d(q-1)*s + 2.0d0*c*e(q-1)*s + c*d(q)*c
       en = c*s*(d(q-1)-d(q)) + (c*c-s*s)*e(q-1)
       em1 = c*e(q-2)
       z = s*e(q-2)
       x = en
       d(q-1) = dn
       d(q) = dp1
       e(q-2) = em1
       e(q-1) = en
       if ( ics-q+p .lt. 0 ) then
          info = 2
          return
       end if
       cv(ics) = c
       sv(ics) = s
       ics = ics - 1

       do i=q-2,p,-1
          if (abs(z) .lt. abs(x)) then
             t = z/x
             sq = sqrt(1.0d0+t**2)
             c = 1.0d0/sq
             s = t*c
             c = c
          else
             t = x/z
             sq = sqrt(1.0d0+t**2)
             s = 1.0d0/sq
             c = t*s
          end if
          !sq = sqrt(z*z+x*x)
          !c = x/sq
          !s = z/sq
          dn = c*d(i)*c - 2.0d0*c*e(i)*s + s*d(i+1)*s
          dp1 = s*d(i)*s + 2.0d0*c*e(i)*s + c*d(i+1)*c
          en = c*s*(d(i)-d(i+1)) + (c*c-s*s)*e(i)
          ep1 = z*s + e(i+1)*c
          em1 = c*e(i-1)
          z = s*e(i-1)
          x = en
          d(i) = dn
          d(i+1) = dp1
          e(i-1) = em1
          e(i) = en
          e(i+1) = ep1
          cv(ics) = c
          sv(ics) = s
          ics = ics - 1
       end do
    end do
    return
  end subroutine dstqle

  subroutine zstqrv(it,ncs,cv,sv,rv,z,ln,bn,en)
    implicit none

    integer,intent(in):: it,ln,bn,en,ncs
    real(kind=8),intent(in):: cv(ncs),sv(ncs)
    integer,intent(in):: rv(2,it)
    complex(kind=8),intent(out):: z(ln,bn:en)

    complex(kind=8):: t1,t2
    integer:: jt,i,p,q,k,ics,jcs

    jcs = 0
    do jt=it,1,-1
       p = rv(1,jt)
       q = rv(2,jt)
       jcs = jcs + q-p
    end do

    z = (0.0d0, 0.0d0)
    do i=bn,en
       z(i,i) = (1.0d0, 0.0d0)
    end do

!OCL TEMP(ics)
!poption tlocal(ics)
    do k=bn,en
       ics = jcs
       do jt=it,1,-1
          p = rv(1,jt)
          q = rv(2,jt)
          do i=q-1,p,-1
             t1 = z(i,k)
             t2 = z(i+1,k)
             z(i,k) = cv(ics)*t1 + sv(ics)*t2
             z(i+1,k) = -sv(ics)*t1 + cv(ics)*t2
             ics = ics - 1
          end do
       end do
    end do
    return
  end subroutine zstqrv

  subroutine zstqlv(it,ncs,cv,sv,rv,z,ln,bn,en)
    implicit none

    integer,intent(in):: it,ln,bn,en,ncs
    real(kind=8),intent(in):: cv(ncs),sv(ncs)
    integer,intent(in):: rv(2,it)
    complex(kind=8),intent(out):: z(ln,bn:en)

    complex(kind=8):: t1,t2
    integer:: jt,i,p,q,k,ics,jcs

    jcs = ncs
    do jt=it,1,-1
       p = rv(1,jt)
       q = rv(2,jt)
       jcs = jcs - q+p
    end do

    z = (0.0d0, 0.0d0)
    do i=bn,en
       z(i,i) = (1.0d0, 0.0d0)
    end do

!OCL TEMP(ics)
!poption tlocal(ics)
    do k=bn,en
       ics = jcs
       do jt=it,1,-1
          p = rv(1,jt)
          q = rv(2,jt)
          do i=p,q-1
             t1 = z(i,k)
             t2 = z(i+1,k)
             ics = ics + 1
             z(i,k) = cv(ics)*t1 + sv(ics)*t2
             z(i+1,k) = -sv(ics)*t1 + cv(ics)*t2
          end do
       end do
    end do
    return
  end subroutine zstqlv

  subroutine zhetru(n,v,ln,scl,z,bn,en)
    implicit none
    integer,intent(in):: n,ln,bn,en
    complex(kind=8),intent(in):: v(ln,n), scl(n)
    complex(kind=8):: z(ln,bn:en)

    integer:: i,j,k
    complex(kind=8):: tz

    do j=bn,en
       do k=n-1,1,-1
          tz = (0.0d0, 0.0d0)
          do i=k+1,n
             tz = tz + conjg(v(i,k))*z(i,j)
          end do
          tz = -scl(k)*tz
          do i=k+1,n
             z(i,j) = z(i,j) + tz*v(i,k)
          end do
       end do
    end do
    return
  end subroutine zhetru

  subroutine dsygv1vu(n,a,b,ln,e,ntsk,comm,xinfo)
#ifdef USE_MPI
    use mpi
#endif
#ifdef EIGSYSTM_PROF
    use timeprof
#endif
    implicit none
    integer,intent(in):: n,ln,ntsk,comm
    integer,intent(out):: xinfo
    real(kind=8):: a(ln,n),b(ln,n)
    real(kind=8),intent(out):: e(n)

#ifdef TMP_ON_STACK
    real(kind=8):: y(ln,n),x(ln,n)
#else
    real(kind=8),allocatable:: y(:,:),x(:,:)
#endif
    !integer:: info
    integer:: i,j,k
    real(kind=8):: sum
    real(kind=8):: csum

    integer:: myrank,nproc,irnk,bn,en,ierr,nfor
    integer,allocatable:: count(:),displ(:)
    real(kind=8),allocatable:: s(:,:),r(:,:)

#ifdef EIGSYSTM_PROF
    call tpf_begin_hc(tpf_eig)
#endif

    nfor = ntsk*2

#ifdef USE_MPI
    call MPI_COMM_RANK(comm,myrank,ierr)
    call MPI_COMM_SIZE(comm,nproc,ierr)
#else
    myrank = 0
    nproc = 1
#endif

    allocate(count(0:nproc-1),displ(0:nproc-1))

    count = n/nproc
    do irnk=0,mod(n,nproc)-1
       count(irnk) = count(irnk)+1
    end do
    displ(0) = 0
    do irnk=0,nproc-2
       displ(irnk+1) = displ(irnk) + count(irnk)
    end do
    bn = displ(myrank)+1
    en = displ(myrank)+count(myrank)

    allocate(s(ln,bn:en),r(ln,n))

    count = ln*count
    displ = ln*displ

#ifndef TMP_ON_STACK
    allocate(y(ln,n),x(ln,n))
#endif
    !
    ! Cholesky decomposition
    !
!cdir reserve
    do k=1,n
       sum = b(k,k)
       do j=1,k-1
          sum = sum - b(j,k)*b(j,k)
       end do
       if (sum.le.0.0d0) then
          xinfo = k
          return
       end if
       sum = sqrt(sum)
       b(k,k) = sum
       do j=k+1,n
          csum = b(k,j)
          do i=1,k-1
             csum = csum - b(i,k)*b(i,j)
          end do
          b(k,j) = csum/sum
       end do
    end do

!soption noloopinterchange
!cdir noloopchg
    do i=bn,en
       do j=1,n
          if (i.le.j) then
             csum = a(i,j)
          else
             csum = a(j,i)
          end if
          do k=1,j-1
             csum = csum - s(k,i)*b(k,j)
          end do
          s(j,i) = csum/b(j,j)
       end do
    end do
#ifdef USE_MPI
    call MPI_ALLGATHERV(s,count(myrank),MPI_DOUBLE_PRECISION, &
         r,count,displ,MPI_DOUBLE_PRECISION,comm,ierr)
#else
    r = s
#endif
    do i=1,n
       do j=1,n
          y(i,j) = r(j,i)
       end do
    end do

!soption noloopinterchange
!cdir noloopchg
    do j=bn,en
       do i=1,n
          csum = y(i,j)
          do k=1,i-1
             csum = csum - b(k,i)*s(k,j)
          end do
          s(i,j) = csum/b(i,i)
       end do
    end do
#ifdef USE_MPI
    call MPI_ALLGATHERV(s,count(myrank),MPI_DOUBLE_PRECISION, &
         x,count,displ,MPI_DOUBLE_PRECISION,comm,ierr)
#else
    x = s
#endif

!cdir release

#ifdef EIGSYSTM_PROF
    call tpf_end_hc(tpf_eig)
#endif
    call dsyevvl(n,x,ln,e,xinfo,ntsk,comm)
#ifdef EIGSYSTM_PROF
    call tpf_begin_hc(tpf_eig)
#endif

!$omp parallel do private(i,j),schedule(static,1)
!poption cyclic
!cdir nosync,concur(for=nfor)
    do j=1,n
       do i=j+1,n
          b(i,j) = b(j,i)
       end do
    end do

!soption noloopinterchange
!cdir reserve
!cdir noloopchg
    do j=bn,en
       do i=n,1,-1
          csum = x(i,j)
          do k=i+1,n
             !
             ! to improve performance, b(k,i) is set to b(i,k).
             !
             csum = csum - b(k,i)*s(k,j)
          end do
          s(i,j) = csum/b(i,i)
       end do
    end do
!cdir release
#ifdef USE_MPI
    call MPI_ALLGATHERV(s,count(myrank),MPI_DOUBLE_PRECISION, &
         a,count,displ,MPI_DOUBLE_PRECISION,comm,ierr)
#else
    a = s
#endif

#ifndef TMP_ON_STACK
    deallocate(y,x)
#endif

    deallocate(s,r,count,displ)

#ifdef EIGSYSTM_PROF
    call tpf_end_hc(tpf_eig)
#endif
    return
  end subroutine dsygv1vu

  subroutine dsygv1vl(n,a,b,ln,e,ntsk,comm,xinfo)
#ifdef EIGSYSTM_PROF
    use timeprof
#endif
    implicit none
    integer,intent(in):: n,ln,ntsk,comm
    integer,intent(out):: xinfo
    real(kind=8):: a(ln,n),b(ln,n)
    real(kind=8),intent(out):: e(n)
    integer:: i,j

#ifdef EIGSYSTM_PROF
    call tpf_begin_hc(tpf_eig)
#endif
    ! XXX
!cdir nosync
    do j=1,n
       do i=j+1,n
          a(j,i) = a(i,j)
          b(j,i) = b(i,j)
       end do
    end do

#ifdef EIGSYSTM_PROF
    call tpf_end_hc(tpf_eig)
#endif

    call dsygv1vu(n,a,b,ln,e,ntsk,comm,xinfo)

    return
  end subroutine dsygv1vl

  subroutine dsyevvl(n,a,ln,eig,info,ntsk,comm)
#ifdef USE_MPI
    use mpi
#endif
#ifdef EIGSYSTM_PROF
    use timeprof
#endif
    implicit none
    integer,intent(in):: n,ln,ntsk,comm
    integer,intent(out):: info
    real(kind=8):: a(ln,n)
    real(kind=8),intent(out):: eig(n)

    integer,parameter:: m = 5

    real(kind=8),allocatable:: v(:,:),scl(:),z(:,:)
    real(kind=8),allocatable:: d(:),e(:),cv(:),sv(:)
    integer,allocatable:: rv(:,:),count(:),displ(:),idx(:)
    integer:: i,it,mt,ncs
    integer:: myrank,nproc,irnk,bn,en,ierr


#ifdef EIGSYSTM_PROF
    call tpf_begin(tpf_eig)
#endif

    info = 0

    mt = m*n
    ncs = n*mt/2
    allocate(d(n),e(0:n),cv(ncs),sv(ncs),rv(2,mt), &
         v(ln,n),scl(n), stat=ierr)
    if (ierr .ne. 0) then
       info = 101
       return
    end if

!cdir reserve=ntsk

    call dsytrt(n,a,ln,d,e,v,scl,ntsk,info)
    if (info .ne. 0) then
       return
    end if
    !call dstqre(n,d,e,ncs,mt,cv,sv,rv,it,info)
    call dstqle(n,d,e,ncs,mt,cv,sv,rv,it,info)
    if (info .ne. 0) then
       return
    end if

    eig = d

#ifdef USE_MPI
    call MPI_COMM_RANK(comm,myrank,ierr)
    call MPI_COMM_SIZE(comm,nproc,ierr)
#else
    myrank = 0
    nproc = 1
#endif

    allocate(count(0:nproc-1),displ(0:nproc-1),stat=ierr)
    if (ierr .ne. 0) then
       info = 102
       return
    end if

    count = n/nproc
    do irnk=0,mod(n,nproc)-1
       count(irnk) = count(irnk)+1
    end do
    displ(0) = 0
    do irnk=0,nproc-2
       displ(irnk+1) = displ(irnk) + count(irnk)
    end do
    bn = displ(myrank)+1
    en = displ(myrank)+count(myrank)

    allocate(z(ln,bn:en),stat=ierr)
    if (ierr .ne. 0) then
       info = 103
       return
    end if

    count = ln*count
    displ = ln*displ

    !call dstqrv(it,ncs,cv,sv,rv,z,ln,bn,en)
    call dstqlv(it,ncs,cv,sv,rv,z,ln,bn,en)
    call dsytru(n,v,ln,scl,z,bn,en)

#ifdef USE_MPI
    call MPI_ALLGATHERV(z,count(myrank),MPI_DOUBLE_PRECISION, &
         v,count,displ,MPI_DOUBLE_PRECISION,comm,ierr)
#else
    v = z
#endif

    deallocate(z)

    allocate(idx(n),stat=ierr)
    if (ierr .ne. 0) then
       info = 105
       return
    end if
    call hsort(n,eig,idx)
    do i=1,n
       a(:,i) = v(:,idx(i))
    end do
    deallocate(idx)

    deallocate(count,displ)

!cdir release

    deallocate(d,e,cv,sv,rv,v,scl)


#ifdef EIGSYSTM_PROF
    call tpf_end(tpf_eig)
#endif
    return
  end subroutine dsyevvl

  subroutine dsytrt(n,a,ln,d,e,v,scl,ntsk,info)
    implicit none
    integer,intent(in):: n,ln,ntsk
    integer,intent(out):: info
    real(kind=8):: a(ln,n)
    real(kind=8),intent(out):: v(ln,n),scl(n)
    real(kind=8),intent(out):: d(n),e(0:n)

    integer:: i,j,k,ir,ierr,nfor
    real(kind=8):: tr,tsq,tm
    real(kind=8):: tz
    real(kind=8),allocatable:: p(:),w(:)

    nfor = ntsk*2

    allocate(p(n),w(n),stat=ierr)
    if (ierr .ne. 0) then
       info = 104
       return
    end if

    do k=1,n-1
       d(k) = a(k,k)
       tm = 0.0d0
       do i=k+1,n
          tr = a(i,k)
          tm = max(tm,abs(tr))
       end do
       if (tm .eq. 0.0d0) then
          v(k+1:n,k) = 0.0d0
          e(k) = 0.0d0
          scl(k) = 0.0d0
          cycle
       end if
       tsq = 0.0d0
       do i=k+1,n
          v(i,k) = a(i,k)/tm
          tr = v(i,k)
          tsq = tsq + tr*tr
       end do
       e(k) = sign(sqrt(tsq),-v(k+1,k))
       scl(k) = tsq - e(k)*v(k+1,k)
       scl(k) = 0.5d0/scl(k)
       v(k+1,k) = v(k+1,k) - e(k)
       e(k) = tm*e(k)

       do i=k+1,n
          p(i) = a(i,i)*v(i,k)
       end do
       call dsytrtp1(n,k,p,a,ln,v,nfor)

       !
       ! before unrolling
       !
       !do i=k+1,n
       !   do j=i+1,n
       !      p(i) = p(i) + a(j,i)*v(j,k)
       !   end do
       !end do
       !
       ir = mod(n-k,2)
       if (ir.eq.1) then
          do j=k+2,n
             p(k+1) = p(k+1) + a(j,k+1)*v(j,k)
          end do
       end if
!$omp parallel do private(i,j),schedule(static,1)
!cdir concur(for=nfor)
!poption cyclic
       do i=k+1+ir,n,2
          p(i) = p(i) + a(i+1,i)*v(i+1,k)
!cdir noloopchg
!soption noloopinterchange,unroll(2)
          do j=i+2,n
             p(i) = p(i) + a(j,i)*v(j,k)
             p(i+1) = p(i+1) + a(j,i+1)*v(j,k)
          end do
       end do

       p(k+1:n) = (2.0d0*scl(k))*p(k+1:n)

       tz = 0.0d0
       do i=k+1,n
          tz = tz + p(i)*v(i,k)
       end do
       tz = scl(k)*tz

       w(k+1:n) = p(k+1:n) - tz*v(k+1:n,k)

!$omp parallel do private(i,j),schedule(static,1)
!cdir concur(for=nfor)
!poption cyclic
       do j=k+1,n
          do i=j,n
             a(i,j) = a(i,j) - v(i,k)*w(j) - w(i)*v(j,k)
          end do
       end do

       scl(k) = 2.0d0*scl(k)
    end do
    d(n) = a(n,n)

    deallocate(p,w)
    return
  end subroutine dsytrt

  subroutine dsytrtp1(n,k,p,a,ln,v,nfor)
    implicit none
    integer,intent(in):: n,k,ln,nfor
    real(kind=8),intent(in):: a(ln,n),v(ln,n)
    real(kind=8):: p(n)

    integer:: i,j

!$omp parallel do private(i,j),schedule(static,1)
    do i=k+2,n
       do j=k+1,i-1
          p(i) = p(i) + a(i,j)*v(j,k)
       end do
    end do

    return
  end subroutine dsytrtp1

  subroutine dstqrv(it,ncs,cv,sv,rv,z,ln,bn,en)
    implicit none

    integer,intent(in):: it,ln,bn,en,ncs
    real(kind=8),intent(in):: cv(ncs),sv(ncs)
    integer,intent(in):: rv(2,it)
    real(kind=8),intent(out):: z(ln,bn:en)

    real(kind=8):: t1,t2
    integer:: jt,i,p,q,k,ics,jcs

    jcs = 0
    do jt=it,1,-1
       p = rv(1,jt)
       q = rv(2,jt)
       jcs = jcs + q-p
    end do

    z = 0.0d0
    do i=bn,en
       z(i,i) = 1.0d0
    end do

!OCL TEMP(ics)
!poption tlocal(ics)
    do k=bn,en
       ics = jcs
       do jt=it,1,-1
          p = rv(1,jt)
          q = rv(2,jt)
          do i=q-1,p,-1
             t1 = z(i,k)
             t2 = z(i+1,k)
             z(i,k) = cv(ics)*t1 + sv(ics)*t2
             z(i+1,k) = -sv(ics)*t1 + cv(ics)*t2
             ics = ics - 1
          end do
       end do
    end do
    return
  end subroutine dstqrv

  subroutine dstqlv(it,ncs,cv,sv,rv,z,ln,bn,en)
    implicit none

    integer,intent(in):: it,ln,bn,en,ncs
    real(kind=8),intent(in):: cv(ncs),sv(ncs)
    integer,intent(in):: rv(2,it)
    real(kind=8),intent(out):: z(ln,bn:en)

    real(kind=8):: t1,t2
    integer:: jt,i,p,q,k,ics,jcs

    jcs = ncs
    do jt=it,1,-1
       p = rv(1,jt)
       q = rv(2,jt)
       jcs = jcs - q+p
    end do

    z = 0.0d0
    do i=bn,en
       z(i,i) = 1.0d0
    end do

!OCL TEMP(ics)
!poption tlocal(ics)
    do k=bn,en
       ics = jcs
       do jt=it,1,-1
          p = rv(1,jt)
          q = rv(2,jt)
          do i=p,q-1
             t1 = z(i,k)
             t2 = z(i+1,k)
             ics = ics + 1
             z(i,k) = cv(ics)*t1 + sv(ics)*t2
             z(i+1,k) = -sv(ics)*t1 + cv(ics)*t2
          end do
       end do
    end do
    return
  end subroutine dstqlv

  subroutine dsytru(n,v,ln,scl,z,bn,en)
    implicit none
    integer,intent(in):: n,ln,bn,en
    real(kind=8),intent(in):: v(ln,n), scl(n)
    real(kind=8):: z(ln,bn:en)

    integer:: i,j,k
    real(kind=8):: tz

    do j=bn,en
       do k=n-1,1,-1
          tz = 0.0d0
          do i=k+1,n
             tz = tz + v(i,k)*z(i,j)
          end do
          tz = -scl(k)*tz
          do i=k+1,n
             z(i,j) = z(i,j) + tz*v(i,k)
          end do
       end do
    end do
    return
  end subroutine dsytru

  subroutine hsort(n, d, idx)
    implicit none
    integer,intent(in):: n
    real(kind=8):: d(n)
    integer:: idx(n)

    integer:: i, j, ip, ic, it
    real(kind=8):: t

    ! initialize idx
    do i=1,n
       idx(i) = i
    end do

    ! create the heap
    do i=2,n
       j = i
       ip = j/2
       do while ( d(j) .gt. d(ip) )
          t = d(ip)
          it = idx(ip)
          d(ip) = d(j)
          idx(ip) = idx(j)
          d(j) = t
          idx(j) = it
          j = ip
          ip = j/2
          if ( ip .eq. 0 ) exit
       end do
    end do

    ! sort it
    do i=n,1,-1
       t = d(i)
       it = idx(i)
       d(i) = d(1)
       idx(i) = idx(1)
       d(1) = t
       idx(1) = it
       j = 1
       ic = 2*j
       do while ( ic .lt. i )
          if ( ic + 1 .lt. i ) then
             if ( d(ic+1) .gt. d(ic) ) ic = ic + 1
          end if
          if ( d(ic) .gt. d(j) ) then
             t = d(ic)
             it = idx(ic)
             d(ic) = d(j)
             idx(ic) = idx(j)
             d(j) = t
             idx(j) = it
             j = ic
          else
             exit
          end if
          ic = 2*j
       end do
    end do
    return
  end subroutine hsort
end module eigsystm
