*********************************************************
*                                                       *
* This file was generated by HUWFUN.                    *
*                                                       *
*********************************************************
*
*     Ntuple Id:      22   
*     Ntuple Title:   semiout
*     Creation:       29/01/2004 19.48.18
*
*********************************************************
*
      LOGICAL         CHAIN
      CHARACTER*128   CFILE
      INTEGER         IDNEVT,NCHEVT,ICHEVT
      REAL            OBS(13)
*
      COMMON /PAWIDN/ IDNEVT,OBS
      COMMON /PAWCHN/ CHAIN, NCHEVT, ICHEVT
      COMMON /PAWCHC/ CFILE
*
*--   Ntuple Variable Declarations
*
      REAL gelee,gelet,gelef,gelex,geley,gelez,gelewgt,gxb,gq2,gw,gpi0e
     + ,gpi0t,gpi0f,gpipe,gpipt,gpipf,gpime,gpimt,gpimf,gproe,gprot
     + ,gprof,gneue,gneut,gneuf,grope,gropt,gropf,gro0e,gro0t,gro0f
     + ,gomee,gomet,gomef,gpipm,gpimm,gpi0m,gro0m,gropm,gomem,radq2
     + ,radnu,radweight,sigrad,sigcor,grade,gradt,gradf
      INTEGER gnele,gelebits,ghpar,gproh,geleh,gnpi0,gnpip,gnpim,gnpro
     + ,gngam,gnneu,gnrop,gnro0,gnome,nsproc,nsele,nspi0,nspip,nspim
     + ,iproctpe
*
      COMMON /PAWCR4/ gnele,gelebits,ghpar,gproh,geleh,gelee,gelet,gelef
     + ,gelex,geley,gelez,gelewgt,gxb,gq2,gw,gnpi0,gnpip,gnpim,gnpro
     + ,gngam,gnneu,gnrop,gnro0,gnome,nsproc,nsele,nspi0,nspip,nspim
     + ,gpi0e,gpi0t,gpi0f,gpipe,gpipt,gpipf,gpime,gpimt,gpimf,gproe
     + ,gprot,gprof,gneue,gneut,gneuf,grope,gropt,gropf,gro0e,gro0t
     + ,gro0f,gomee,gomet,gomef,gpipm,gpimm,gpi0m,gro0m,gropm,gomem
     + ,iproctpe,radq2,radnu,radweight,sigrad,sigcor,grade,gradt,gradf