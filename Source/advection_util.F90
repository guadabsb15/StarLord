module advection_util_module

  use amrex_fort_module, only: rt => amrex_real

  implicit none

  ! This derived type stores all of the temporary arrays needed
  ! during a hydro update.

  type :: ht

     ! Arrays for workspace
     real(rt), pointer :: flatn(:,:,:)
     real(rt), pointer :: div(:,:,:)
     real(rt), pointer :: pdivu(:,:,:)

     ! Edge-centered primitive variables (Riemann state)
     real(rt), pointer :: q1(:,:,:,:)
     real(rt), pointer :: q2(:,:,:,:)
     real(rt), pointer :: q3(:,:,:,:)
     real(rt), pointer :: qint(:,:,:,:)

     real(rt), pointer :: shk(:,:,:)

     ! Local arrays for flattening
     real(rt), pointer :: dp(:,:,:), z(:,:,:), chi(:,:,:)

     ! Local arrays in cmpflx
     real(rt), pointer :: smallc(:,:), cavg(:,:)
     real(rt), pointer :: gamcm(:,:), gamcp(:,:)

     real(rt), pointer :: us1d(:)

     ! \delta s_{\ib}^{vL}
     real(rt), pointer :: dsvl(:,:)

     ! s_{i+\half}^{H.O.}
     real(rt), pointer :: sedge(:,:)

     ! temporary interface values of the parabola
     real(rt), pointer :: sxm(:,:,:,:), sym(:,:,:,:), szm(:,:,:,:)
     real(rt), pointer :: sxp(:,:,:,:), syp(:,:,:,:), szp(:,:,:,:)

     real(rt), pointer :: qm(:,:,:,:,:)
     real(rt), pointer :: qp(:,:,:,:,:)

  end type ht

contains

#ifdef CUDA
  attributes(device) &
#endif
  subroutine enforce_minimum_density(uin,uin_lo,uin_hi, &
                                     uout,uout_lo,uout_hi, &
                                     vol,vol_lo,vol_hi, &
                                     lo,hi,frac_change,verbose)

    use network, only: nspec, naux
    use bl_constants_module, only: ZERO
    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR, URHO, UEINT, UEDEN, small_dens

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3), verbose
    integer,  intent(in   ) ::  uin_lo(3),  uin_hi(3)
    integer,  intent(in   ) :: uout_lo(3), uout_hi(3)
    integer,  intent(in   ) ::  vol_lo(3),  vol_hi(3)

    real(rt), intent(in   ) ::  uin( uin_lo(1): uin_hi(1), uin_lo(2): uin_hi(2), uin_lo(3): uin_hi(3),NVAR)
    real(rt), intent(inout) :: uout(uout_lo(1):uout_hi(1),uout_lo(2):uout_hi(2),uout_lo(3):uout_hi(3),NVAR)
    real(rt), intent(in   ) ::  vol( vol_lo(1): vol_hi(1), vol_lo(2): vol_hi(2), vol_lo(3): vol_hi(3))
    real(rt), intent(inout) :: frac_change

    ! Local variables
    integer  :: i,ii,j,jj,k,kk
    integer  :: i_set, j_set, k_set
    real(rt) :: max_dens
    real(rt) :: f_c
    real(rt) :: old_state(NVAR), new_state(NVAR), unew(NVAR)
    integer  :: num_positive_zones

    real(rt) :: initial_mass, final_mass
    real(rt) :: initial_eint, final_eint
    real(rt) :: initial_eden, final_eden

    logical :: have_reset

    initial_mass = ZERO
    final_mass   = ZERO

    initial_eint = ZERO
    final_eint   = ZERO

    initial_eden = ZERO
    final_eden   = ZERO

    max_dens = ZERO

    have_reset = .false.

    do k = lo(3),hi(3)
       do j = lo(2),hi(2)
          do i = lo(1),hi(1)

             initial_mass = initial_mass + uout(i,j,k,URHO ) * vol(i,j,k)
             initial_eint = initial_eint + uout(i,j,k,UEINT) * vol(i,j,k)
             initial_eden = initial_eden + uout(i,j,k,UEDEN) * vol(i,j,k)

             if (uout(i,j,k,URHO) .eq. ZERO) then

