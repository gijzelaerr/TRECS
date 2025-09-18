! Minimal stub for pix_tools module to support fitstools compilation
module pix_tools
  use healpix_types
  implicit none

  ! Overloaded interface for different integer types
  interface npix2nside
    module procedure npix2nside_i4b, npix2nside_i8b
  end interface

contains

  function nside2npix(nside)
    implicit none
    integer(i4b), intent(in) :: nside
    integer(i8b) :: nside2npix
    nside2npix = 12_i8b * int(nside, i8b) * int(nside, i8b)
  end function nside2npix

  function nside2npweights(nside)
    implicit none
    integer(i4b), intent(in) :: nside
    integer(i4b) :: nside2npweights
    ! Simple stub - return 2*nside for weights
    nside2npweights = 2 * nside
  end function nside2npweights

  function npix2nside_i4b(npix)
    implicit none
    integer(i4b), intent(in) :: npix
    integer(i4b) :: npix2nside_i4b
    ! Simple inverse: nside = sqrt(npix/12)
    npix2nside_i4b = int(sqrt(real(npix)/12.0), i4b)
  end function npix2nside_i4b

  function npix2nside_i8b(npix)
    implicit none
    integer(i8b), intent(in) :: npix
    integer(i4b) :: npix2nside_i8b
    ! Simple inverse: nside = sqrt(npix/12)
    npix2nside_i8b = int(sqrt(real(npix)/12.0), i4b)
  end function npix2nside_i8b

end module pix_tools