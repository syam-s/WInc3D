!==========================================================
! Subroutines for computing the SFS from the ABL
!==========================================================
subroutine wall_shear_stress(ux,uy,uz,tauwallxy,tauwallzy,wallfluxx,wallfluxy,wallfluxz)

USE param
USE variables
USE decomp_2d
USE MPI

implicit none
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: ux,uy,uz
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: uxf,uyf,uzf
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: wallfluxx,wallfluxy,wallfluxz
!real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: tauwallxy1, tauwallzy1 
real(mytype),dimension(xsize(1),xsize(3)) :: tauwallxy, tauwallzy 
!real(mytype),dimension(ysize(1),ysize(2),ysize(3)) :: tauwallxy2, tauwallzy2 
!real(mytype),dimension(zsize(1),zsize(2),zsize(3)) :: tauwallxy3, tauwallzy3
real(mytype),dimension(xsize(1),xsize(2),xsize(3)) :: gxy1,gyx1,gyz1,gzy1,di1
real(mytype),dimension(ysize(1),ysize(2),ysize(3)) :: gxy2,gzy2,gyz2,di2
real(mytype),dimension(zsize(1),zsize(2),zsize(3)) :: gyz3,di3
integer :: i,j,k,code
real(mytype) :: ut,ut1,utt,ut11, abl_vel, ABLtaux, ABLtauz, delta
real(mytype) :: ux_HAve_local, uz_HAve_local,S_HAve_local
real(mytype) :: ux_HAve, uz_HAve,S_HAve



call filter()

! Filter the velocity with twice the grid scale according to Bou-zeid et al 2005
call filx(uxf,ux,di1,sx,vx,fiffx,fifx,ficx,fibx,fibbx,filax,&
fiz1x,fiz2x,xsize(1),xsize(2),xsize(3),0)
call filx(uzf,uz,di1,sx,vx,fiffx,fifx,ficx,fibx,fibbx,filax,&
fiz1x,fiz2x,xsize(1),xsize(2),xsize(3),0)


! Determine the shear stress using Moeng's formulation
!*****************************************************************************************
    ux_HAve_local=0.
    uz_HAve_local=0.
    S_HAve_local=0.
    
    if (xstart(2)==1) then
    
    do k=1,xsize(3)
    do i=1,xsize(1)
        ux_HAve_local=ux_HAve_local+0.5*(uxf(i,1,k)+uxf(i,2,k))
        uz_HAve_local=uz_HAve_local+0.5*(uzf(i,1,k)+uzf(i,2,k))
        !S_HAve_local=S_HAve_local+sqrt((0.5*(uxf(i,1,k)+uxf(i,2,k)))**2.+ (0.5*(uz(i,1,k)+uz(i,2,k)))**2.) 
    enddo
    enddo
    
    ux_HAve_local=ux_HAve_local/xsize(3)/xsize(1)
    uz_HAve_local=uz_HAve_local/xsize(3)/xsize(1)
    !S_HAve_local= S_HAve_local/xsize(3)/xsize(1)
   
    else 
    
    ux_HAve_local=0.  
    uz_HAve_local=0.
    S_HAve_local =0.
   
    endif
    
    call MPI_ALLREDUCE(ux_HAve_local,ux_HAve,1,real_type,MPI_SUM,MPI_COMM_WORLD,code)
    call MPI_ALLREDUCE(uz_HAve_local,uz_HAve,1,real_type,MPI_SUM,MPI_COMM_WORLD,code)
    !call MPI_ALLREDUCE(S_HAve_local,S_HAve,1,real_type,MPI_SUM,MPI_COMM_WORLD,code)
    
    ux_HAve=ux_HAve/p_col
    uz_HAve=uz_HAve/p_col
     !S_HAve= S_HAve/p_col
   
    if (istret.ne.0) delta=(yp(2)-yp(1))/2.0
    if (istret.eq.0) delta=dy/2.0   
    
    ! Compute the friction velocity u_shear
    u_shear=k_roughness*sqrt(ux_HAve**2.+uz_HAve**2.)/log(delta/z_zero)
    if (nrank==0) write(*,*) "Horizontally-averaged velocity at y=1/2... ", ux_HAve,0,uz_Have
    if (nrank==0) write(*,*) "Friction velocity ... ", u_shear 
    !Compute the shear stresses -- only on the wall
    !u_shear=ustar
    wallfluxx = 0. 
    wallfluxy = 0.
    wallfluxz = 0.
    
    if (xstart(2)==1) then
    do k=1,xsize(3)
    do i=1,xsize(1)                        
    tauwallxy(i,k)=-u_shear**2.0*0.5*(uxf(i,1,k)+uxf(i,2,k))/sqrt(ux_HAve**2.+uz_HAve**2.)
    tauwallzy(i,k)=-u_shear**2.0*0.5*(uzf(i,1,k)+uzf(i,2,k))/sqrt(ux_HAve**2.+uz_Have**2.)
    wallfluxx(i,1,k) = 2.0*tauwallxy(i,k)/delta
    wallfluxy(i,1,k) = 0.
    wallfluxz(i,1,k) = 2.0*tauwallzy(i,k)/delta
    enddo
    enddo
     
    endif
!*********************************************************************************************************

if (nrank==0) write(*,*)  'Maximum wall shear stress for x and z', maxval(tauwallxy), maxval(tauwallzy)
if (nrank==0) write(*,*)  'Minimum wall shear stress for x and z', minval(tauwallxy), minval(tauwallzy)

return

! Computing the wall fluxes 
! Derivates for x 
!call derx (gyx1,tauwallxy1,di1,sx,ffxp,fsxp,fwxp,xsize(1),xsize(2),xsize(3),1)
!
!! Transpose X --> Y
!call transpose_x_to_y(tauwallxy1,tauwallxy2)
!call transpose_x_to_y(tauwallzy1,tauwallzy2)
!
!! Differentiate for y
!call dery (gxy2,tauwallxy2,di2,sy,ffyp,fsyp,fwyp,ppy,ysize(1),ysize(2),ysize(3),1)
!call dery (gzy2,tauwallzy2,di2,sy,ffyp,fsyp,fwyp,ppy,ysize(1),ysize(2),ysize(3),1)
!
!! Transpose Y --> Z
!call transpose_y_to_z(tauwallzy2,tauwallzy3)
!
!! Differentiate for z
!call derz(gyz3,tauwallzy3,di3,sz,ffzp,fszp,fwzp,zsize(1),zsize(2),zsize(3),1)
!
!!Transpose Z --> Y
!call transpose_z_to_y(gyz3,gyz2)
!
!! Transpose Y --> X
!call transpose_y_to_x(gyz2,gyz1)
!call transpose_y_to_x(gxy2,gxy1)
!call transpose_y_to_x(gzy2,gzy1)
!
!wallfluxx(:,:,:) = tauwallxy1(:,:,:)/delta!-gxy1(:,:,:)
!wallfluxy(:,:,:) = 0.!-(gyx1(:,:,:)+gyz1(:,:,:))
!wallfluxz(:,:,:) = tauwallzy1(:,:,:)/delta!-gzy1(:,:,:)


!if (nrank==0) write(*,*)  'Maximum wallflux for x, y and z', maxval(wallfluxx), maxval(wallfluxy), maxval(wallfluxz)
!if (nrank==0) write(*,*)  'Minimum wallflux for x, y and z', minval(wallfluxx), minval(wallfluxy), minval(wallfluxz)
!return
end subroutine wall_shear_stress