#ifndef CUDA
                print *,'DENSITY EXACTLY ZERO AT CELL ',i,j,k
                print *,'  in grid ',lo(1),lo(2),lo(3),hi(1),hi(2),hi(3)
                call bl_error("Error:: advection_util_nd.F90 :: ca_enforce_minimum_density")
#endif

             else if (uout(i,j,k,URHO) < small_dens) then

                have_reset = .true.

                old_state = uin(i,j,k,:)

                ! Store the maximum (negative) fractional change in the density

                if ( uout(i,j,k,URHO) < ZERO ) then

                   f_c = (uout(i,j,k,URHO) - uin(i,j,k,URHO)) / uin(i,j,k,URHO)

#ifdef CUDA
                   f_c = atomicmin(frac_change, f_c)
#else
                   frac_change = min(frac_change, f_c)
#endif

                endif

                ! Reset to the characteristics of the adjacent state with the highest density.

                max_dens = uout(i,j,k,URHO)
                i_set = i
                j_set = j
                k_set = k
                do kk = -1,1
                   do jj = -1,1
                      do ii = -1,1
                         if (i+ii.ge.lo(1) .and. j+jj.ge.lo(2) .and. k+kk.ge.lo(3) .and. &
                              i+ii.le.hi(1) .and. j+jj.le.hi(2) .and. k+kk.le.hi(3)) then
                            if (uout(i+ii,j+jj,k+kk,URHO) .gt. max_dens) then
                               i_set = i+ii
                               j_set = j+jj
                               k_set = k+kk
                               max_dens = uout(i_set,j_set,k_set,URHO)
                            endif
                         endif
                      end do
                   end do
                end do

                if (max_dens < small_dens) then

                   ! We could not find any nearby zones with sufficient density.

                   call reset_to_small_state(old_state, new_state, [i, j, k], lo, hi, verbose)

                else

                   unew = uout(i_set,j_set,k_set,:)

                   call reset_to_zone_state(old_state, new_state, unew, [i, j, k], lo, hi, verbose)

                endif

                uout(i,j,k,:) = new_state

             endif

             final_mass = final_mass + uout(i,j,k,URHO ) * vol(i,j,k)
             final_eint = final_eint + uout(i,j,k,UEINT) * vol(i,j,k)
             final_eden = final_eden + uout(i,j,k,UEDEN) * vol(i,j,k)

          enddo
       enddo
    enddo

  end subroutine enforce_minimum_density



#ifdef CUDA
  attributes(device) &
#endif
  subroutine reset_to_small_state(old_state, new_state, idx, lo, hi, verbose)

    use bl_constants_module, only: ZERO
    use network, only: nspec, naux
    use eos_type_module, only: eos_t, eos_input_rt
    use eos_module, only: eos
    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR, URHO, UMX, UMY, UMZ, UTEMP, UEINT, UEDEN, UFS, small_temp, small_dens, npassive, upass_map

    implicit none

    real(rt), intent(in   ) :: old_state(NVAR)
    real(rt), intent(inout) :: new_state(NVAR)
    integer,  intent(in   ) :: idx(3), lo(3), hi(3), verbose

    integer      :: n, ipassive
    type (eos_t) :: eos_state

    ! If no neighboring zones are above small_dens, our only recourse
    ! is to set the density equal to small_dens, and the temperature
    ! equal to small_temp. We set the velocities to zero,
    ! though any choice here would be arbitrary.

