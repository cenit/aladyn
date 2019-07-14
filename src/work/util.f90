!*****************************************************************************************************!
!                            Copyright 2008-2018  The ALaDyn Collaboration                            !
!*****************************************************************************************************!

!*****************************************************************************************************!
!  This file is part of ALaDyn.                                                                       !
!                                                                                                     !
!  ALaDyn is free software: you can redistribute it and/or modify                                     !
!  it under the terms of the GNU General Public License as published by                               !
!  the Free Software Foundation, either version 3 of the License, or                                  !
!  (at your option) any later version.                                                                !
!                                                                                                     !
!  ALaDyn is distributed in the hope that it will be useful,                                          !
!  but WITHOUT ANY WARRANTY; without even the implied warranty of                                     !
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                                      !
!  GNU General Public License for more details.                                                       !
!                                                                                                     !
!  You should have received a copy of the GNU General Public License                                  !
!  along with ALaDyn.  If not, see <http://www.gnu.org/licenses/>.                                    !
!*****************************************************************************************************!

 module util

  use precision_def
  use code_util

  implicit none

!--------------------------
 contains

!--------------------------
  subroutine ran_number(idum, ran2)
   integer, intent (inout) :: idum
   real (dp), intent (out) :: ran2

   integer, parameter :: im1 = 2147483563, im2 = 2147483399, &
     ia1 = 40014, ia2 = 40692, iq1 = 53668, iq2 = 52774, ir1 = 12211, &
     ir2 = 3791, ntab = 32, imm1 = im1 - 1, ndiv = 1 + int(imm1/ntab)
   real (dp), parameter :: am = 1.0/im1, eps = 1.2e-07, rnmx = 1.0 - eps
   integer :: j, k
   integer, save :: iv(32) = 0, iy = 0, idum2 = 123456789

   if (idum<=0) then
    idum = max(-idum, 1)
    idum2 = idum
    do j = ntab + 8, 1, -1
     k = idum/iq1
     idum = ia1*(idum-k*iq1) - k*ir1
     if (idum<0) idum = idum + im1
     if (j<=ntab) iv(j) = idum
    end do
    iy = iv(1)
   end if
   k = idum/iq1
   idum = ia1*(idum-k*iq1) - k*ir1
   if (idum<0) idum = idum + im1
   k = idum2/iq2
   idum2 = ia2*(idum2-k*iq2) - k*ir2
   if (idum2<0) idum2 = idum2 + im2
   j = 1 + iy/ndiv
   iy = iv(j) - idum2
   iv(j) = idum
   if (iy<1) iy = iy + imm1
   ran2 = min(am*iy, rnmx)
  end subroutine

!--------------------------

  subroutine init_random_seed(myrank)
   integer, intent (in) :: myrank
   integer, allocatable :: seed(:)
   integer :: i, n, un, istat, dt(8), pid, t(2), s
   integer (8) :: count, tms

   i = 0
   call random_seed(size=n)
   allocate (seed(n))

   if (.not. l_disable_rng_seed) then
    un = 123
! First try if the OS provides a random number generator
    open (unit=un, file='/dev/urandom', access='stream', &
      form='unformatted', action='read', status='old', iostat=istat)
    if (istat==0) then
     read (un) seed
     close (un)
    else
! Fallback to XOR:ing the current time and pid. The PID is
! useful in case one launches multiple instances of the same
! program in parallel.
     call system_clock(count)
     if (count/=0) then
      t = transfer(count, t)
     else
      call date_and_time(values=dt)
      tms = (dt(1)-1970)*365_8*24*60*60*1000 + dt(2)*31_8*24*60*60*1000 &
        + dt(3)*24*60*60*60*1000 + dt(5)*60*60*1000 + dt(6)*60*1000 + &
        dt(7)*1000 + dt(8)
      t = transfer(tms, t)
     end if
     s = ieor(t(1), t(2))
     pid = myrank + 1099279 ! Add a prime
     s = ieor(s, pid)
     if (n>=3) then
      seed(1) = t(1) + 36269
      seed(2) = t(2) + 72551
      seed(3) = pid
      if (n>3) then
       seed(4:) = s + 37* [ (i,i=0,n-4) ]
      end if
     else
      seed = s + 37* [ (i,i=0,n-1) ]
     end if
    end if
   else
    seed = myrank
   end if
   call random_seed(put=seed)
  end subroutine
