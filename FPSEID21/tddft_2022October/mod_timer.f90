module mod_timer
  implicit none

  integer, private, parameter :: num_max_routines = 100
  integer, private, parameter :: num_max_namelen = 100
  integer, private :: num_of_routines = 0

  character(len=num_max_namelen), private, dimension(num_max_routines) :: t_name = ''
  real(kind=8), private, dimension(num_max_routines) :: ts = 0.0d0
  real(kind=8), private, dimension(num_max_routines) :: t_value = 0.0d0
  integer, private, dimension(num_max_routines) :: call_count = 0
  logical, private, dimension(num_max_routines) :: timer_start = .false.

  private :: wallclock

contains

  subroutine start_timer(subroutine_name)
    character(len=*), intent(in) :: subroutine_name
    integer :: nlen
    integer :: i

    nlen = min(len_trim(subroutine_name), num_max_namelen)

    do i = 1, num_of_routines
      if (subroutine_name(1:nlen) == trim(t_name(i))) then
        if (timer_start(i)) then
          write(0,*) 'Timer for ', trim(subroutine_name), ' is already started!!!'
          return
        end if
        timer_start(i) = .true.
        call_count(i) = call_count(i) + 1
        call wallclock(ts(i))
        return
      end if
    end do

    if (num_of_routines >= num_max_routines) then
      write(0,*) 'Timer table is full: ', trim(subroutine_name)
      return
    end if

    num_of_routines = num_of_routines + 1
    t_name(num_of_routines) = subroutine_name(1:nlen)
    timer_start(num_of_routines) = .true.
    call_count(num_of_routines) = call_count(num_of_routines) + 1
    call wallclock(ts(num_of_routines))
  end subroutine start_timer

  subroutine stop_timer(subroutine_name)
    character(len=*), intent(in) :: subroutine_name
    integer :: nlen
    integer :: i
    real(kind=8) :: te_tmp

    call wallclock(te_tmp)
    nlen = min(len_trim(subroutine_name), num_max_namelen)

    do i = 1, num_of_routines
      if (subroutine_name(1:nlen) == trim(t_name(i))) then
        if (.not. timer_start(i)) then
          write(0,*) 'Timer for ', trim(subroutine_name), ' is NOT started!!!'
          return
        end if
        timer_start(i) = .false.
        t_value(i) = t_value(i) + (te_tmp - ts(i))
        return
      end if
    end do

    write(0,*) 'Timer for ', trim(subroutine_name), ' is NOT started!!!'
  end subroutine stop_timer

  subroutine print_timer()
    integer :: i
    character(len=31) :: p_name

    write(6,'(a)') ''
    write(6,'(a)') '[Timer Output]'
    write(6,'(a)') '+--------------------------------+----------+------------+'
    write(6,'(a)') '|Timer region                    |Called    |Elapsed     |'
    write(6,'(a)') '|                                |          |Time[s]     |'
    write(6,'(a)') '+--------------------------------+----------+------------+'
    do i = 1, num_of_routines
      if (timer_start(i)) then
        write(0,*) 'Timer for ', trim(t_name(i)), ' is NOT stopped!!!'
        return
      end if
      p_name = ''
      p_name = trim(t_name(i))
      write(6,'(a,a,i10,a,f12.3,a)') '|', p_name // '|', call_count(i), '|', t_value(i), '|'
    end do
    write(6,'(a)') '+--------------------------------+----------+------------+'
  end subroutine print_timer

  subroutine wallclock(t)
    real(kind=8), intent(out) :: t
    integer(kind=8) :: c
    integer(kind=8) :: c_rate

    call system_clock(c, c_rate)
    t = dble(c) / dble(c_rate)
  end subroutine wallclock

end module mod_timer
