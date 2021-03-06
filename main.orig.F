C...As an example, consider a main program of the form
C...Double precision and integer declarations.
      IMPLICIT DOUBLE PRECISION(A-H, O-Z)
      IMPLICIT INTEGER(I-N)
#include "phydata1234.inc"

      INTEGER PYK,PYCHGE,PYCOMP
      REAL pyth_xsec,rccorr,sigobs,sigtrue
      DOUBLE PRECISION pbeam, px, py, pz

C...Input and output strings.
      CHARACTER*12 FRAME,BEAM,TARGET
      CHARACTER*100 PARAM
      LOGICAL UseLut,GenLut,lOK
      COMMON/PYSUBS/MSEL,MSELPD,MSUB(500),KFIN(2,-40:40),CKIN(200)
      COMMON/PYINT1/MINT(400),VINT(400)
      Save /PYSUBS/,/PYPARS/,/PYINT1/



	include "mc_set.inc"
	include "py6strf.inc"
	include "mcRadCor.inc"
	include "radgen.inc"
c
#include "pyhtlist.inc"
#include "options.inc"
c
       data v4el0 /0.0,0.0,0.0,0.0/
       data v4pr0 /0.0,0.0,0.0,0.93827/
c      
c ... force block data modules to be read
        external pydata

        px = 0.
        py = 0.
        pz = 0.

       Model=0
       qedrad=0
       UseLUT=.false.
       GenLUT=.false.
       emass=PYMASS(11)
       rccorr =1.
       call CL_OPTIONS          ! command line processing
c
       v4el0(3)=cl_beam_energy
       v4el0(4)=cl_beam_energy
c

C...Read parameters for PYINIT call (frame, beam particle, target particle,
C...energy).
       FRAME='FIXT'
       BEAM=cl_beam
       TARGET=cl_target
       PBEAM=cl_beam_energy
       PRINT *,'FRAME,BEAM,TARGET,PBEAM',FRAME,BEAM,TARGET,PBEAM
C...Read number of events to generate, and to print.
       READ(*,*) NEV,NPRT
       PRINT *,'NEV,NPRT',NEV,NPRT
C...Read parameters for PYTHIA-Model = which generation is done     
       READ(*,*) Model
C...Read parameters of radcorr: do radcorr swith also operated look-up table operation  
       READ(*,*) qedrad
C...Read min/max y of generation range      
       READ(*,*) mcSet_YMin,mcSet_YMax
C...Read min/max Q2 of generation range      
       READ(*,*) mcSet_Q2Min,mcSet_Q2Max
C...Read target type mass and charge
       READ(*,*) mcSet_TarA,mcSet_TarZ
C...Read information for cross section used in radgen
       READ(*,*) genSet_FStruct,genSet_R
C...Loop over reading and setting parameters/switches.
  100  READ(*,'(A)',END=200) PARAM
       CALL PYGIVE(PARAM)
       GOTO 100
C...Initialize PYTHIA.      
  200  write(*,*) 'NOW all parameters are read by PYTHIA'
C       call pylist(11)
c       call pylist(12)
       if (Model.eq.0) then
         UseLUT=.false.
         GenLUT=.false.
         qedrad=0
         MSTP(199)=0
       elseif (Model.eq.1) then
         if (qedrad.eq.1) then
           mcSet_EneBeam=real(pbeam)
           UseLUT=.true.
           MSTP(199)=1
           call radgen_init(UseLUT,GenLUT)
           write(*,*) 'I have initialized radgen'
         elseif (qedrad.eq.2) then
           write(*,*) 'radgen lookup table will be generated'
           mcSet_EneBeam=real(pbeam)
           UseLUT=.true.
           GenLUT=.true.
           MSTP(199)=1
           call radgen_init(UseLUT,GenLUT)
           goto 500
         elseif (qedrad.eq.0) then
           mcSet_EneBeam=real(pbeam)
           UseLUT=.false.
           GenLUT=.false.
           MSTP(199)=1
         endif
       endif 
       call pyinit ('FIXT',beam,target, pbeam)
c
c     read the random seed
c
c      dir='/group/gpd/claspith/'
      if(cl_rndm) then
         print *,'read random seed from','tmp/'//
     6cl_hispath(1:4)//cl_target(1:2)//'.txti'
         OPEN(unit=42,file='tmp/'//
     6cl_hispath(1:4)//cl_target(1:2)//'.txti',STATUS='OLD',
     6FORM='UNFORMATTED')
        call PYRSET(42,0)
        CLOSE(42)
      endif
