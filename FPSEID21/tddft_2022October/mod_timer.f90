module mod_timer
  use mpi
  implicit none

  integer, private, parameter :: num_max_routines = 192
  integer, private, parameter :: num_max_tree_nodes = 512
  integer, private, parameter :: num_max_namelen = 100
  integer, private :: num_of_routines = 0
  integer, private :: num_tree_nodes = 0
  integer, private :: timer_stack_depth = 0

  character(len=num_max_namelen), private :: t_name(num_max_routines) = ''
  real(kind=8), private :: ts(num_max_routines) = 0.0d0
  real(kind=8), private :: t_value(num_max_routines) = 0.0d0
  integer, private :: call_count(num_max_routines) = 0
  logical, private :: timer_start(num_max_routines) = .false.
  integer, private :: active_tree_node(num_max_routines) = 0

  integer, private :: tree_name_index(num_max_tree_nodes) = 0
  integer, private :: tree_parent(num_max_tree_nodes) = 0
  integer, private :: tree_depth(num_max_tree_nodes) = 0
  integer, private :: tree_call_count(num_max_tree_nodes) = 0
  real(kind=8), private :: tree_ts(num_max_tree_nodes) = 0.0d0
  real(kind=8), private :: tree_value(num_max_tree_nodes) = 0.0d0
  integer, private :: timer_stack(num_max_routines) = 0

  private :: wallclock, find_or_add_tree_node, print_timer_tree

