module mod_stepa_diag
  use iso_c_binding, only: c_double, c_double_complex, c_int, c_intptr_t, &
                           c_size_t, c_sizeof
  use iso_fortran_env, only: error_unit
  implicit none
  include 'mpif.h'

  private
  public :: fpseid_stepa_diag_p
  public :: fpseid_stepa_diag_coef
  public :: fpseid_stepa_diag_ylm_parent
  public :: fpseid_stepa_diag_ylm_section
  public :: fpseid_stepa_diag_vpj_parent
  public :: fpseid_stepa_diag_vpj_section
  public :: fpseid_stepa_diag_extau_parent
  public :: fpseid_stepa_diag_extau_section
  public :: fpseid_stepa_diag_nonlocal

  integer(c_int), parameter :: query_invalid = -1_c_int
  integer(c_intptr_t), parameter :: null_address = 0_c_intptr_t

  logical, save :: rank_initialized = .false.
  integer, save :: diagnostic_rank = -1
  logical, save :: diagnosed_p = .false.
  logical, save :: diagnosed_coef = .false.
  logical, save :: diagnosed_ylm_parent(5) = .false.
  logical, save :: diagnosed_ylm_section(5) = .false.
  logical, save :: diagnosed_vpj_parent(5) = .false.
  logical, save :: diagnosed_vpj_section(5) = .false.
  logical, save :: diagnosed_extau_parent(5) = .false.
  logical, save :: diagnosed_extau_section(5) = .false.
  logical, save :: diagnosed_nonlocal(2) = .false.

  logical, save :: p_address_recorded = .false.
  integer, save :: p_sample_np = 0
  integer(c_intptr_t), save :: p_host_address = null_address
  integer(c_intptr_t), save :: p_device_address = null_address
  integer(c_intptr_t), save :: ylm_host_address(5) = null_address
  integer(c_intptr_t), save :: vpj_host_address(5) = null_address
  integer(c_intptr_t), save :: extau_host_address(5) = null_address

  interface
    integer(c_int) function c_acc_query_c16(base, nbytes, haddr, daddr) &
        bind(C, name='fpseid_acc_query_c16')
      import c_double_complex, c_int, c_intptr_t, c_size_t
      complex(c_double_complex), intent(in) :: base(*)
      integer(c_size_t), value :: nbytes
      integer(c_intptr_t), intent(out) :: haddr, daddr
    end function c_acc_query_c16

    integer(c_int) function c_acc_query_r8(base, nbytes, haddr, daddr) &
        bind(C, name='fpseid_acc_query_r8')
      import c_double, c_int, c_intptr_t, c_size_t
      real(c_double), intent(in) :: base(*)
      integer(c_size_t), value :: nbytes
      integer(c_intptr_t), intent(out) :: haddr, daddr
    end function c_acc_query_r8

    integer(c_int) function c_acc_query_i4(base, nbytes, haddr, daddr) &
        bind(C, name='fpseid_acc_query_i4')
      import c_int, c_intptr_t, c_size_t
      integer(c_int), intent(in) :: base(*)
      integer(c_size_t), value :: nbytes
      integer(c_intptr_t), intent(out) :: haddr, daddr
    end function c_acc_query_i4
  end interface