c
      call INIT_PAW            ! init hbook

C...Event generation loop
       DO 300 IEV=1,NEV
         CALL PYEVNT
c         IF(IEV.LE.NPRT) CALL PYLIST(2)
C...Calculate the kinematics of the scattered lepton
        genpprim = sqrt(geneprim**2 - emass**2)
        px = genpprim*sin(genthe)*cos(genphi)
        py = genpprim*sin(genthe)*sin(genphi)
        pz = genpprim*cos(genthe)         

C Calculate all needed to get the info for cross sections and weights
        if(mod(iev,nprt).eq.0) print *, 'event #',iev,nev,(MINT(III),III=1,10)

        IF ((MSTP(199).eq.1).and.(qedrad.ne.0)) then

C P.L. Born cross section at observed kinematics
         call MKF2(dble(genq2),dble(genx),
     +           mcSet_TarA,mcSet_TarZ,py6f2,py6f1)
         IF(genSet_FStruct(1:4).EQ.'ALLM') THEN
          call MKR(dble(genq2),dble(genx),py6r)
          py6f1=(1.+genq2/gennu**2)/(2.*genx*(1.+py6r))*py6f2
         ENDIF
         sigobs=pyth_xsec(genx,genq2,py6f1,py6f2)
     +          *genx*genq2

C P.L. Born cross section at true kinematics
         call MKF2(dble(mcRadCor_Q2True),dble(mcRadCor_XTrue),
     +           mcSet_TarA,mcSet_TarZ,py6f2,py6f1)
          IF(genSet_FStruct(1:4).EQ.'ALLM') THEN
          call MKR(dble(mcRadCor_Q2True),dble(mcRadCor_XTrue),py6r)
          py6f1=(1.+mcRadCor_Q2True/mcRadCor_NuTrue**2)/
     +     (2.*mcRadCor_XTrue*(1.+py6r))*py6f2
          ENDIF
         sigtrue=pyth_xsec(mcRadCor_XTrue, mcRadCor_Q2True,py6f1, py6f2)
     +          *mcRadCor_XTrue*mcRadCor_Q2True

C P.L. Ratio of sigma_born(observed)/sigma_born(true)
          IF(mcRadCor_EBrems.eq.0) THEN
           IF (sig1g.gt.0.) then
            rccorr=(tbor+mcRadCor_TailIne)/sig1g/
     +     (MINT(199)+1)
           ELSE
            rccorr=0.
           ENDIF
          ELSEIF(mcRadCor_EBrems.gt.0) THEN
           IF ((sig1g.gt.0.).and.(sigtrue.gt.0.)) then
             rccorr=(tbor+mcRadCor_TailIne)/sig1g*
     +       sigobs/sigtrue/(MINT(199)+1)
           ELSE
            rccorr=0.
           ENDIF
          ENDIF

        ELSE

         call MKF2(dble(genq2),dble(genx),
     +           mcSet_TarA,mcSet_TarZ,py6f2,py6f1)
         IF(genSet_FStruct(1:4).EQ.'ALLM') THEN
          call MKR(dble(genq2),dble(genx),py6r)
          py6f1=(1.+genq2/gennu**2)/(2.*genx*(1.+py6r))*py6f2
         ENDIF

        ENDIF
C       write(*,*)"F1 =   ",py6f1, "F2 =   ",py6f2, 
C    +            "rccorr = ", rccorr
         call fillevent(lOK)
c
         if(lOK) then
             IEVNTUPLE= IEVNTUPLE+1
c            print *,'---y=',1.0-gelee/cl_beam_energy
            radq2=genq2
            radnu=genx
            gelex=geneprim
            geley=genthe
            gelez=genphi
            gelewgy=mcRadCor_Sigcor
            grade=mcRadCor_EBrems
            gradt=mcRadCor_ThetaBrems
            gradf=mcRadCor_PhiBrems
            radweight=mcRadCor_Redfac
            r_sigrad=mcRadCor_SigRad
            r_sigcor=mcRadCor_Sigcor
            if(mcRadCor_cType.eq.'elas') then 
             iproctpe=2
            else if (mcRadCor_cType.eq.'qela') then
             iproctpe=3
            else if (mcRadCor_cType.eq.'inel') then
             iproctpe=1
            else
             iproctpe=0
            endif