!--------------------------

  subroutine gasdev(dev)

   real (dp), intent (out) :: dev
   real (dp) :: v1, v2, rsq
   real (dp), save :: g
   logical, save :: gaus_store = .false.

   if (gaus_store) then
    dev = g
    gaus_store = .false.
   else
    do
     call random_number(v1)
     call random_number(v2)
     v1 = 2.0*v1 - 1.0
     v2 = 2.0*v2 - 1.0
     rsq = v1*v1 + v2*v2
     if (rsq<1.0) exit
    end do
    rsq = sqrt(-2.0*log(rsq)/rsq)
    dev = v1*rsq
    g = v2*rsq
    gaus_store = .true.
   end if
  end subroutine

!--------------------------

  subroutine set_x2_distrib(xb, nxb)
   integer, intent (in) :: nxb
   real (dp), intent (out) :: xb(:)
   real (dp) :: th, uu, du
   integer :: i

   du = 1./real(nxb, dp)
   do i = 1, nxb
    uu = 1. - 2*du*(real(i,dp)-0.5)
    th = acos(uu)/3.
    xb(i) = sqrt(3.)*sin(th) - cos(th)
   end do
  end subroutine

!--------------------------

  subroutine set_pden(xp, x0, nx0, rat, id, isp)
   integer, intent (in) :: nx0(:), id, isp
   real (dp), intent (in) :: rat, x0(:)
   real (dp), intent (out) :: xp(:, :)
   integer :: i, i1
   real (dp) :: xx, delt1, delt2, delt3, delt4, alp

   select case (id)
   case (0)
    delt1 = 1./real(nx0(1), dp)
    delt2 = 1./real(nx0(2), dp)
    do i = 1, nx0(1)
     xp(i, isp) = x0(1)*sqrt(delt1*(real(i,dp)))
    end do
    xx = xp(nx0(1), isp)
    do i = 1, nx0(2)
     i1 = i + nx0(1)
     xp(i1, isp) = xx + x0(2)*delt2*(real(i,dp))
    end do

   case (1)
    delt1 = 1./real(nx0(1), dp)
    delt2 = 1./real(nx0(2), dp)
    delt3 = 1./real(nx0(3), dp)
    do i = 1, nx0(1)
     xp(i, isp) = x0(1)*sqrt(delt1*(real(i,dp)-0.5))
    end do
    do i = 1, nx0(2)
     i1 = i + nx0(1)
     xp(i1, isp) = x0(1) + x0(2)*delt2*(real(i,dp)-0.5)
    end do
    i1 = nx0(1) + nx0(2)
    do i = 1, nx0(3)
     xp(i+i1, isp) = xp(i1, isp) + x0(3)*(1.-sqrt(1.-delt3*(real(i,dp)- &
       0.5)))
    end do

   case (2)
    delt1 = 1./real(nx0(1), dp)
    delt2 = 1./real(nx0(2), dp)
    delt3 = 1./real(nx0(3), dp)
    delt4 = 1./real(nx0(4), dp)
    alp = 1. - rat*rat
    do i = 1, nx0(1)
     xp(i, isp) = x0(1)*sqrt(delt1*(real(i,dp)))
    end do
    do i = 1, nx0(2)
     i1 = i + nx0(1)
     xp(i1, isp) = xp(nx0(1), isp) + x0(2)*delt2*(real(i,dp))
    end do
    i1 = nx0(1) + nx0(2)
    do i = 1, nx0(3)
     xp(i+i1, isp) = xp(i1, isp) + x0(3)*(1.-sqrt(delt3*(real(nx0(3)-i, &
       dp))))
    end do
    i1 = i1 + nx0(3)
    do i = 1, nx0(4)
     xp(i+i1, isp) = xp(i1, isp) + x0(4)*delt4*real(i, dp)
    end do

   case (3)
    delt1 = 1./real(nx0(1), dp)
    delt2 = 1./real(nx0(2), dp)
    do i = 1, nx0(1)
     xp(i, isp) = x0(1)*(delt1*(real(i,dp)))**(0.2)
    end do
    do i = 1, nx0(2)
     i1 = i + nx0(1)
     xp(i1, isp) = xp(nx0(1), isp) + x0(2)*delt2*(real(i,dp))
    end do
   end select
  end subroutine