#ifndef CUDA
    if (verbose .gt. 0) then
       print *,'   '
       if (new_state(URHO) < ZERO) then
          print *,'>>> RESETTING NEG.  DENSITY AT ',idx(1),idx(2),idx(3)
       else
          print *,'>>> RESETTING SMALL DENSITY AT ',idx(1),idx(2),idx(3)
       endif
       print *,'>>> FROM ',new_state(URHO),' TO ',small_dens
       print *,'>>> IN GRID ',lo(1),lo(2),lo(3),hi(1),hi(2),hi(3)
       print *,'>>> ORIGINAL DENSITY FOR OLD STATE WAS ',old_state(URHO)
       print *,'   '
    end if
#endif

    do ipassive = 1, npassive
       n = upass_map(ipassive)
       new_state(n) = new_state(n) * (small_dens / new_state(URHO))
    end do

    eos_state % rho = small_dens
    eos_state % T   = small_temp
    eos_state % xn  = new_state(UFS:UFS+nspec-1) / small_dens
    eos_state % aux = new_state(UFS:UFS+naux-1) / small_dens

    call eos(eos_input_rt, eos_state)

    new_state(URHO ) = eos_state % rho
    new_state(UTEMP) = eos_state % T

    new_state(UMX  ) = ZERO
    new_state(UMY  ) = ZERO
    new_state(UMZ  ) = ZERO

    new_state(UEINT) = eos_state % rho * eos_state % e
    new_state(UEDEN) = new_state(UEINT)

  end subroutine reset_to_small_state



#ifdef CUDA
  attributes(device) &
#endif
  subroutine reset_to_zone_state(old_state, new_state, input_state, idx, lo, hi, verbose)

    use bl_constants_module, only: ZERO
    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR, URHO

    implicit none

    real(rt), intent(in   ) :: old_state(NVAR), input_state(NVAR)
    real(rt), intent(inout) :: new_state(NVAR)
    integer,  intent(in   ) :: idx(3), lo(3), hi(3), verbose

#ifndef CUDA
    if (verbose .gt. 0) then
       if (new_state(URHO) < ZERO) then
          print *,'   '
          print *,'>>> RESETTING NEG.  DENSITY AT ',idx(1),idx(2),idx(3)
          print *,'>>> FROM ',new_state(URHO),' TO ',input_state(URHO)
          print *,'>>> IN GRID ',lo(1),lo(2),lo(3),hi(1),hi(2),hi(3)
          print *,'>>> ORIGINAL DENSITY FOR OLD STATE WAS ',old_state(URHO)
          print *,'   '
       else
          print *,'   '
          print *,'>>> RESETTING SMALL DENSITY AT ',idx(1),idx(2),idx(3)
          print *,'>>> FROM ',new_state(URHO),' TO ',input_state(URHO)
          print *,'>>> IN GRID ',lo(1),lo(2),lo(3),hi(1),hi(2),hi(3)
          print *,'>>> ORIGINAL DENSITY FOR OLD STATE WAS ',old_state(URHO)
          print *,'   '
       end if
    end if
#endif

    new_state(:) = input_state(:)

  end subroutine reset_to_zone_state



#ifdef CUDA
  attributes(device) &
