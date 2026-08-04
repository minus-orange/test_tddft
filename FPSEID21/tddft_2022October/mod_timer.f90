module mod_timer
  use mpi
  implicit none

  integer, private, parameter :: num_max_routines = 192
  integer, private, parameter :: num_max_namelen = 100
  integer, private :: num_of_routines = 0

  character(len=num_max_namelen), private :: t_name(num_max_routines) = ''
  real(kind=8), private :: ts(num_max_routines) = 0.0d0
  real(kind=8), private :: t_value(num_max_routines) = 0.0d0
  integer, private :: call_count(num_max_routines) = 0
  logical, private :: timer_start(num_max_routines) = .false.

  private :: wallclock

contains

  subroutine reset_timer()
    num_of_routines = 0
    t_name = ''
    ts = 0.0d0
    t_value = 0.0d0
    call_count = 0
    timer_start = .false.
  end subroutine reset_timer

  subroutine start_timer(subroutine_name)
    character(len=*), intent(in) :: subroutine_name
    integer :: nlen
    integer :: i

    nlen = min(len_trim(subroutine_name), num_max_namelen)

    do i = 1, num_of_routines
      if (subroutine_name(1:nlen) == trim(t_name(i))) then
        if (timer_start(i)) then
          write(0,*) 'Timer for ', trim(subroutine_name), &
            ' is already started!!!'
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
          write(0,*) 'Timer for ', trim(subroutine_name), &
            ' is NOT started!!!'
          return
        end if
        timer_start(i) = .false.
        t_value(i) = t_value(i) + (te_tmp - ts(i))
        return
      end if
    end do

    write(0,*) 'Timer for ', trim(subroutine_name), &
      ' is NOT started!!!'
  end subroutine stop_timer

  subroutine print_timer()
    integer :: i
    integer :: ierr
    integer :: my_rank
    integer :: nproc
    integer :: min_routines
    integer :: max_routines
    integer :: total_count
    integer :: count_max(num_max_routines)
    logical :: mpi_ready
    character(len=31) :: p_name
    real(kind=8) :: total_value
    real(kind=8) :: value_sum(num_max_routines)
    real(kind=8) :: value_max(num_max_routines)

    my_rank = -1
    nproc = 1
    call MPI_Initialized(mpi_ready, ierr)
    if (mpi_ready) then
      call MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)
      call MPI_Comm_size(MPI_COMM_WORLD, nproc, ierr)
      call MPI_Allreduce(num_of_routines, min_routines, 1, MPI_INTEGER, &
        MPI_MIN, MPI_COMM_WORLD, ierr)
      call MPI_Allreduce(num_of_routines, max_routines, 1, MPI_INTEGER, &
        MPI_MAX, MPI_COMM_WORLD, ierr)
      if (min_routines /= max_routines) then
        if (my_rank == 0) then
          write(0,*) 'Timer region count differs between MPI ranks.'
        end if
        return
      end if
      call MPI_Reduce(t_value, value_sum, num_max_routines, &
        MPI_DOUBLE_PRECISION, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
      call MPI_Reduce(t_value, value_max, num_max_routines, &
        MPI_DOUBLE_PRECISION, MPI_MAX, 0, MPI_COMM_WORLD, ierr)
      call MPI_Reduce(call_count, count_max, num_max_routines, &
        MPI_INTEGER, MPI_MAX, 0, MPI_COMM_WORLD, ierr)
      if (my_rank /= 0) return
    else
      value_sum = t_value
      value_max = t_value
      count_max = call_count
    end if

    total_count = 0
    total_value = 0.0d0

    write(6,'(a)') ''
    write(6,'(a)') '[Timer Output]'
    write(6,'(a)') '+--------------------------------+------+----------+------------+'
    write(6,'(a)') '|Timer region                    |Rank  |Called    |Elapsed     |'
    write(6,'(a)') '|                                |      |          |Time[s]     |'
    write(6,'(a)') '+--------------------------------+------+----------+------------+'
    do i = 1, num_of_routines
      if (timer_start(i)) then
        write(0,*) 'Timer for ', trim(t_name(i)), ' is NOT stopped!!!'
        return
      end if
      p_name = ''
      p_name = trim(t_name(i))
      total_count = total_count + call_count(i)
      total_value = total_value + t_value(i)
      write(6,'(a,a31,a,i6,a,i10,a,f12.3,a)') '|', p_name, &
        '|', my_rank, '|', call_count(i), '|', t_value(i), '|'
    end do
    p_name = 'TOTAL'
    write(6,'(a)') '+--------------------------------+------+----------+------------+'
    write(6,'(a,a31,a,i6,a,i10,a,f12.3,a)') '|', p_name, &
      '|', my_rank, '|', total_count, '|', total_value, '|'
    write(6,'(a)') '+--------------------------------+------+----------+------------+'

    write(6,*)
    write(6,*) 'FPSEID_PROFILE_BEGIN'
    write(6,*) ' id label                    count', &
      '      max_rank_sec       avg_rank_sec'
    do i = 1, num_of_routines
      if (count_max(i) <= 0) cycle
      write(6,100) i, t_name(i)(1:24), count_max(i), value_max(i), &
        value_sum(i) / dble(nproc)
    end do
    write(6,*) 'FPSEID_PROFILE_END'
    write(6,*)
100 format(1x,i3,1x,a24,1x,i10,2(1x,f18.6))
  end subroutine print_timer

  subroutine wallclock(t)
    real(kind=8), intent(out) :: t
    integer(kind=8) :: c
    integer(kind=8) :: c_rate

    call system_clock(c, c_rate)
    t = dble(c) / dble(c_rate)
  end subroutine wallclock

end module mod_timer

subroutine init_timer(rank)
  use mod_timer, only: reset_timer
  implicit none
  integer, intent(in) :: rank
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
  integer :: i
  integer :: exobs(5), exsame(5), exchanged(5)
  integer :: exngsame(5), excfsame(5), exwksame(5)
  integer :: ewobs, ewsame, ewchanged, ewesame, ewforcesame
  common /exnlpreuse/ exobs, exsame, exchanged
  common /exnlpparts/ exngsame, excfsame, exwksame
  common /ewaldreuse/ ewobs, ewsame, ewchanged, ewesame, ewforcesame
#endif

  call reset_timer()
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
  do i = 1, 5
    exobs(i) = 0
    exsame(i) = 0
    exchanged(i) = 0
    exngsame(i) = 0
    excfsame(i) = 0
    exwksame(i) = 0
  end do
  ewobs = 0
  ewsame = 0
  ewchanged = 0
  ewesame = 0
  ewforcesame = 0
#endif
end subroutine init_timer

subroutine start_timer(subroutine_name)
  use mod_timer, only: module_start_timer => start_timer
  implicit none
  character(len=*), intent(in) :: subroutine_name

  call module_start_timer(subroutine_name)
end subroutine start_timer

subroutine stop_timer(subroutine_name)
  use mod_timer, only: module_stop_timer => stop_timer
  implicit none
  character(len=*), intent(in) :: subroutine_name

  call module_stop_timer(subroutine_name)
end subroutine stop_timer

subroutine print_timer()
  use mod_timer, only: module_print_timer => print_timer
  use mpi
  implicit none
  integer :: ierr
  integer :: rank

  call module_print_timer()
#ifdef FPSEID_FRPRMN_DIAGNOSTIC
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  if (rank == 0) then
    call exnlp_reuse_report()
    call ewald_reuse_report()
  end if
#endif
end subroutine print_timer