!--------------------------

  subroutine ludcmp(am, n)
   integer, intent (in) :: n
   real (dp), intent (inout) :: am(n, n)
   real (dp), parameter :: epsa = 1.e-06
   integer :: j, i, k, kk0
   real (dp) :: suma, dum

   do j = 1, n
    if (j>1) then
     do i = 1, j - 1
      suma = am(i, j)
      if (i>1) then
       kk0 = max(1, i-2)
       do k = kk0, i - 1
        suma = suma - am(i, k)*am(k, j)
       end do
       am(i, j) = suma
      end if
     end do
    end if
    do i = j, n
     suma = am(i, j)
     if (j>1) then
      kk0 = max(1, j-2)
      do k = kk0, j - 1
       suma = suma - am(i, k)*am(k, j)
      end do
      am(i, j) = suma
     end if
    end do
    if (j<n) then
     dum = 1./(am(j,j)+epsa)
     do i = j + 1, n
      am(i, j) = am(i, j)*dum
     end do
    end if
   end do
   do j = 1, n
    am(j, j) = 1./(am(j,j)+epsa)
   end do

  end subroutine

!--------------------------

  subroutine trid0(a, b, c, u, n)

   integer, intent (in) :: n
   real (dp), intent (in) :: a(n), b(n), c(n)
   real (dp), intent (inout) :: u(n)
   real (dp) :: g(n), bet
   integer :: k

   if (n==1) return

   g(1) = 0.0
   bet = b(1)
   u(1) = u(1)/bet
   do k = 2, n
    g(k) = c(k-1)/bet
    bet = b(k) - a(k)*g(k)
    u(k) = (u(k)-a(k)*u(k-1))/bet
   end do
   do k = n - 1, 1, -1
    u(k) = u(k) - g(k+1)*u(k+1)
   end do
  end subroutine

!--------------------------

  subroutine cycl0(a, b, c, x, n)

   integer, intent (in) :: n
   real (dp), intent (in) :: a(n), b(n), c(n)
   real (dp), intent (inout) :: x(n)
   real (dp) :: bb(n), u(n), gm, alp, bet, fact

   alp = c(n)
   bet = a(1)

   gm = -b(1)
   bb(1) = b(1) - gm
   bb(n) = b(n) - alp*bet/gm
   bb(2:n-1) = b(2:n-1)
   call trid0(a, bb, c, x, n)
   u(1) = gm
   u(n) = alp
   u(2:n-1) = 0.0
   call trid0(a, bb, c, u, n)
   fact = (x(1)+bet*x(n)/gm)/(1.+u(1)+bet*u(n)/gm)
   x(1:n) = x(1:n) - fact*u(1:n)

  end subroutine

  subroutine k_fact(k, kfatt)
   integer, intent (in) :: k
   real (dp), intent (out) :: kfatt
   integer :: ck

   kfatt = k
   if (k<2) return
   do ck = k - 1, 2, -1
    kfatt = kfatt*ck
   end do
  end subroutine