#endif
  subroutine compute_cfl(q, q_lo, q_hi, &
                         qaux, qa_lo, qa_hi, &
                         lo, hi, dt, dx, courno) &
                         bind(C, name = "compute_cfl")

    use bl_constants_module, only: ZERO, ONE
    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NQ, QRHO, QU, QV, QW, QC, NQAUX
    use prob_params_module, only: dim

    implicit none

    integer :: lo(3), hi(3)
    integer :: q_lo(3), q_hi(3), qa_lo(3), qa_hi(3)

    real(rt)         :: q(q_lo(1):q_hi(1),q_lo(2):q_hi(2),q_lo(3):q_hi(3),NQ)
    real(rt)         :: qaux(qa_lo(1):qa_hi(1),qa_lo(2):qa_hi(2),qa_lo(3):qa_hi(3),NQAUX)
    real(rt)         :: dt, dx(3), courno

    real(rt)         :: courx, coury, courz, courmx, courmy, courmz, courtmp
    real(rt)         :: dtdx, dtdy, dtdz
    integer          :: i, j, k

    ! Compute running max of Courant number over grids

    courmx = courno
    courmy = courno
    courmz = courno

    dtdx = dt / dx(1)

    if (dim .ge. 2) then
       dtdy = dt / dx(2)
    else
       dtdy = ZERO
    endif

    if (dim .eq. 3) then
       dtdz = dt / dx(3)
    else
       dtdz = ZERO
    endif

    do k = lo(3),hi(3)
       do j = lo(2),hi(2)
          do i = lo(1),hi(1)

             courx = ( qaux(i,j,k,QC) + abs(q(i,j,k,QU)) ) * dtdx
             coury = ( qaux(i,j,k,QC) + abs(q(i,j,k,QV)) ) * dtdy
             courz = ( qaux(i,j,k,QC) + abs(q(i,j,k,QW)) ) * dtdz

             courmx = max( courmx, courx )
             courmy = max( courmy, coury )
             courmz = max( courmz, courz )

             ! method-of-lines constraint
             courtmp = courx
             if (dim >= 2) then
                courtmp = courtmp + coury
             endif
             if (dim == 3) then
                courtmp = courtmp + courz
             endif

#ifndef CUDA
             ! note: it might not be 1 for all RK integrators
             if (courtmp > ONE) then
                print *,'   '
                call bl_warning("Warning:: advection_util_nd.F90 :: CFL violation in compute_cfl")
                print *,'>>> ... at cell (i,j,k)   : ', i, j, k
                print *,'>>> ... u,v,w, c            ', q(i,j,k,QU), q(i,j,k,QV), q(i,j,k,QW), qaux(i,j,k,QC)
                print *,'>>> ... density             ', q(i,j,k,QRHO)
             endif
#endif

#ifdef CUDA
             courtmp = atomicmax(courno, courtmp)
#else
             courno = max(courno, courtmp)
#endif

          enddo
       enddo
    enddo

  end subroutine compute_cfl



#ifdef CUDA
  attributes(device) &
#endif
  subroutine ctoprim(lo, hi, &
                     uin, uin_lo, uin_hi, &
                     q,     q_lo,   q_hi, &
                     qaux, qa_lo,  qa_hi)

    use actual_network, only: nspec, naux
    use eos_module, only: eos
    use eos_type_module, only: eos_t, eos_input_re
    use bl_constants_module, only: ZERO, HALF, ONE
    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR, URHO, UMX, UMZ, &
                                  UEDEN, UEINT, UTEMP, &
                                  QRHO, QU, QV, QW, &
                                  QREINT, QPRES, QTEMP, QGAME, QFS, QFX, &
                                  NQ, QC, QCSML, QGAMC, QDPDR, QDPDE, NQAUX, &
                                  npassive, upass_map, qpass_map, small_dens

    implicit none

    integer, intent(in) :: lo(3), hi(3)
    integer, intent(in) :: uin_lo(3), uin_hi(3)
    integer, intent(in) :: q_lo(3), q_hi(3)
    integer, intent(in) :: qa_lo(3), qa_hi(3)

    real(rt), intent(in   ) :: uin(uin_lo(1):uin_hi(1),uin_lo(2):uin_hi(2),uin_lo(3):uin_hi(3),NVAR)
    real(rt), intent(inout) :: q(q_lo(1):q_hi(1),q_lo(2):q_hi(2),q_lo(3):q_hi(3),NQ)
    real(rt), intent(inout) :: qaux(qa_lo(1):qa_hi(1),qa_lo(2):qa_hi(2),qa_lo(3):qa_hi(3),NQAUX)

    real(rt), parameter :: small = 1.e-8_rt
    real(rt), parameter :: dual_energy_eta1 = 1.e0_rt

    integer  :: i, j, k, g
    integer  :: n, iq, ipassive
    real(rt) :: kineng, rhoinv
    real(rt) :: vel(3)

    type (eos_t) :: eos_state

    do k = lo(3), hi(3)
       do j = lo(2), hi(2)

          do i = lo(1), hi(1)
