C     PROGRAM MAIN
C     IMPLICIT REAL*8 (A-H,O-Z)
C     PARAMETER(NRX=116,NRY=116,NRZ=116,NXYZ=NRX*NRY*NRZ)
C     COMPLEX*16 RHO1,RHO2,WSAVEX,WSAVEY,WSAVEZ,RHO3
C     COMMON/COMELE/RHO1(NXYZ),RHO2(NXYZ),RHO3(NXYZ),
C    &              WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ),
C    &              IFACX(30),IFACY(30),IFACZ(30),
C    &              LX1(NXYZ),LX2(NXYZ),LY1(NXYZ),
C    &              LY2(NXYZ),LZ1(NXYZ),LZ2(NXYZ)
C     CALL PREFFT(NRX,NRY,NRZ,NXYZ,
C    & WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C     II=0
C     DO 200 K=1,NRZ
C     DO 200 J=1,NRY
C     DO 200 I=1,NRX
C     II=II+1
C     RHO2(II)=DCMPLX(MOD(LOG(I*2.5D0+J*4.2D0+K*5.9D0),1.D0)
C    &               ,MOD(LOG(I*6.5D0+J*2.2D0+K*0.9D0),1.D0))
C200  RHO3(II)=RHO2(II)
C     CALL CLOCK(TIME0)
C     CALL FFT3FX(     NRX,NRY,NRZ,NXYZ,RHO2,RHO1,
C    &WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C     CALL FFT3BX(     NRX,NRY,NRZ,NXYZ,RHO1,RHO2,
C    &WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
C     CALL CLOCK(TIME1)
C     WRITE(6,*) 'USED TIME=',TIME1-TIME0
C     DO 220 I=1,NXYZ
C 220 IF(ABS(RHO1(I)-RHO3(I)).GT.1.D-12)
C    &WRITE(6,*) I,RHO1(I)-RHO3(I)
C     STOP
C     END
C
C     SUBROUTINE FFT3BX(    NRX,NRY,NRZ,NG,RHOG,WORK,
C    &                  WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,
C    &                  LX1,LX2,LY1,LY2,LZ1,LZ2)
C***********************************************************
C     三次元フーリエ変換(REAL SPACE-->G-SPACE)
C                                   (1990-04-12) OSAMU SUGINO
C     INPUT :RHO,NR?,NG,WSAVE?,IFAC?,L??
C     OUTPUT:RHOG
C     WORK  :WORK
C
C     IMPLICIT REAL*8 (A-H,O-Z)
C     COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
C     DIMENSION RHOG(2,NG),WORK(2,NG)
C     DIMENSION IFACX(30),IFACY(30),IFACZ(30)
C     DIMENSION LX1(NG),LX2(NG),LY1(NG),LY2(NG),LZ1(NG),LZ2(NG)
C     FAC=1.0D0/DBLE(NG)
C
C     DO 15 IG=1,NG
C     WORK(1,IG)=RHOG(1,IG)
C     WORK(2,IG)=RHOG(2,IG)
C  15 CONTINUE
C     CALL FFTSV1(NG,RHOG,WORK)
C     CALL CFFT3B(NG,NRX*NRY,NRZ,WORK,RHOG,WSAVEZ,IFACZ)
C
C     CALL FFTXYZ(NG,NRX*NRY,NRZ,WORK,RHOG,LZ1,LZ2)
C     CALL CFFT3B(NG,NRZ*NRX,NRY,RHOG,WORK,WSAVEY,IFACY)
C
C     CALL FFTXYZ(NG,NRZ*NRX,NRY,RHOG,WORK,LY1,LY2)
C     CALL CFFT3B(NG,NRY*NRZ,NRX,WORK,RHOG,WSAVEX,IFACX)
C
C     CALL FFTXYZ(NG,NRY*NRZ,NRX,WORK,RHOG,LX1,LX2)
C     CALL FFTSV2(NG,RHOG,WORK)
C     DO 40 I=1,NG
C     RHOG(1,I)= WORK(1,I)*FAC
C     RHOG(2,I)= WORK(2,I)*FAC
C  40 CONTINUE
C
C     RETURN
C     END
C***********************************************************
C     SUBROUTINE FFT3FX(NRX,NRY,NRZ,NG,RHOG,WORK,
C    &                  WSAVEX,WSAVEY,WSAVEZ,IFACX,IFACY,IFACZ,
C    &                  LX1,LX2,LY1,LY2,LZ1,LZ2)
C***********************************************************
C     三次元フーリエ変換(G-SPACE -->REAL SPACE)
C                                   (1990-04-12) OSAMU SUGINO
C     INPUT :RHOG,NR?,NG,WSAVE?,IFAC?,L??
C     OUTPUT:WORK
C     WORK  :NONE
C
C     IMPLICIT REAL*8 (A-H,O-Z)
C     DIMENSION  RHOG(NG),WORK(NG)
C     COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
C     DIMENSION IFACX(30),IFACY(30),IFACZ(30)
C     DIMENSION LX1(NG),LX2(NG),LY1(NG),LY2(NG),LZ1(NG),LZ2(NG)
C
C     CALL FFTSV1(NG,RHOG,WORK)
C     CALL CFFT3F(NG,NRX*NRY,NRZ,WORK,RHOG,WSAVEZ,IFACZ)
C
C     CALL FFTXYZ(NG,NRX*NRY,NRZ,WORK,RHOG,LZ1,LZ2)
C     CALL CFFT3F(NG,NRZ*NRX,NRY,RHOG,WORK,WSAVEY,IFACY)
C
C     CALL FFTXYZ(NG,NRZ*NRX,NRY,RHOG,WORK,LY1,LY2)
C     CALL CFFT3F(NG,NRY*NRZ,NRX,WORK,RHOG,WSAVEX,IFACX)
C
C     CALL FFTXYZ(NG,NRY*NRZ,NRX,WORK,RHOG,LX1,LX2)
C     CALL FFTSV2(NG,RHOG,WORK)
C     RETURN
C     END
C
      SUBROUTINE FFTSV1(NG,RHOG,WORK)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION RHOG(2,NG),WORK(NG,2)
!$omp parallel default(shared)
!$omp do private(I)
      DO 10 I=1,NG
      WORK(I,1)=RHOG(1,I)
   10 WORK(I,2)=RHOG(2,I)
!$omp enddo
!$omp end parallel
      RETURN
      END
      SUBROUTINE FFTSV2(NG,RHOG,WORK)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION RHOG(NG,2),WORK(2,NG)
!$omp parallel default(shared)
!$omp do private(I)
      DO 10 I=1,NG
      WORK(1,I)=RHOG(I,1)
   10 WORK(2,I)=RHOG(I,2)
!$omp enddo
!$omp end parallel
      RETURN
      END
C***********************************************************
      SUBROUTINE FFTXYZ(NG,NRXY,NRZ,WORK,RHOG,LT1,LT2)
C***********************************************************
C                                   (1990-04-12) OSAMU SUGINO
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION WORK(NRXY,NRZ,2),RHOG(NG,2),LT1(NG),LT2(NG)
C
!$omp parallel default(shared)
!$omp do private(I,LLT1,LLT2)
      DO 20 I=1,NG
c      RHOG(I,1)=WORK(LT2(I),LT1(I),1)
c      RHOG(I,2)=WORK(LT2(I),LT1(I),2)
      LLT1=LT1(I) 
      LLT2=LT2(I) 
      RHOG(I,1)=WORK(LLT2,LLT1,1)
      RHOG(I,2)=WORK(LLT2,LLT1,2)
   20 CONTINUE
!$omp enddo
!$omp end parallel
      RETURN
      END
C***************************************************************
C*****************FFT3D*****************************************
C SUBROUTINE PACKAGE OF THE 3-DIMENSIONAL FFT
C WRITTEN BY OSAMU SUGINO 1990-03-14 FIRST VERSION
C *************
C THIS IS A VECTORIZED VERSION OF THE NCARL FFTPACK IN U-TOKYO
C ( FTPKCV     VERSION T03                       1985-11-18 )
C ( PART OF VECTORIZED VERSION OF FFTPACK IN NCARL.         )
C *************
C BY THIS ROUTINE THE THIRD VARIABLE IS FOURIER-TRANSFORMED.
C SO, YOU HAVE TO SUCCESSIVELY CALL THIS ROUTINE 3-TIMES FOR THE
C COMPLETE 3-DIMENSIONAL FFT.
C     **********************************************************
C     NOTE:   CPU_TIME=1.6E-3 SEC (FOR SX-2)
C
C ****************USAGE****************************************
C
C CFFT3I:EQUIPMENT ROUTINE
C       N:DIMENSION OF THE THIRD VARIABLE
C       WSAVE:ARRAY[1..2*N] OF REAL*8; WORK
C       IFAC:ARRAY[1..30] OF INTEGER*4; WORK
C       ************************
C       CALL CFFT3I(N,WSAVE,IFAC)
C       ************************
C
C
C CFFT3B:REAL-SPACE --> K-SPACE FFT
C       NRXY:PRODUCT OF THE DIMENSION OF THE FIRST AND THE SECOND
C            VARIABLES
C       N:DIMENSION OF THE THIRD VARIABLE
C       C:ARRAY[1..NRXY,1..N] OF COMPLEX*16; INPUT AND OUTPUT
C       WORK:ARRAY[1..NRXY,1..N] OF COMPLEX*16; WORK
C       WSAVE:ARRAY[1..2*N] OF REAL*8; WORK
C       IFAC:ARRAY[1..30] OF INTEGER*4; WORK
C       ************************************
C       CALL CFFT3B(NRXY,N,C,WORK,WSAVE,IFAC)
C       ************************************
C
C
C CFFT3F:K-SPACE --> REAL-SPACE FFT
C       NRXY:PRODUCT OF THE DIMENSION OF THE FIRST AND THE SECOND
C            VARIABLES
C       N:DIMENSION OF THE THIRD VARIABLE
C       C:ARRAY[1..NRXY,1..N] OF COMPLEX*16; INPUT AND OUTPUT
C       WORK:ARRAY[1..NRXY,1..N] OF COMPLEX*16; WORK
C       WSAVE:ARRAY[1..2*N] OF REAL*8; WORK
C       IFAC:ARRAY[1..30] OF INTEGER*4; WORK
C       ************************************
C       CALL CFFT3F(NRXY,N,C,WORK,WSAVE,IFAC)
C       ************************************
C
C
C FOR FUTURE PROGRAMMING:
C     THIS ROUTINE MAY BECOME FASTER IF YOU CHANGE
C
*     DO 203 I=1,IDO
*     DO 203 IJ=1,NRXY
C
C     TO
C
*     DO 203 IL=1,IDO*NRXY
*     I=(IL-1)/NRXY+1
*     IJ=MOD(IL-1,NRXY)+1
C
C     BUT THIS WAS NOT AN IMPROVEMENT FOR THE SX-2 SUPER-COMPUTER
C     SUSTEM
C****************************************************************
      SUBROUTINE PREFFT(NRX,NRY,NRZ,NG,WSAVEX,WSAVEY,WSAVEZ,
     & IFACX,IFACY,IFACZ,LX1,LX2,LY1,LY2,LZ1,LZ2)
      IMPLICIT REAL*8 (A-H,O-Z)
      COMPLEX*16 WSAVEX(NRX),WSAVEY(NRY),WSAVEZ(NRZ)
      DIMENSION IFACX(30),IFACY(30),IFACZ(30)
      DIMENSION LX1(NG),LX2(NG),LY1(NG),LY2(NG),LZ1(NG),LZ2(NG)
C
C        MAKE LIST VECTORS
C
      IJ=0
      DO 961 J=1,NRX*NRY
      DO 961 I=1,NRZ
      IJ=IJ+1
      LZ1(IJ)=I
  961 LZ2(IJ)=J
      IJ=0
      DO 962 J=1,NRY*NRZ
      DO 962 I=1,NRX
      IJ=IJ+1
      LX1(IJ)=I
  962 LX2(IJ)=J
      IJ=0
      DO 963 J=1,NRZ*NRX
      DO 963 I=1,NRY
      IJ=IJ+1
      LY1(IJ)=I
  963 LY2(IJ)=J
      CALL CFFT3I(NRX,WSAVEX,IFACX)
      CALL CFFT3I(NRY,WSAVEY,IFACY)
      CALL CFFT3I(NRZ,WSAVEZ,IFACZ)
      RETURN
      END
      SUBROUTINE CFFT3I(N,WSAVE,IFAC)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION WSAVE(*),IFAC(*)
      IF (N .EQ. 1) RETURN
      CALL CFT3I1 (N,WSAVE,IFAC)
      RETURN
      END
      SUBROUTINE CFT3I1 (N,WA,IFAC)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION WA(*),IFAC(*),NTRYH(4)
      DATA NTRYH(1),NTRYH(2),NTRYH(3),NTRYH(4)/3,4,2,5/
      DATA TPI/6.28318530717959D0/
      NL = N
      NF = 0
      J = 0
  101 J = J+1
      IF (J-4) 102,102,103
  102 NTRY = NTRYH(J)
      GO TO 104
  103 NTRY = NTRY+2
  104 NQ = NL/NTRY
      NR = NL-NTRY*NQ
      IF (NR) 101,105,101
  105 NF = NF+1
      IFAC(NF+2) = NTRY
      NL = NQ
      IF (NTRY .NE. 2) GO TO 107
      IF (NF .EQ. 1) GO TO 107
      DO 106 I=2,NF
         IB = NF-I+2
         IFAC(IB+2) = IFAC(IB+1)
  106 CONTINUE
      IFAC(3) = 2
  107 IF (NL .NE. 1) GO TO 104
      IFAC(1) = N
      IFAC(2) = NF
      ARGH = TPI/DFLOAT(N)
      I2 = 2
      L1 = 1
      DO 110 K1=1,NF
         IP = IFAC(K1+2)
         LD = 0
         L2 = L1*IP
         IDO = N/L2
         IPM = IP-1
         DO 109 J=1,IPM
            I1 = I2
            WA(I1-1) = 1.
            WA(I1)   = 0.
            LD = LD+L1
            ARGLD = DFLOAT(LD)*ARGH
            DO 108 IFI=1,IDO
               ARG = DFLOAT(IFI)*ARGLD
               WA(2*IFI+I1-1) = COS(ARG)
               WA(2*IFI+I1) = SIN(ARG)
  108       CONTINUE
            I2 = I1+IDO+IDO
            IF (IP .LE. 5) GO TO 109
            WA(I1-1) = WA(I2-1)
            WA(I1)   = WA(I2)
  109    CONTINUE
         L1 = L2
  110 CONTINUE
      RETURN
      END
      SUBROUTINE CFFT3B(NG,NRXY,N,C,WORK,WSAVE,IFAC)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C(NG,2),WSAVE(*),WORK(NG,2),IFAC(*)
      IF (N .EQ. 1) RETURN
      CALL CFT3B1 (NRXY,N,C(1,1),C(1,2),WORK(1,1),WORK(1,2),WSAVE,IFAC)
      RETURN
      END
      SUBROUTINE CFT3B1 (NRXY,N,CR,CI,CHR,CHI,WA,IFAC)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHI(*),CHR(*),CR(*),CI(*),WA(*),IFAC(*)
      NF = IFAC(2)
      NA = 0
      L1 = 1
      IW = 1
      DO 116 K1=1,NF
         IP = IFAC(K1+2)
         L2 = IP*L1
         IDO = N/L2
         IDOT = IDO
         IDL1 = IDOT*L1
         IF (IP .NE. 4) GO TO 103
         IX2 = IW+IDOT*2
         IX3 = IX2+IDOT*2
         IF (NA .NE. 0) GO TO 101
         CALL THDB4V(NRXY,IDOT,L1,CR,CI,CHR,CHI,WA(IW),WA(IX2),WA(IX3))
         GO TO 102
  101    CALL THDB4V(NRXY,IDOT,L1,CHR,CHI,CR,CI,WA(IW),WA(IX2),WA(IX3))
  102    NA = 1-NA
         GO TO 115
  103    IF (IP .NE. 2) GO TO 106
         IF (NA .NE. 0) GO TO 104
         CALL THDB2V(NRXY,IDOT,L1,CR,CI,CHR,CHI,WA(IW))
         GO TO 105
  104    CALL THDB2V(NRXY,IDOT,L1,CHR,CHI,CR,CI,WA(IW))
  105    NA = 1-NA
         GO TO 115
  106    IF (IP .NE. 3) GO TO 109
         IX2 = IW+IDOT*2
         IF (NA .NE. 0) GO TO 107
         CALL THDB3V(NRXY,IDOT,L1,CR,CI,CHR,CHI,WA(IW),WA(IX2))
         GO TO 108
  107    CALL THDB3V(NRXY,IDOT,L1,CHR,CHI,CR,CI,WA(IW),WA(IX2))
  108    NA = 1-NA
         GO TO 115
  109    IF (IP .NE. 5) GO TO 112
         IX2 = IW+IDOT*2
         IX3 = IX2+IDOT*2
         IX4 = IX3+IDOT*2
         IF (NA .NE. 0) GO TO 110
         CALL THDB5V(NRXY,IDOT,L1,CR,CI,CHR,CHI,
     &               WA(IW),WA(IX2),WA(IX3),WA(IX4))
         GO TO 111
  110    CALL THDB5V(NRXY,IDOT,L1,CHR,CHI,CR,CI,
     &               WA(IW),WA(IX2),WA(IX3),WA(IX4))
  111    NA = 1-NA
         GO TO 115
  112    IF (NA .NE. 0) GO TO 113
         CALL THDBG (NRXY,NAC,IDOT,IP,L1,IDL1,CR,CI,CR,CI,CR,CI,
     &               CHR,CHI,CHR,CHI,WA(IW))
         GO TO 114
  113    CALL THDBG (NRXY,NAC,IDOT,IP,L1,IDL1,CHR,CHI,CHR,CHI,CHR,CHI,
     &               CR,CI,CR,CI,WA(IW))
  114    IF (NAC .NE. 0) NA = 1-NA
  115    L1 = L2
         IW = IW+(IP-1)*IDOT*2
  116 CONTINUE
      IF (NA .EQ. 0) RETURN
      DO 1171 I=1,N*NRXY
      CR(I) = CHR(I)
 1171 CI(I) = CHI(I)
      RETURN
      END
      SUBROUTINE CFFT3F(NG,NRXY,N,C,WORK,WSAVE,IFAC)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C(NG,2),WSAVE(*),WORK(NG,2),IFAC(*)
      IF (N .EQ. 1) RETURN
      CALL CFT3F1 (NRXY,N,C(1,1),C(1,2),WORK(1,1),WORK(1,2),WSAVE,IFAC)
      RETURN
      END
      SUBROUTINE CFT3F1 (NRXY,N,CR,CI,CHR,CHI,WA,IFAC)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(*),CHI(*),CR(*),CI(*),WA(*),IFAC(*)
      NF = IFAC(2)
      NA = 0
      L1 = 1
      IW = 1
      DO 116 K1=1,NF
         IP = IFAC(K1+2)
         L2 = IP*L1
         IDO = N/L2
         IDOT = IDO
         IDL1 = IDOT*L1
         IF (IP .NE. 4) GO TO 103
         IX2 = IW+IDOT*2
         IX3 = IX2+IDOT*2
         IF (NA .NE. 0) GO TO 101
         CALL THDF4V(NRXY,IDOT,L1,CR,CI,CHR,CHI,WA(IW),WA(IX2),WA(IX3))
         GO TO 102
  101    CALL THDF4V(NRXY,IDOT,L1,CHR,CHI,CR,CI,WA(IW),WA(IX2),WA(IX3))
  102    NA = 1-NA
         GO TO 115
  103    IF (IP .NE. 2) GO TO 106
         IF (NA .NE. 0) GO TO 104
         CALL THDF2V(NRXY,IDOT,L1,CR,CI,CHR,CHI,WA(IW))
         GO TO 105
  104    CALL THDF2V(NRXY,IDOT,L1,CHR,CHI,CR,CI,WA(IW))
  105    NA = 1-NA
         GO TO 115
  106    IF (IP .NE. 3) GO TO 109
         IX2 = IW+IDOT*2
         IF (NA .NE. 0) GO TO 107
         CALL THDF3V(NRXY,IDOT,L1,CR,CI,CHR,CHI,WA(IW),WA(IX2))
         GO TO 108
  107    CALL THDF3V(NRXY,IDOT,L1,CHR,CHI,CR,CI,WA(IW),WA(IX2))
  108    NA = 1-NA
         GO TO 115
  109    IF (IP .NE. 5) GO TO 112
         IX2 = IW+IDOT*2
         IX3 = IX2+IDOT*2
         IX4 = IX3+IDOT*2
         IF (NA .NE. 0) GO TO 110
         CALL THDF5V(NRXY,IDOT,L1,CR,CI,CHR,CHI,
     &               WA(IW),WA(IX2),WA(IX3),WA(IX4))
         GO TO 111
  110    CALL THDF5V(NRXY,IDOT,L1,CHR,CHI,CR,CI,
     &               WA(IW),WA(IX2),WA(IX3),WA(IX4))
  111    NA = 1-NA
         GO TO 115
  112    IF (NA .NE. 0) GO TO 113
         CALL THDFG (NRXY,NAC,IDOT,IP,L1,IDL1,CR,CI,CR,CI,CR,CI,
     &               CHR,CHI,CHR,CHI,WA(IW))
         GO TO 114
  113    CALL THDFG (NRXY,NAC,IDOT,IP,L1,IDL1,CHR,CHI,CHR,CHI,CHR,CHI,
     &               CR,CI,CR,CI,WA(IW))
  114    IF (NAC .NE. 0) NA = 1-NA
  115    L1 = L2
         IW = IW+(IP-1)*IDOT*2
  116 CONTINUE
      IF (NA .EQ. 0) RETURN
      DO 1171 I=1,N*NRXY
      CR(I) = CHR(I)
 1171 CI(I) = CHI(I)
      RETURN
      END
C-----------------------------------------------------------------------
      SUBROUTINE THDB2V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CCR(NRXY,IDO,2,L1),CHR(NRXY,IDO,L1,2),WA1(*)
      DIMENSION CCI(NRXY,IDO,2,L1),CHI(NRXY,IDO,L1,2)
      DO 203 I=1,IDO
      DO 203 K=1,L1
C THE FOLLOWING DUMMY STATEMENT IS ADDED SO THAT THE LONGEST
C IJ LOOP REMAINS THE INNERMOST LOOP
      IF(I.EQ.0.OR.K.EQ.0) STOP
!$omp parallel default(shared)
!$omp do private(ij,TR2,TI2,TWR,TWI)
      DO 202 IJ=1,NRXY
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)+CCR(IJ,I,2,K)
          TR2 = CCR(IJ,I,1,K)-CCR(IJ,I,2,K)
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)+CCI(IJ,I,2,K)
          TI2 = CCI(IJ,I,1,K)-CCI(IJ,I,2,K)
          TWR = WA1(2*I-1)*TR2
          TWI = WA1(2*I-1)*TI2
          CHI(IJ,I,K,2) = TWI + WA1(2*I)*TR2
          CHR(IJ,I,K,2) = TWR - WA1(2*I)*TI2
  202 CONTINUE
!$omp enddo
!$omp end parallel
  203 CONTINUE
      RETURN
      END
      SUBROUTINE THDB3V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1,WA2)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CCR(NRXY,IDO,3,L1),CHR(NRXY,IDO,L1,3),
     &          CCI(NRXY,IDO,3,L1),CHI(NRXY,IDO,L1,3),
     &          WA1(*),WA2(*)
      DATA TAUR,TAUI /-.5D0,.866025403784439D0/
