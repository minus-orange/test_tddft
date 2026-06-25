	subroutine cpu_block(nband,ncpu,nbegin,nend,ncpuq)
	implicit double precision(a-h,o-z)
        include 'mpif.h'
	dimension nbegin(0:ncpuq),nend(0:ncpuq)
        call MPI_COMM_RANK(MPI_COMM_WORLD,my_rank,ierr)
	nrest=mod(nband,ncpu+1)
	if ( my_rank.eq.0 ) write(6,*)' nrest = ',nrest
	if ( nrest.eq.0 ) then
	 nband_cpu=nband/(ncpu+1)
	 do icpu=0,ncpu
	  nbegin(icpu)=nband_cpu*(icpu) + 1
	  nend(icpu)=nbegin(icpu)+nband_cpu-1
	 enddo
	else
	 nband_cpu=int( dfloat(nband)/dfloat(ncpu+1) )
	 do icpu=0,nrest-1
	  nbegin(icpu)=(nband_cpu+1)*icpu + 1
	  nend(icpu)=nbegin(icpu)+nband_cpu
	 enddo
	 nblock0=(nband_cpu+1)*nrest+1
	 do icpu=nrest,ncpu
	  nbegin(icpu)=nband_cpu*(icpu-nrest)+nblock0
	  nend(icpu)=nbegin(icpu)+nband_cpu-1
	 enddo
	endif
        if (my_rank.eq.0 ) then
         do icpu=0,ncpu
          write(6,*)' nbegin(',icpu,')=',nbegin(icpu),
     &    '   nend(',icpu,')=',nend(icpu)
         enddo
        endif
	return
	end