#ifndef CUDA
             if (uin(i,j,k,URHO) .le. ZERO) then
                print *,'   '
                print *,'>>> Error: advection_util_nd.F90::ctoprim ',i, j, k
                print *,'>>> ... negative density ', uin(i,j,k,URHO)
                call bl_error("Error:: advection_util_nd.F90 :: ctoprim")
             else if (uin(i,j,k,URHO) .lt. small_dens) then
                print *,'   '
                print *,'>>> Error: advection_util_nd.F90::ctoprim ',i, j, k
                print *,'>>> ... small density ', uin(i,j,k,URHO)
                call bl_error("Error:: advection_util_nd.F90 :: ctoprim")
             endif
#endif
          end do

          do i = lo(1), hi(1)

             q(i,j,k,QRHO) = uin(i,j,k,URHO)
             rhoinv = ONE/q(i,j,k,QRHO)

             vel = uin(i,j,k,UMX:UMZ) * rhoinv

             q(i,j,k,QU:QW) = vel

             ! Get the internal energy, which we'll use for
             ! determining the pressure.  We use a dual energy
             ! formalism. If (E - K) < eta1 and eta1 is suitably
             ! small, then we risk serious numerical truncation error
             ! in the internal energy.  Therefore we'll use the result
             ! of the separately updated internal energy equation.
             ! Otherwise, we'll set e = E - K.

             kineng = HALF * q(i,j,k,QRHO) * (q(i,j,k,QU)**2 + q(i,j,k,QV)**2 + q(i,j,k,QW)**2)

             if ( (uin(i,j,k,UEDEN) - kineng) / uin(i,j,k,UEDEN) .gt. dual_energy_eta1) then
                q(i,j,k,QREINT) = (uin(i,j,k,UEDEN) - kineng) * rhoinv
             else
                q(i,j,k,QREINT) = uin(i,j,k,UEINT) * rhoinv
             endif

             ! If we're advecting in the rotating reference frame,
             ! then subtract off the rotation component here.

             q(i,j,k,QTEMP) = uin(i,j,k,UTEMP)
          enddo
       enddo
    enddo

    ! Load passively advected quatities into q
    do ipassive = 1, npassive
       n  = upass_map(ipassive)
       iq = qpass_map(ipassive)
       do k = lo(3),hi(3)
          do j = lo(2),hi(2)
             do i = lo(1),hi(1)
                q(i,j,k,iq) = uin(i,j,k,n)/q(i,j,k,QRHO)
             enddo
          enddo
       enddo
    enddo

    ! get gamc, p, T, c, csml using q state
    do k = lo(3), hi(3)
       do j = lo(2), hi(2)
          do i = lo(1), hi(1)

             eos_state % T   = q(i,j,k,QTEMP )
             eos_state % rho = q(i,j,k,QRHO  )
             eos_state % e   = q(i,j,k,QREINT)
             eos_state % xn  = q(i,j,k,QFS:QFS+nspec-1)
             eos_state % aux = q(i,j,k,QFX:QFX+naux-1)

             call eos(eos_input_re, eos_state)

             q(i,j,k,QTEMP)  = eos_state % T
             q(i,j,k,QREINT) = eos_state % e * q(i,j,k,QRHO)
             q(i,j,k,QPRES)  = eos_state % p
             q(i,j,k,QGAME)  = q(i,j,k,QPRES) / q(i,j,k,QREINT) + ONE

             qaux(i,j,k,QDPDR)  = eos_state % dpdr_e
             qaux(i,j,k,QDPDE)  = eos_state % dpde

             qaux(i,j,k,QGAMC)  = eos_state % gam1
             qaux(i,j,k,QC   )  = eos_state % cs
             qaux(i,j,k,QCSML)  = max(small, small * qaux(i,j,k,QC))
          enddo
       enddo
    enddo

  end subroutine ctoprim



