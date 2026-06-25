c
      subroutine tdep(f,df,t)
      implicit double precision(a-h,o-z)
c *** phase shift !!
      COMMON/PHASE/phshft
      COMMON/PULSE/t000,tw00,tau00  ! peak, period, width
      tpi=2*dacos(-1.d0)
c      tau00=50.0d0  ! in fsec width
      tau=tau00*100.d0/2.42d0  ! in a.u. of time
c      t00=200.d0  ! in fsec  peak of time
      t0=t000*100.d0/2.42d0   ! in a.u. of time
c        tw00=2.6685d0  !  time frequency
        tw=tw00*100.d0/2.42d0  ! in a.u. of time
      omega=tpi/tw
      tt=(t-t0)/tau
c **** truly FWHM
      A=-1.d0/2.d0*dlog(1.d0/2.d0)
        theta=(t-t0)*omega
        if (theta.gt.tpi) theta=theta-tpi
        expt=dexp(-A*tt*tt)
        dsw=dsin( theta + phshft )
        dcw=dcos( theta + phshft )
        f=expt*dsw
        df=( omega*dcw - 2*A*tt/tau*dsw )*expt
      return
      end