!$omp parallel default(shared)
!$omp+private(I,K,IJ,TR2,CR2,TI2,CI2,CR3,CI3,
!$omp+DR2,DR3,DI2,DI3,DWR2,DWI2,DWR3,DWI3)
      DO 203 I=1,IDO
      DO 203 K=1,L1
!$omp do
      DO 202 IJ=1,NRXY
          TR2 = CCR(IJ,I,2,K)+CCR(IJ,I,3,K)
          CR2 = CCR(IJ,I,1,K)+TAUR*TR2
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)+TR2
          TI2 = CCI(IJ,I,2,K)+CCI(IJ,I,3,K)
          CI2 = CCI(IJ,I,1,K)+TAUR*TI2
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)+TI2
          CR3 = TAUI*(CCR(IJ,I,2,K)-CCR(IJ,I,3,K))
          CI3 = TAUI*(CCI(IJ,I,2,K)-CCI(IJ,I,3,K))
          DR2 = CR2-CI3
          DR3 = CR2+CI3
          DI2 = CI2+CR3
          DI3 = CI2-CR3
          DWR2= WA1(2*I-1)*DR2
          DWI2= WA1(2*I-1)*DI2
          DWR3= WA2(2*I-1)*DR3
          DWI3= WA2(2*I-1)*DI3
          CHI(IJ,I,K,2) = DWI2+WA1(2*I)*DR2
          CHR(IJ,I,K,2) = DWR2-WA1(2*I)*DI2
          CHI(IJ,I,K,3) = DWI3+WA2(2*I)*DR3
          CHR(IJ,I,K,3) = DWR3-WA2(2*I)*DI3
  202 CONTINUE
