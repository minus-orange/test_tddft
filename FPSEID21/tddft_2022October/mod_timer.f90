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
    include 'mpif.h'
    integer :: i
    integer :: ierr
    integer :: my_rank
    integer :: total_count
    logical :: mpi_ready
    character(len=31) :: p_name
    real(kind=8) :: total_value

    my_rank = -1
    call MPI_Initialized(mpi_ready, ierr)
    if (mpi_ready) then
      call MPI_Comm_rank(MPI_COMM_WORLD, my_rank, ierr)
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
  end subroutine print_timer

  subroutine wallclock(t)
    real(kind=8), intent(out) :: t
    integer(kind=8) :: c
    integer(kind=8) :: c_rate

    call system_clock(c, c_rate)
    t = dble(c) / dble(c_rate)
  end subroutine wallclock

end module mod_timer

subroutine fpseid_mod_timer_start(id)
  use mod_timer, only: start_timer
  implicit none
  integer, intent(in) :: id
  character(len=100) :: name

  call fpseid_mod_timer_name(id, name)
  if (len_trim(name) > 0) call start_timer(trim(name))
end subroutine fpseid_mod_timer_start

subroutine fpseid_mod_timer_stop(id)
  use mod_timer, only: stop_timer
  implicit none
  integer, intent(in) :: id
  character(len=100) :: name

  call fpseid_mod_timer_name(id, name)
  if (len_trim(name) > 0) call stop_timer(trim(name))
end subroutine fpseid_mod_timer_stop

subroutine fpseid_mod_timer_name(id, name)
  implicit none
  integer, intent(in) :: id
  character(len=*), intent(out) :: name

  name = ''
  select case (id)
  case (1)
    name = 'time_step_total'
  case (2)
    name = 'g_vector_update'
  case (3)
    name = 'ion_md'
  case (4)
    name = 'frprmn'
  case (5)
    name = 'electf_force'
  case (6)
    name = 'force_energy_update'
  case (7)
    name = 'prenon'
  case (8)
    name = 'tmevl_total'
  case (9)
    name = 'tmevl_exkin'
  case (10)
    name = 'tmevl_s2'
  case (11)
    name = 's2_nonlocal'
  case (12)
    name = 's2_fft_local'
  case (13)
    name = 'tmevl_expectation'
  case (14)
    name = 'fft_wrapper'
  case (15)
    name = 'startup_before_steps'
  case (16)
    name = 'fft_plan_init'
  case (17)
    name = 's2_acc_update'
  case (18)
    name = 's2_acc_kernel'
  case (19)
    name = 's2_zero_rho2'
  case (20)
    name = 's2_scatter_p'
  case (21)
    name = 's2_vg_build'
  case (22)
    name = 's2_local_multiply'
  case (23)
    name = 's2_gather_p'
  case (24)
    name = 's2_copyout_p'
  case (25)
    name = 's2_nonlocal_make'
  case (26)
    name = 's2_nonlocal_gemm'
  case (27)
    name = 'exnlp_gemm_data'
  case (28)
    name = 'exnlp_gemm_dot'
  case (29)
    name = 'exnlp_gemm_update'
  case (30)
    name = 'exnlp_gemm_enter'
  case (31)
    name = 'exnlp_gemm_zero'
  case (32)
    name = 'exnlp_gemm_exit'
  case (33)
    name = 's2_p_enter'
  case (34)
    name = 's2_p_exit'
  case (35)
    name = 'tmevl_p_enter'
  case (36)
    name = 'tmevl_p_exit'
  case (37)
    name = 'exkin_acc_kernel'
  case (38)
    name = 'exnlp_work1_enter'
  case (39)
    name = 'exnlp_meta_enter'
  case (40)
    name = 'exnlp_ct1_create'
  case (45)
    name = 'frprmn_coef_setup'
  case (46)
    name = 'frprmn_gdump_prepare'
  case (47)
    name = 'frprmn_part1to5'
  case (48)
    name = 'frprmn_extau_prepare'
  case (49)
    name = 'part1to5_getylm'
  case (50)
    name = 'vpjgen_cpu_integral'
  case (51)
    name = 'vpjgen_mpi_allreduce'
  case (52)
    name = 'vpjgen_postreduce'
  case (53)
    name = 'frprmn_vloc_prepare'
  case (54)
    name = 'frprmn_vrho_mix'
  case (55)
    name = 'frprmn_energy_diag'
  case (56)
    name = 'frprmn_initial_density'
  case (57)
    name = 'frprmn_iter_init'
  case (58)
    name = 'frprmn_pre_tmevl'
  case (59)
    name = 'frprmn_post_tmevl'
  case (60)
    name = 'frprmn_density_init'
  case (61)
    name = 'frprmn_exit_cleanup'
  case (62)
    name = 'frprmn_vrho_vofrho'
  case (63)
    name = 'frprmn_vrho_smooth_fft'
  case (64)
    name = 'frprmn_vrho_mix_control'
  case (65)
    name = 'frprmn_vloc_locpot'
  case (66)
    name = 'frprmn_vloc_smooth_fft'
  case (67)
    name = 'frprmn_vrho_seed_ctrl'
  case (68)
    name = 'frprmn_vrho_predict_ctrl'
  case (69)
    name = 'frprmn_vrho_correct_ctrl'
  case (70)
    name = 'frprmn_vrho_interp'
  case (71)
    name = 'frprmn_vrho_converge'
  case (72)
    name = 'frprmn_vrho_coef_restore'
  case (73)
    name = 'vpjgen_host_zero'
  case (74)
    name = 'vpjgen_vpp2_zero'
  case (75)
    name = 'vpjgen_acc_kernel_d2h'
  case (76)
    name = 'vpjgen_acc_kernel_wait'
  case (77)
    name = 'vpjgen_acc_d2h'
  case (78)
    name = 'frprmn_energy_vg_build'
  case (79)
    name = 'frprmn_energy_efield'
  case (80)
    name = 'frprmn_energy_expect'
  end select
end subroutine fpseid_mod_timer_name
