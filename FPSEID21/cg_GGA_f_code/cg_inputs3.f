C**************************************************************
C     INPUT STRUCTURE CONSTANTS
C               CRYST AND STRUC
C                   OSAMU SUGINO (1990-12-03)
C**************************************************************
      SUBROUTINE AINPUT(IOPT,CELLDM,MAXFN,OKSTEP,ZVAL,NBND,
     &                  NFL, NPFL, RCUT,
     &                  GCUT2,GRAT, KCONT )
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION IOPT(10,5),CELLDM(6)
      COMMON/COMFRP/RMIX,TR2,ITCMAX,ITMAX,ITC1,ITC7
      COMMON/COMINI/MAXG2
      COMMON/COMFIX/FATM(3,101),NFIX,IFATM(101)
c
      COMMON /DOSCAL/NBANDI1,NBANDI2,EDWN,EUP,EDD
      CHARACTER ATEMP(80)*72,NUL*72,ASAVE(80)*12,
     &          BSAVE(80)*40,A1(72)*1,NAIBU*80
C
      NFIX = 0
      NUL=' '
      DO 2100 I=1,80
      ASAVE(I)=' '
      BSAVE(I)=' '
 2100 ATEMP(I)=' '
      MAXG2=0
C****************************************************
C****************************************************
      READ(*,1) A1
      WRITE(6,1) A1
      I=0
 9000 READ(*,1) A1
    1 FORMAT(72A1)
      N=1
 9100 IF(A1(N).EQ.'/') GO TO 9200
      IF(A1(N).EQ.' ') GO TO 9101
C
C
      J=1
      I=I+1
      ATEMP(I)=A1(N)
 9110 N=N+1
      IF(A1(N).EQ.'/') GO TO 9200
      IF(A1(N).EQ.' ') GO TO 9101
      ATEMP(I)=ATEMP(I)(1:J)//A1(N)
      J=J+1
      IF(   N .LT. 72) GO TO 9110
 9101 N=N+1
      IF(   N .LE. 72) GO TO 9100
                       GO TO 9000
C***************************************************
C     MAIN ROUTINE
C***************************************************
 9200 L=0
      DO 1000 I=1,80
      IF(ATEMP(I).EQ.NUL) GO TO 201
      L=L+1
C
C
      DO 140 J=72,1,-1
  140 IF(ATEMP(I)(J:J).NE.' ') GO TO 141
C
C
  141 CONTINUE
      IEQ=INDEX(ATEMP(I),'=')
      IF(IEQ.EQ.0) THEN
         ASAVE(L)=ATEMP(I)(1:J)
         BSAVE(L)=ATEMP(I)(13:32)
      ELSE
         ASAVE(L)=ATEMP(I)(1:IEQ-1)
         BSAVE(L)=ATEMP(I)(IEQ+1:J)
      ENDIF
 1000 CONTINUE
  201 JSAVE=L
C
      WRITE(6,*) ' # OF COMMANDS = ',JSAVE
      DO 220 I=1,JSAVE
  220 WRITE(6,221) I,ASAVE(I),BSAVE(I)
  221 FORMAT(' NO. ',I2,'  COMMAND = ',A12,' OPERATION = ',A20)
C
      DO 3000 L=1,JSAVE
      IF(ASAVE(L)(1:2).EQ.'PP') THEN
         IF(INDEX(BSAVE(L),'KB').NE.0) THEN
            IOPT(1,1)=0
            WRITE(6,*) ' KLEINMAN BYLANDER PSEUDOPOTENTIAL IS USED '
         ENDIF
         IF(INDEX(BSAVE(L),'BHS').NE.0) THEN
            IOPT(1,1)=1
            WRITE(6,*) ' BHS TYPE  PSEUDOPOTENTIAL IS USED '
         ENDIF
         IF(INDEX(BSAVE(L),'DEBUG').NE.0) THEN
            IOPT(1,1)=2
            WRITE(6,*) ' DEBUG KB PSEUDOPOTENTIAL '
         ENDIF
         IF(INDEX(BSAVE(L),'SOFT').NE.0) THEN
            IOPT(5,1)=0
            WRITE(6,*) ' SOFT PSEUDOPOTENTIAL IS USED '
         ENDIF
         IF(INDEX(BSAVE(L),'HARD').NE.0) THEN
            IOPT(5,1)=1
            WRITE(6,*) ' HARD PSEUDOPOTENTIAL IS USED '
         ENDIF
         IF(INDEX(BSAVE(L),'NOND').NE.0) THEN
            IOPT(6,1)=1
            WRITE(6,*) ' D-COMPONENT IS SET ZERO '
         ENDIF
      ELSEIF(ASAVE(L)(1:4).EQ.'DISP') THEN
         IOPT(2,1)=1
         WRITE(6,*) ' BAND DISPERION IS CALCULATED '
      ELSEIF(ASAVE(L)(1:4).EQ.'FCHK') THEN
         IOPT(2,1)=2
         WRITE(6,*) ' FORCE IS CHECKED '
      ELSEIF(ASAVE(L)(1:5).EQ.'STEEP') THEN
         IOPT(2,1)=3
         WRITE(6,*) ' STEEPEST DESCENT '
      ELSEIF(ASAVE(L)(1:5).EQ.'PROJE') THEN
         IOPT(2,1)=4
         WRITE(6,*) ' ORBITAL PROJECTION ON ATOMS'
      ELSEIF(ASAVE(L)(1:3).EQ.'GGA') THEN
         IOPT(8,2)=1
         WRITE(6,*) ' GGA is adopted'
      ELSEIF(ASAVE(L)(1:5).EQ.'FFTWF') THEN
         IOPT(2,1)=5
         WRITE(6,*) ' WFs on FFT grids are saved'
      ELSEIF(ASAVE(L)(1:3).EQ.'DOS') THEN
         IOPT(2,1)=6
         WRITE(6,*) ' DOS CALCULATION '
            I0 = INDEX(BSAVE(L),'(') + 1
            I9 = INDEX(BSAVE(L),')') - 1
            I1 = INDEX(BSAVE(L),',')
            I2 = INDEX(BSAVE(L)(I1+1:I9),',') + I1
            I3 = INDEX(BSAVE(L)(I2+1:I9),',') + I2
            I4 = INDEX(BSAVE(L)(I3+1:I9),',') + I3
            WRITE(NAIBU,'(A30)') BSAVE(L)(I0:I1-1)
            READ(NAIBU,'(BN,I30)') NBANDI1
            WRITE(NAIBU,'(A30)') BSAVE(L)(I1+1:I2-1)
            READ(NAIBU,'(BN,I30)') NBANDI2
            WRITE(NAIBU,'(A30)') BSAVE(L)(I2+1:I3-1)
c            READ(NAIBU,'(BN,E30.0)') EDWN
            READ(NAIBU,*) EDWN
            WRITE(NAIBU,'(A30)') BSAVE(L)(I3+1:I4-1)
c            READ(NAIBU,'(BN,E30.0)') EUP
            READ(NAIBU,*) EUP
            WRITE(NAIBU,'(A30)') BSAVE(L)(I4+1:I9)