#ifdef CUDA
  attributes(device) &
#endif
  subroutine normalize_species_fluxes(flux1,flux1_lo,flux1_hi, &
                                      flux2,flux2_lo,flux2_hi, &
                                      flux3,flux3_lo,flux3_hi, &
                                      lo, hi)

    ! here we normalize the fluxes of the mass fractions so that
    ! they sum to 0.  This is essentially the CMA procedure that is
    ! defined in Plewa & Muller, 1999, A&A, 342, 179

    use network, only: nspec
    use bl_constants_module, only: ZERO, ONE
    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR, URHO, UFS

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3)
    integer,  intent(in   ) :: flux1_lo(3), flux1_hi(3)
    integer,  intent(in   ) :: flux2_lo(3), flux2_hi(3)
    integer,  intent(in   ) :: flux3_lo(3), flux3_hi(3)
    real(rt), intent(inout) :: flux1(flux1_lo(1):flux1_hi(1),flux1_lo(2):flux1_hi(2),flux1_lo(3):flux1_hi(3),NVAR)
    real(rt), intent(inout) :: flux2(flux2_lo(1):flux2_hi(1),flux2_lo(2):flux2_hi(2),flux2_lo(3):flux2_hi(3),NVAR)
    real(rt), intent(inout) :: flux3(flux3_lo(1):flux3_hi(1),flux3_lo(2):flux3_hi(2),flux3_lo(3):flux3_hi(3),NVAR)

    ! Local variables
    integer  :: i, j, k, n
    real(rt) :: sum, fac

    do k = lo(3),hi(3)
       do j = lo(2),hi(2)
          do i = lo(1),hi(1)+1
             sum = ZERO
             do n = UFS, UFS+nspec-1
                sum = sum + flux1(i,j,k,n)
             end do
             if (sum .ne. ZERO) then
                fac = flux1(i,j,k,URHO) / sum
             else
                fac = ONE
             end if
             do n = UFS, UFS+nspec-1
                flux1(i,j,k,n) = flux1(i,j,k,n) * fac
             end do
          end do
       end do
    end do

    do k = lo(3),hi(3)
       do j = lo(2),hi(2)+1
          do i = lo(1),hi(1)
             sum = ZERO
             do n = UFS, UFS+nspec-1
                sum = sum + flux2(i,j,k,n)
             end do
             if (sum .ne. ZERO) then
                fac = flux2(i,j,k,URHO) / sum
             else
                fac = ONE
             end if
             do n = UFS, UFS+nspec-1
                flux2(i,j,k,n) = flux2(i,j,k,n) * fac
             end do
          end do
       end do
    end do

    do k = lo(3),hi(3)+1
       do j = lo(2),hi(2)
          do i = lo(1),hi(1)
             sum = ZERO
             do n = UFS, UFS+nspec-1
                sum = sum + flux3(i,j,k,n)
             end do
             if (sum .ne. ZERO) then
                fac = flux3(i,j,k,URHO) / sum
             else
                fac = ONE
             end if
             do n = UFS, UFS+nspec-1
                flux3(i,j,k,n) = flux3(i,j,k,n) * fac
             end do
          end do
       end do
    end do

  end subroutine normalize_species_fluxes

! :::
! ::: ------------------------------------------------------------------
! :::

#ifdef CUDA
  attributes(device) &