!$omp enddo
  203 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDB4V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1,WA2,WA3)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CCR(NRXY,IDO,4,L1),CHR(NRXY,IDO,L1,4),
     &          CCI(NRXY,IDO,4,L1),CHI(NRXY,IDO,L1,4),
     &                WA1(*)     ,WA2(*)     ,WA3(*)
!$omp parallel default(shared)
!$omp+private(i,k,ij,TI1,TI2,TI3,TR4,TR1,TR2,TI4,TR3,
!$omp+CR3,CI3,CR2,CR4,CI2,CI4,WR2,WI2,WR3,WI3,WR4,WI4)
      DO 203 I=1,IDO
      DO 203 K=1,L1
!$omp do
      DO 202 IJ=1,NRXY
          TI1 = CCI(IJ,I,1,K)-CCI(IJ,I,3,K)
          TI2 = CCI(IJ,I,1,K)+CCI(IJ,I,3,K)
          TI3 = CCI(IJ,I,2,K)+CCI(IJ,I,4,K)
          TR4 = CCI(IJ,I,4,K)-CCI(IJ,I,2,K)
          TR1 = CCR(IJ,I,1,K)-CCR(IJ,I,3,K)
          TR2 = CCR(IJ,I,1,K)+CCR(IJ,I,3,K)
          TI4 = CCR(IJ,I,2,K)-CCR(IJ,I,4,K)
          TR3 = CCR(IJ,I,2,K)+CCR(IJ,I,4,K)
          CHR(IJ,I,K,1) = TR2+TR3
          CR3 = TR2-TR3
          CHI(IJ,I,K,1) = TI2+TI3
          CI3 = TI2-TI3
          CR2 = TR1+TR4
          CR4 = TR1-TR4
          CI2 = TI1+TI4
          CI4 = TI1-TI4
          WR2 = WA1(2*I-1)*CR2
          WI2 = WA1(2*I-1)*CI2
          WR3 = WA2(2*I-1)*CR3
          WI3 = WA2(2*I-1)*CI3
          WR4 = WA3(2*I-1)*CR4
          WI4 = WA3(2*I-1)*CI4
          CHR(IJ,I,K,2) = WR2-WA1(2*I)*CI2
          CHI(IJ,I,K,2) = WI2+WA1(2*I)*CR2
          CHR(IJ,I,K,3) = WR3-WA2(2*I)*CI3
          CHI(IJ,I,K,3) = WI3+WA2(2*I)*CR3
          CHR(IJ,I,K,4) = WR4-WA3(2*I)*CI4
          CHI(IJ,I,K,4) = WI4+WA3(2*I)*CR4
  202 CONTINUE