contains

  subroutine initialize_rank()
    integer :: ierr

    if (rank_initialized) return
    call MPI_Comm_rank(MPI_COMM_WORLD, diagnostic_rank, ierr)
    if (ierr /= MPI_SUCCESS) diagnostic_rank = -1
    rank_initialized = .true.
  end subroutine initialize_rank

  logical function emit_on_this_rank()
    call initialize_rank()
    emit_on_this_rank = diagnostic_rank == 0
  end function emit_on_this_rank

  pure function query_status_name(status) result(name)
    integer(c_int), intent(in) :: status
    character(len=22) :: name

    select case (status)
    case (1_c_int)
      name = 'OK'
    case (0_c_int)
      name = 'ABSENT'
    case default
      name = 'SKIPPED_INVALID_BOUNDS'
    end select
  end function query_status_name

  subroutine emit_i(label, value)
    character(len=*), intent(in) :: label
    integer, intent(in) :: value
    write(error_unit, '(A,I0)', advance='no') label, value
  end subroutine emit_i

  subroutine emit_size(label, value)
    character(len=*), intent(in) :: label
    integer(c_size_t), intent(in) :: value
    write(error_unit, '(A,I0)', advance='no') label, value
  end subroutine emit_size

  subroutine emit_offset(label, value)
    character(len=*), intent(in) :: label
    integer(c_intptr_t), intent(in) :: value
    write(error_unit, '(A,I0)', advance='no') label, value
  end subroutine emit_offset

  subroutine emit_hex(label, value)
    character(len=*), intent(in) :: label
    integer(c_intptr_t), intent(in) :: value
    write(error_unit, '(A,Z0)', advance='no') label, value
  end subroutine emit_hex

  subroutine emit_l(label, value)
    character(len=*), intent(in) :: label
    logical, intent(in) :: value
    write(error_unit, '(A,L1)', advance='no') label, value
  end subroutine emit_l

  subroutine emit_s(label, value)
    character(len=*), intent(in) :: label
    character(len=*), intent(in) :: value
    write(error_unit, '(A,A)', advance='no') label, trim(value)
  end subroutine emit_s

  subroutine end_record()
    write(error_unit, '(A)') ''
  end subroutine end_record

  subroutine fpseid_stepa_diag_p(sample_np, ng2q, nxyz, ng2, ngcont, &
      mxbnd, nbndloc, nbegin, nend, p, j2g)
    integer, intent(in) :: sample_np, ng2q, nxyz, ng2, ngcont
    integer, intent(in) :: mxbnd, nbndloc, nbegin, nend
    complex(c_double_complex), intent(in) :: p(ng2q, mxbnd)
    integer(c_int), intent(in) :: j2g(ng2q)
    integer :: j2g_extent, j2g_min, j2g_max
    integer(c_int) :: parent_status, first_status, last_status
    integer(c_intptr_t) :: haddr, daddr, scratch_haddr, scratch_daddr
    integer(c_size_t) :: nbytes
    logical :: dimensions_valid, j2g_valid, p_index_bounds_ok, bounds_ok

    if (diagnosed_p) return
    if (.not. emit_on_this_rank()) return
    diagnosed_p = .true.
    p_sample_np = sample_np

    j2g_extent = 0
    j2g_min = 0
    j2g_max = 0
    j2g_valid = .false.
    if (nxyz > 0 .and. ng2q > 0) then
      j2g_extent = min(nxyz, ng2q)
      if (j2g_extent > 0) then
        j2g_min = minval(j2g(1:j2g_extent))
        j2g_max = maxval(j2g(1:j2g_extent))
        j2g_valid = j2g_min >= 1 .and. j2g_max <= nxyz
      end if
    end if

    dimensions_valid = ng2q > 0 .and. nxyz > 0 .and. mxbnd > 0 .and. &
                       nbndloc > 0 .and. nbndloc <= mxbnd
    p_index_bounds_ok = nxyz > 0 .and. nxyz <= ng2q
    bounds_ok = dimensions_valid .and. p_index_bounds_ok .and. j2g_valid

    parent_status = query_invalid
    first_status = query_invalid
    last_status = query_invalid
    haddr = null_address
    daddr = null_address
    scratch_haddr = null_address
    scratch_daddr = null_address
    if (dimensions_valid) then
      nbytes = int(ng2q, c_size_t) * int(nbndloc, c_size_t) * &
               c_sizeof(p(1,1))
      parent_status = c_acc_query_c16(p(1,1), nbytes, haddr, daddr)
      p_host_address = haddr
      p_device_address = daddr
      p_address_recorded = .true.
    end if
    if (dimensions_valid .and. p_index_bounds_ok) then
      nbytes = int(nxyz, c_size_t) * c_sizeof(p(1,1))
      first_status = c_acc_query_c16(p(1,1), nbytes, scratch_haddr, &
                                     scratch_daddr)
      last_status = c_acc_query_c16(p(1,nbndloc), nbytes, scratch_haddr, &
                                    scratch_daddr)
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_P'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' sample_np=', sample_np)
    call emit_i(' ng2q=', ng2q)
    call emit_i(' nxyz=', nxyz)
    call emit_i(' ng2=', ng2)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' mxbnd=', mxbnd)
    call emit_i(' nbndloc=', nbndloc)
    call emit_i(' nbegin=', nbegin)
    call emit_i(' nend=', nend)
    call emit_i(' p_lb1=', 1)
    call emit_i(' p_ub1=', ng2q)
    call emit_i(' p_lb2=', 1)
    call emit_i(' p_ub2=', mxbnd)
    call emit_i(' j2g_lb=', 1)
    call emit_i(' j2g_ub=', ng2q)
    call emit_i(' j2g_extent=', j2g_extent)
    call emit_i(' j2g_min=', j2g_min)
    call emit_i(' j2g_max=', j2g_max)
    call emit_l(' j2g_valid=', j2g_valid)
    call emit_l(' p_index_bounds_ok=', p_index_bounds_ok)
    call emit_l(' j2g_value_bounds_ok=', j2g_valid)
    call emit_s(' parent_status=', query_status_name(parent_status))
    call emit_i(' parent_present=', int(parent_status))
    call emit_hex(' haddr=0x', haddr)
    call emit_hex(' daddr=0x', daddr)
    call emit_s(' first_col_status=', query_status_name(first_status))
    call emit_i(' first_col_present=', int(first_status))
    call emit_s(' last_col_status=', query_status_name(last_status))
    call emit_i(' last_col_present=', int(last_status))
    call emit_l(' bounds_ok=', bounds_ok)
    call end_record()
  end subroutine fpseid_stepa_diag_p

  subroutine fpseid_stepa_diag_coef(ng2q, mxbnd, nbndloc, coef)
    integer, intent(in) :: ng2q, mxbnd, nbndloc
    complex(c_double_complex), intent(in) :: coef(ng2q, mxbnd)
    integer(c_int) :: query_status
    integer(c_intptr_t) :: haddr, daddr, host_offset, device_offset
    integer(c_size_t) :: nbytes

    if (diagnosed_coef) return
    if (.not. emit_on_this_rank()) return
    diagnosed_coef = .true.

    query_status = query_invalid
    haddr = null_address
    daddr = null_address
    if (ng2q > 0 .and. mxbnd > 0 .and. nbndloc > 0 .and. &
        nbndloc <= mxbnd) then
      nbytes = int(ng2q, c_size_t) * int(nbndloc, c_size_t) * &
               c_sizeof(coef(1,1))
      query_status = c_acc_query_c16(coef(1,1), nbytes, haddr, daddr)
    end if

    host_offset = null_address
    device_offset = null_address
    if (p_address_recorded) host_offset = haddr - p_host_address
    if (query_status == 1_c_int .and. p_device_address /= null_address) &
      device_offset = daddr - p_device_address

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_COEF'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' sample_np=', p_sample_np)
    call emit_i(' ng2q=', ng2q)
    call emit_i(' mxbnd=', mxbnd)
    call emit_i(' nbndloc=', nbndloc)
    call emit_i(' coef_lb1=', 1)
    call emit_i(' coef_ub1=', ng2q)
    call emit_i(' coef_lb2=', 1)
    call emit_i(' coef_ub2=', mxbnd)
    call emit_s(' query_status=', query_status_name(query_status))
    call emit_i(' present=', int(query_status))
    call emit_hex(' haddr=0x', haddr)
    call emit_hex(' daddr=0x', daddr)
    call emit_hex(' p_haddr=0x', p_host_address)
    call emit_hex(' p_daddr=0x', p_device_address)
    call emit_offset(' host_offset=', host_offset)
    call emit_offset(' device_offset=', device_offset)
    call end_record()
  end subroutine fpseid_stepa_diag_coef

  subroutine fpseid_stepa_diag_ylm_parent(phase, symbol, ngcont, ylm)
    integer, intent(in) :: phase, ngcont
    character(len=*), intent(in) :: symbol
    real(c_double), intent(in) :: ylm(ngcont,16)
    integer(c_int) :: query_status
    integer(c_intptr_t) :: haddr, daddr
    integer(c_size_t) :: nbytes

    if (phase < 1 .or. phase > 5) return
    if (diagnosed_ylm_parent(phase)) return
    if (.not. emit_on_this_rank()) return
    diagnosed_ylm_parent(phase) = .true.

    query_status = query_invalid
    haddr = null_address
    daddr = null_address
    nbytes = 0_c_size_t
    if (ngcont > 0) then
      nbytes = int(ngcont, c_size_t) * 16_c_size_t * c_sizeof(ylm(1,1))
      query_status = c_acc_query_r8(ylm(1,1), nbytes, haddr, daddr)
      ylm_host_address(phase) = haddr
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_YLM_PARENT'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' phase=', phase)
    call emit_s(' symbol=', symbol)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' parent_lb1=', 1)
    call emit_i(' parent_ub1=', ngcont)
    call emit_i(' parent_lb2=', 1)
    call emit_i(' parent_ub2=', 16)
    call emit_size(' parent_bytes=', nbytes)
    call emit_s(' query_status=', query_status_name(query_status))
    call emit_i(' parent_present=', int(query_status))
    call emit_hex(' parent_haddr=0x', haddr)
    call emit_hex(' parent_daddr=0x', daddr)
    call end_record()
  end subroutine fpseid_stepa_diag_ylm_parent

  subroutine fpseid_stepa_diag_ylm_section(phase, ngcont, lylm, ylm)
    integer, intent(in) :: phase, ngcont, lylm
    real(c_double), intent(in) :: ylm(ngcont,16)
    integer(c_int) :: query_status
    integer(c_intptr_t) :: haddr, daddr, expected_offset, observed_offset
    integer(c_size_t) :: nbytes
    character(len=8) :: symbol

    if (phase < 1 .or. phase > 5) return
    if (diagnosed_ylm_section(phase)) return
    if (.not. emit_on_this_rank()) return
    diagnosed_ylm_section(phase) = .true.

    write(symbol, '(A,I0)') 'YLM', phase
    query_status = query_invalid
    haddr = null_address
    daddr = null_address
    expected_offset = null_address
    observed_offset = null_address
    nbytes = 0_c_size_t
    if (ngcont > 0 .and. lylm >= 1 .and. lylm <= 16) then
      nbytes = int(ngcont, c_size_t) * c_sizeof(ylm(1,lylm))
      query_status = c_acc_query_r8(ylm(1,lylm), nbytes, haddr, daddr)
      expected_offset = int((lylm-1)*ngcont, c_intptr_t) * &
                        int(c_sizeof(ylm(1,lylm)), c_intptr_t)
      if (ylm_host_address(phase) /= null_address) &
        observed_offset = haddr - ylm_host_address(phase)
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_YLM_SECTION'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' phase=', phase)
    call emit_s(' symbol=', symbol)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' lylm=', lylm)
    call emit_i(' section_lb=', 1)
    call emit_i(' section_ub=', ngcont)
    call emit_size(' section_bytes=', nbytes)
    call emit_s(' query_status=', query_status_name(query_status))
    call emit_i(' section_present=', int(query_status))
    call emit_hex(' section_haddr=0x', haddr)
    call emit_hex(' section_daddr=0x', daddr)
    call emit_offset(' expected_offset=', expected_offset)
    call emit_offset(' observed_offset=', observed_offset)
    call emit_l(' contiguous=', .true.)
    call end_record()
  end subroutine fpseid_stepa_diag_ylm_section

  subroutine fpseid_stepa_diag_vpj_parent(phase, symbol, ngcont, ntyq, vpj)
    integer, intent(in) :: phase, ngcont, ntyq
    character(len=*), intent(in) :: symbol
    real(c_double), intent(in) :: vpj(ngcont,3,4,ntyq)
    integer(c_int) :: query_status
    integer(c_intptr_t) :: haddr, daddr
    integer(c_size_t) :: nbytes

    if (phase < 1 .or. phase > 5) return
    if (diagnosed_vpj_parent(phase)) return
    if (.not. emit_on_this_rank()) return
    diagnosed_vpj_parent(phase) = .true.

    query_status = query_invalid
    haddr = null_address
    daddr = null_address
    nbytes = 0_c_size_t
    if (ngcont > 0 .and. ntyq > 0) then
      nbytes = int(ngcont, c_size_t) * 3_c_size_t * 4_c_size_t * &
               int(ntyq, c_size_t) * c_sizeof(vpj(1,1,1,1))
      query_status = c_acc_query_r8(vpj(1,1,1,1), nbytes, haddr, daddr)
      vpj_host_address(phase) = haddr
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_VPJ_PARENT'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' phase=', phase)
    call emit_s(' symbol=', symbol)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' ntyq=', ntyq)
    call emit_i(' parent_lb1=', 1)
    call emit_i(' parent_ub1=', ngcont)
    call emit_i(' parent_lb2=', 1)
    call emit_i(' parent_ub2=', 3)
    call emit_i(' parent_lb3=', 1)
    call emit_i(' parent_ub3=', 4)
    call emit_i(' parent_lb4=', 1)
    call emit_i(' parent_ub4=', ntyq)
    call emit_size(' parent_bytes=', nbytes)
    call emit_s(' query_status=', query_status_name(query_status))
    call emit_i(' parent_present=', int(query_status))
    call emit_hex(' parent_haddr=0x', haddr)
    call emit_hex(' parent_daddr=0x', daddr)
    call end_record()
  end subroutine fpseid_stepa_diag_vpj_parent

  subroutine fpseid_stepa_diag_vpj_section(phase, ngcont, ntyq, ip, il, &
      ity, vpj)
    integer, intent(in) :: phase, ngcont, ntyq, ip, il, ity
    real(c_double), intent(in) :: vpj(ngcont,3,4,ntyq)
    integer(c_int) :: query_status
    integer(c_intptr_t) :: haddr, daddr, expected_offset, observed_offset
    integer(c_size_t) :: nbytes
    integer(c_intptr_t) :: element_offset
    character(len=8) :: symbol

    if (phase < 1 .or. phase > 5) return
    if (diagnosed_vpj_section(phase)) return
    if (.not. emit_on_this_rank()) return
    diagnosed_vpj_section(phase) = .true.

    write(symbol, '(A,I0)') 'VPJ', phase
    query_status = query_invalid
    haddr = null_address
    daddr = null_address
    expected_offset = null_address
    observed_offset = null_address
    nbytes = 0_c_size_t
    if (ngcont > 0 .and. ntyq > 0 .and. ip >= 1 .and. ip <= 3 .and. &
        il >= 1 .and. il <= 4 .and. ity >= 1 .and. ity <= ntyq) then
      nbytes = int(ngcont, c_size_t) * c_sizeof(vpj(1,ip,il,ity))
      query_status = c_acc_query_r8(vpj(1,ip,il,ity), nbytes, haddr, daddr)
      element_offset = int(ngcont, c_intptr_t) * &
        int((ip-1) + 3*(il-1) + 12*(ity-1), c_intptr_t)
      expected_offset = element_offset * &
                        int(c_sizeof(vpj(1,ip,il,ity)), c_intptr_t)
      if (vpj_host_address(phase) /= null_address) &
        observed_offset = haddr - vpj_host_address(phase)
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_VPJ_SECTION'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' phase=', phase)
    call emit_s(' symbol=', symbol)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' ntyq=', ntyq)
    call emit_i(' ip=', ip)
    call emit_i(' il=', il)
    call emit_i(' ity=', ity)
    call emit_i(' section_lb=', 1)
    call emit_i(' section_ub=', ngcont)
    call emit_size(' section_bytes=', nbytes)
    call emit_s(' query_status=', query_status_name(query_status))
    call emit_i(' section_present=', int(query_status))
    call emit_hex(' section_haddr=0x', haddr)
    call emit_hex(' section_daddr=0x', daddr)
    call emit_offset(' expected_offset=', expected_offset)
    call emit_offset(' observed_offset=', observed_offset)
    call emit_l(' contiguous=', .true.)
    call end_record()
  end subroutine fpseid_stepa_diag_vpj_section

  subroutine fpseid_stepa_diag_extau_parent(phase, ngcont, ntauq, extau)
    integer, intent(in) :: phase, ngcont, ntauq
    complex(c_double_complex), intent(in) :: extau(ngcont,5,ntauq)
    integer(c_int) :: query_status
    integer(c_intptr_t) :: haddr, daddr
    integer(c_size_t) :: nbytes

    if (phase < 1 .or. phase > 5) return
    if (diagnosed_extau_parent(phase)) return
    if (.not. emit_on_this_rank()) return
    diagnosed_extau_parent(phase) = .true.

    query_status = query_invalid
    haddr = null_address
    daddr = null_address
    nbytes = 0_c_size_t
    if (ngcont > 0 .and. ntauq > 0) then
      nbytes = int(ngcont, c_size_t) * 5_c_size_t * int(ntauq, c_size_t) * &
               c_sizeof(extau(1,1,1))
      query_status = c_acc_query_c16(extau(1,1,1), nbytes, haddr, daddr)
      extau_host_address(phase) = haddr
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_EXTAU_PARENT'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' phase=', phase)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' ntauq=', ntauq)
    call emit_i(' parent_lb1=', 1)
    call emit_i(' parent_ub1=', ngcont)
    call emit_i(' parent_lb2=', 1)
    call emit_i(' parent_ub2=', 5)
    call emit_i(' parent_lb3=', 1)
    call emit_i(' parent_ub3=', ntauq)
    call emit_size(' parent_bytes=', nbytes)
    call emit_s(' query_status=', query_status_name(query_status))
    call emit_i(' parent_present=', int(query_status))
    call emit_hex(' parent_haddr=0x', haddr)
    call emit_hex(' parent_daddr=0x', daddr)
    call end_record()
  end subroutine fpseid_stepa_diag_extau_parent

  subroutine fpseid_stepa_diag_extau_section(phase, ngcont, ntauq, np, &
      itseq, extau)
    integer, intent(in) :: phase, ngcont, ntauq, np, itseq
    complex(c_double_complex), intent(in) :: extau(ngcont,5,ntauq)
    integer(c_int) :: query_status
    integer(c_intptr_t) :: haddr, daddr, expected_offset, observed_offset
    integer(c_size_t) :: nbytes
    integer(c_intptr_t) :: element_offset

    if (phase < 1 .or. phase > 5) return
    if (diagnosed_extau_section(phase)) return
    if (.not. emit_on_this_rank()) return
    diagnosed_extau_section(phase) = .true.

    query_status = query_invalid
    haddr = null_address
    daddr = null_address
    expected_offset = null_address
    observed_offset = null_address
    nbytes = 0_c_size_t
    if (ngcont > 0 .and. ntauq > 0 .and. np >= 1 .and. np <= 5 .and. &
        itseq >= 1 .and. itseq <= ntauq) then
      nbytes = int(ngcont, c_size_t) * c_sizeof(extau(1,np,itseq))
      query_status = c_acc_query_c16(extau(1,np,itseq), nbytes, haddr, daddr)
      element_offset = int(ngcont, c_intptr_t) * &
                       int((np-1) + 5*(itseq-1), c_intptr_t)
      expected_offset = element_offset * &
                        int(c_sizeof(extau(1,np,itseq)), c_intptr_t)
      if (extau_host_address(phase) /= null_address) &
        observed_offset = haddr - extau_host_address(phase)
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_EXTAU_SECTION'
    call emit_i(' rank=', diagnostic_rank)
    call emit_i(' phase=', phase)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' ntauq=', ntauq)
    call emit_i(' np=', np)
    call emit_i(' itseq=', itseq)
    call emit_i(' section_lb=', 1)
    call emit_i(' section_ub=', ngcont)
    call emit_size(' section_bytes=', nbytes)
    call emit_s(' query_status=', query_status_name(query_status))
    call emit_i(' section_present=', int(query_status))
    call emit_hex(' section_haddr=0x', haddr)
    call emit_hex(' section_daddr=0x', daddr)
    call emit_offset(' expected_offset=', expected_offset)
    call emit_offset(' observed_offset=', observed_offset)
    call emit_l(' contiguous=', .true.)
    call end_record()
  end subroutine fpseid_stepa_diag_extau_section

  subroutine fpseid_stepa_diag_nonlocal(block_id, loopcnt, work2_ncol, &
      ngcont, ng2q, work2, cfac, ngnl)
    integer, intent(in) :: block_id, loopcnt, work2_ncol, ngcont, ng2q
    complex(c_double_complex), intent(in) :: work2(ngcont,*), cfac(*)
    integer(c_int), intent(in) :: ngnl(*)
    integer :: ngnl_min, ngnl_max
    integer(c_int) :: work2_status, cfac_status, ngnl_status
    integer(c_intptr_t) :: work2_haddr, work2_daddr
    integer(c_intptr_t) :: cfac_haddr, cfac_daddr
    integer(c_intptr_t) :: ngnl_haddr, ngnl_daddr
    integer(c_size_t) :: nbytes
    logical :: ngnl_valid, ngnl_bounds_ok
    character(len=7) :: block_name

    if (block_id < 1 .or. block_id > 2) return
    if (diagnosed_nonlocal(block_id)) return
    if (.not. emit_on_this_rank()) return
    diagnosed_nonlocal(block_id) = .true.

    if (block_id == 1) then
      block_name = 'forward'
    else
      block_name = 'reverse'
    end if
    ngnl_min = 0
    ngnl_max = 0
    ngnl_valid = .false.
    ngnl_bounds_ok = .false.
    work2_status = query_invalid
    cfac_status = query_invalid
    ngnl_status = query_invalid
    work2_haddr = null_address
    work2_daddr = null_address
    cfac_haddr = null_address
    cfac_daddr = null_address
    ngnl_haddr = null_address
    ngnl_daddr = null_address

    if (loopcnt > 0) then
      ngnl_min = minval(ngnl(1:loopcnt))
      ngnl_max = maxval(ngnl(1:loopcnt))
      ngnl_valid = ngnl_min >= 0 .and. ngnl_max <= ngcont .and. &
                   ngnl_max <= ng2q
      ngnl_bounds_ok = ngnl_valid .and. loopcnt <= work2_ncol
      if (ngcont > 0 .and. loopcnt <= work2_ncol) then
        nbytes = int(ngcont, c_size_t) * int(loopcnt, c_size_t) * &
                 c_sizeof(work2(1,1))
        work2_status = c_acc_query_c16(work2(1,1), nbytes, work2_haddr, &
                                       work2_daddr)
      end if
      nbytes = int(loopcnt, c_size_t) * c_sizeof(cfac(1))
      cfac_status = c_acc_query_c16(cfac(1), nbytes, cfac_haddr, cfac_daddr)
      nbytes = int(loopcnt, c_size_t) * c_sizeof(ngnl(1))
      ngnl_status = c_acc_query_i4(ngnl(1), nbytes, ngnl_haddr, ngnl_daddr)
    end if

    write(error_unit, '(A)', advance='no') 'FPSEID_STEPA_NONLOCAL'
    call emit_i(' rank=', diagnostic_rank)
    call emit_s(' block=', block_name)
    call emit_i(' loopcnt=', loopcnt)
    call emit_i(' work2_ncol=', work2_ncol)
    call emit_i(' ngcont=', ngcont)
    call emit_i(' ng2q=', ng2q)
    call emit_i(' ngnl_min=', ngnl_min)
    call emit_i(' ngnl_max=', ngnl_max)
    call emit_l(' ngnl_valid=', ngnl_valid)
    call emit_l(' ngnl_bounds_ok=', ngnl_bounds_ok)
    call emit_s(' work2_status=', query_status_name(work2_status))
    call emit_i(' work2_present=', int(work2_status))
    call emit_s(' cfac_status=', query_status_name(cfac_status))
    call emit_i(' cfac_present=', int(cfac_status))
    call emit_s(' ngnl_status=', query_status_name(ngnl_status))
    call emit_i(' ngnl_present=', int(ngnl_status))
    call emit_hex(' work2_haddr=0x', work2_haddr)
    call emit_hex(' work2_daddr=0x', work2_daddr)
    call emit_hex(' cfac_haddr=0x', cfac_haddr)
    call emit_hex(' cfac_daddr=0x', cfac_daddr)
    call emit_hex(' ngnl_haddr=0x', ngnl_haddr)
    call emit_hex(' ngnl_daddr=0x', ngnl_daddr)
    call end_record()
  end subroutine fpseid_stepa_diag_nonlocal

end module mod_stepa_diag