c            
            if(cl_verb.gt.100) call printntuple
            call HFNT(22)
            call write2file(i,1)  ! 1-all 2-GSIM-lundc
        endif
  300  CONTINUE

c
c
      close(41)
        OPEN(unit=42,file='tmp/'//
     6cl_hispath(1:4)//cl_target(1:2)//'.txt',FORM='UNFORMATTED')
        call PYRGET(42,0)
        CLOSE(42)
C...Print the Pythia cross section which is needed to get an absolute 
C   normalisation the number is in microbarns
       write(*,*)"Pythia total cross section normalisation",
     +           pari(1)*1000.
      
C...Print cross sections.
       CALL PYSTAT(1)
       CALL PYSTAT(4)
         call HCDIR('//ZXC',' ')
         call HROUT(0,icycle,'')
         call HREND('ZXC')

  500  if (qedrad.eq.2) then
         write(*,*) 'lookup table is generated;'
         write(*,*) 'to run now pythia change parameter qedrad to 1'
       endif
   
       END

C***********************************************************************
          subroutine write2file(jj,il)
C***********************************************************************
c write the LUND event:
c
c the header:
c N number of particles in the event
c PARL(1),PARL(2): number of nucleons and protons of target
c cl_pol,elpol: polarization of proton and electron
c LEX,LEYY,LEW2,LEQ2,LEU: x,y,W^2,Q^2, nu
c
c the body:
c i particle number
c plu(i,6) : particle charge
c
c K(I,1) = 3, 13} or \ttt{14}, instead, it  contains special
c K(I,2) : particle code
c K(I,3) : line number of parent particle, where known,otherwise 0. 
c K(I,4) : normally the line number of the first daughter and
c          0 for an undecayed particle or unfragmented parton.
c
c P(I,1) $p_x$, momentum in the $x$ direction, in GeV/$c$.
c P(I,2) $p_y$, momentum in the $y$ direction, in GeV/$c$.
c P(I,3) $p_z$, momentum in the $z$ direction, in GeV/$c$.
c P(I,4) $E$, energy, in GeV.
c P(I,5) $m$, mass, in GeV/$c^2$. 
c       In parton showers, with  space-like virtualities, 
c       i.e.\ where $Q^2 = - m^2 > 0$, one puts \ttt{P(I,5)}$ = -Q$.
c
c V(I,1) $x$ position of production vertex, in cm.
c V(I,2) $y$ position of production vertex, in cm.
c V(I,3) $z$ position of production vertex, in cm.
c V(I,4) time of production, in mm/$c$ ($\approx 3.33 \times 10^{-12}$ s).
c V(I,5) proper lifetime of particle, in mm/$c$
c      ($\approx 3.33 \times 10^{-12}$ s). 
c      If the particle is not expected to decay V(I,5)=0}.
c  A line with K(I,1)=4, i.e.\ a  particle that could have decayed,
c   but did not within the allowed region, has the proper non-zero V(I,5).
cIn the absence of electric or magnetic fields, or other
cdisturbances, the decay vertex \ttt{VP} of an unstable particle
cmay be calculated as VP(j) = V(I,j) + V(I,5)*P(I,j)/P(I,5)},
c
c
c
c
          implicit none
#include "pyhtlist.inc"
#include "options.inc"
#include "phydata1234.inc"
          real plu
          integer jj,il,i,j,istat,elpol
          logical lFirst
          DATA lFirst /.TRUE./
          DATA elpol /1/
c
            if (lFirst) then   ! open the file
             OPEN(unit=41,file='tmp/lund.dat',status='unknown')
             lFirst=.FALSE.
            endif
c
               if(il.eq.2) then
                 j=0
                 do i=1,N
                  if(k(i,1).lt.11) j=j+1   ! save space
                 enddo
                 write(41,111) j,1.0,gQ2,gW,1.0*elpol,1.0*elpol
               else
                write(41,101) N,1.0,1.0,elpol,elpol,
     6                   gxb,gxb,gW,gQ2,gq2
               endif
c
 111           FORMAT(2x,I5,10F10.4)
 110           FORMAT(2x,10I10)
 112           FORMAT(2x,10F10.4)