!$omp enddo
  203 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDB5V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1,WA2,WA3,WA4)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION  CCR(NRXY,IDO,5,L1),CHR(NRXY,IDO,L1,5),
     1           CCI(NRXY,IDO,5,L1),CHI(NRXY,IDO,L1,5),
     1           WA1(*)     ,WA2(*)     ,WA3(*)     ,WA4(*)
      DATA TR11,TI11,TR12,TI12 /.309016994374947D0,.951056516295154D0,
     1-.809016994374947D0,.587785252292473D0/
!$omp parallel default(shared)
!$omp+private(i,k,ij,TI5,TI2,TI4,TI3,TR5,TR2,TR4,TR3,
!$omp+CR2,CI2,CR3,CI3,CR5,CI5,CR4,CI4,
!$omp+DR3,DR4,DI3,DI4,DR5,DR2,DI5,DI2)
      DO 203 I=1,IDO
      DO 203 K=1,L1
!$omp do
      DO 202 IJ=1,NRXY
          TI5 = CCI(IJ,I,2,K)-CCI(IJ,I,5,K)
          TI2 = CCI(IJ,I,2,K)+CCI(IJ,I,5,K)
          TI4 = CCI(IJ,I,3,K)-CCI(IJ,I,4,K)
          TI3 = CCI(IJ,I,3,K)+CCI(IJ,I,4,K)
          TR5 = CCR(IJ,I,2,K)-CCR(IJ,I,5,K)
          TR2 = CCR(IJ,I,2,K)+CCR(IJ,I,5,K)
          TR4 = CCR(IJ,I,3,K)-CCR(IJ,I,4,K)
          TR3 = CCR(IJ,I,3,K)+CCR(IJ,I,4,K)
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)+TR2+TR3
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)+TI2+TI3
          CR2 = CCR(IJ,I,1,K)+TR11*TR2+TR12*TR3
          CI2 = CCI(IJ,I,1,K)+TR11*TI2+TR12*TI3
          CR3 = CCR(IJ,I,1,K)+TR12*TR2+TR11*TR3
          CI3 = CCI(IJ,I,1,K)+TR12*TI2+TR11*TI3
          CR5 = TI11*TR5+TI12*TR4
          CI5 = TI11*TI5+TI12*TI4
          CR4 = TI12*TR5-TI11*TR4
          CI4 = TI12*TI5-TI11*TI4
          DR3 = CR3-CI4
          DR4 = CR3+CI4
          DI3 = CI3+CR4
          DI4 = CI3-CR4
          DR5 = CR2+CI5
          DR2 = CR2-CI5
          DI5 = CI2-CR5
          DI2 = CI2+CR5
          CHR(IJ,I,K,2) = WA1(2*I-1)*DR2-WA1(2*I)*DI2
          CHI(IJ,I,K,2) = WA1(2*I-1)*DI2+WA1(2*I)*DR2
          CHR(IJ,I,K,3) = WA2(2*I-1)*DR3-WA2(2*I)*DI3
          CHI(IJ,I,K,3) = WA2(2*I-1)*DI3+WA2(2*I)*DR3
          CHR(IJ,I,K,4) = WA3(2*I-1)*DR4-WA3(2*I)*DI4
          CHI(IJ,I,K,4) = WA3(2*I-1)*DI4+WA3(2*I)*DR4
          CHR(IJ,I,K,5) = WA4(2*I-1)*DR5-WA4(2*I)*DI5
          CHI(IJ,I,K,5) = WA4(2*I-1)*DI5+WA4(2*I)*DR5
  202 CONTINUE