!--------------------------

  subroutine sort(part, np)

   real (dp), intent (inout) :: part(:)
   integer, intent (in) :: np
   integer :: ir, i, j, k, l, jstack
   integer, parameter :: m = 7, nstack = 50
   real (dp) :: a
   integer :: istack(nstack)

   jstack = 0
   ir = np
   l = 1
   do
    if (ir-l<m) then
     do j = l + 1, ir
      a = part(j)
      do i = j - 1, l, -1
       if (part(i)<=a) exit
       part(i+1) = part(i)
      end do
      part(i+1) = a
     end do
     if (jstack==0) return
     ir = istack(jstack)
     l = istack(jstack-1)
     jstack = jstack - 2
    else
     k = (l+ir)/2
     call swap(k, l+1)

     if (part(l)>part(ir)) call swap(l, ir)
     if (part(l+1)>part(ir)) call swap(l+1, ir)
     if (part(l)>part(l+1)) call swap(l, l+1)

     i = l + 1
     j = ir
     a = part(l+1)
     do
      do
       i = i + 1
       if (part(i)>=a) exit
      end do
      do
       j = j - 1
       if (part(j)<=a) exit
      end do
      if (j<i) exit
      call swap(i, j)
     end do
     part(l+1) = part(j)
     part(j) = a
     jstack = jstack + 2
     if (jstack>nstack) exit
     if (ir-i+1>=j-l) then
      istack(jstack) = ir
      istack(jstack-1) = i
      ir = j - 1
     else
      istack(jstack) = j - 1
      istack(jstack-1) = l
      l = i
     end if
    end if
   end do

  contains

   subroutine swap(i1, i2)
    integer, intent (in) :: i1, i2
    real (dp) :: temp

    temp = part(i1)
    part(i1) = part(i2)
    part(i2) = temp

   end subroutine

  end subroutine

!--------------------------

  subroutine vsort(part, np, ndv, dir)

   real (dp), intent (inout) :: part(:, :)
   integer, intent (in) :: np, ndv, dir
   integer :: ir, i, j, k, l, jstack
   integer, parameter :: m = 7, nstack = 50
   real (dp) :: a(ndv), temp(ndv)
   integer :: istack(nstack)

   jstack = 0
   ir = np
   l = 1
   do
    if (ir-l<m) then
     do j = l + 1, ir
      a(1:ndv) = part(1:ndv, j)
      do i = j - 1, l, -1
       if (part(dir,i)<=a(dir)) exit
       part(1:ndv, i+1) = part(1:ndv, i)
      end do
      part(1:ndv, i+1) = a(1:ndv)
     end do
     if (jstack==0) return
     ir = istack(jstack)
     l = istack(jstack-1)
     jstack = jstack - 2
    else
     k = (l+ir)/2
     call swap(k, l+1, ndv)

     if (part(dir,l)>part(dir,ir)) call swap(l, ir, ndv)
     if (part(dir,l+1)>part(dir,ir)) call swap(l+1, ir, ndv)
     if (part(dir,l)>part(dir,l+1)) call swap(l, l+1, ndv)

     i = l + 1
     j = ir
     a(1:ndv) = part(1:ndv, l+1)
     do
      do
       i = i + 1
       if (part(dir,i)>=a(dir)) exit
      end do
      do
       j = j - 1
       if (part(dir,j)<=a(dir)) exit
      end do
      if (j<i) exit
      call swap(i, j, ndv)
     end do
     part(1:ndv, l+1) = part(1:ndv, j)
     part(1:ndv, j) = a(1:ndv)
     jstack = jstack + 2
     if (jstack>nstack) exit
     if (ir-i+1>=j-l) then
      istack(jstack) = ir
      istack(jstack-1) = i
      ir = j - 1
     else
      istack(jstack) = j - 1
      istack(jstack-1) = l
      l = i
     end if
    end if
   end do

  contains

   subroutine swap(i1, i2, nd)
    integer, intent (in) :: i1, i2, nd

    temp(1:nd) = part(1:nd, i1)
    part(1:nd, i1) = part(1:nd, i2)
    part(1:nd, i2) = temp(1:nd)

   end subroutine

  end subroutine