c 101      FORMAT(2x,I10,2F4.0,2I3,5F6.3)
 101      FORMAT(2x,I10,2F4.0,2I3,5(F6.3,2x))
 102      FORMAT(2x,I3,F4.0,2I5,2I3,5F10.4,2X,5F10.4)
              do i=1,N
               if(il.eq.2) then
                 if(k(i,1).lt.11) then   ! save space
                   write(41,110) (k(i,j),j=1,5) 
                   write(41,112) (p(i,j),j=1,5) 
                   write(41,112) 0.0,0.0,cl_zpos,0.0,0.0
                 endif 
               else
                 write (41,102) i,plu(k(i,2)),(k(i,j),j=1,4),(P(i,j),j=1,5)
     6                                                   ,(V(i,j)*0.1,j=1,3)
               endif
              enddo
          return
          end
c
c
          real function plu(id)
         integer id
         SELECT CASE (id)  
         CASE (11) ! electron
          plu=-1.0
         CASE (2112) ! neutron
          plu=0.0
         CASE (2212) ! proton
          plu=1.0
         CASE (211) ! pi+
          plu=1.0
         CASE (321) ! K+
          plu=1.0
         CASE (-211) ! pi-
          plu=-1.0
         CASE (-321) ! K-
          plu=-1.0
         CASE (111) ! pi0
          plu=0.0
         CASE (22) ! pi0
          plu=0.0
         CASE (113) ! ro0
          plu=0.0
         CASE (213) ! ro+
          plu=1.0
         CASE (223) ! omega
          plu=0.0
         CASE DEFAULT
          plu=0.0
         END SELECT
          return
         end
c
       SUBROUTINE INIT_PAW
       implicit none
       integer h,nwpawc
       parameter (nwpawc=1000000)
       integer  NTID_OUT

       common /PAWC/ h(nwpawc)
       call HLIMIT(nwpawc)
       NTID_OUT=22
       call hini(NTID_OUT)
       return
       end
c 
      subroutine printntuple()
      implicit none
#include "pyhtlist.inc"
c
       print *,'ELEGEN-1 ',gnele,gelebits,ghpar,gproh,geleh,gelee,gelet
       print *,'ELEGEN-2 ',gelef,gelex,geley,gelez,gelewgt,gxb,gq2,gw
c234567890123456789012345678901234567890123456789012345678901234567890123456
*
       print *,'HADGEN-1 ', gnpi0,gnpip,gnpim,gnpro,gngam
       print *,'HADGEN-2 ',gnneu,gnrop,gnro0,gnome
       print *,'HADGEN-3 ',nsproc,nsele,nspi0,nspip,nspim
       print *,'HADGEN-4 ',gpi0e,gpi0t,gpi0f
       print *,'HADGEN-5 ',gpipe,gpipt,gpipf
       print *,'HADGEN-6 ',gpime,gpimt,gpimf
       print *,'HADGEN-7 ',gproe,gprot,gprof
       print *,'HADGEN-8 ',gneue,gneut,gneuf
       print *,'HADGEN-9 ',grope,gropt,gropf
       print *,'HADGEN-10 ',gro0e,gro0t,gro0f
       print *,'HADGEN-11 ',gomee,gomet,gomef
       print *,'HADGEN-12 ',gpipm,gpimm,gpi0m,gro0m,gropm,gomem
       print *,'RADGN-1 ',iproctpe,radq2,radnu,radweight,radweight,r_sigrad,r_sigcor
       print *,'RADGN-2 ',grade,gradt,gradf
       return
       end
c 
      subroutine hini(NTID_OUT)
      implicit none
#include "pyhtlist.inc"
#include "options.inc"
c
      integer NTID_OUT,NTID_OUTM,IQUEST
      COMMON/QUEST/IQUEST(100) 
      integer lrec,istat
      character*80 hbooknm
       hbooknm='tmp/'//cl_hispath(1:5)//cl_target(1:2)//'.hbook'
      lrec=8191