!$omp enddo
  203 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDF2V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CCR(NRXY,IDO,2,L1),CHR(NRXY,IDO,L1,2),
     &          CCI(NRXY,IDO,2,L1),CHI(NRXY,IDO,L1,2),
     1          WA1(*)
      DO 203 I=1,IDO
      DO 203 K=1,L1
C THE FOLLOWING DUMMY STATEMENT IS ADDED SO THAT THE LONGEST
C IJ LOOP REMAINS THE INNERMOST LOOP
      IF(I.EQ.0.OR.K.EQ.0) STOP
!$omp parallel default(shared)
!$omp do private(ij,TR2,TI2)
      DO 202 IJ=1,NRXY
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)+CCR(IJ,I,2,K)
          TR2 = CCR(IJ,I,1,K)-CCR(IJ,I,2,K)
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)+CCI(IJ,I,2,K)
          TI2 = CCI(IJ,I,1,K)-CCI(IJ,I,2,K)
          CHI(IJ,I,K,2) = WA1(2*I-1)*TI2-WA1(2*I)*TR2
          CHR(IJ,I,K,2) = WA1(2*I-1)*TR2+WA1(2*I)*TI2
  202 CONTINUE
!$omp enddo
!$omp end parallel
  203 CONTINUE
      RETURN
      END
      SUBROUTINE THDF3V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1,WA2)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CCR(NRXY,IDO,3,L1),CHR(NRXY,IDO,L1,3),
     &          CCI(NRXY,IDO,3,L1),CHI(NRXY,IDO,L1,3),
     1                WA1(*)     ,WA2(*)
      DATA TAUR,TAUI /-.5D0,-.866025403784439D0/
!$omp parallel default(shared)
!$omp+private(i,k,ij,TR2,CR2,TI2,CI2,CR3,CI3,
!$omp+DR2,DR3,DI2,DI3)
      DO 203 I=1,IDO
      DO 203 K=1,L1
!$omp do
      DO 202 IJ=1,NRXY
          TR2 = CCR(IJ,I,2,K)+CCR(IJ,I,3,K)
          CR2 = CCR(IJ,I,1,K)+TAUR*TR2
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)+TR2
          TI2 = CCI(IJ,I,2,K)+CCI(IJ,I,3,K)
          CI2 = CCI(IJ,I,1,K)+TAUR*TI2
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)+TI2
          CR3 = TAUI*(CCR(IJ,I,2,K)-CCR(IJ,I,3,K))
          CI3 = TAUI*(CCI(IJ,I,2,K)-CCI(IJ,I,3,K))
          DR2 = CR2-CI3
          DR3 = CR2+CI3
          DI2 = CI2+CR3
          DI3 = CI2-CR3
          CHI(IJ,I,K,2) = WA1(2*I-1)*DI2-WA1(2*I)*DR2
          CHR(IJ,I,K,2) = WA1(2*I-1)*DR2+WA1(2*I)*DI2
          CHI(IJ,I,K,3) = WA2(2*I-1)*DI3-WA2(2*I)*DR3
          CHR(IJ,I,K,3) = WA2(2*I-1)*DR3+WA2(2*I)*DI3
  202 CONTINUE
!$omp enddo
  203 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDF4V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1,WA2,WA3)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CCR(NRXY,IDO,4,L1),CHR(NRXY,IDO,L1,4),
     &          CCI(NRXY,IDO,4,L1),CHI(NRXY,IDO,L1,4),
     1          WA1(*)     ,WA2(*)     ,WA3(*)
!$omp parallel default(shared)
!$omp+private(i,k,ij,TI1,TI2,TI3,TR4,TR1,
!$omp+TR2,TI4,TR3,CR3,CI3,CR2,CR4,CI2,CI4)
      DO 203 I=1,IDO
      DO 203 K=1,L1
!$omp do
      DO 202 IJ=1,NRXY
          TI1 = CCI(IJ,I,1,K)-CCI(IJ,I,3,K)
          TI2 = CCI(IJ,I,1,K)+CCI(IJ,I,3,K)
          TI3 = CCI(IJ,I,2,K)+CCI(IJ,I,4,K)
          TR4 = CCI(IJ,I,2,K)-CCI(IJ,I,4,K)
          TR1 = CCR(IJ,I,1,K)-CCR(IJ,I,3,K)
          TR2 = CCR(IJ,I,1,K)+CCR(IJ,I,3,K)
          TI4 = CCR(IJ,I,4,K)-CCR(IJ,I,2,K)
          TR3 = CCR(IJ,I,2,K)+CCR(IJ,I,4,K)
          CHR(IJ,I,K,1) = TR2+TR3
          CR3 = TR2-TR3
          CHI(IJ,I,K,1) = TI2+TI3
          CI3 = TI2-TI3
          CR2 = TR1+TR4
          CR4 = TR1-TR4
          CI2 = TI1+TI4
          CI4 = TI1-TI4
          CHR(IJ,I,K,2) = WA1(2*I-1)*CR2+WA1(2*I)*CI2
          CHI(IJ,I,K,2) = WA1(2*I-1)*CI2-WA1(2*I)*CR2
          CHR(IJ,I,K,3) = WA2(2*I-1)*CR3+WA2(2*I)*CI3
          CHI(IJ,I,K,3) = WA2(2*I-1)*CI3-WA2(2*I)*CR3
          CHR(IJ,I,K,4) = WA3(2*I-1)*CR4+WA3(2*I)*CI4
          CHI(IJ,I,K,4) = WA3(2*I-1)*CI4-WA3(2*I)*CR4
  202 CONTINUE
!$omp enddo
  203 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDF5V(NRXY,IDO,L1,CCR,CCI,CHR,CHI,WA1,WA2,WA3,WA4)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CCR(NRXY,IDO,5,L1),CHR(NRXY,IDO,L1,5),
     &          CCI(NRXY,IDO,5,L1),CHI(NRXY,IDO,L1,5),
     1          WA1(*)     ,WA2(*)     ,WA3(*)     ,WA4(*)
      DATA TR11,TI11,TR12,TI12 /.309016994374947D0,-.951056516295154D0,
     1-.809016994374947D0,-.587785252292473D0/
!$omp parallel default(shared)
!$omp+private(i,k,ij,TI5,TI2,TI4,TI3,TR5,TR2,
!$omp+TR4,TR3,CR2,CI2,CR3,CI3,CR5,CI5,CR4,CI4,
!$omp+DR3,DR4,DI3,DI4,DR5,DR2,DI5,DI2)
      DO 203 I=1,IDO
      DO 203 K=1,L1