!--------------------------
  subroutine bunch_gen(ndm, n1, n2, sx, sy, sz, gm, ey, ez, cut, dg, &
    bunch)
   integer, intent (in) :: ndm, n1, n2
   real (dp), intent (in) :: sx, sy, sz, gm, ey, ez, cut, dg
   real (dp), intent (inout) :: bunch(:, :)
   integer :: i, j, np
   real (dp) :: sigs(6)
   real (dp) :: xm, ym, zm, pxm, pym, pzm
   real (dp) :: v1, v2, rnd, a

!============= ey,ez are emittances (in mm-microns)
! FIX emittances are ALWAYS a dimension times an angle...
! so this (in mm-micron) doesn't make any sense
! dg=d(gamma)/gamma (%)
! dp_y=ey/s_y dp_z=ez/s_z dp_x=d(gamma)
!=============================================

!Distribute (x,y,z,px,py,pz) centered on 0; px=> px+gamma

   select case (ndm)
   case (2)
    sigs(1) = sx
    sigs(2) = sy
    sigs(3) = sqrt(3.0)*0.01*dg*gm !dpz
    sigs(4) = ey/sy
    do i = n1, n2
     j = 2
     do
      call random_number(v1)
      call random_number(v2)
      v1 = 2.0*v1 - 1.0
      v2 = 2.0*v2 - 1.0
      rnd = v1*v1 + v2*v2
      if (rnd<1.0) exit
     end do
     rnd = sqrt(-2.0*log(rnd)/rnd)
     bunch(j, i) = v1*rnd
     bunch(j+2, i) = v2*rnd
     j = 1
     call gasdev(rnd)
     bunch(j, i) = rnd
     j = 3
     do
      call random_number(rnd)
      rnd = 2.*rnd - 1.
      a = cut*rnd
      if (a*a<1.) exit
     end do
     bunch(j, i) = a
    end do
    do i = n1, n2
     do j = 1, 4
      bunch(j, i) = sigs(j)*bunch(j, i)
     end do
    end do
    bunch(3, n1:n2) = bunch(3, n1:n2) + gm
    xm = 0.0
    ym = 0.0
    pxm = 0.0
    pym = 0.0
! Reset centering
    do i = n1, n2
     xm = xm + bunch(1, i)
     ym = ym + bunch(2, i)
     pxm = pxm + bunch(3, i)
     pym = pym + bunch(4, i)
    end do
    np = n2 + 1 - n1
    xm = xm/real(np, dp)
    ym = ym/real(np, dp)
    pxm = pxm/real(np, dp)
    pym = pym/real(np, dp)
    do i = n1, n2
     bunch(1, i) = bunch(1, i) - xm
     bunch(2, i) = bunch(2, i) - ym
     bunch(3, i) = bunch(3, i) - (pxm-gm)
     bunch(4, i) = bunch(4, i) - pym
    end do
   case (3)
    sigs(1) = sx
    sigs(2) = sy
    sigs(3) = sz
    sigs(4) = sqrt(3.0)*0.01*dg*gm !dpz
    sigs(5) = ey/sy
    sigs(6) = ez/sz
    do i = n1, n2
     do j = 2, 5, 3
      do
       call random_number(v1)
       call random_number(v2)
       v1 = 2.0*v1 - 1.0
       v2 = 2.0*v2 - 1.0
       rnd = v1*v1 + v2*v2
       if (rnd<1.0) exit
      end do
      rnd = sqrt(-2.0*log(rnd)/rnd)
      bunch(j, i) = v1*rnd
      bunch(j+1, i) = v2*rnd
     end do
     j = 1
     call gasdev(rnd)
     bunch(j, i) = rnd
     j = 4
     do
      call random_number(rnd)
      rnd = 2.*rnd - 1.
      a = cut*rnd
      if (a*a<1.) exit
     end do
     bunch(j, i) = a
    end do
    do i = n1, n2
     do j = 1, 6
      bunch(j, i) = sigs(j)*bunch(j, i)
     end do
    end do
    bunch(4, n1:n2) = bunch(4, n1:n2) + gm

    xm = 0.0
    ym = 0.0
    zm = 0.0
    pxm = 0.0
    pym = 0.0
    pzm = 0.0

