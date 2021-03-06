module cuda_interfaces_module

  implicit none

contains

  attributes(global) &
  subroutine cuda_enforce_consistent_e(lo,hi,state,s_lo,s_hi)

    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR
    use castro_util_module, only: enforce_consistent_e

    implicit none

    integer, intent(in)     :: lo(3), hi(3)
    integer, intent(in)     :: s_lo(3), s_hi(3)
    real(rt), intent(inout) :: state(s_lo(1):s_hi(1),s_lo(2):s_hi(2),s_lo(3):s_hi(3),NVAR)

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call enforce_consistent_e(idx, idx, state, s_lo, s_hi)

  end subroutine cuda_enforce_consistent_e



  attributes(global) &
  subroutine cuda_enforce_minimum_density(uin, uin_lo, uin_hi, &
                                          uout, uout_lo, uout_hi, &
                                          vol, vol_lo, vol_hi, &
                                          lo, hi, frac_change, verbose)

    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR
    use advection_util_module, only: enforce_minimum_density

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3)
    integer,  intent(in   ) :: uin_lo(3), uin_hi(3)
    integer,  intent(in   ) :: uout_lo(3), uout_hi(3)
    integer,  intent(in   ) :: vol_lo(3), vol_hi(3)
    real(rt), intent(in   ) :: uin(uin_lo(1):uin_hi(1),uin_lo(2):uin_hi(2),uin_lo(3):uin_hi(3),NVAR)
    real(rt), intent(inout) :: uout(uout_lo(1):uout_hi(1),uout_lo(2):uout_hi(2),uout_lo(3):uout_hi(3),NVAR)
    real(rt), intent(in   ) :: vol(vol_lo(1):vol_hi(1),vol_lo(2):vol_hi(2),vol_lo(3):vol_hi(3))
    real(rt), intent(inout) :: frac_change
    integer,  intent(in   ) :: verbose

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call enforce_minimum_density(uin, uin_lo, uin_hi, &
                                 uout, uout_lo, uout_hi, &
                                 vol, vol_lo, vol_hi, &
                                 idx, idx, frac_change, verbose)

  end subroutine cuda_enforce_minimum_density



  attributes(global) &
  subroutine cuda_normalize_species(u, u_lo, u_hi, lo, hi)

    use amrex_fort_module, only: rt => amrex_real
    use castro_util_module, only: normalize_species
    use meth_params_module, only: NVAR

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3)
    integer,  intent(in   ) :: u_lo(3), u_hi(3)
    real(rt), intent(inout) :: u(u_lo(1):u_hi(1),u_lo(2):u_hi(2),u_lo(3):u_hi(3),NVAR)

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call normalize_species(u, u_lo, u_hi, idx, idx)

  end subroutine cuda_normalize_species



  attributes(global) &
  subroutine cuda_ctoprim(lo, hi, &
                          uin, uin_lo, uin_hi, &
                          q,     q_lo,   q_hi, &
                          qaux, qa_lo,  qa_hi)

    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR, NQ, NQAUX
    use advection_util_module, only: ctoprim

    implicit none

    integer, intent(in   ) :: lo(3), hi(3)
    integer, intent(in   ) :: uin_lo(3), uin_hi(3)
    integer, intent(in   ) :: q_lo(3), q_hi(3)
    integer, intent(in   ) :: qa_lo(3), qa_hi(3)

    real(rt), intent(in   ) :: uin(uin_lo(1):uin_hi(1),uin_lo(2):uin_hi(2),uin_lo(3):uin_hi(3),NVAR)
    real(rt), intent(inout) :: q(q_lo(1):q_hi(1),q_lo(2):q_hi(2),q_lo(3):q_hi(3),NQ)
    real(rt), intent(inout) :: qaux(qa_lo(1):qa_hi(1),qa_lo(2):qa_hi(2),qa_lo(3):qa_hi(3),NQAUX)

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call ctoprim(idx, idx, &
                 uin, uin_lo, uin_hi, &
                 q,     q_lo,   q_hi, &
                 qaux, qa_lo,  qa_hi)

  end subroutine cuda_ctoprim



  attributes(global) &
  subroutine cuda_reset_internal_e(lo,hi,u,u_lo,u_hi,verbose)

    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR
    use castro_util_module, only: reset_internal_e

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3), verbose
    integer,  intent(in   ) :: u_lo(3), u_hi(3)
    real(rt), intent(inout) :: u(u_lo(1):u_hi(1),u_lo(2):u_hi(2),u_lo(3):u_hi(3),NVAR)

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call reset_internal_e(idx, idx, u, u_lo, u_hi, verbose)

  end subroutine cuda_reset_internal_e



  attributes(global) &
  subroutine cuda_dervel(vel,v_lo,v_hi,nv, &
                         dat,d_lo,d_hi,nc,lo,hi,domlo, &
                         domhi,delta,xlo,time,dt,bc,level,grid_no)

    use amrex_fort_module, only: rt => amrex_real
    use castro_util_module, only: dervel

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3)
    integer,  intent(in   ) :: v_lo(3), v_hi(3), nv
    integer,  intent(in   ) :: d_lo(3), d_hi(3), nc
    integer,  intent(in   ) :: domlo(3), domhi(3)
    integer,  intent(in   ) :: bc(3,2,nc)
    real(rt), intent(in   ) :: delta(3), xlo(3), time, dt
    real(rt), intent(inout) :: vel(v_lo(1):v_hi(1),v_lo(2):v_hi(2),v_lo(3):v_hi(3),nv)
    real(rt), intent(in   ) :: dat(d_lo(1):d_hi(1),d_lo(2):d_hi(2),d_lo(3):d_hi(3),nc)
    integer,  intent(in   ) :: level, grid_no

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call dervel(vel,v_lo,v_hi,nv, &
                dat,d_lo,d_hi,nc,idx,idx,domlo, &
                domhi,delta,xlo,time,dt,bc,level,grid_no)

  end subroutine cuda_dervel



  attributes(global) &
  subroutine cuda_derpres(p,p_lo,p_hi,ncomp_p, &
                          u,u_lo,u_hi,ncomp_u,lo,hi,domlo, &
                          domhi,dx,xlo,time,dt,bc,level,grid_no)

    use amrex_fort_module, only: rt => amrex_real
    use castro_util_module, only: derpres

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3)
    integer,  intent(in   ) :: p_lo(3), p_hi(3), ncomp_p
    integer,  intent(in   ) :: u_lo(3), u_hi(3), ncomp_u
    integer,  intent(in   ) :: domlo(3), domhi(3)
    real(rt), intent(inout) :: p(p_lo(1):p_hi(1),p_lo(2):p_hi(2),p_lo(3):p_hi(3),ncomp_p)
    real(rt), intent(in   ) :: u(u_lo(1):u_hi(1),u_lo(2):u_hi(2),u_lo(3):u_hi(3),ncomp_u)
    real(rt), intent(in   ) :: dx(3), xlo(3), time, dt
    integer,  intent(in   ) :: bc(3,2,ncomp_u), level, grid_no

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call derpres(p,p_lo,p_hi,ncomp_p, &
                 u,u_lo,u_hi,ncomp_u,idx,idx,domlo, &
                 domhi,dx,xlo,time,dt,bc,level,grid_no)

  end subroutine cuda_derpres



  attributes(global) &
  subroutine cuda_compute_temp(lo,hi,state,s_lo,s_hi)

    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR
    use castro_util_module, only: compute_temp

    implicit none

    integer , intent(in   ) :: lo(3),hi(3)
    integer , intent(in   ) :: s_lo(3),s_hi(3)
    real(rt), intent(inout) :: state(s_lo(1):s_hi(1),s_lo(2):s_hi(2),s_lo(3):s_hi(3),NVAR)

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call compute_temp(idx, idx, state, s_lo, s_hi)

  end subroutine cuda_compute_temp



  attributes(global) &
  subroutine cuda_estdt(lo,hi,u,u_lo,u_hi,dx,dt)

    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NVAR
    use timestep_module, only: estdt

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3)
    integer,  intent(in   ) :: u_lo(3), u_hi(3)
    real(rt), intent(in   ) :: u(u_lo(1):u_hi(1),u_lo(2):u_hi(2),u_lo(3):u_hi(3),NVAR)
    real(rt), intent(in   ) :: dx(3)
    real(rt), intent(inout) :: dt

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call estdt(idx,idx,u,u_lo,u_hi,dx,dt)

  end subroutine cuda_estdt


  attributes(global) &
  subroutine cuda_mol_single_stage(time, &
                                   lo, hi, domlo, domhi, &
                                   uin, uin_l1, uin_l2, uin_l3, uin_h1, uin_h2, uin_h3, &
                                   uout, uout_l1, uout_l2, uout_l3, uout_h1, uout_h2, uout_h3, &
                                   q, q_l1, q_l2, q_l3, q_h1, q_h2, q_h3, &
                                   qaux, qa_l1, qa_l2, qa_l3, qa_h1, qa_h2, qa_h3, &
                                   update, updt_l1, updt_l2, updt_l3, updt_h1, updt_h2, updt_h3, &
                                   dx, dt, h, &
                                   flux1, flux1_l1, flux1_l2, flux1_l3, flux1_h1, flux1_h2, flux1_h3, &
                                   flux2, flux2_l1, flux2_l2, flux2_l3, flux2_h1, flux2_h2, flux2_h3, &
                                   flux3, flux3_l1, flux3_l2, flux3_l3, flux3_h1, flux3_h2, flux3_h3, &
                                   area1, area1_l1, area1_l2, area1_l3, area1_h1, area1_h2, area1_h3, &
                                   area2, area2_l1, area2_l2, area2_l3, area2_h1, area2_h2, area2_h3, &
                                   area3, area3_l1, area3_l2, area3_l3, area3_h1, area3_h2, area3_h3, &
                                   vol, vol_l1, vol_l2, vol_l3, vol_h1, vol_h2, vol_h3, &
                                   courno, verbose)

    use amrex_fort_module, only: rt => amrex_real
    use meth_params_module, only: NQ, NQAUX, NVAR
    use mol_module, only: mol_single_stage
    use advection_util_module, only: ht

    implicit none

    integer,  intent(in   ) :: lo(3), hi(3), verbose
    integer,  intent(in   ) :: domlo(3), domhi(3)
    integer,  intent(in   ) :: uin_l1, uin_l2, uin_l3, uin_h1, uin_h2, uin_h3
    integer,  intent(in   ) :: uout_l1, uout_l2, uout_l3, uout_h1, uout_h2, uout_h3
    integer,  intent(in   ) :: q_l1, q_l2, q_l3, q_h1, q_h2, q_h3
    integer,  intent(in   ) :: qa_l1, qa_l2, qa_l3, qa_h1, qa_h2, qa_h3
    integer,  intent(in   ) :: updt_l1, updt_l2, updt_l3, updt_h1, updt_h2, updt_h3
    integer,  intent(in   ) :: flux1_l1, flux1_l2, flux1_l3, flux1_h1, flux1_h2, flux1_h3
    integer,  intent(in   ) :: flux2_l1, flux2_l2, flux2_l3, flux2_h1, flux2_h2, flux2_h3
    integer,  intent(in   ) :: flux3_l1, flux3_l2, flux3_l3, flux3_h1, flux3_h2, flux3_h3
    integer,  intent(in   ) :: area1_l1, area1_l2, area1_l3, area1_h1, area1_h2, area1_h3
    integer,  intent(in   ) :: area2_l1, area2_l2, area2_l3, area2_h1, area2_h2, area2_h3
    integer,  intent(in   ) :: area3_l1, area3_l2, area3_l3, area3_h1, area3_h2, area3_h3
    integer,  intent(in   ) :: vol_l1, vol_l2, vol_l3, vol_h1, vol_h2, vol_h3

    real(rt), intent(in   ) :: uin(uin_l1:uin_h1, uin_l2:uin_h2, uin_l3:uin_h3, NVAR)
    real(rt), intent(inout) :: uout(uout_l1:uout_h1, uout_l2:uout_h2, uout_l3:uout_h3, NVAR)
    real(rt), intent(inout) :: q(q_l1:q_h1, q_l2:q_h2, q_l3:q_h3, NQ)
    real(rt), intent(inout) :: qaux(qa_l1:qa_h1, qa_l2:qa_h2, qa_l3:qa_h3, NQAUX)
    real(rt), intent(inout) :: update(updt_l1:updt_h1, updt_l2:updt_h2, updt_l3:updt_h3, NVAR)
    real(rt), intent(inout) :: flux1(flux1_l1:flux1_h1, flux1_l2:flux1_h2, flux1_l3:flux1_h3, NVAR)
    real(rt), intent(inout) :: flux2(flux2_l1:flux2_h1, flux2_l2:flux2_h2, flux2_l3:flux2_h3, NVAR)
    real(rt), intent(inout) :: flux3(flux3_l1:flux3_h1, flux3_l2:flux3_h2, flux3_l3:flux3_h3, NVAR)
    real(rt), intent(in   ) :: area1(area1_l1:area1_h1, area1_l2:area1_h2, area1_l3:area1_h3)
    real(rt), intent(in   ) :: area2(area2_l1:area2_h1, area2_l2:area2_h2, area2_l3:area2_h3)
    real(rt), intent(in   ) :: area3(area3_l1:area3_h1, area3_l2:area3_h2, area3_l3:area3_h3)
    real(rt), intent(in   ) :: vol(vol_l1:vol_h1, vol_l2:vol_h2, vol_l3:vol_h3)
    real(rt), intent(in   ) :: dx(3), dt, time
    type(ht), intent(inout) :: h
    real(rt), intent(inout) :: courno

    integer :: idx(3)

    ! Get our spatial index based on the CUDA thread index

    idx(1) = lo(1) + (threadIdx%x - 1) + blockDim%x * (blockIdx%x - 1)
    idx(2) = lo(2) + (threadIdx%y - 1) + blockDim%y * (blockIdx%y - 1)
    idx(3) = lo(3) + (threadIdx%z - 1) + blockDim%z * (blockIdx%z - 1)

    if (idx(1) .gt. hi(1) .or. idx(2) .gt. hi(2) .or. idx(3) .gt. hi(3)) return

    call mol_single_stage(time, &
                          idx, idx, domlo, domhi, &
                          uin, uin_l1, uin_l2, uin_l3, uin_h1, uin_h2, uin_h3, &
                          uout, uout_l1, uout_l2, uout_l3, uout_h1, uout_h2, uout_h3, &
                          q, q_l1, q_l2, q_l3, q_h1, q_h2, q_h3, &
                          qaux, qa_l1, qa_l2, qa_l3, qa_h1, qa_h2, qa_h3, &
                          update, updt_l1, updt_l2, updt_l3, updt_h1, updt_h2, updt_h3, &
                          dx, dt, h, &
                          flux1, flux1_l1, flux1_l2, flux1_l3, flux1_h1, flux1_h2, flux1_h3, &
                          flux2, flux2_l1, flux2_l2, flux2_l3, flux2_h1, flux2_h2, flux2_h3, &
                          flux3, flux3_l1, flux3_l2, flux3_l3, flux3_h1, flux3_h2, flux3_h3, &
                          area1, area1_l1, area1_l2, area1_l3, area1_h1, area1_h2, area1_h3, &
                          area2, area2_l1, area2_l2, area2_l3, area2_h1, area2_h2, area2_h3, &
                          area3, area3_l1, area3_l2, area3_l3, area3_h1, area3_h2, area3_h3, &
                          vol, vol_l1, vol_l2, vol_l3, vol_h1, vol_h2, vol_h3, &
                          courno, verbose)
    
  end subroutine cuda_mol_single_stage

end module cuda_interfaces_module