#endif
  subroutine divu(lo,hi,q,q_lo,q_hi,dx,div,div_lo,div_hi)

    use bl_constants_module, only: FOURTH, ONE
    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: QU, QV, QW, QVAR

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3)
    integer,  intent(in   ) :: q_lo(3), q_hi(3)
    integer,  intent(in   ) :: div_lo(3), div_hi(3)
    real(rt), intent(in   ) :: dx(3)
    real(rt), intent(inout) :: div(div_lo(1):div_hi(1),div_lo(2):div_hi(2),div_lo(3):div_hi(3))
    real(rt), intent(in   ) :: q(q_lo(1):q_hi(1),q_lo(2):q_hi(2),q_lo(3):q_hi(3),QVAR)

    integer  :: i, j, k
    real(rt) :: ux, vy, wz, dxinv, dyinv, dzinv

    dxinv = ONE/dx(1)
    dyinv = ONE/dx(2)
    dzinv = ONE/dx(3)

    do k=lo(3),hi(3)+1
       do j=lo(2),hi(2)+1
          do i=lo(1),hi(1)+1

             ux = FOURTH*( &
                    + q(i  ,j  ,k  ,QU) - q(i-1,j  ,k  ,QU) &
                    + q(i  ,j  ,k-1,QU) - q(i-1,j  ,k-1,QU) &
                    + q(i  ,j-1,k  ,QU) - q(i-1,j-1,k  ,QU) &
                    + q(i  ,j-1,k-1,QU) - q(i-1,j-1,k-1,QU) ) * dxinv

             vy = FOURTH*( &
                    + q(i  ,j  ,k  ,QV) - q(i  ,j-1,k  ,QV) &
                    + q(i  ,j  ,k-1,QV) - q(i  ,j-1,k-1,QV) &
                    + q(i-1,j  ,k  ,QV) - q(i-1,j-1,k  ,QV) &
                    + q(i-1,j  ,k-1,QV) - q(i-1,j-1,k-1,QV) ) * dyinv

             wz = FOURTH*( &
                    + q(i  ,j  ,k  ,QW) - q(i  ,j  ,k-1,QW) &
                    + q(i  ,j-1,k  ,QW) - q(i  ,j-1,k-1,QW) &
                    + q(i-1,j  ,k  ,QW) - q(i-1,j  ,k-1,QW) &
                    + q(i-1,j-1,k  ,QW) - q(i-1,j-1,k-1,QW) ) * dzinv

             div(i,j,k) = ux + vy + wz

          enddo
       enddo
    enddo

  end subroutine divu



  ! Allocate the components of a hydro temporary.

  subroutine allocate_ht(h, lo, hi, flux1_lo, flux1_hi, flux2_lo, flux2_hi, &
                         flux3_lo, flux3_hi, st_lo, st_hi, It_lo, It_hi, &
                         shk_lo, shk_hi, g_lo, g_hi, gd_lo, gd_hi, q_lo, q_hi)

    use meth_params_module, only: NGDNV, NQ

    implicit none

    type(ht), intent(inout) :: h

    integer, intent(in) :: lo(3), hi(3)
    integer, intent(in) :: flux1_lo(3), flux1_hi(3)
    integer, intent(in) :: flux2_lo(3), flux2_hi(3)
    integer, intent(in) :: flux3_lo(3), flux3_hi(3)
    integer, intent(in) :: q_lo(3), q_hi(3)
    integer, intent(in) :: It_lo(3), It_hi(3)
    integer, intent(in) :: st_lo(3), st_hi(3)
    integer, intent(in) :: shk_lo(3), shk_hi(3)
    integer, intent(in) :: g_lo(3), g_hi(3)
    integer, intent(in) :: gd_lo(2), gd_hi(2)

    allocate(h % div(lo(1):hi(1)+1, lo(2):hi(2)+1, lo(3):hi(3)+1))
    allocate(h % pdivu(lo(1):hi(1), lo(2):hi(2)  , lo(3):hi(3)))

    allocate(h % q1(flux1_lo(1):flux1_hi(1),flux1_lo(2):flux1_hi(2),flux1_lo(3):flux1_hi(3),NGDNV))
    allocate(h % q2(flux2_lo(1):flux2_hi(1),flux2_lo(2):flux2_hi(2),flux2_lo(3):flux2_hi(3),NGDNV))
    allocate(h % q3(flux3_lo(1):flux3_hi(1),flux3_lo(2):flux3_hi(2),flux3_lo(3):flux3_hi(3),NGDNV))

    allocate(h % sxm(st_lo(1):st_hi(1),st_lo(2):st_hi(2),st_lo(3):st_hi(3),NQ))
    allocate(h % sxp(st_lo(1):st_hi(1),st_lo(2):st_hi(2),st_lo(3):st_hi(3),NQ))
    allocate(h % sym(st_lo(1):st_hi(1),st_lo(2):st_hi(2),st_lo(3):st_hi(3),NQ))
    allocate(h % syp(st_lo(1):st_hi(1),st_lo(2):st_hi(2),st_lo(3):st_hi(3),NQ))
    allocate(h % szm(st_lo(1):st_hi(1),st_lo(2):st_hi(2),st_lo(3):st_hi(3),NQ))
    allocate(h % szp(st_lo(1):st_hi(1),st_lo(2):st_hi(2),st_lo(3):st_hi(3),NQ))

    allocate(h % qm(It_lo(1):It_hi(1), It_lo(2):It_hi(2), It_lo(3):It_hi(3), NQ, 3))
    allocate(h % qp(It_lo(1):It_hi(1), It_lo(2):It_hi(2), It_lo(3):It_hi(3), NQ, 3))

    allocate(h % qint(It_lo(1):It_hi(1),It_lo(2):It_hi(2),It_lo(3):It_hi(3),NGDNV))

    allocate(h % shk(shk_lo(1):shk_hi(1),shk_lo(2):shk_hi(2),shk_lo(3):shk_hi(3)))

    allocate(h % dp (g_lo(1)-1:g_hi(1)+1,g_lo(2)-1:g_hi(2)+1,g_lo(3)-1:g_hi(3)+1))
    allocate(h % z  (g_lo(1)-1:g_hi(1)+1,g_lo(2)-1:g_hi(2)+1,g_lo(3)-1:g_hi(3)+1))
    allocate(h % chi(g_lo(1)-1:g_hi(1)+1,g_lo(2)-1:g_hi(2)+1,g_lo(3)-1:g_hi(3)+1))

    allocate(h % dsvl(lo(1)-2:hi(1)+2,lo(2)-2:hi(2)+2))

    allocate(h % sedge(lo(1)-1:hi(1)+2,lo(2)-1:hi(2)+2))

    allocate(h % smallc(gd_lo(1):gd_hi(1),gd_lo(2):gd_hi(2)))
    allocate(h %   cavg(gd_lo(1):gd_hi(1),gd_lo(2):gd_hi(2)))
    allocate(h %  gamcm(gd_lo(1):gd_hi(1),gd_lo(2):gd_hi(2)))
    allocate(h %  gamcp(gd_lo(1):gd_hi(1),gd_lo(2):gd_hi(2)))

    allocate(h % us1d(gd_lo(1):gd_hi(1)))

    allocate(h % flatn(q_lo(1):q_hi(1),q_lo(2):q_hi(2),q_lo(3):q_hi(3)))

  end subroutine allocate_ht




  subroutine deallocate_ht(h)

    implicit none

    type(ht), intent(inout) :: h

    deallocate(h % dsvl)
    deallocate(h % sedge)

    deallocate(h % dp )
    deallocate(h % z  )
    deallocate(h % chi)

    deallocate(h % smallc)
    deallocate(h %  cavg)
    deallocate(h % gamcm)
    deallocate(h % gamcp)

    deallocate(h % us1d)

    deallocate(h % flatn)

    deallocate(h % sxm)
    deallocate(h % sxp)
    deallocate(h % sym)
    deallocate(h % syp)
    deallocate(h % szm)
    deallocate(h % szp)

    deallocate(h % qm)
    deallocate(h % qp)

    deallocate(h % qint)
    deallocate(h % shk)

    deallocate(h % div)
    deallocate(h % pdivu)

    deallocate(h % q1)
    deallocate(h % q2)
    deallocate(h % q3)

  end subroutine deallocate_ht

end module advection_util_module