! Reset centering
    do i = n1, n2
     xm = xm + bunch(1, i)
     ym = ym + bunch(2, i)
     zm = zm + bunch(3, i)
     pxm = pxm + bunch(4, i)
     pym = pym + bunch(5, i)
     pzm = pzm + bunch(6, i)
    end do
    np = n2 + 1 - n1
    xm = xm/real(np, dp)
    ym = ym/real(np, dp)
    zm = zm/real(np, dp)
    pxm = pxm/real(np, dp)
    pym = pym/real(np, dp)
    pzm = pzm/real(np, dp)
    do i = n1, n2
     bunch(1, i) = bunch(1, i) - xm
     bunch(2, i) = bunch(2, i) - ym
     bunch(3, i) = bunch(3, i) - zm
     bunch(4, i) = bunch(4, i) - (pxm-gm)
     bunch(5, i) = bunch(5, i) - pym
     bunch(6, i) = bunch(6, i) - pzm
    end do
   end select
  end subroutine

  subroutine pbunch_gen(stp, n1, n2, lx, sy, sz, ey, ez, betx, bunch)
   integer, intent (in) :: stp, n1, n2
   real (dp), intent (in) :: lx, sy, sz, ey, ez, betx
   real (dp), intent (inout) :: bunch(:, :)
   integer :: i, j, np
   real (dp) :: sigs(6)
   real (dp) :: ym, zm, pzm, pym
   real (dp) :: v1, v2, rnd

!Distribute (z,y,pz,py) centered on 0;
!Distribute (x,px) uniformly

   np = n2 + 1 - n1
   sigs(1) = lx/real(np, dp) !x-distrution
   sigs(2) = sy
   sigs(3) = sz
   sigs(4) = 0.0 !dpz
   sigs(5) = betx*ey/sy
   sigs(6) = betx*ez/sz
! =====================
   do i = n1, n2
    bunch(1, i) = sigs(1)*real(i-1, dp)
    bunch(4, i) = betx
   end do
!======================= transverse (py,pz) iand (sy,sz) are gaussian
   select case (stp)
   case (1) !Gaussian distributions
    do i = n1, n2
     do j = 2, 5, 3
      do
       call random_number(v1)
       call random_number(v2)
       v1 = 2.0*v1 - 1.0
       v2 = 2.0*v2 - 1.0
       rnd = v1*v1 + v2*v2
       if (rnd<1.0) exit
      end do
      rnd = sqrt(-2.0*log(rnd)/rnd)
      bunch(j, i) = v1*rnd
      bunch(j+1, i) = v2*rnd
     end do
    end do
   case (2)
    do i = n1, n2
     do j = 2, 5, 3
      do
       call random_number(v1)
       call random_number(v2)
       v1 = 2.0*v1 - 1.0
       v2 = 2.0*v2 - 1.0
       rnd = v1*v1 + v2*v2
       if (rnd<1.) exit
      end do
      bunch(j, i) = v1
      bunch(j+1, i) = v2
     end do
    end do
   end select
   do i = n1, n2
    do j = 2, 5, 3
     bunch(j, i) = sigs(j)*bunch(j, i)
     bunch(j+1, i) = sigs(j+1)*bunch(j+1, i)
    end do
   end do

   ym = 0.0
   zm = 0.0
   pym = 0.0
   pzm = 0.0

! Reset centering
   do i = n1, n2
    ym = ym + bunch(2, i)
    zm = zm + bunch(3, i)
    pym = pym + bunch(5, i)
    pzm = pzm + bunch(6, i)
   end do
