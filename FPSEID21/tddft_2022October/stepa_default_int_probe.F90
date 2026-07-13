program stepa_default_int_probe
  use iso_c_binding, only: c_int
  implicit none

  interface
    subroutine require_c_int(value)
      import c_int
      integer(c_int), intent(in) :: value(*)
    end subroutine require_c_int
  end interface

  integer :: value(1)

  call require_c_int(value)
end program stepa_default_int_probe