!$omp do
      DO 202 IJ=1,NRXY
          TI5 = CCI(IJ,I,2,K)-CCI(IJ,I,5,K)
          TI2 = CCI(IJ,I,2,K)+CCI(IJ,I,5,K)
          TI4 = CCI(IJ,I,3,K)-CCI(IJ,I,4,K)
          TI3 = CCI(IJ,I,3,K)+CCI(IJ,I,4,K)
          TR5 = CCR(IJ,I,2,K)-CCR(IJ,I,5,K)
          TR2 = CCR(IJ,I,2,K)+CCR(IJ,I,5,K)
          TR4 = CCR(IJ,I,3,K)-CCR(IJ,I,4,K)
          TR3 = CCR(IJ,I,3,K)+CCR(IJ,I,4,K)
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)+TR2+TR3
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)+TI2+TI3
          CR2 = CCR(IJ,I,1,K)+TR11*TR2+TR12*TR3
          CI2 = CCI(IJ,I,1,K)+TR11*TI2+TR12*TI3
          CR3 = CCR(IJ,I,1,K)+TR12*TR2+TR11*TR3
          CI3 = CCI(IJ,I,1,K)+TR12*TI2+TR11*TI3
          CR5 = TI11*TR5+TI12*TR4
          CI5 = TI11*TI5+TI12*TI4
          CR4 = TI12*TR5-TI11*TR4
          CI4 = TI12*TI5-TI11*TI4
          DR3 = CR3-CI4
          DR4 = CR3+CI4
          DI3 = CI3+CR4
          DI4 = CI3-CR4
          DR5 = CR2+CI5
          DR2 = CR2-CI5
          DI5 = CI2-CR5
          DI2 = CI2+CR5
          CHR(IJ,I,K,2) = WA1(2*I-1)*DR2+WA1(2*I)*DI2
          CHI(IJ,I,K,2) = WA1(2*I-1)*DI2-WA1(2*I)*DR2
          CHR(IJ,I,K,3) = WA2(2*I-1)*DR3+WA2(2*I)*DI3
          CHI(IJ,I,K,3) = WA2(2*I-1)*DI3-WA2(2*I)*DR3
          CHR(IJ,I,K,4) = WA3(2*I-1)*DR4+WA3(2*I)*DI4
          CHI(IJ,I,K,4) = WA3(2*I-1)*DI4-WA3(2*I)*DR4
          CHR(IJ,I,K,5) = WA4(2*I-1)*DR5+WA4(2*I)*DI5
          CHI(IJ,I,K,5) = WA4(2*I-1)*DI5-WA4(2*I)*DR5
  202 CONTINUE
!$omp enddo
  203 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG1(NRXY,IDO,IP,L1,IPPH,IPP2,CCR,CCI,CHR,CHI)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(NRXY,IDO,L1,IP),CCR(NRXY,IDO,IP,L1)
      DIMENSION CHI(NRXY,IDO,L1,IP),CCI(NRXY,IDO,IP,L1)
C
!$omp parallel default(shared)
!$omp+private(j,jc,i,k,ij)
      DO 208 J=2,IPPH
          JC = IPP2-J
        DO 207 I=1,IDO
          DO 206 K=1,L1
!$omp do
          DO 205 IJ=1,NRXY
            CHR(IJ,I,K,J) = CCR(IJ,I,J,K)+CCR(IJ,I,JC,K)
            CHI(IJ,I,K,J) = CCI(IJ,I,J,K)+CCI(IJ,I,JC,K)
            CHR(IJ,I,K,JC) = CCR(IJ,I,J,K)-CCR(IJ,I,JC,K)
            CHI(IJ,I,K,JC) = CCI(IJ,I,J,K)-CCI(IJ,I,JC,K)
  205     CONTINUE
!$omp enddo
  206     CONTINUE
  207   CONTINUE
  208 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG2(NRXY,IDO,IP,L1,CCR,CCI,CHR,CHI)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(NRXY,IDO,L1,IP),CCR(NRXY,IDO,IP,L1)
      DIMENSION CHI(NRXY,IDO,L1,IP),CCI(NRXY,IDO,IP,L1)
C
!$omp parallel default(shared)
!$omp+private(k,i,ij)
      DO 518 K=1,L1
        DO 517 I=1,IDO
!$omp do
        DO 516 IJ=1,NRXY
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)
  516   CONTINUE
!$omp enddo
  517   CONTINUE
  518 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG3(NRXY,IDL1,IP,IDO,IPPH,IPP2,C2R,C2I,CH2R,CH2I,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP),WA(*)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
c     !$omp+private(ik,idl,l,lc,idl,ij)
!$omp+private(ik,idl,l,lc,ij)
      DO 133 IK=1,IDL1
          IDL = 2-IDO*2
        DO 132 L=2,IPPH
          LC = IPP2-L
          IDL = IDL+IDO*2
!$omp do
          DO 131 IJ=1,NRXY
          C2R(IJ,IK,L) = CH2R(IJ,IK,1)+WA(IDL-1)*CH2R(IJ,IK,2)
          C2I(IJ,IK,L) = CH2I(IJ,IK,1)+WA(IDL-1)*CH2I(IJ,IK,2)
          C2R(IJ,IK,LC) = WA(IDL)*CH2R(IJ,IK,IP)
          C2I(IJ,IK,LC) = WA(IDL)*CH2I(IJ,IK,IP)
  131   CONTINUE
!$omp enddo
  132   CONTINUE
  133 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG4(NRXY,IDL1,IP,IDO,IDP,IPPH,IPP2,C2R,C2I,CH2R,CH2I
     &                 ,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP),WA(*)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
c     !$omp+private(l,lc,idlj,inc,j,jc,idlj,war,wai,ik)
!$omp+private(l,lc,idlj,inc,j,jc,war,wai,ik)
      DO 138 L=2,IPPH
          LC = IPP2-L
          IDLJ = 2+IDO*2*(L-2)
          INC = IDO*2*(L-1)
        DO 137 J=3,IPPH
            JC = IPP2-J
            IDLJ = IDLJ+INC
            IF (IDLJ .GT. IDP) IDLJ = IDLJ-IDP
            WAR = WA(IDLJ-1)
            WAI = WA(IDLJ)
          DO 136 IK=1,IDL1
!$omp do
          DO 135 IJ=1,NRXY
            C2R(IJ,IK,L) = C2R(IJ,IK,L)+WAR*CH2R(IJ,IK,J)
            C2I(IJ,IK,L) = C2I(IJ,IK,L)+WAR*CH2I(IJ,IK,J)
            C2R(IJ,IK,LC) = C2R(IJ,IK,LC)+WAI*CH2R(IJ,IK,JC)
            C2I(IJ,IK,LC) = C2I(IJ,IK,LC)+WAI*CH2I(IJ,IK,JC)
  135     CONTINUE
