c234567
      subroutine clock(a)
      use omp_lib
      real*8 a,tomp0
      COMMON/OMPTIME/TOMP0
      a=omp_get_wtime()
      a=a-tomp0
      return
      end
c  
      subroutine clock0
      use omp_lib
      real*8 tomp0
      COMMON/OMPTIME/TOMP0
      tomp0=omp_get_wtime()
      return
      end