c
       OPEN(unit=41,file='tmp/'//
     6cl_hispath(1:4)//cl_target(1:2)//'.dat',status='NEW')
c     open koko
c
       IQUEST(10)=65000
       print *,'INIT PAW hbook=',hbooknm
       CALL HROPEN(50,'ZXC',hbooknm,'NQE',LREC,ISTAT)
       call hbset('BSIZE',8176,istat)
      if (istat.ne.0) stop
      call HBNT(NTID_OUT,'semiout',' ')
      call HBNAME(NTID_OUT,'elegen',gnele,
     +'gnele:I,gelebits:I,ghpar:I,gproh:I,geleh:I,'//
     +'gelee:R,gelet:R,gelef:R,'//
     +'gelex:R,geley:R,gelez:R,gelewgt:R,gxb:R,gq2:R,gw:R')
c234567890123456789012345678901234567890123456789012345678901234567890123456
      call HBNAME(NTID_OUT,'hadgen',gnpi0,
     +'gnpi0:I,gnpip:I,gnpim:I,gnpro:I,gngam:I,'//
     +'gnneu:I,gnrop:I,gnro0:I,gnome:I,'//
     +'nsproc:I,nsele:I,nspi0:I,nspip:I,nspim:I,'//
     +'gpi0e:R,gpi0t:R,gpi0f:R,'//
     +'gpipe:R,gpipt:R,gpipf:R,'//
     +'gpime:R,gpimt:R,gpimf:R,'//
     +'gproe:R,gprot:R,gprof:R,'//
     +'gneue:R,gneut:R,gneuf:R,'//
     +'grope:R,gropt:R,gropf:R,'//
     +'gro0e:R,gro0t:R,gro0f:R,'//
     +'gomee:R,gomet:R,gomef:R,'//
     +'gpipm:R,gpimm:R,gpi0m:R,gro0m:R,gropm:R,gomem:R')
c
c      if (cl_radgen) then    
       call HBNAME(NTID_OUT,'radgn',iproctpe,
     +'iproctpe:I,radq2:R,radnu:R,radweight:R,sigrad:R,sigcor:R,'//
     +'grade:R,gradt:R,gradf:R')
c      endif
      return
      end
c

      subroutine fillevent(lOK)
      implicit none
#include "phydata1234.inc"
#include "pyhtlist.inc"
#include "options.inc"
      integer mint
      double precision VINT
      COMMON/PYINT1/MINT(400),VINT(400)
       real v4pr(4),v4el(4),v4ne(4),v4pip(4),v4pim(4),v4pi0(4)
     6 ,v4rop(4),v4ro0(4),v4ome(4),tmp4(4),qiu4(4),vmass,vdotm
       real PolarTheta,Azimuthalphi,anu,zmin,mismas
       integer i,part_id
       logical lOK,hOK
       call VZERO(gnele,14)
       call VZERO(gnpi0,44)
       call VZERO(iproctpe,8)
c
       zmin=0.4
       hOK=.FALSE.
       lOK=.FALSE.
c
       do i=1,N
c$$$        if(k(i,2).eq.213.or.k(i,2).eq.113) then
c$$$           call pylist(1)
c$$$           hOK=.TRUE.
c$$$        endif
        if(k(i,2).gt.9999.or.k(i,2).lt.-9999) k(i,2)=0 
c
        if(k(i,1).lt.21) then
         part_id=k(i,2)
c
         SELECT CASE (part_id)  
         CASE (11) ! electron
          gnele=gnele+1
          v4el(1)=P(i,1)
          v4el(2)=P(i,2)
          v4el(3)=P(i,3)
          v4el(4)=P(i,4)
          gelee=v4el(4)
          gelet=PolarTheta(v4el(1),v4el(2),v4el(3))
          gelef=Azimuthalphi(v4el(1),v4el(2))
          nsele=k(k(i,3),2)
         CASE (2112) ! neutron
          gnneu=gnneu+1
          v4ne(1)=P(i,1)
          v4ne(2)=P(i,2)
          v4ne(3)=P(i,3)
          v4ne(4)=P(i,4)
          gneue=v4ne(4)
          gneut=PolarTheta(v4ne(1),v4ne(2),v4ne(3))
          gneuf=Azimuthalphi(v4ne(1),v4ne(2))
        CASE (2212) ! proton
          gnpro=gnpro+1
          v4pr(1)=P(i,1)
          v4pr(2)=P(i,2)
          v4pr(3)=P(i,3)
          v4pr(4)=P(i,4)
          gproe=v4pr(4)
          gprot=PolarTheta(v4pr(1),v4pr(2),v4pr(3))
          gprof=Azimuthalphi(v4pr(1),v4pr(2))
         CASE (211) ! pi+
          gnpip=gnpip+1
           if(gnpip.eq.1.or.v4pip(4).lt.P(i,4)) then
           v4pip(1)=P(i,1)
           v4pip(2)=P(i,2)
           v4pip(3)=P(i,3)
           v4pip(4)=P(i,4)
           gpipe=v4pip(4)
           gpipt=PolarTheta(v4pip(1),v4pip(2),v4pip(3))
           gpipf=Azimuthalphi(v4pip(1),v4pip(2))
           nspip=k(k(i,3),2)
           endif
         CASE (-211) ! pi-
          gnpim=gnpim+1
          if(gnpim.eq.1.or.v4pim(4).lt.P(i,4)) then
          v4pim(1)=P(i,1)
          v4pim(2)=P(i,2)
          v4pim(3)=P(i,3)
          v4pim(4)=P(i,4)
          gpime=v4pim(4)
          gpimt=PolarTheta(v4pim(1),v4pim(2),v4pim(3))
          gpimf=Azimuthalphi(v4pim(1),v4pim(2))
          nspim=k(k(i,3),2)
          endif
         CASE (111) ! pi0
          gnpi0=gnpi0+1
          if(gnpi0.eq.1.or.v4pi0(4).lt.P(i,4)) then
          v4pi0(1)=P(i,1)
          v4pi0(2)=P(i,2)
          v4pi0(3)=P(i,3)
          v4pi0(4)=P(i,4)
          gpi0e=v4pi0(4)
          gpi0t=PolarTheta(v4pi0(1),v4pi0(2),v4pi0(3))
          gpi0f=Azimuthalphi(v4pi0(1),v4pi0(2))
          nspi0=k(k(i,3),2)
          endif
         CASE (113) ! ro0
          gnro0=gnro0+1
          v4ro0(1)=P(i,1)
          v4ro0(2)=P(i,2)
          v4ro0(3)=P(i,3)
          v4ro0(4)=P(i,4)
          gro0e=v4ro0(4)
          gro0t=PolarTheta(v4ro0(1),v4ro0(2),v4ro0(3))
          gro0f=Azimuthalphi(v4ro0(1),v4ro0(2))
         CASE (213) ! ro+
          gnrop=gnrop+1
          v4rop(1)=P(i,1)
          v4rop(2)=P(i,2)
          v4rop(3)=P(i,3)
          v4rop(4)=P(i,4)
          grope=v4rop(4)
          gropt=PolarTheta(v4rop(1),v4rop(2),v4rop(3))
          gropf=Azimuthalphi(v4rop(1),v4rop(2))
         CASE (223) ! omega
          gnome=gnome+1
          v4ome(1)=P(i,1)
          v4ome(2)=P(i,2)
          v4ome(3)=P(i,3)
          v4ome(4)=P(i,4)
          gomee=v4ome(4)
          gomet=PolarTheta(v4ome(1),v4ome(2),v4ome(3))
          gomef=Azimuthalphi(v4ome(1),v4ome(2))
         CASE DEFAULT
         END SELECT
        endif       
       enddo

          geleh=MSTI(1)
          ghpar=MINT(2)
          gproh=MSTI(9)
c
         if (gnele.ge.1.and.(gelet*180/3.1415).gt.13.35
     6        .and.(1.0-gelee/cl_beam_energy).lt.0.93) then
          if(cl_beam.eq.'gamma') then ! photon beam
            qiu4(4)=cl_beam_energy
            qiu4(3)=cl_beam_energy
            qiu4(1)=0
            qiu4(2)=0
           else
            call vdifm(v4el0,v4el,qiu4,4)
            gq2=vdotm(qiu4,qiu4,4)
c
             if(qiu4(4).gt.0) then
              gxb=gq2/2.0/0.93827/qiu4(4)
              if(gxb.gt.0) then
               gw=0.88035+gq2/gxb-gq2
              else
               gw=0
              endif
              anu=qiu4(4)
             else
              gxb=0
              gw=0
              anu=100000.0
             endif
           endif
c          
c        
c
         if(gelet.gt.0.26) then
c
c          fill relevant mismases
c
            if(gnpip.gt.0) gpipm=mismas(qiu4,v4pip)
            if(gnpim.gt.0) gpimm=mismas(qiu4,v4pim)
            if(gnpi0.gt.0) gpi0m=mismas(qiu4,v4pi0)
            if(gnro0.gt.0) gro0m=mismas(qiu4,v4ro0)
            if(gnrop.gt.0) gropm=mismas(qiu4,v4rop)
            if(gnome.gt.0) gomem=mismas(qiu4,v4rop)
            if((gnpip.gt.0.and.gpipe/(cl_beam_energy-gelee).gt.0.3).or.
     6      (gnpi0.gt.0.and.gpi0e/(cl_beam_energy-gelee).gt.0.3).or.
     6      (gnpim.gt.0.and.gpime/(cl_beam_energy-gelee).gt.0.3)) then
              lOK=.TRUE.  ! high energy stuff
            endif
cccc            lOK=.TRUE.
          endif
       endif
c          
      return
      end
c
       real function vmass(a)
       real vm
        vm= vdotm(a,a,4)
        if (vm.lt.0.0) then
          vmass=sqrt(-vm)
        else
          vmass=-1.0
        endif 
       return
       end
c
       real function vdotm(a,b,n)
       real a(n),b(n),s
       integer i,n
       s=0.0
       do i=1,3
         s=s+a(i)*b(i)
       enddo
       if(n.eq.4) s=s-a(n)*b(n)
       vdotm=s
       return
       end
c   
       subroutine vsumm(a,b,c,n)
       real a(n),b(n),c(n)
       integer i,n
        do i=1,n
          c(i)=a(i)+b(i)
        enddo
       return
       end
c
       subroutine vdifm(a,b,c,n)
       real a(n),b(n),c(n)
       integer i,n
        do i=1,n
          c(i)=a(i)-b(i)
        enddo
       return
       end

c
        real function  PolarTheta(vx,vy,vz)
      implicit none
        real vx,vy,vz,pmod,theta
        pmod=vx*vx+vy*vy+vz*vz
        if(pmod .gt. 0 ) then
         theta=acos(vz/sqrt(pmod))
        else
         theta=-100
        endif
        PolarTheta=theta
        return
        end

        real function Azimuthalphi(vx,vy )
      implicit none
        real pi
        parameter ( PI=3.1415926)
        real vx,vy,pmod,phi,cosf
        pmod=vx*vx+vy*vy
        if(pmod .gt. 0 ) then
         pmod=sqrt(pmod)
         cosf=vx/pmod
        else
         cosf=1.0
        endif
        if(abs(cosf) .le. 1.0) phi=acos(cosf);
        if(vy .lt. 0.0) phi= 2*PI-phi;
        Azimuthalphi=phi
        return
        end
c
       SUBROUTINE CL_OPTIONS
       implicit none
#include "options.inc"
       integer i,iran,irannom
       real VEC1,valnum
       character*20 cnumber
       integer  numopts,NCDECI
       integer*4 now(3)
c
c    command line processing
c
c     defaults
      cl_rndm = .FALSE. 
      cl_zpos = 0.0  
      cl_triggers = 100  
      cl_beam_energy=5.754   ! def 
      cl_beam='gamma/e-'     ! electron 
      cl_hispath='pythi'    ! (w9)
      cl_target='p+'     ! (def proton target)
      cl_nprint=1000         ! print every cl_nprint event
      cl_verb=0
      cl_radgen=.FALSE.
      cl_dis=.FALSE.
c
      numopts  = IARGC()
c      
      if(numopts.gt.0 ) then
        i=0
      else
        goto 2
      endif
 1    i=i+1
        CALL GETARG(i,cnumber)
        if(cnumber.eq.'--trig'.and.i.lt.numopts) then
          i=i+1
          CALL GETARG(i,cnumber)
          cl_triggers=NCDECI(cnumber)
        elseif(cnumber.eq.'--v'.and.i.lt.numopts) then
           i=i+1
           CALL GETARG(i,cnumber)
           cl_verb=NCDECI(cnumber)
        elseif(cnumber.eq.'--print'.and.i.lt.numopts) then
           i=i+1
           CALL GETARG(i,cnumber)
           cl_nprint=NCDECI(cnumber)
        elseif(cnumber.eq.'--path'.and.i.lt.numopts) then
           i=i+1
           CALL GETARG(i,cl_hispath)
        elseif(cnumber.eq.'--targ'.and.i.lt.numopts) then
           i=i+1
           CALL GETARG(i,cl_target)
        elseif(cnumber.eq.'--beam'.and.i.lt.numopts) then
           i=i+1
           CALL GETARG(i,cl_beam)
        elseif(cnumber.eq.'--radgen') then
           cl_radgen=.TRUE.
        elseif(cnumber.eq.'--dis') then
           cl_dis=.TRUE.
        elseif(cnumber.eq.'--ebeam'.and.i.lt.numopts) then
           i=i+1
           CALL GETARG(i,cnumber)
           cl_beam_energy=valnum(cnumber)           
        elseif(cnumber.eq.'--zpos'.and.i.lt.numopts) then
           i=i+1
           CALL GETARG(i,cnumber)
           cl_zpos=valnum(cnumber)           
        elseif(cnumber.eq.'--rndm') then
           cl_rndm=.TRUE.
        else
          call printusage
          stop
        endif
        if(i.lt. numopts) goto 1
 2      continue
        call printvalues
        return 
        end
c
        subroutine printusage
        print *,' pythia [options]            '
        print *,'      option  value      default    comment  '
        print *,'  --trig nevents         10      number of triggers '
        print *,'  --beam beam_type    gamma/e-     e- beam '
        print *,'     --targ target         p+       n0 for neutron '
        print *,'  --ebeam beam_energy     5.754  e- momentum in GeV '
        print *,'  --zpos  z_position      0.0    e- momentum in GeV '
        print *,'  --radgen                   include radgen'
        print *,'  --path hisid          w9/p       write dir  '
        print *,'  --print nprint       1000   print nprint event '
        print *,'  --dis                .FALSE.     all dis events in '
        print *,'  --v     verblev       0     verbos. level '
        return
        end

        subroutine printvalues
        implicit none
#include "options.inc"
        print *,'pythia input values:'    
        print *,'triggers:  ',cl_triggers     
        print *,'BEAM type:         ',cl_beam  
        print *,'TARGET:              ', cl_target 
        print *,'BEAM ENERGY:         ',cl_beam_energy  
        print *,'path              ', cl_hispath 
        print *,'nprint            ',cl_nprint
        print *,'verbosity lev.    ',cl_verb
        print *,'RADGEN ON        :   ', cl_radgen 
        return
        end
c
      real function valnum(str)
c     return the real value contained into a string

      implicit integer (k-l)
      character *(*) str
      logical segno
      

      segno=.false.
      valnum=0.00
      lu=length(str)
      
c     check the number sign
      if(str(1:1).eq.'-')then
      segno=.true.
      str=str(2:lu)
      lu=lu-1
      end if

c     check if number is float or integer
      if(index(str,'.').ne.0)then
      iin=index(str,'.')-1
      else
      iin=lu
      end if

      ifr=lu-(iin+1)

c     translate the integer portion
      doi=1,iin  
      k=ichar(str(i:i))-48
      valnum=valnum+float(k)*10.00**float(iin-i)
      end do         

      if(iin.eq.lu)goto 10
      str=str(iin+2:lu)

c     translate the decimal portion
      doi=1,ifr  
      k=ichar(str(i:i))-48
      valnum=valnum+float(k)/10.00**float(i)
      end do

10    if(segno)valnum=-valnum

      return
      end     
c
      integer function length(str)
c     return the string length without the blanks characters

      implicit integer (k-l)
      character *(*) str    
      
      lmax=len(str)      
       
c     search the last non blank character
      do i=lmax,1,-1
      if(str(i:i).ne.' ')then
      length=i
      return
      end if
      end do

      length=lmax

      return
      end     
c
       real function mismas(qiu4,v4)
       implicit none
       real qiu4(4),v4(4),pro4(4),tnorm(4),tnorm2(4)
       real Mp,vmass,vmass2,vangle,vdotm,phigstar
       parameter (Mp=0.93827)
c proton
c
        pro4(4)=Mp
        pro4(3)=0
        pro4(2)=0
        pro4(1)=0
c
         call vsumm(qiu4,pro4,tnorm,4)
         call vdifm(tnorm,v4,tnorm2,4)
         mismas=vmass2(tnorm2)
         return
         end
c
       real function vmass2(a)
       implicit none
       real vm,a(4), vdotm
        vm= vdotm(a,a,4)
        vmass2=-vm
       return
       end
c