contains

  subroutine reset_timer()
    num_of_routines = 0
    t_name = ''
    ts = 0.0d0
    t_value = 0.0d0
    call_count = 0
    timer_start = .false.
    active_tree_node = 0
    num_tree_nodes = 0
    tree_name_index = 0
    tree_parent = 0
    tree_depth = 0
    tree_call_count = 0
    tree_ts = 0.0d0
    tree_value = 0.0d0
    timer_stack_depth = 0
    timer_stack = 0
  end subroutine reset_timer

  subroutine start_timer(subroutine_name)
    character(len=*), intent(in) :: subroutine_name
    integer :: nlen
    integer :: i
    integer :: name_index
    integer :: node_index
    integer :: parent_index
    real(kind=8) :: t_start

    nlen = min(len_trim(subroutine_name), num_max_namelen)
    if (nlen <= 0) then
      write(0,*) 'Timer region name must not be empty.'
      return
    end if

    name_index = 0
    do i = 1, num_of_routines
      if (subroutine_name(1:nlen) == trim(t_name(i))) then
        if (timer_start(i)) then
          write(0,*) 'Timer for ', trim(subroutine_name), &
            ' is already started!!!'
          return
        end if
        name_index = i
        exit
      end if
    end do

    if (name_index == 0) then
      if (num_of_routines >= num_max_routines) then
        write(0,*) 'Timer table is full: ', trim(subroutine_name)
        return
      end if

      num_of_routines = num_of_routines + 1
      name_index = num_of_routines
      t_name(name_index) = subroutine_name(1:nlen)
    end if

    parent_index = 0
    if (timer_stack_depth > 0) then
      parent_index = timer_stack(timer_stack_depth)
    end if
    call find_or_add_tree_node(name_index, parent_index, node_index)
    if (node_index == 0) return

    if (timer_stack_depth >= num_max_routines) then
      write(0,*) 'Timer nesting is too deep: ', trim(subroutine_name)
      return
    end if

    call wallclock(t_start)
    timer_start(name_index) = .true.
    call_count(name_index) = call_count(name_index) + 1
    ts(name_index) = t_start
    active_tree_node(name_index) = node_index
    tree_call_count(node_index) = tree_call_count(node_index) + 1
    tree_ts(node_index) = t_start
    timer_stack_depth = timer_stack_depth + 1
    timer_stack(timer_stack_depth) = node_index
  end subroutine start_timer

  subroutine stop_timer(subroutine_name)
    character(len=*), intent(in) :: subroutine_name
    integer :: nlen
    integer :: i
    integer :: j
    integer :: node_index
    real(kind=8) :: te_tmp

    call wallclock(te_tmp)
    nlen = min(len_trim(subroutine_name), num_max_namelen)
    if (nlen <= 0) then
      write(0,*) 'Timer region name must not be empty.'
      return
    end if

    do i = 1, num_of_routines
      if (subroutine_name(1:nlen) == trim(t_name(i))) then
        if (.not. timer_start(i)) then
          write(0,*) 'Timer for ', trim(subroutine_name), &
            ' is NOT started!!!'
          return
        end if
        timer_start(i) = .false.
        t_value(i) = t_value(i) + (te_tmp - ts(i))
        node_index = active_tree_node(i)
        if (node_index > 0) then
          tree_value(node_index) = tree_value(node_index) + &
            (te_tmp - tree_ts(node_index))
        end if
        active_tree_node(i) = 0

        if (timer_stack_depth > 0 .and. &
          timer_stack(timer_stack_depth) == node_index) then
          timer_stack(timer_stack_depth) = 0
          timer_stack_depth = timer_stack_depth - 1
        else
          write(0,*) 'Timer nesting mismatch at ', trim(subroutine_name)
          do j = timer_stack_depth, 1, -1
            if (timer_stack(j) == node_index) then
              timer_stack(j:timer_stack_depth-1) = &
                timer_stack(j+1:timer_stack_depth)
              timer_stack(timer_stack_depth) = 0
              timer_stack_depth = timer_stack_depth - 1
              exit
            end if
          end do
        end if
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
    character(len=47) :: p_name
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
    write(6,'(a)') 'Elapsed time is inclusive; indentation shows the call path.'
    write(6,'(a)') 'A repeated region name means it was called from multiple parents.'
    write(6,'(a)') '+------------------------------------------------+------+----------+------------+'
    write(6,'(a)') '|Timer region / call path                        |Rank  |Called    |Elapsed     |'
    write(6,'(a)') '|                                                |      |          |Time[s]     |'
    write(6,'(a)') '+------------------------------------------------+------+----------+------------+'
    do i = 1, num_of_routines
      if (timer_start(i)) then
        write(0,*) 'Timer for ', trim(t_name(i)), ' is NOT stopped!!!'
        return
      end if
    end do
    if (timer_stack_depth /= 0) then
      write(0,*) 'Timer nesting stack is not empty at print_timer.'
      return
    end if
    call print_timer_tree(my_rank, total_count, total_value)
    p_name = 'TOTAL (inclusive regions)'
    write(6,'(a)') '+------------------------------------------------+------+----------+------------+'
    write(6,'(a,a47,a,i6,a,i10,a,f12.3,a)') '|', p_name, &
      '|', my_rank, '|', total_count, '|', total_value, '|'
    write(6,'(a)') '+------------------------------------------------+------+----------+------------+'

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

  subroutine find_or_add_tree_node(name_index, parent_index, node_index)
    integer, intent(in) :: name_index
    integer, intent(in) :: parent_index
    integer, intent(out) :: node_index
    integer :: i

    do i = 1, num_tree_nodes
      if (tree_name_index(i) == name_index .and. &
        tree_parent(i) == parent_index) then
        node_index = i
        return
      end if
    end do

    if (num_tree_nodes >= num_max_tree_nodes) then
      write(0,*) 'Timer call-path table is full: ', trim(t_name(name_index))
      node_index = 0
      return
    end if

    num_tree_nodes = num_tree_nodes + 1
    node_index = num_tree_nodes
    tree_name_index(node_index) = name_index
    tree_parent(node_index) = parent_index
    if (parent_index > 0) then
      tree_depth(node_index) = tree_depth(parent_index) + 1
    else
      tree_depth(node_index) = 0
    end if
  end subroutine find_or_add_tree_node

  subroutine print_timer_tree(rank, total_count, total_value)
    integer, intent(in) :: rank
    integer, intent(inout) :: total_count
    real(kind=8), intent(inout) :: total_value
    integer :: i
    integer :: j
    integer :: indent_len
    integer :: name_len
    integer :: name_offset
    integer :: output_stack(num_max_tree_nodes)
    integer :: output_stack_size
    character(len=47) :: p_name

    output_stack = 0
    output_stack_size = 0
    do i = num_tree_nodes, 1, -1
      if (tree_parent(i) /= 0) cycle
      output_stack_size = output_stack_size + 1
      output_stack(output_stack_size) = i
    end do

    do while (output_stack_size > 0)
      i = output_stack(output_stack_size)
      output_stack(output_stack_size) = 0
      output_stack_size = output_stack_size - 1
      p_name = ''
      indent_len = min(2 * tree_depth(i), len(p_name) - 4)
      name_offset = indent_len
      if (tree_depth(i) > 0) then
        p_name(indent_len+1:indent_len+3) = '+- '
        name_offset = indent_len + 3
      end if
      name_len = min(len_trim(t_name(tree_name_index(i))), &
        len(p_name) - name_offset)
      if (name_len > 0) then
        p_name(name_offset+1:name_offset+name_len) = &
          t_name(tree_name_index(i))(1:name_len)
      end if
      total_count = total_count + tree_call_count(i)
      total_value = total_value + tree_value(i)
      write(6,'(a,a47,a,i6,a,i10,a,f12.3,a)') '|', p_name, &
        '|', rank, '|', tree_call_count(i), '|', tree_value(i), '|'
      do j = num_tree_nodes, 1, -1
        if (tree_parent(j) /= i) cycle
        output_stack_size = output_stack_size + 1
        output_stack(output_stack_size) = j
      end do
    end do
  end subroutine print_timer_tree

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