!$omp enddo
  136     CONTINUE
  137   CONTINUE
  138 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG5(NRXY,IDL1,IP,IPPH,CH2R,CH2I)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CH2R(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
!$omp+private(j,ik,ij)
      DO 541 J=2,IPPH
        DO 540 IK=1,IDL1
!$omp do
        DO 539 IJ=1,NRXY
          CH2R(IJ,IK,1) = CH2R(IJ,IK,1)+CH2R(IJ,IK,J)
          CH2I(IJ,IK,1) = CH2I(IJ,IK,1)+CH2I(IJ,IK,J)
  539   CONTINUE
!$omp enddo
  540   CONTINUE
  541 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG6(NRXY,IDL1,IP,IPPH,IPP2,C2R,C2I,CH2R,CH2I)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
!$omp+private(ik,j,jc,ij)
      DO 253 IK=1,IDL1
        DO 252 J=2,IPPH
          JC = IPP2-J
!$omp do
          DO 251 IJ=1,NRXY
          CH2R(IJ,IK,J) = C2R(IJ,IK,J)-C2I(IJ,IK,JC)
          CH2I(IJ,IK,J) = C2I(IJ,IK,J)+C2R(IJ,IK,JC)
          CH2R(IJ,IK,JC) = C2R(IJ,IK,J)+C2I(IJ,IK,JC)
          CH2I(IJ,IK,JC) = C2I(IJ,IK,J)-C2R(IJ,IK,JC)
  251   CONTINUE
!$omp enddo
  252   CONTINUE
  253 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG7(NRXY,IDL1,IP,C2R,C2I,CH2R,CH2I)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
!$omp+private(ik,ij)
      DO 255 IK=1,IDL1
!$omp do
      DO 254 IJ=1,NRXY
       C2R(IJ,IK,1) = CH2R(IJ,IK,1)
       C2I(IJ,IK,1) = CH2I(IJ,IK,1)
  254 CONTINUE
!$omp enddo
  255 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG8(NRXY,IDO,IP,L1,C1R,C1I,CHR,CHI)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C1R(NRXY,IDO,L1,IP),CHR(NRXY,IDO,L1,IP)
      DIMENSION C1I(NRXY,IDO,L1,IP),CHI(NRXY,IDO,L1,IP)
C
!$omp parallel default(shared)
!$omp+private(j,k,ij)
      DO 357 J=2,IP
        DO 356 K=1,L1
!$omp do
        DO 355 IJ=1,NRXY
          C1R(IJ,1,K,J) = CHR(IJ,1,K,J)
          C1I(IJ,1,K,J) = CHI(IJ,1,K,J)
  355   CONTINUE
!$omp enddo
  356   CONTINUE
  357 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG9(NRXY,IDO,IP,L1,C1R,C1I,CHR,CHI,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C1R(NRXY,IDO,L1,IP),CHR(NRXY,IDO,L1,IP),WA(*)
      DIMENSION C1I(NRXY,IDO,L1,IP),CHI(NRXY,IDO,L1,IP)
C
!$omp parallel default(shared)
!$omp+private(idj,j,i,idij,k,ij)
        IDJ = -IDO*2
      DO 264 J=2,IP
          IDJ = IDJ+IDO*2
        DO 263 I=2,IDO
            IDIJ = IDJ+I*2
          DO 262 K=1,L1
!$omp do
          DO 261 IJ=1,NRXY
            C1R(IJ,I,K,J) = WA(IDIJ-1)*CHR(IJ,I,K,J)
     &                     - WA(IDIJ  )*CHI(IJ,I,K,J)
            C1I(IJ,I,K,J) = WA(IDIJ-1)*CHI(IJ,I,K,J)
     &                     + WA(IDIJ  )*CHR(IJ,I,K,J)
  261     CONTINUE
!$omp enddo
  262     CONTINUE
  263   CONTINUE
  264 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG1(NRXY,IDO,IP,L1,IPPH,IPP2,CCR,CCI,CHR,CHI)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(NRXY,IDO,L1,IP),CCR(NRXY,IDO,IP,L1)
      DIMENSION CHI(NRXY,IDO,L1,IP),CCI(NRXY,IDO,IP,L1)
C
!$omp parallel default(shared)
!$omp+private(i,j,jc,k,ij)
      DO 108 I=1,IDO
        DO 107 J=2,IPPH
            JC = IPP2-J
          DO 106 K=1,L1
!$omp do
          DO 105 IJ=1,NRXY
            CHR(IJ,I,K,J) = CCR(IJ,I,J,K)+CCR(IJ,I,JC,K)
            CHI(IJ,I,K,J) = CCI(IJ,I,J,K)+CCI(IJ,I,JC,K)
            CHR(IJ,I,K,JC) = CCR(IJ,I,J,K)-CCR(IJ,I,JC,K)
            CHI(IJ,I,K,JC) = CCI(IJ,I,J,K)-CCI(IJ,I,JC,K)
  105     CONTINUE
!$omp enddo
  106   CONTINUE
  107   CONTINUE
  108 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG2(NRXY,IDO,IP,L1,CCR,CCI,CHR,CHI)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(NRXY,IDO,L1,IP),CCR(NRXY,IDO,IP,L1)
      DIMENSION CHI(NRXY,IDO,L1,IP),CCI(NRXY,IDO,IP,L1)
C
!$omp parallel default(shared)
!$omp+private(k,i,ij)
      DO 518 K=1,L1
        DO 517 I=1,IDO
!$omp do
        DO 516 IJ=1,NRXY
          CHR(IJ,I,K,1) = CCR(IJ,I,1,K)
          CHI(IJ,I,K,1) = CCI(IJ,I,1,K)
  516   CONTINUE
!$omp enddo
  517 CONTINUE
  518 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG3(NRXY,IDL1,IP,IDO,IPPH,IPP2,C2R,C2I,CH2R,CH2I,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP),WA(*)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
!$omp+private(ik,idl,l,lc,ij)
      DO 133 IK=1,IDL1
          IDL = 2-IDO*2
        DO 132 L=2,IPPH
          LC = IPP2-L
          IDL = IDL+IDO*2
!$omp do
          DO 131 IJ=1,NRXY
          C2R(IJ,IK,L) = CH2R(IJ,IK,1)+WA(IDL-1)*CH2R(IJ,IK,2)
          C2I(IJ,IK,L) = CH2I(IJ,IK,1)+WA(IDL-1)*CH2I(IJ,IK,2)
          C2R(IJ,IK,LC) = -WA(IDL)*CH2R(IJ,IK,IP)
          C2I(IJ,IK,LC) = -WA(IDL)*CH2I(IJ,IK,IP)
  131   CONTINUE
!$omp enddo
  132   CONTINUE
  133 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG4(NRXY,IDL1,IP,IDO,IDP,IPPH,IPP2,C2R,C2I,CH2R,CH2I
     &                 ,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP),WA(*)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
c    !$omp+private(l,lc,idlj,inc,j,jc,idlj,war,wai,ik)
!$omp+private(l,lc,idlj,inc,j,jc,war,wai,ik)
      DO 138 L=2,IPPH
          LC =IPP2-L
          IDLJ = 2+IDO*2*(L-2)
          INC = IDO*2*(L-1)
        DO 137 J=3,IPPH
            JC = IPP2-J
            IDLJ = IDLJ+INC
            IF (IDLJ .GT. IDP) IDLJ = IDLJ-IDP
            WAR = WA(IDLJ-1)
            WAI = WA(IDLJ)
          DO 136 IK=1,IDL1
!$omp do
          DO 135 IJ=1,NRXY
             C2R(IJ,IK,L) = C2R(IJ,IK,L)+WAR*CH2R(IJ,IK,J)
             C2I(IJ,IK,L) = C2I(IJ,IK,L)+WAR*CH2I(IJ,IK,J)
             C2R(IJ,IK,LC) = C2R(IJ,IK,LC)-WAI*CH2R(IJ,IK,JC)
             C2I(IJ,IK,LC) = C2I(IJ,IK,LC)-WAI*CH2I(IJ,IK,JC)
  135     CONTINUE
!$omp enddo
  136     CONTINUE
  137   CONTINUE
  138 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG5(NRXY,IDL1,IP,IPPH,CH2R,CH2I)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CH2R(NRXY,IDL1,IP)
      DIMENSION CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
!$omp+private(j,ik,ij)
      DO 541 J=2,IPPH
        DO 540 IK=1,IDL1
!$omp do
        DO 539 IJ=1,NRXY
          CH2R(IJ,IK,1) = CH2R(IJ,IK,1)+CH2R(IJ,IK,J)
          CH2I(IJ,IK,1) = CH2I(IJ,IK,1)+CH2I(IJ,IK,J)
  539   CONTINUE
!$omp enddo
  540   CONTINUE
  541 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG6(NRXY,IDL1,IP,IPPH,IPP2,C2R,C2I,CH2R,CH2I)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
!$omp+private(ik,j,jc,ij)
      DO 253 IK=1,IDL1
        DO 252 J=2,IPPH
          JC = IPP2-J
!$omp do
          DO 251 IJ=1,NRXY
          CH2R(IJ,IK,J) = C2R(IJ,IK,J)-C2I(IJ,IK,JC)
          CH2I(IJ,IK,J) = C2I(IJ,IK,J)+C2R(IJ,IK,JC)
          CH2R(IJ,IK,JC) = C2R(IJ,IK,J)+C2I(IJ,IK,JC)
          CH2I(IJ,IK,JC) = C2I(IJ,IK,J)-C2R(IJ,IK,JC)
  251   CONTINUE
!$omp enddo
  252   CONTINUE
  253 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG7(NRXY,IDL1,IP,C2R,C2I,CH2R,CH2I)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C2R(NRXY,IDL1,IP),CH2R(NRXY,IDL1,IP)
      DIMENSION C2I(NRXY,IDL1,IP),CH2I(NRXY,IDL1,IP)
C
!$omp parallel default(shared)
!$omp+private(ik,ij)
      DO 255 IK=1,IDL1
!$omp do
      DO 256 IJ=1,NRXY
       C2R(IJ,IK,1) = CH2R(IJ,IK,1)
       C2I(IJ,IK,1) = CH2I(IJ,IK,1)
  256 CONTINUE
!$omp enddo
  255 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG8(NRXY,IDO,IP,L1,C1R,C1I,CHR,CHI)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION C1R(NRXY,IDO,L1,IP),CHR(NRXY,IDO,L1,IP)
      DIMENSION C1I(NRXY,IDO,L1,IP),CHI(NRXY,IDO,L1,IP)
C
!$omp parallel default(shared)
!$omp+private(j,k,ij)
      DO 358 J=2,IP
        DO 357 K=1,L1
!$omp do
        DO 356 IJ=1,NRXY
          C1R(IJ,1,K,J) = CHR(IJ,1,K,J)
          C1I(IJ,1,K,J) = CHI(IJ,1,K,J)
  356   CONTINUE
!$omp enddo
  357 CONTINUE
  358 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDFG9(NRXY,IDO,L1,IP,C1R,C1I,CHR,CHI,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(NRXY,IDO,L1,IP),C1R(NRXY,IDO,L1,IP),WA(*)
      DIMENSION CHI(NRXY,IDO,L1,IP),C1I(NRXY,IDO,L1,IP)
C
!$omp parallel default(shared)
!$omp+private(idj,j,i,idij,k,ij)
        IDJ = -IDO*2
      DO 264 J=2,IP
          IDJ = IDJ+IDO*2
        DO 263 I=2,IDO
            IDIJ = IDJ+I*2
          DO 262 K=1,L1
!$omp do
          DO 261 IJ=1,NRXY
            C1R(IJ,I,K,J) = WA(IDIJ-1)*CHR(IJ,I,K,J)
     &                     + WA(IDIJ  )*CHI(IJ,I,K,J)
            C1I(IJ,I,K,J) = WA(IDIJ-1)*CHI(IJ,I,K,J)
     &                     - WA(IDIJ  )*CHR(IJ,I,K,J)
  261     CONTINUE
!$omp enddo
  262     CONTINUE
  263   CONTINUE
  264 CONTINUE
!$omp end parallel
      RETURN
      END
      SUBROUTINE THDBG(NRXY,NAC,IDO,IP,L1,IDL1,
     & CCR,CCI,C1R,C1I,C2R,C2I,CHR,CHI,CH2R,CH2I,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(NRXY,IDO,L1,IP),CCR(NRXY,IDO,IP,L1),
     1          C1R(NRXY,IDO,L1,IP),WA(*),C2R(NRXY,IDL1,IP),
     2         CH2R(NRXY,IDL1,IP)
      DIMENSION CHI(NRXY,IDO,L1,IP),CCI(NRXY,IDO,IP,L1),
     1          C1I(NRXY,IDO,L1,IP),      C2I(NRXY,IDL1,IP),
     2         CH2I(NRXY,IDL1,IP)
C
      IPP2 = IP+2
      IPPH = (IP+1)/2
      IDP = IP*IDO*2
C
        CALL THDBG1(NRXY,IDO,IP,L1,IPPH,IPP2,CCR,CCI,CHR,CHI)
        CALL THDBG2(NRXY,IDO,IP,L1,CCR,CCI,CHR,CHI)
        CALL THDBG3(NRXY,IDL1,IP,IDO,IPPH,IPP2,C2R,C2I,CH2R,CH2I,WA)
        CALL THDBG4(NRXY,IDL1,IP,IDO,IDP,IPPH,IPP2,C2R,C2I,CH2R,CH2I,WA)
        CALL THDBG5(NRXY,IDL1,IP,IPPH,CH2R,CH2I)
        CALL THDBG6(NRXY,IDL1,IP,IPPH,IPP2,C2R,C2I,CH2R,CH2I)
      NAC = 1
      IF (IDO*2 .EQ. 2) RETURN
      NAC = 0
C
        CALL THDBG7(NRXY,IDL1,IP,C2R,C2I,CH2R,CH2I)
        CALL THDBG8(NRXY,IDO,IP,L1,C1R,C1I,CHR,CHI)
        CALL THDBG9(NRXY,IDO,IP,L1,C1R,C1I,CHR,CHI,WA)
      RETURN
      END
      SUBROUTINE THDFG(NRXY,NAC,IDO,IP,L1,IDL1,
     & CCR,CCI,C1R,C1I,C2R,C2I,CHR,CHI,CH2R,CH2I,WA)
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION CHR(NRXY,IDO,L1,IP),CCR(NRXY,IDO,IP,L1),
     1          C1R(NRXY,IDO,L1,IP),WA(*),C2R(NRXY,IDL1,IP),
     2          CH2R(NRXY,IDL1,IP)
      DIMENSION CHI(NRXY,IDO,L1,IP),CCI(NRXY,IDO,IP,L1),
     1          C1I(NRXY,IDO,L1,IP),      C2I(NRXY,IDL1,IP),
     2          CH2I(NRXY,IDL1,IP)
C
      IPP2 = IP+2
      IPPH = (IP+1)/2
      IDP = IP*IDO*2
C
        CALL THDFG1(NRXY,IDO,IP,L1,IPPH,IPP2,CCR,CCI,CHR,CHI)
        CALL THDFG2(NRXY,IDO,IP,L1,CCR,CCI,CHR,CHI)
        CALL THDFG3(NRXY,IDL1,IP,IDO,IPPH,IPP2,C2R,C2I,CH2R,CH2I,WA)
        CALL THDFG4(NRXY,IDL1,IP,IDO,IDP,IPPH,IPP2,C2R,C2I,CH2R,CH2I,WA)
        CALL THDFG5(NRXY,IDL1,IP,IPPH,CH2R,CH2I)
        CALL THDFG6(NRXY,IDL1,IP,IPPH,IPP2,C2R,C2I,CH2R,CH2I)
      NAC = 1
      IF (IDO*2 .EQ. 2) RETURN
      NAC = 0
C
        CALL THDFG7(NRXY,IDL1,IP,C2R,C2I,CH2R,CH2I)
        CALL THDFG8(NRXY,IDO,IP,L1,C1R,C1I,CHR,CHI)
        CALL THDFG9(NRXY,IDO,L1,IP,C1R,C1I,CHR,CHI,WA)
      RETURN
      END