c            READ(NAIBU,'(BN,E30.0)') EDD
            READ(NAIBU,*) EDD
            WRITE(6,*) ' BANDS for DOS ',NBANDI1,' to',NBANDI2
            WRITE(6,*) ' Energy range :',EDWN,'eV  below Ef'
            write(6,*) '               ',EUP ,'eV  above Ef'
            write(6,*) ' Energy resolution ',EDD ,'eV'
      ELSEIF(ASAVE(L)(1:5).EQ.'k-PRO') THEN
         IOPT(2,1)=7
         WRITE(6,*) ' ORBITAL PROJECTION ON GENERAL k-POINTS'
      ELSEIF(ASAVE(L)(1:7).EQ.'k-FFTWF') THEN
         IOPT(2,1)=8
         WRITE(6,*) ' ORBITAL CHARGE ON GENERAL k-POINTS'
      ELSEIF(ASAVE(L)(1:4).EQ.'LDOS') THEN
         IF(BSAVE(L)(1:3).EQ.'SMK') THEN
            IOPT(10,1)=1
            WRITE(6,*) ' LDOS: K SAMPLING AS IN SCF'
         ELSEIF(BSAVE(L)(1:3).EQ.'NWK') THEN
            IOPT(10,1)=2
            WRITE(6,*) ' LDOS: NEW K SAMPLING '
         ENDIF
      ELSEIF(ASAVE(L)(1:2).EQ.'CD') THEN
         IF(BSAVE(L)(1:1).EQ.'I') THEN
            IOPT(3,1)=0
            WRITE(6,*) ' CHARGE DENSITY IS CREADTED INTERNALLY '
         ELSEIF(BSAVE(L)(1:1).EQ.'R') THEN
            IOPT(3,1)=2
            WRITE(6,*) ' READ PREVIOUS CHARGE DENSITY FROM FILE20 '
         ELSEIF(BSAVE(L)(1:1).EQ.'A') THEN
            IOPT(3,1)=4
            WRITE(6,*) ' MAKE CHARGE FROM OVERLAP OF ATOM CHARGE '
         ELSEIF(BSAVE(L)(1:1).EQ.'F') THEN
            IOPT(3,1)=1
            WRITE(6,*) ' READ CHARGE DENSITY FROM FILE20 (REAL SPACE)'
         ELSE
            IOPT(3,1)=3
            WRITE(6,*) ' CREATE CHARGE DENSITY FROM READ WAVEFUNCTION'
         ENDIF
      ELSEIF(ASAVE(L)(1:2).EQ.'WF') THEN
         IF(BSAVE(L)(1:1).EQ.'I') THEN
            IOPT(4,1)=0
            WRITE(6,*) ' WAVEFUNCTION IS CREADTED INTERNALLY '
         ELSE
            IOPT(4,1)=1
            WRITE(6,*) ' READ PREVIOUS WAVEFUNCTION FROM FILE22 '
         ENDIF
      ELSEIF(ASAVE(L)(1:2).EQ.'CG') THEN
            I0 = INDEX(BSAVE(L),'(') + 1
            I9 = INDEX(BSAVE(L),')') - 1
            I1 = INDEX(BSAVE(L),',')
            I2 = INDEX(BSAVE(L)(I1+1:I9),',') + I1
            WRITE(NAIBU,'(A20)') BSAVE(L)(I0:I1-1)
            READ(NAIBU,'(BN,I20)') ITC7
            WRITE(NAIBU,'(A20)') BSAVE(L)(I1+1:I2-1)
            READ(NAIBU,'(BN,I20)') ITC1
            WRITE(NAIBU,'(A20)') BSAVE(L)(I2+1:I9)
            READ(NAIBU,'(BN,I20)') ITCMAX
            WRITE(6,*) ' #CG  STEP IS ',ITC7,ITC1,ITCMAX
      ELSEIF(ASAVE(L)(1:3).EQ.'SCF') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
         READ(NAIBU,'(BN,I20)') ITMAX
         WRITE(6,*) ' #SCF STEP IS ',ITMAX
      ELSEIF(ASAVE(L)(1:3).EQ.'EXT') THEN
         IF(BSAVE(L)(1:3).EQ.'PAN') THEN
            IOPT(7,1)=0
            WRITE(6,*) ' PANDEY EXTRAPOLATION SCHEME (R) IS USED '
         ELSEIF(BSAVE(L)(1:3).EQ.'PAG') THEN
            IOPT(7,1)=2
            WRITE(6,*) ' PANDEY EXTRAPOLATION SCHEME (G) IS USED '
         ELSEIF(BSAVE(L)(1:3).EQ.'PKB') THEN
            IOPT(7,1)=3
            WRITE(6,*) ' PANDEY-KB EXTRAPOLATION SCHEME IS USED '
         ELSEIF(BSAVE(L)(1:3).EQ.'NEX') THEN
            IOPT(7,1)=4
            WRITE(6,*) ' NO EXTRAPOLATION SCHEMES IS USED '
         ELSE
            IOPT(7,1)=1
            WRITE(6,*) ' KB EXTRAPOLATION SCHEME IS USED '
         ENDIF
      ELSEIF(ASAVE(L)(1:4).EQ.'RMIX') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') RMIX
         READ(NAIBU,*) RMIX
         WRITE(6,*) ' MIXING RATIO IS ',RMIX
      ELSEIF(ASAVE(L)(1:4).EQ.'CONV') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') TR2
         READ(NAIBU,*) TR2
         WRITE(6,*) ' SCF CONVERGENCE CRITERION IS ',TR2
      ELSEIF(ASAVE(L)(1:4).EQ.'MAXF') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
         READ(NAIBU,'(BN,I20)') MAXFN
         WRITE(6,*) ' #G-OPT LOOP IS ',MAXFN
      ELSEIF(ASAVE(L)(1:4).EQ.'KCON') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
         READ(NAIBU,'(BN,I20)') KCONT
         WRITE(6,*) ' CONTINUATION? KCONT =  ', KCONT
      ELSEIF(ASAVE(L)(1:4).EQ.'OKST') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') OKSTEP
         READ(NAIBU,*) OKSTEP
         WRITE(6,*) ' AT G-OPT INITIAL DISPLACEMENT IS ',OKSTEP
      ELSEIF(ASAVE(L)(1:4).EQ.'ALAT') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') CELLDM(1)
         READ(NAIBU,*) CELLDM(1)
         WRITE(6,*) ' LATTICE CONSTANT ',CELLDM(1)
      ELSEIF(ASAVE(L)(1:4).EQ.'ZVAL') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') ZVAL
         READ(NAIBU,*) ZVAL
         WRITE(6,*) ' #CHARGE IS ',ZVAL
      ELSEIF(ASAVE(L)(1:4).EQ.'DUAL') THEN
         IOPT(5,2)=1
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') GRAT
         READ(NAIBU,*) GRAT
         WRITE(6,*) ' DUAL SPACE FORMALISM RATIO = ',GRAT
         IF(GRAT.EQ.0.D0) GRAT=1.D0
      ELSEIF(ASAVE(L)(1:4).EQ.'NBND') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
         READ(NAIBU,'(BN,I20)') NBND
         WRITE(6,*) ' #OCCUPIED BAND IS ',NBND
      ELSEIF(ASAVE(L)(1:4).EQ.'RCUT') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') RCUT
         READ(NAIBU,*) RCUT
         WRITE(6,*) ' RCUT**2 IS (AU) ',RCUT
      ELSEIF(ASAVE(L)(1:4).EQ.'GCUT') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
c         READ(NAIBU,'(BN,E20.0)') GCUT2
         READ(NAIBU,*) GCUT2
         WRITE(6,*) ' GCUT2 IS ',GCUT2
c **** Miyamoto
      elseif(asave(l)(1:2).eq.'ST') then
         if(asave(l)(3:4).eq.'ND') then
          iopt(1,2)=99
          write(6,*) ' ****  Standard inputs !!!! *****'
         end if
c
      ELSEIF(ASAVE(L)(1:2).EQ.'AL') THEN
            IOPT(1,2)=11
            WRITE(6,*) ' AL FCC LATTICE'
      ELSEIF(ASAVE(L)(1:2).EQ.'CB') THEN
            IOPT(1,2)=30
            WRITE(6,*) ' CRISTOBALITE'
      ELSEIF(ASAVE(L)(1:2).EQ.'SI') THEN
         IF(ASAVE(L)(3:4).EQ.'TE') THEN
            IOPT(1,2)=1
            WRITE(6,*) ' SITEST CALCULATION'
         ELSEIF(ASAVE(L)(3:4).EQ.'O2') THEN
            IOPT(1,2)=2
            WRITE(6,*) ' SIO2 '
         ELSEIF(ASAVE(L)(3:4).EQ.'EP') THEN
            IOPT(1,2)=13
            WRITE(6,*) ' SUPER CELL CALCULATION FOR A-QUARTZ'
         ELSEIF(ASAVE(L)(3:5).EQ.'GEH') THEN
            IOPT(1,2)=21
            WRITE(6,*) ' SI/GE + H '
         ELSEIF(ASAVE(L)(3:3).EQ.'8') THEN
            IOPT(1,2)=5
            WRITE(6,*) ' SI8 CUBIC LATTICE'
         ELSEIF(ASAVE(L)(3:3).EQ.'2') THEN
            IOPT(1,2)=0
            WRITE(6,*) ' SI2 LATTICE'
         ELSEIF(ASAVE(L)(3:5).EQ.'SL5') THEN
            IOPT(1,2)=6
            WRITE(6,*) ' 5-LAYER SLAB CALCULATIONS'
         ELSEIF(ASAVE(L)(3:6).EQ.'SLH1') THEN
            IOPT(1,2)=8
            WRITE(6,*) ' H-TERMINATED SLAB CALCULATIONS: 1'
         ELSEIF(ASAVE(L)(3:6).EQ.'SLH2') THEN
            IOPT(1,2)=3
            WRITE(6,*) ' H-TERMINATED SLAB CALCULATIONS: 2'
         ELSEIF(ASAVE(L)(3:6).EQ.'SLH3') THEN
            IOPT(1,2)=4
            WRITE(6,*) ' H-TERMINATED SLAB CALCULATIONS: 3'
         ELSEIF(ASAVE(L)(3:6).EQ.'SLH4') THEN
            IOPT(1,2)=10
            WRITE(6,*) ' H-TERMINATED VICINAL SURFACE CALCULATIONS'
         ELSEIF(ASAVE(L)(3:6).EQ.'SLH5') THEN
            IOPT(1,2)=12
            WRITE(6,*) ' H-TERMINATED (1,1,10) VICINAL SURFACE '
         ELSEIF(ASAVE(L)(3:4).EQ.'H4') THEN
            IOPT(1,2)=9
            WRITE(6,*) ' SIH4(CUBIC CELL) CALCULATIONS'
         ELSE
            WRITE(6,*) ' SUCH A LATTICE IS NOT SUPPORTED HERE '
            STOP
         ENDIF
      ELSEIF(ASAVE(L)(1:2).EQ.'KP') THEN
         IF(BSAVE(L)(1:1).EQ.'0') THEN
            IOPT(2,2)=0
            WRITE(6,*) ' INTERNAL SAMPLING FOR K-VECTORS'
         ELSEIF(BSAVE(L)(1:1).EQ.'1') THEN
            IOPT(2,2)=1
            WRITE(6,*) ' GAMMA SAMPLING '
         ELSEIF(BSAVE(L)(1:1).EQ.'2') THEN
            IOPT(2,2)=2
            WRITE(6,*) ' # OF K-POINT = 2 '
         ELSEIF(BSAVE(L)(1:1).EQ.'4') THEN
            IOPT(2,2)=4
            WRITE(6,*) ' # OF K-POINT = 4 '
         ELSEIF(BSAVE(L)(1:1).EQ.'M') THEN
            IOPT(2,2)=100
            WRITE(6,*) ' MESH SAMPLING FOR K-VECTROS'
         ELSE
            WRITE(6,*) ' SUCH A KPOINT SAMPLING IS NOT SUPPORTED HERE'
            STOP
         ENDIF