!==================== uniform x distribution dx=Lx/np
   ym = ym/real(np, dp)
   zm = zm/real(np, dp)
   pym = pym/real(np, dp)
   pzm = pzm/real(np, dp)

   do i = n1, n2
    bunch(2, i) = bunch(2, i) - ym
    bunch(3, i) = bunch(3, i) - zm
    bunch(5, i) = bunch(5, i) - pym
    bunch(6, i) = bunch(6, i) - pzm
   end do
  end subroutine

  subroutine boxmuller_vector(randnormal, len)
   integer, intent (in) :: len
   real (dp), intent (inout) :: randnormal(len)
   real (dp) :: x, y, s, r
   real (dp) :: mu, std
   integer :: i

   do i = 1, len
    s = 10.
    do while (s>=1.)
     call random_number(x)
     call random_number(y)
     x = 2.*x - 1.
     y = 2.*y - 1.
     s = x**2 + y**2
    end do
    r = sqrt(-2.*log(s)/s)
    randnormal(i) = x*r
   end do
!--- convergence to N(0,1) ---!
   mu = sum(randnormal)/(1.*len-1.)
   std = sqrt(sum((randnormal-mu)**2)/(1.*len-1.))
   randnormal = (randnormal-mu)/std
  end subroutine

!Box-Muller with cut in the distribution
  subroutine boxmuller_vector_cut(randnormal, len, cut)
   integer, intent (in) :: len
   real (8), intent (inout) :: randnormal(len)
   real (8), intent (in) :: cut
   real (8) :: x, y, s, r
   integer :: i

   do i = 1, len
100 continue !if the particle is cut :: recalculate particle position
    s = 10.
    do while (s>=1.)
     call random_number(x)
     call random_number(y)
     x = 2.*x - 1.
     y = 2.*y - 1.
     s = x**2 + y**2
    end do
    r = sqrt(-2.*log(s)/s)
    randnormal(i) = x*r
    if (abs(randnormal(i))>cut) go to 100
   end do
   randnormal = randnormal - sum(randnormal)/(1.*max(1,size(randnormal)) &
     )
  end subroutine
!=======================================
  subroutine bunch_twissrotation(n1, n2, generated_bunch, alpha_y_t, &
    beta_y_t, alpha_z_t, beta_z_t, s_y, s_z, eps_y, eps_z, x_cm, y_cm, &
    z_cm)
   integer, intent (in) :: n1, n2
   real (dp), intent (inout) :: generated_bunch(:, :)
   real (dp), intent (in) :: alpha_y_t, beta_y_t, alpha_z_t, beta_z_t
   real (dp), intent (in) :: s_y, s_z, eps_y, eps_z, x_cm, y_cm, z_cm
   integer :: i
   real (dp) :: ay11, ay12, az11, az12

!twiss-rotation-matrix
   ay11 = sqrt(eps_y*beta_y_t/(eps_y**2+s_y**2*alpha_y_t**2))
   az11 = sqrt(eps_z*beta_z_t/(eps_z**2+s_z**2*alpha_z_t**2))
   ay12 = -ay11*alpha_y_t*s_y**2/eps_y
   az12 = -az11*alpha_z_t*s_z**2/eps_z

!twiss-rotation
   do i = n1, n2
    generated_bunch(2, i) = generated_bunch(2, i) - y_cm
    generated_bunch(2, i) = ay11*generated_bunch(2, i) + &
      ay12*generated_bunch(5, i) + y_cm
    generated_bunch(3, i) = generated_bunch(3, i) - z_cm
    generated_bunch(3, i) = az11*generated_bunch(3, i) + &
      az12*generated_bunch(6, i) + z_cm
    generated_bunch(5, i) = generated_bunch(5, i)/ay11
    generated_bunch(6, i) = generated_bunch(6, i)/az11
   end do
  end subroutine

!=====================
 end module
!=====================