C
      ELSEIF(ASAVE(L)(1:5).EQ.'METAL') THEN
         IF(INDEX(BSAVE(L),',').NE.0) THEN
            I1=INDEX(BSAVE(L),'(')+1
            I2=INDEX(BSAVE(L),',')-1
            WRITE(NAIBU,'(A20)') BSAVE(L)(I1:I2)
            READ(NAIBU,'(BN,I20)') NFL
            I1=INDEX(BSAVE(L),',')+1
            I2=INDEX(BSAVE(L),')')-1
            WRITE(NAIBU,'(A20)') BSAVE(L)(I1:I2)
            READ(NAIBU,'(BN,I20)') NPFL
         ELSE
            WRITE(6,*) ' ******  CHECK YOUR INPUT... METAL = ?'
            STOP
         ENDIF
            WRITE(6,*) ' METAL CASE: NFL NPFL = ', NFL, NPFL
C
      ELSEIF(ASAVE(L)(1:5).EQ.'FORCE') THEN
         I0=INDEX(BSAVE(L),'(')+1
         I9=INDEX(BSAVE(L),')')-1
         I1=INDEX(BSAVE(L),',')
         I2=INDEX(BSAVE(L)(I1+1:I9),',')+I1
         I3=INDEX(BSAVE(L)(I2+1:I9),',')+I2
         NFIX=NFIX+1
         WRITE(NAIBU,'(A20)') BSAVE(L)(I0:I1-1)
         READ(NAIBU,'(BN,I20)') IFATM(NFIX)
         WRITE(NAIBU,'(A20)') BSAVE(L)(I1+1:I2-1)
         READ(NAIBU,'(BN,F20.0)') XX
         WRITE(NAIBU,'(A20)') BSAVE(L)(I2+1:I3-1)
         READ(NAIBU,'(BN,F20.0)') YY
         WRITE(NAIBU,'(A20)') BSAVE(L)(I3+1:I9)
         READ(NAIBU,'(BN,F20.0)') ZZ
         RR=SQRT(XX**2+YY**2+ZZ**2)
         IF(RR.LT.1.D-5) THEN
            RR=0.D0
            IFATM(NFIX)=-IFATM(NFIX)
         ELSE
            RR=1.D0/RR
         ENDIF
         FATM(1,NFIX)=XX*RR
         FATM(2,NFIX)=YY*RR
         FATM(3,NFIX)=ZZ*RR
         WRITE(6,'('' FIXED ATOM '',2I5,3F15.7)')
     &               NFIX,IFATM(NFIX),XX,YY,ZZ
      ELSEIF(ASAVE(L)(1:5).EQ.'MAXG2') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
         READ(NAIBU,'(BN,I20)') MAXG2
         WRITE(6,*) ' #MAXG2 IS ',MAXG2
      ELSEIF(ASAVE(L)(1:5).EQ.'OUTWF') THEN
         WRITE(NAIBU,'(A20)') BSAVE(L)
         READ(NAIBU,'(BN,I20)') ITEMP
         WRITE(6,*) ' WRITE WF TO FILE ',ITEMP
         IOPT(4,2)=ITEMP
      ELSE
         WRITE(6,*) ' OPTION ',ASAVE(L),' IS NOT SUPPORTED'
      ENDIF
 3000 CONTINUE
      WRITE(6,3002)
 3002 FORMAT(' ------------',
     &'------------------------------------------------------------'//)
      RETURN
      END
C*************************************************************
      SUBROUTINE CRYST(NRX,NRY,NRZ,NXYZ,NG,NGQ,
     & NBNDQ,NBND,ZVAL,NFL, NPFL, NUMK,
     & NUMKQ,CELLDM,NTOT,S,VECK,WGT,G,I2G,OMEGA,GCUT,
     & GCUT2,GRAT,GG,I2GG,INDX,OCC,
     & LATQ,RVEC,RCUT,NLV,RR,NWK,
     & NTAUQ,NTYQ,NTYPE,TAU, CTAU, NUMTY,NIDN,
     & RKK,KG,KZ,NSY,NEXPND,
     & RCOSIN,CCO,NKMESH,SK,WK,JDR,MM,NJD, NDX, NDY, NDZ, MXOFL )
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
     &        , CTAU(3,NTAUQ), MXOFL(NTYQ)
      COMMON/AVEC/A1(3),A2(3),A3(3),B1(3),B2(3),B3(3),COVA,ALAT
      DIMENSION G(4,NGQ),CELLDM(6)
      DIMENSION GG(4,NGQ),I2GG(NGQ),INDX(NGQ)
      DIMENSION VECK(3,NUMKQ),WGT(NUMKQ),I2G(NGQ)
      DIMENSION RR(LATQ),NWK(LATQ),RVEC(4,LATQ),OCC(NBNDQ,NUMKQ)
      INTEGER*4 S(3,3,48)
      INTEGER PGIND, RIND(32)
      COMMON/COMOPT/IOPT(10,5)
      PARAMETER (IRLATQ=144,NARF=IRLATQ)
      PARAMETER (NAS=144,NAD=72)
      DIMENSION RKK(IRLATQ),KG(3,IRLATQ),KZ(3,IRLATQ,48),NSY(IRLATQ)
      DIMENSION RCOSIN(NAS,IRLATQ),CCO(-NAD:NAD),SK(3,NAS),WK(NAS),
     &          JDR(48,NAS),MM(3,10000),NJD(NAS)
      DATA RIND/5*1,2*3,6*2,4*1,3*2,7*1,2*2,3*1/
C
C**********************************************************
C     SETS UP THE BASIS VECTORS AND INITIAL GEOMETRY.
      CALL STRUC(CELLDM,IBRAV,PGIND,NK,NBNDQ,NBND,ZVAL,GCUT,
     &  GCUT2,GRAT,A1,A2,A3,OMEGA,OCC,NUMKQ,
     &  NTAUQ,NTYQ,TAU,NTYPE,NUMTY,NIDN, MXOFL, COVA, ALAT )
C
      WRITE(6,3001) IBRAV,PGIND,NFL,NBND,NPFL,NK,RCUT,GCUT,GCUT2
 3001 FORMAT(/' IBRAV = ',I3,' PGIND = ',I3,' NFL = ',I3,
     &       ' NBND = ',I3,' NPFL = ',I3,' NK = ',I3/
     &       ' RCUT = ',F15.7,' GCUT = ',F15.7,' GCUT2 = ',F15.7)
      WRITE(6,3002) (A1(I),A2(I),A3(I),I=1,3),OMEGA
 3002 FORMAT(' A-VECTORS'/,3(' ',3F15.7/),' OMEGA=',F15.7)
C**************ROTATION MATRIX S**********************
C     OBTAIN THE ROTATION MATRIX(IN REAL SPACE)
C
      IF( IOPT(1,2) .EQ. 0 ) THEN
         CALL SMAT(PGIND,S,NTOT,IBRAV)
C
C    **     NO SYMMETRY IS ASSUMED
CARE  ELSEIF( IOPT(1,2).EQ.5 .OR. IOPT(1,2).EQ.11 .OR.
C    &        IOPT(1,2).EQ.8 .OR. IOPT(1,2).EQ.9  ) THEN
      ELSEIF( IOPT(1,2).EQ.5 .OR. IOPT(1,2).EQ.11 .OR.
     &        IOPT(1,2).EQ.8 .OR. IOPT(1,2).EQ.3  .OR.
     &        IOPT(1,2).EQ.4 .OR. IOPT(1,2).EQ.10 .OR.
     &        IOPT(1,2).EQ.12 .OR. IOPT(1,2).EQ.1 .OR.
     &        IOPT(1,2).EQ.2  .OR. IOPT(1,2).EQ.21 .OR.
     &        IOPT(1,2).EQ.13 .OR. IOPT(1,2).EQ.30     ) THEN
        NTOT=1
        DO 53 I3=1,NTOT
        DO 53 I2=1,3
        DO 53 I1=1,3
          S(I1,I2,I3)=0
   53   CONTINUE
        DO 54 I1=1,3
          S(I1,I1,1)=1
   54   CONTINUE
C
      ELSE IF(IOPT(1,2).EQ.6) THEN
C ******   D2D SYMMETRY FOR A1=(0.5,0.5,0), A2=(-0.5,0.5,0)
C                           A3=(0,0,1)
        NTOT=8
          DO 60 IOP = 1, NTOT
          DO 60 K1 = 1, 3
          DO 60 K2 = 1, 3
   60     S(K1,K2,IOP) = 0
        DO 62 K1 = 1, 3
   62   S(K1,K1,1) = 1
C ***      3C(2)
        S(1,2,2) = -1
        S(2,1,2) = -1
        S(3,3,2) = -1
C
        S(1,2,3) =  1
        S(2,1,3) =  1
        S(3,3,3) = -1
C
        S(1,1,4) = -1
        S(2,2,4) = -1
        S(3,3,4) =  1
C ***     2 MIRRORS
        S(1,1,5) =  1
        S(2,2,5) = -1
        S(3,3,5) =  1
C
        S(1,1,6) = -1
        S(2,2,6) =  1
        S(3,3,6) =  1
C ***     2 ADDITIONAL S(4)
        S(1,2,7) = -1
        S(2,1,7) =  1
        S(3,3,7) = -1
C
        S(1,2,8) =  1
        S(2,1,8) = -1
        S(3,3,8) = -1
      ELSE IF(IOPT(1,2).EQ.9) THEN
C ******   D2D SYMMETRY FOR A1=(1,0,0), A2=(0,1,0)
C                           A3=(0,0,1)
        NTOT=8
          DO 360 IOP = 1, NTOT
          DO 360 K1 = 1, 3
          DO 360 K2 = 1, 3
  360     S(K1,K2,IOP) = 0
        DO 362 K1 = 1, 3
  362   S(K1,K1,1) = 1
C ***      3C(2)
        S(1,1,2) =  1
        S(2,2,2) = -1
        S(3,3,2) = -1
C
        S(1,1,3) = -1
        S(2,2,3) =  1
        S(3,3,3) = -1
C
        S(1,1,4) = -1
        S(2,2,4) = -1
        S(3,3,4) =  1
C ***     2 MIRRORS
        S(1,2,5) =  1
        S(2,1,5) =  1
        S(3,3,5) =  1
C
        S(1,2,6) = -1
        S(2,1,6) = -1
        S(3,3,6) =  1
C ***     2 ADDITIONAL S(4)
        S(1,2,7) =  1
        S(2,1,7) = -1
        S(3,3,7) = -1
C
        S(1,2,8) = -1
        S(2,1,8) =  1
        S(3,3,8) = -1
c ***  Miyamoto 
      elseif ( iopt(1,2).eq.99 ) then
       write(6,*)' Read S-matrices fron file !!'
       read(55,*)ntot
       do 199 ir=1,ntot
        read(55,*)irot,((s(i,j,ir),j=1,3),i=1,3)
  199  continue
      ELSE
        WRITE(6,*) '  ***  IOPT(1,2) = ', IOPT(1,2), ' NOT PROGRAMED'
        STOP
      ENDIF
C
      WRITE(6,*) ' # OF SYMMETRY OPERATIONS: NTOT = ',NTOT
      WRITE(6,*) ' S MATRICES: OP  1ST RAW   2ND RAW   3RD RAW'
      DO 6662 I3 = 1, NTOT
 6662 WRITE(6,6660) I3, (  (S(I1,I2,I3),I2=1,3), I1=1,3)
 6660 FORMAT( 7X,I3,3X,3(2X,3I3) )
      WRITE(6,*) ' '
C******************************************************
C     GENERATE ALL LATTICE VECTORS INSIDE A RADIUS RCUT
      CALL LVGEN(A1,A2,A3,LATQ,NLV,RCUT,RVEC,RR,NWK)
      WRITE(6,*) '   # OF LATTICE VECTORS: NLV = ',NLV
C***********************************************************
C     GENERATE ALL RECIPROCAL LATTICE VECTORS INSIDE GCUT
      CALL GGEN(CELLDM(1),A1,A2,A3,B1,B2,B3,NRX,NRY,NRZ,NXYZ,
     &          NG,NGQ,G,I2G,GCUT,GG,I2GG,INDX)
C**************SYMMETRY BUSINESS***********************
C
      IF(NTOT.NE.1) CALL SMATCHK2( S, TAU, CTAU, B1, B2, B3, CELLDM(1),
     &                            NTOT, NTAUQ )
C
C     GENERATE VECK'S AND WEIGHTS WITHIN IRREDUCIBLE BZ
      IF( IOPT(2,2).EQ.0 ) THEN
        CALL KWGT( NUMKQ, VECK, WGT, NK, IBRAV, CELLDM, OMEGA,
     &             RIND(PGIND), NUMK )
C *******   SUM OF WGT OVER NUMK SHOULD BE THE INVERSE OF OMEGA
             DO 7002 IK = 1, NUMK
 7002        WGT(IK) = DBLE(NTOT) * WGT(IK)
C               ALSO NKMESH WHICH IS NOT ESSENTIALLY USED SHOULD NOT
C               BE ZERO IN NONLOCF
             NKMESH = 1
C *******
        DO 7000 IK = 1, NUMK
 7000   WK(IK) = OMEGA * WGT(IK)
      ELSE IF( IOPT(2,2) .EQ. 100 ) THEN
        CALL LVGENX(A1,A2,A3,S,NTOT,RKK,KG,KZ,NSY,NEXPND)
        CALL MESHK(S,NTOT,NUMK,NKMESH,KG,NEXPND,MM,RCOSIN,JDR,SK,
     &           WK,NJD,CCO, NDX, NDY, NDZ )
C
CARE ****
c **** Miyamoto 9/6/95
c        read(5,*)nexpnd
            IF( NUMK.LT.NEXPND ) THEN
               NEXPND = MIN( NUMK, NEXPND )
               WRITE(6,6600) NEXPND
 6600          FORMAT(/20X,'  ****  CRYST: NEXPND CHANGED TO BE ',I3)
             ELSE
             END IF
CARE         NEXPND = 10
CARE END *****
C
        DO 55 IK=1,NUMKQ
          VECK(1,IK)=0.D0
          VECK(2,IK)=0.D0
          VECK(3,IK)=0.D0
          WGT(IK)=0.D0
 55     CONTINUE
        DO 56 IK=1,NUMK
          VECK(1,IK)=SK(1,IK)*B1(1)+SK(2,IK)*B2(1)+SK(3,IK)*B3(1)
          VECK(2,IK)=SK(1,IK)*B1(2)+SK(2,IK)*B2(2)+SK(3,IK)*B3(2)
          VECK(3,IK)=SK(1,IK)*B1(3)+SK(2,IK)*B2(3)+SK(3,IK)*B3(3)
          WGT(IK)=WK(IK)/OMEGA
 56     CONTINUE
      ELSEIF(IOPT(2,2).EQ.1) THEN
         NUMK=1
         NKMESH = 1
CARE
           IF( IOPT(1,2) .EQ. 2 ) THEN
C ** HEXAGONAL ONE SPECIAL POINT
             OTH = 0.333333333333333D+00
             VECK(1,1) = OTH
             VECK(2,1) = OTH / SQRT(3.0D+00)
             VECK(3,1) = 0.25D+00 / COVA
           ELSE IF(IOPT(1,2) .EQ. 30 ) THEN
C ** TETRAGONAL ONE SPECIAL POINT
             VECK(1,1) =  0.25d+00
             VECK(2,1) =  0.25d+00
             VECK(3,1) =  0.25D+00 / COVA
           ELSE IF(IOPT(1,2) .EQ. 13 ) THEN
C ** TRICLINIC SUPERCELL
             OTH = 1.0D+00 / 9.0D+00
             VECK(1,1) = - OTH
             VECK(2,1) =   OTH * SQRT(3.0D+00)
             VECK(3,1) =   2.0D+00 * OTH / COVA
           ELSE
C **  GAMMA POINT
             VECK(1, 1)=0.000D0
             VECK(2, 1)=0.000D0
             VECK(3, 1)=0.000D0
           END IF
C **
         WGT( 1)=1.D0/(OMEGA)
         WK( 1)=1.D0
      ELSEIF(IOPT(2,2).EQ.2) THEN
         STOP ' NUMK=2 IS NOT SUPPORTED'
      ELSEIF(IOPT(2,2).EQ.3) THEN
         NUMK=3
         VECK(1, 1)=0.125D0
         VECK(2, 1)=0.000D0
         VECK(3, 1)=0.000D0
         WGT( 1)=1.D0/(3.D0*OMEGA)
         WK( 1)=1.D0/3.D0
         VECK(1, 2)=0.000D0
         VECK(2, 2)=0.125D0
         VECK(3, 2)=0.000D0
         WGT( 2)=1.D0/(3.D0*OMEGA)
         WK( 2)=1.D0/3.D0
         VECK(1, 3)=0.000D0
         VECK(2, 3)=0.000D0
         VECK(3, 3)=0.125D0
         WGT( 3)=1.D0/(3.D0*OMEGA)
         WK( 3)=1.D0/3.D0
      ELSEIF(IOPT(2,2).EQ.4) THEN
         NUMK=4
         VECK(1, 1)= 0.25D0
         VECK(2, 1)= 0.25D0
         VECK(3, 1)= 0.25D0
         WGT( 1)=1.D0/(4.D0*OMEGA)
         WK( 1)=1.D0/4.D0
         VECK(1, 2)=-0.25D0
         VECK(2, 2)= 0.25D0
         VECK(3, 2)= 0.25D0
         WGT( 2)=1.D0/(4.D0*OMEGA)
         WK( 2)=1.D0/4.D0
         VECK(1, 3)= 0.25D0
         VECK(2, 3)=-0.25D0
         VECK(3, 3)= 0.25D0
         WGT( 3)=1.D0/(4.D0*OMEGA)
         WK( 3)=1.D0/4.D0
         VECK(1, 4)= 0.25D0
         VECK(2, 4)= 0.25D0
         VECK(3, 4)=-0.25D0
         WGT( 4)=1.D0/(4.D0*OMEGA)
         WK( 4)=1.D0/4.D0
      ELSEIF(IOPT(2,2).EQ.6) THEN
         NUMK=4
         VECK(1, 1)= 0.25D0
         VECK(2, 1)= 0.25D0
         VECK(3, 1)= 0.25D0
         WGT( 1)=1.D0/(4.D0*OMEGA)
         WK( 1)=1.D0/4.D0
         VECK(1, 2)=-0.25D0
         VECK(2, 2)= 0.25D0
         VECK(3, 2)= 0.25D0
         WGT( 2)=1.D0/(4.D0*OMEGA)
         WK( 2)=1.D0/4.D0
         VECK(1, 3)= 0.25D0
         VECK(2, 3)=-0.25D0
         VECK(3, 3)= 0.25D0
         WGT( 3)=1.D0/(4.D0*OMEGA)
         WK( 3)=1.D0/4.D0
         VECK(1, 4)= 0.25D0
         VECK(2, 4)= 0.25D0
         VECK(3, 4)=-0.25D0
         WGT( 4)=1.D0/(4.D0*OMEGA)
         WK( 4)=1.D0/4.D0
      ELSEIF(IOPT(2,2).EQ.5) THEN
         NUMK=4
         VECK(1, 1)= 1.D0/SQRT(32.D0)
         VECK(2, 1)= 1.D0/SQRT(32.D0)
         VECK(3, 1)= 1.D0/8.D0
         WGT( 1)=1.D0/(4.D0*OMEGA)
         WK( 1)=1.D0/4.D0
         VECK(1, 2)=-1.D0/SQRT(32.D0)
         VECK(2, 2)= 1.D0/SQRT(32.D0)
         VECK(3, 2)= 1.D0/8.D0
         WGT( 2)=1.D0/(4.D0*OMEGA)
         WK( 2)=1.D0/4.D0
         VECK(1, 3)= 1.D0/SQRT(32.D0)
         VECK(2, 3)=-1.D0/SQRT(32.D0)
         VECK(3, 3)= 1.D0/8.D0
         WGT( 3)=1.D0/(4.D0*OMEGA)
         WK( 3)=1.D0/4.D0
         VECK(1, 4)=-1.D0/SQRT(32.D0)
         VECK(2, 4)=-1.D0/SQRT(32.D0)
         VECK(3, 4)= 1.D0/8.D0
         WGT( 4)=1.D0/(4.D0*OMEGA)
         WK( 4)=1.D0/4.D0
      ENDIF
         IF(NUMK.LE.0.OR.NUMK.GT.NUMKQ) STOP ' NUMK '
C
      DO 811 IK=1,NUMK
  811 WRITE(6,812) IK,(VECK(KK,IK),KK=1,3)
  812 FORMAT(' ***   CRYST: VECK(',I2,') =',3(F10.5,3X))
      DO 3004 K2 = 1, NUMK
 3004 WRITE(6,3003) K2, ( OCC(K1,K2), K1 = 1, NFL + NPFL ) 
 3003 FORMAT(' OCC: K2 = ',I3/(7X,5F12.4))
C
      RETURN
      END
C**********************************************************
      SUBROUTINE STRUC(CELLDM,IBRAV,PGIND,NK,NBNDQ,NBND,ZVAL,
     &  GCUT,GCUT2,GRAT,A1,A2,A3,OMEGA,OCC,NUMKQ,
     &  NTAUQ,NTYQ,
     &  TAU,NTYPE,NUMTY,NIDN, MXOFL, COVA, ALAT )
      IMPLICIT REAL*8 (A-H,O-Z)
C
      PARAMETER (ZERO=0.D0, UM=1.D0, TRES=3.D0)
C
      CHARACTER*1 IOP(3,3),JOP(3),IP
      DIMENSION AVEC(3,3),RAT(3),DRAT(3)
      REAL*8 CELLDM(6)
      INTEGER PGIND
      DIMENSION TAU(3,NTAUQ),NUMTY(NTYQ),NIDN(NTAUQ,NTYQ)
     &         ,OCC(NBNDQ,NUMKQ), MXOFL(NTYQ)
      DIMENSION A1(3),A2(3),A3(3)
      COMMON/COMOPT/IOPT(10,5)
      PI=4.D0*ATAN(1.D0)
C   FOLLOWING PARAMETER (IBRAV,PGIND,NK) IS VALID IN SI2 CALCULATION
C     IBRAV=FCC TYPE BRAVAIS LATTICE
      IBRAV=0
      NK = 0
C     PGIND IS THE POINT-GROUP INDEX, WHICH DETERMINES THE IRREDUCIBLE
C     WEDGE FOR THE GIVEN STRUCTURE.
C
C     POINT GROUP CHARACTERISTIC IS OF TD.
      PGIND=0
C
C     CELLDM(1) IS THE LATTICE CONSTANT (THE STANDARD CRYSTALLOGRAPHIC
C     BASAL-PLANE DIMENSION A) IN ATOMIC UNITS.
C     REQUIRED VALUES OF CELLDM(I),I>1 ARE GIVEN IN THE TABLE BELOW FOR
C     EACH POINT GROUP AND BRAVAIS LATTICE.
C
C
C     SI-SI DISTANCE
C     RSI=4.44D0
C     SIMPLE CUBIC LATTICE,  EIGHT ATOMS IN A UNIT CELL
CELLDM(1)=ALAT
CELLDM(2)=B/A
CELLDM(3)=C/A
CELLDM(4)=COS(BC)
CELLDM(5)=COS(AC)
CELLDM(6)=COS(AB)
C     Alat=RSI/(SQRT(3.D0)*0.25D0)
C                      /VACANCY/ LATTICE CONSTANT
      ALAT=CELLDM(1)
C
C
      IF(IOPT(5,2).EQ.0) THEN
         GCUT=(GCUT2*4.D0)/((PI*2.D0/CELLDM(1))**2 )
      ELSE
         WRITE(6,*) ' !!! DUAL SPACE FORMALISM MAY NOT WORK WELL !!!'
         GCUT=(GCUT2*GRAT)/((PI*2.D0/CELLDM(1))**2 )
      ENDIF
C
c          IF( ZVAL.LT.0.1D00 ) STOP ' **  STRUC:  ZVAL = 0 ???'
c          NBND =  ZVAL + 0.1D-04
c          IF( MOD(NBND,2) .EQ. 0 ) THEN
c               IFLAG = 0
c               NBND = NBND / 2
c          ELSE
c               IFLAG = 1
c               NBND = NBND / 2 + 1
c          END IF
c                    DO 120 K=1,NUMKQ
c                    DO 120 I=1,NBNDQ
c  120               OCC(I,K)=0.D0
c          DO 121 K=1,NUMKQ
c          DO 122 I=1,NBND
c  122     OCC(I,K)=1.D0
c          IF( IFLAG .EQ. 1) OCC(NBND,K) = 0.5D+00
c  121     CONTINUE
C
          IF( ZVAL.LT.0.1D00 ) STOP ' **  STRUC:  ZVAL = 0 ???'
C
      nbnd=zval
      rest=zval-1.d0*nbnd
      if ( mod(nbnd,2).eq.0 ) then
        if ( rest.lt.1.d-08 ) then
         nbnd=nbnd/2
         rest=0.d0
         IFLAG=0
        else
         IFLAG=1
         nbnd=nbnd/2+1
         rest=zval/2.d0-(nbnd-1)*1.d0
        endif
      elseif ( mod(nbnd,2).eq.1 ) then
         IFLAG=1
         nbnd=nbnd/2+1
         rest=zval/2.d0-(nbnd-1)*1.d0
      endif
                    DO 120 K=1,NUMKQ
                    DO 120 I=1,NBNDQ
  120               OCC(I,K)=0.D0
          DO 121 K=1,NUMKQ
          DO 122 I=1,NBND
  122     OCC(I,K)=1.D0
          IF( IFLAG .EQ. 1) OCC(NBND,K) = rest
  121     CONTINUE
C
C
C
C     THERE ARE ONE TYPE OF ATOMS.
C
      IF(IOPT(1,2).EQ.0) THEN
C   SI 2
        IBRAV = 2
        PGIND = 31
        NK = 3
        NTYPE=1
        NUMTY(1)=NTAUQ
        DO 711 I=1,NTAUQ
  711   NIDN(I,1)=I
        MXOFL(1) = 2
        DO 712 IR=1,3
        A1(IR)=0.D0
        A2(IR)=0.D0
  712   A3(IR)=0.D0
C     IBRAV=2:FCC
C     A1=(-A/2,  0,A/2)
C     A2=(   0,A/2,A/2)
C     A3=(-A/2,A/2,  0)
        TERM=CELLDM(1)/2.D0
        A1(1)=-TERM
        A1(3)=TERM
        A2(2)=TERM
        A2(3)=TERM
        A3(1)=-TERM
        A3(2)=TERM
        TAU(1,1)=0.D0
        TAU(2,1)=0.D0
        TAU(3,1)=0.D0
        TAU(1,2)=ALAT/4.D0
        TAU(2,2)=ALAT/4.D0
        TAU(3,2)=ALAT/4.D0
      ELSEIF(IOPT(1,2).EQ.1) THEN
C   ***   SITEST:   SI2 CASE
        NTYPE=1
        NUMTY(1)=NTAUQ
        DO 731 I=1,NTAUQ
  731   NIDN(I,1)=I
        MXOFL(1) = 2
        DO 732 IR=1,3
        A1(IR)=0.D0
        A2(IR)=0.D0
  732   A3(IR)=0.D0
C     A1=( A/2,   0, A/2)
C     A2=( A/2, A/2,   0)
C     A3=(   0, A/2, A/2)
        TERM=CELLDM(1)/2.D0
        A1(1) =  TERM
        A1(3) =  TERM
        A2(1) =  TERM
        A2(2) =  TERM
        A3(2) =  TERM
        A3(3) =  TERM
        TAU(1,1)=0.D0
        TAU(2,1)=0.D0
        TAU(3,1)=0.D0
        TAU(1,2)=ALAT/4.D0
        TAU(2,2)=ALAT/4.D0
        TAU(3,2)=ALAT/4.D0
      ELSEIF(IOPT(1,2).EQ.2 .OR. IOPT(1,2).EQ.30 ) THEN
C  **           O2 OR SIO2
C         O2
CARE    NTYPE = 1
C       NUMTY(1) = NTAUQ
C       MXOFL(1) = 1
C       DO 800 IR=1,3
C       A1(IR)=0.D0
C       A2(IR)=0.D0
C 800   A3(IR)=0.D0
C       DO 810 I = 1, abs( NUMTY(1) )
C 810   NIDN(I,1) = I
C       A1(1) =  ALAT
C       A2(2) =  ALAT
C       A3(3) =  ALAT
C       READ(5,*) DIST
C
C       DO 820 K = 1, 3
C       DO 820 ITAU = 1, NUMTY(1)
C 820   TAU(K,ITAU) = 0.0D+00
C       TAU(3,1) =   0.5D+00 * DIST
C       TAU(3,2) = - 0.5D+00 * DIST
CARE  **  ALPHA QUARTZ or CRISTOBALITE
        NTYPE = 2
        NUMTY(1) = NTAUQ / 3
        NUMTY(2) = 2 * NUMTY(1)
          NUMCHK = NUMTY(1) + NUMTY(2)
          IF( NUMCHK .NE. NTAUQ ) THEN
             WRITE(6,801) NUMTY(1), NUMTY(2), NTAUQ
  801        FORMAT(' ** STRUC  SIO2:  NUMTY(1) NUMTY(2) NTAUQ = ',3I5)
             STOP
          END IF
        MXOFL(1) = 2
        MXOFL(2) = 1
        DO 800 IR=1,3
        A1(IR)=0.D0
        A2(IR)=0.D0
  800   A3(IR)=0.D0
        DO 810 I = 1, NUMTY(1)
  810   NIDN(I,1) = I
        DO 812 I = 1, NUMTY(2)
  812   NIDN(I,2) = I + NUMTY(1)
        READ(5,*) COVA, U, X, Y, Z
          if( iopt(1,2) .eq. 2 ) then
        A1(1) =                    0.5D+00 * ALAT
        A1(2) = - 0.5D+00 * SQRT(3.0D+00 ) * ALAT
        A2(1) =                    0.5D+00 * ALAT
        A2(2) =   0.5D+00 * SQRT(3.0D+00 ) * ALAT
        A3(3) =                       COVA * ALAT
C
        OTH = 0.3333333333333333D+00
        DO 820 K = 1, 3
        TAU(K,1) = - U * ( A1(K) + A2(K) ) + OTH * A3(K)
        TAU(K,2) =   U * A1(K)
        TAU(K,3) =   U * A2(K) - OTH * A3(K)
        TAU(K,4) =   X * A1(K) + Y * A2(K) + Z * A3(K)
        TAU(K,5) =   (Y-X) * A1(K) - X * A2(K) + (Z+OTH) * A3(K)
        TAU(K,6) = - Y * A1(K) + (X-Y) * A2(K) + (Z-OTH) * A3(K)
        TAU(K,7) =   (X-Y) * A1(K) - Y * A2(K) - Z * A3(K)
        TAU(K,8) =   Y * A1(K) + X * A2(K) - (Z+OTH) * A3(K)
  820   TAU(K,9) = - X * A1(K) + (Y-X) * A2(K) - (Z-OTH) * A3(K)

Care *** Tau for Cristobalite  by A.Yokozawa *****   

            else if( iopt(1,2) .eq. 30 ) then
        A1(1) =    ALAT
        A2(2) =    ALAT
        A3(3) =    COVA * ALAT
        DO 823 K = 1, 3
        TAU(K, 1) =   U * ( A1(K) + A2(K) )
        TAU(K, 2) =  -U * ( A1(K) + A2(K) ) + 0.5 * A3(K)
        TAU(K, 3) =  (0.5-U) * A1(K) + (0.5+U) * A2(K) - 0.25 * A3(K)
        TAU(K, 4) =  (0.5+U) * A1(K) + (0.5-U) * A2(K) + 0.75 * A3(K)
        TAU(K, 5) =   X * A1(K) + Y * A2(K) + Z * A3(K)
        TAU(K, 6) =  -X * A1(K) - Y * A2(K) + (0.5+Z) * A3(K)
        TAU(K, 7) =  (0.5-Y) * A1(K) + (0.5+X) * A2(K)+(Z+0.25) * A3(K)
        TAU(K, 8) =  (0.5+Y) * A1(K) + (0.5-X) * A2(K)+(Z+0.75) * A3(K)
        TAU(K, 9) =   Y * A1(K) + X * A2(K) - Z * A3(K)
        TAU(K,10) =  -Y * A1(K) - X * A2(K) + (0.5-Z) * A3(K)
        TAU(K,11) =  (0.5-X) * A1(K) + (0.5+Y) * A2(K)+(0.25-Z) * A3(K)
  823   TAU(K,12) =  (0.5+X) * A1(K) + (0.5-Y) * A2(K)+(0.75-Z) * A3(K)
            end if
C
        READ(5,*) IREAD
        IF(IREAD.EQ.1) THEN
          DO 821 I = 1, NTAUQ
  821     READ(76,*) ( TAU(K,I), K = 1, 3 )
        END IF
CARE END
      ELSEIF(IOPT(1,2).EQ.13) THEN
CARE  **  ALPHA QUARTZ:  TRICLINIC SUPER CELL
C        NTYPE = 2
C        NUMTY(1) = NTAUQ / 3
C        NUMTY(2) = 2 * NUMTY(1)
C          NUMCHK = NUMTY(1) + NUMTY(2)
C          IF( NUMCHK .NE. NTAUQ ) THEN
C             WRITE(6,801) NUMTY(1), NUMTY(2), NTAUQ
C             STOP
C          END IF
C        MXOFL(1) = 2
C        MXOFL(2) = 1
C        DO 880 IR=1,3
C        A1(IR)=0.D0
C        A2(IR)=0.D0
C  880   A3(IR)=0.D0
C        DO 882 I = 1, NUMTY(1)
C  882   NIDN(I,1) = I
C        DO 884 I = 1, NUMTY(2)
C  884   NIDN(I,2) = I + NUMTY(1)
C        READ(5,*) COVA
C        A1(1) =                    1.5D+00 * ALAT
C        A1(2) =   0.5D+00 * SQRT(3.0D+00 ) * ALAT
C        A2(2) =             SQRT(3.0D+00 ) * ALAT
C        A3(1) =                    0.5D+00 * ALAT
C        A3(2) =   0.5D+00 * SQRT(3.0D+00 ) * ALAT
C        A3(3) =                       COVA * ALAT
C
C          DO 888 I = 1, NTAUQ
C  888     READ(76,*) ( TAU(K,I), K = 1, 3 )
CARE END
CARE  **  OXYGEN VACANCY IN ALPHA QUARTZ:  TRICLINIC SUPER CELL
        NTYPE = 2
        NUMTY(1) = 9
        NUMTY(2) = 17
        MXOFL(1) = 2
        MXOFL(2) = 1
        DO 880 IR=1,3
        A1(IR)=0.D0
        A2(IR)=0.D0
  880   A3(IR)=0.D0
        DO 882 I = 1, NUMTY(1)
  882   NIDN(I,1) = I
        DO 884 I = 1, NUMTY(2)
  884   NIDN(I,2) = I + NUMTY(1)
        READ(5,*) COVA
        A1(1) =                    1.5D+00 * ALAT
        A1(2) =   0.5D+00 * SQRT(3.0D+00 ) * ALAT
        A2(2) =             SQRT(3.0D+00 ) * ALAT
        A3(1) =                    0.5D+00 * ALAT
        A3(2) =   0.5D+00 * SQRT(3.0D+00 ) * ALAT
        A3(3) =                       COVA * ALAT
C
          DO 888 I = 1, NTAUQ
CC888     READ(76,*) IDUMM, ( TAU(K,I), K = 1, 3 )
  888     READ(76,*) ( TAU(K,I), K = 1, 3 )
CARE END
c ***** Miyamoto
c      for standard inputs
c
      elseif(iopt(1,2).eq.99) then
cccc        read(5,*) alat   ! read in AINPUT
        read(5,*)(avec(i,1),i=1,3)
        read(5,*)(avec(i,2),i=1,3)
        read(5,*)(avec(i,3),i=1,3)
        do 991 i=1,3
         a1(i)=alat*avec(i,1)
         a2(i)=alat*avec(i,2)
         a3(i)=alat*avec(i,3)
  991   continue
        read(5,*)ntype
        ntseq=0
        do 992 ity=1,ntype
         read(5,*)numty(ity),mxofl(ity)
          do 993 it=1,abs( numty(ity) )
           ntseq=ntseq+1
           if (ntseq.gt.ntauq ) then
            write(6,*) ' NTAUQ should be grater than ',ntseq
            stop
           endif
           nidn(it,ity)=ntseq
           read(5,*)(rat(i),i=1,3)
           tau(1,ntseq)=a1(1)*rat(1)+a2(1)*rat(2)+a3(1)*rat(3)
           tau(2,ntseq)=a1(2)*rat(1)+a2(2)*rat(2)+a3(2)*rat(3)
           tau(3,ntseq)=a1(3)*rat(1)+a2(3)*rat(2)+a3(3)*rat(3)
  993     continue
  992   continue
cc
      ELSEIF(IOPT(1,2).EQ.11) THEN
C   AL
        NTYPE=1
        MXOFL(1) = 2
        NUMTY(1)=NTAUQ
        DO 721 I=1,NTAUQ
  721   NIDN(I,1)=I
        READ(5,100) ALAT
        WRITE(6,200) ALAT
        CELLDM(1)=ALAT
C
C     READ THE BASIS VECTORS FOR THE LATTICE (CARTESIAN COORDINATES
C     AND ATOMIC UNITS DIVIDED BY ASCALE). MODIFY ACCORDING TO IOP..
C     MULTIPLY BY ALAT.
C
        READ(5,101) (IOP(I,1),AVEC(I,1),I=1,3)
        READ(5,101) (IOP(I,2),AVEC(I,2),I=1,3)
        READ(5,101) (IOP(I,3),AVEC(I,3),I=1,3)
        DO 10 J=1,3
        DO 10 I=1,3
          SGN=UM
          IF(AVEC(I,J).LT.ZERO) SGN=-UM
          AVEC(I,J)=ABS(AVEC(I,J))
          IF(IOP(I,J).EQ.'S') AVEC(I,J)=SQRT(AVEC(I,J))
          IF(IOP(I,J).EQ.'C') AVEC(I,J)=AVEC(I,J)**(UM/TRES)
          IF(IOP(I,J).EQ.'T') AVEC(I,J)=AVEC(I,J)/TRES
          IF(IOP(I,J).EQ.'H') AVEC(I,J)=AVEC(I,J)/SQRT(TRES)
          AVEC(I,J)=SGN*ALAT*AVEC(I,J)
   10   CONTINUE
        DO 11 I=1,3
          A1(I)=AVEC(I,1)
          A2(I)=AVEC(I,2)
          A3(I)=AVEC(I,3)
   11   CONTINUE
        READ(5,*) NUMAT
        IF(NUMAT.NE.NTAUQ) THEN
          WRITE(6,*) ' ERROR IN NUMBER OF ATOMS '
        ENDIF
        DO 12 JA=1,NTAUQ
          READ(5,101) (JOP(I),RAT(I),I=1,3),IP
          DO 13 I=1,3
            SGN=UM
            IF(RAT(I).LT.ZERO) SGN=-UM
            RAT(I)=ABS(RAT(I))
            IF(JOP(I).EQ.'S') RAT(I)=SQRT(RAT(I))
            IF(JOP(I).EQ.'C') RAT(I)=RAT(I)**(UM/TRES)
            IF(JOP(I).EQ.'T') RAT(I)=RAT(I)/TRES
            RAT(I)=SGN*RAT(I)
   13     CONTINUE
          IF(IP.NE.' ') THEN
            READ(5,101) (JOP(I),DRAT(I),I=1,3)
            DO 14 I=1,3
              SGN=UM
              IF(DRAT(I).LT.ZERO) SGN=-UM
              DRAT(I)=ABS(DRAT(I))
              IF(JOP(I).EQ.'S') DRAT(I)=SQRT(DRAT(I))
              IF(JOP(I).EQ.'C') DRAT(I)=DRAT(I)**(UM/TRES)
              IF(JOP(I).EQ.'T') DRAT(I)=DRAT(I)/TRES
              DRAT(I)=SGN*DRAT(I)
              RAT(I)=RAT(I)+DRAT(I)
   14       CONTINUE
          ENDIF
          TAU(1,JA)=RAT(1)*A1(1)+RAT(2)*A2(1)+RAT(3)*A3(1)
          TAU(2,JA)=RAT(1)*A1(2)+RAT(2)*A2(2)+RAT(3)*A3(2)
          TAU(3,JA)=RAT(1)*A1(3)+RAT(2)*A2(3)+RAT(3)*A3(3)
   12   CONTINUE
        READ(5,*) IBRAV,PGIND
C
      ELSEIF(IOPT(1,2).EQ.5) THEN
C     SI8 CUBIC STRUCTURE
         IBRAV=1
         PGIND=1
         ALAT=CELLDM(1)
         NTYPE=1
         MXOFL(1) = 2
         NUMTY(1)=NTAUQ
         DO 31 I=1,NTAUQ
   31    NIDN(I,1)=I
         DO 32 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
   32    A3(IR)=0.D0
C        CUBIC 8 ATOMS
C        A1=(  A,  0,  0)
C        A2=(  0,  A,  0)
C        A3=(  0,  0,  A)
         A1(1)=ALAT
         A2(2)=ALAT
         A3(3)=ALAT
C
        DO 33 J=1,NTAUQ
   33   READ(76,*) (TAU(I,J),I=1,3)
C **
      ELSEIF(IOPT(1,2).EQ.6) THEN
C               SI SLAB
         ALAT=CELLDM(1)
         NTYPE=1
         MXOFL(1) = 2
         NUMTY(1)=NTAUQ
         DO 35 I=1,NTAUQ
   35    NIDN(I,1)=I
         DO 36 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
   36    A3(IR)=0.D0
         A1(1) =   0.5D+00 * ALAT
         A1(2) =   0.5D+00 * ALAT
         A2(1) = - 0.5D+00 * ALAT
         A2(2) =   0.5D+00 * ALAT
C ***       SI XTAL (5 LAYER)
C                 A3(3) =   ALAT
C ***       SI (100)  (5 LAYER + 6-LAYER VACUUM)
C                 A3(3) =   2.5D+00 * ALAT
C ***       SI (100)  (9 LAYER + 6-LAYER VACUUM)
C                 A3(3) =   3.5D+00 * ALAT
           READ(5,*) A3(3)
           A3(3) = A3(3) * ALAT
C
        DO 37 J=1,NTAUQ
   37   READ(5,*) (TAU(I,J),I=1,3)
C ***
      ELSEIF(IOPT(1,2).EQ.9) THEN
C     SIH4 CUBIC STRUCTURE
         ALAT=CELLDM(1)
         NTYPE=2
         NUMTY(1)=1
         MXOFL(1) = 2
C ** FOR LOCAL POTENTIAL ONLY, SET NUMTY BE NEGATIVE.
             NUMTY(2)= - ( NTAUQ-NUMTY(1) )
             MXOFL(2) = 0
C **
         DO 631 I=1,ABS(NUMTY(1))
  631    NIDN(I,1)=I
         DO 639 I=1,ABS(NUMTY(2))
  639    NIDN(I,2)=I + NUMTY(1)
         DO 632 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
  632    A3(IR)=0.D0
C        CUBIC 8 ATOMS
C        A1=(  A,  0,  0)
C        A2=(  0,  A,  0)
C        A3=(  0,  0,  A)
         A1(1)=ALAT
         A2(2)=ALAT
         A3(3)=ALAT
C
        DO 633 J=1,NTAUQ
  633   READ(5,*) (TAU(I,J),I=1,3)
C **
C
      ELSEIF( IOPT(1,2) .EQ. 21 ) THEN
C     SI/GE PLUS H
         ALAT = CELLDM(1)
         NTYPE=3
C ** TYPE 1 = GE, TYPE 2 = SI, TYPE 3 = H
         NUMTY(1) = 10
         NUMTY(2) = 2
         NUMTY(3) = - 4
         MXOFL(1) = 2
         MXOFL(2) = 2
         MXOFL(3) = 0
         DO 645 I=1,ABS(NUMTY(1))
  645    NIDN(I,1) = I + 2
         NIDN(1,2) = 1
         NIDN(2,2) = 2
         DO 646 I=1,ABS(NUMTY(3))
  646    NIDN(I,3) = I + ABS(NUMTY(1)) + ABS(NUMTY(2))
         A1(1) =   0.5D+00  *   ALAT
         A1(2) = - 0.5D+00  *   ALAT
         A1(3) =   0.0D+00
         A2(1) =   1.0D+00  *   ALAT
         A2(2) =   1.0D+00  *   ALAT
         A2(3) =   0.0D+00
         A3(1) =   0.0D+00
         A3(2) =   0.0D+00
         A3(3) =   2.75D+00 *   ALAT
C
        DO 648 J=1,NTAUQ
  648   READ(76,*) (TAU(I,J),I=1,3)
C **
C
      ELSEIF(IOPT(1,2).EQ.8) THEN
C     SISLH1
         ALAT=CELLDM(1)
         NTYPE=2
         NUMTY(1)=10
         MXOFL(1) = 2
C ** FOR LOCAL POTENTIAL ONLY, SET NUMTY BE NEGATIVE.
             NUMTY(2)= - ( NTAUQ-NUMTY(1) )
             MXOFL(2) = 0
C **
         DO 640 I=1,ABS(NUMTY(1))
  640    NIDN(I,1)=I
         DO 641 I=1,ABS(NUMTY(2))
  641    NIDN(I,2)=I + NUMTY(1)
         DO 642 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
  642    A3(IR)=0.D0
C           2X1 LATERAL CELL
         A1(1) =   0.5D+00  * ALAT
         A1(2) = - 0.5D+00  * ALAT
         A2(1) =              ALAT
         A2(2) =              ALAT
C TEMP   A3(3) =   2.75D+00 * ALAT
         A3(3) =   2.25D+00 * ALAT
C
        DO 643 J=1,NTAUQ
  643   READ(76,*) (TAU(I,J),I=1,3)
C **
C **
C
      ELSEIF(IOPT(1,2).EQ.3) THEN
C     SISLH2
         ALAT=CELLDM(1)
         NTYPE=2
         NUMTY(1)=72
         MXOFL(1) = 2
C ** FOR LOCAL POTENTIAL ONLY, SET NUMTY BE NEGATIVE.
             NUMTY(2)= - ( NTAUQ-NUMTY(1) )
             MXOFL(2) = 0
C **
         DO 650 I=1,ABS(NUMTY(1))
  650    NIDN(I,1)=I
         DO 651 I=1,ABS(NUMTY(2))
  651    NIDN(I,2)=I + NUMTY(1)
         DO 652 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
  652    A3(IR)=0.D0
C           6X2 LATERAL CELL
         A1(1) =              ALAT
         A1(2) = -            ALAT
         A2(1) =   3.00D+00  * ALAT
         A2(2) =   3.00D+00  * ALAT
         A3(3) =   3.00D+00  * ALAT
C
        DO 653 J=1,NTAUQ
  653   READ(76,*) (TAU(I,J),I=1,3)
C **
C **
C
      ELSEIF(IOPT(1,2).EQ.4) THEN
C     SISLH3
C ******* CARE
         ALAT=CELLDM(1)
         NTYPE=2
C 2X4    NUMTY(1)=40
C 2X8    NUMTY(1)=80
         NUMTY(1)=20
C        NUMTY(1)=62
C 2X6DBN NUMTY(1)=58
C 2X1    NUMTY(1)=20
         MXOFL(1) = 2
C ** FOR LOCAL POTENTIAL ONLY, SET NUMTY BE NEGATIVE.
             NUMTY(2)= - ( NTAUQ-NUMTY(1) )
             MXOFL(2) = 0
C **
         DO 660 I=1,ABS(NUMTY(1))
  660    NIDN(I,1)=I
         DO 661 I=1,ABS(NUMTY(2))
  661    NIDN(I,2)=I + NUMTY(1)
         DO 662 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
  662    A3(IR)=0.D0
C           2X2  2X4  2X6  2X8  LATERAL CELL
         A1(1) =              ALAT
         A1(2) = -            ALAT
CARE     A2(1) =   4.00D+00  * ALAT
CARE     A2(2) =   4.00D+00  * ALAT
CARE     A2(1) =   3.00D+00  * ALAT
CARE     A2(2) =   3.00D+00  * ALAT
CARE     A2(1) =   2.00D+00  * ALAT
CARE     A2(2) =   2.00D+00  * ALAT
         A2(1) =   1.00D+00  * ALAT
         A2(2) =   1.00D+00  * ALAT
         A3(3) =   2.75D+00  * ALAT
CARE     A3(3) =   3.00D+00  * ALAT
CARE     A3(3) =   2.50D+00  * ALAT
C
        DO 663 J=1,NTAUQ
  663   READ(76,*) (TAU(I,J),I=1,3)
C **
C **
C
      ELSEIF(IOPT(1,2).EQ.10) THEN
C     SISLH4:  VICINAL SURFACE
         ALAT=CELLDM(1)
         NTYPE=2
CARE ***    NON-REBONDED DB CASE AND OTHERS
CARE     NUMTY(1)=62
         NUMTY(1)=63
CARE     NUMTY(1)=64
         MXOFL(1) = 2
CARE END ****
C ** FOR LOCAL POTENTIAL ONLY, SET NUMTY BE NEGATIVE.
             NUMTY(2)= - ( NTAUQ-NUMTY(1) )
             MXOFL(2) = 0 
C **
         DO 670 I=1,ABS(NUMTY(1))
  670    NIDN(I,1)=I
         DO 671 I=1,ABS(NUMTY(2))
  671    NIDN(I,2)=I + NUMTY(1)
         DO 672 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
  672    A3(IR)=0.D0
C          (1,1,15) VICINAL SURFACE
         A1(1) =              ALAT
         A1(2) = -            ALAT
         A2(1) =   3.50D+00  * ALAT
         A2(2) =   4.00D+00  * ALAT
         A2(3) = - 0.50D+00  * ALAT
C ****  TEMP CARE
               THICK =  26.0D+00
C ****
         A3(1) =              THICK / SQRT( 227.0D+00 )
         A3(2) =              THICK / SQRT( 227.0D+00 )
         A3(3) =   15.0D+00 * THICK / SQRT( 227.0D+00 )
C
        DO 673 J=1,NTAUQ
  673   READ(76,*) JDUMMY, (TAU(I,J),I=1,3)
CARE    DO 673 J=1,NTAUQ
C 673   READ(76,*)         (TAU(I,J),I=1,3)
C **
C **
C
      ELSEIF(IOPT(1,2).EQ.12) THEN
C     SISLH5:  (1,1,10) VICINAL SURFACE
         ALAT=CELLDM(1)
         NTYPE=2
CARE ***    QB CASE
         NUMTY(1)=84
         MXOFL(1) = 2
CARE END ****
C ** FOR LOCAL POTENTIAL ONLY, SET NUMTY BE NEGATIVE.
             NUMTY(2)= - ( NTAUQ-NUMTY(1) )
             MXOFL(2) = 0
C **
         DO 680 I=1,ABS(NUMTY(1))
  680    NIDN(I,1)=I
         DO 681 I=1,ABS(NUMTY(2))
  681    NIDN(I,2)=I + NUMTY(1)
         DO 682 IR=1,3
         A1(IR)=0.D0
         A2(IR)=0.D0
  682    A3(IR)=0.D0
C          (1,1,10) VICINAL SURFACE
         A1(1) =              ALAT
         A1(2) = -            ALAT
         A2(1) =   5.0D+00  * ALAT
         A2(2) =   5.0D+00  * ALAT
         A2(3) = - 1.0D+00  * ALAT
C ****  TEMP CARE
               THICK =  26.0D+00
C ****
         A3(1) =              THICK / SQRT( 102.0D+00 )
         A3(2) =              THICK / SQRT( 102.0D+00 )
         A3(3) =   10.0D+00 * THICK / SQRT( 102.0D+00 )
C
        DO 683 J=1,NTAUQ
  683   READ(76,*) (TAU(I,J),I=1,3)
C **
C
      ENDIF
C
C
      WRITE(6,6000)
 6000 FORMAT(/
     & ' INITIAL POSITION OF ATOM IN CARTESIAN COORDINATE IN ATOMIC'
     &,' UNIT:')
      DO 314 J=1,NTAUQ
  314 WRITE(6,6001) J, (TAU(I,J),I=1,3)
 6001 FORMAT(3X,I4,2X,3F15.7)
      WRITE(6,6003) NTYPE, ( NUMTY(J), J=1,NTYPE )
 6003 FORMAT(5X,'  ****  NTYPE = ',I3,'  NUMTY = ',4I4)
C
C     WRITE(6,*) ' BAND OCCUPATION FOR NBNDQ BANDS: '
C     DO 322 K=1,NUMKQ
C 322 WRITE(6,6002) K, (OCC(I,K),I=1,NBNDQ)
C6002 FORMAT(3X,'K = ',I3/(7X,6F7.3) )
C
C
 1000 OMEGA=0.D0
      S=1.D0
      I=1
      J=2
      K=3
 1001 DO 1002 IPERM=1,3
      OMEGA=OMEGA+S*A1(I)*A2(J)*A3(K)
      L=I
      I=J
      J=K
      K=L
 1002 CONTINUE
      I=2
      J=1
      K=3
      S=-S
      IF(S.LT.0.D0) GO TO 1001
      OMEGA=ABS(OMEGA)
C
C
      RETURN
  100 FORMAT(F12.6)
  101 FORMAT(3(2X,A1,F12.6),1X,A1)
  200 FORMAT(//,' CRYSTAL STRUCTURE :',//,' LATTICE CONSTANT ',
     &      F12.5,' (A.U.)',/)
 7100 FORMAT(3(4X,F14.7))
      END
