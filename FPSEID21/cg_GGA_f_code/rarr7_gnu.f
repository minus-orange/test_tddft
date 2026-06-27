C ******************************************************************
c  This subroutine generates irreducible latice vectors.
c
c         Original: Drs. K. Shiraishi, T. Nakayama and Prof. N. Shima
c         Modified by Y. Miyamoto 9/28/1995
c ******************************************************************
      SUBROUTINE RARR3(SP,RG,NG,INV,QF,EPS,IPRINT,AKK,KG,KZ,NNK,NKG)
      IMPLICIT REAL*8(A-H,O-Z)
      PARAMETER(LATQ=128)
      DIMENSION KG(3,LATQ),AKK(LATQ),SP(3,3),NN(3)
     &         ,KZ(3,LATQ,48),NNK(LATQ)
      dimension kz0(3,latq,48),nnk0(latq),akk0(latq)
      INTEGER*4 RG(3,3,48)
      REAL*8  AKK,SP
      EQUIVALENCE (N1,NN(1)),(N2,NN(2)),(N3,NN(3))
c **** In case of slab calculation where A3 is normal to the slab
c       use following five lines.
      sp(1,1)=sp(1,1)*100
      sp(1,3)=sp(1,3)*100
      sp(3,1)=sp(3,1)*100
      sp(3,3)=sp(3,3)*100
      sp(1,2)=sp(1,2)*100
      sp(2,1)=sp(2,1)*100
c **** end
      IND=0
      QFF=QF*QF
      A=SP(3,3)
      B0=SP(2,2)*SP(3,3)-SP(2,3)**2
      B=B0/A
      C=(SP(1,1)*SP(2,2)*SP(3,3)+2.0*SP(2,3)*SP(3,1)*SP(1,2)
     &  -(SP(1,1)*SP(2,3)**2+SP(2,2)*SP(3,1)**2+SP(3,3)*SP(1,2)**2))/B0
      N=0
      QN1=-QF/SQRT(C)
      N1=QN1
   20 GK1=N1
      SB=-(SP(1,2)*SP(3,3)-SP(1,3)*SP(2,3))*GK1/B0
      S=C*GK1*GK1
      RS=QFF-S
      IF(RS) 65,21,21
   21 QN2=SB-SQRT(RS/B)
      N2=QN2
      IF(QN2.GT.0.0) N2=N2+1
   22 GK2=N2
      SA=-(SP(1,3)*GK1+SP(2,3)*GK2)/A
      SS=S+B*(GK2-SB)**2
      RS=QFF-SS
      IF(RS) 64,23,23
   23 QN3=SA-SQRT(RS/A)
      N3=QN3
      IF(QN3.GT.0.0) N3=N3+1
   24 GK3=N3
      SSS=SS+A*(GK3-SA)**2
      IF(QFF-SSS) 62,25,25
   25 IF(N) 46,46,26
   26 DO 28 K=1,NKG
      IF(AKK(K)-(SSS-EPS)) 28,32,32
   28 CONTINUE
      IF(N-LATQ) 30,50,50
   30 K=N+1
      GO TO 48
   32 IF(AKK(K)-(SSS+EPS)) 52,52,34
   34 IF(N-LATQ) 38,36,36
   36 IF(NKG-K) 48,48,40
   40 KM=K+1
      GO TO 42
   38 KM=K
   42 DO 44 KK=KM,NKG
      KS=NKG-KK+K
      AKK(KS+1)=AKK(KS)
      DO 41 J=1,3
   41 KG(J,KS+1)=KG(J,KS)
   44 CONTINUE
      GO TO 48
   46 K=1
   48 AKK(K)=SSS
      DO 49 I=1,3
   49 KG(I,K)=NN(I)
   50 N=N+1
      NKG=MIN0(N,LATQ)
      GO TO 60
   52 DO 54 IV=1,INV+1
      DO 54 IG=1,NG
      DO 55 I=1,3
      IS=0
      DO 56 M=1,3
   56 IS=IS+RG(M,I,IG)*KG(M,K)
      IF( IV.EQ.2) IS=-IS
      IF(IS-NN(I)) 54,55,54
   55 CONTINUE
      GO TO 60
   54 CONTINUE
      IF(K.GE.LATQ) GO TO 50
      K=K+1
      IF(K.GT.NKG) GO TO 48
      IF(AKK(K)-(SSS+EPS)) 52,52,34
   60 N3=N3+1
      GO TO 24
   62 N2=N2+1
      GO TO 22
   64 N1=N1+1
      GO TO 20
   65 CONTINUE
      IF(N.GT.NKG) IND=-1
C
      WRITE(6,6000) NKG, IND
 6000 FORMAT(/8X,
     &'  **** RARR3: NEXPND = ',I4,' IND = ',I2,' SHOULD BE 0')
C
c      IF(IPRINT.NE.0) WRITE(6,100) N
c  100 FORMAT(8X
c     &'              N = ',I3,'   NO  KR1 KR2 KR3    ADR ')
c      IF(IPRINT) 90,88,90
c   90 write(6,*)' Reducible R-vectors '
c      DO 92 KK=1,NKG
c      WRITE(6,2000) KK,(KG(I,KK),I=1,3),AKK(KK)
c 2000 FORMAT(31X,I3,2X,3I3,2X,D13.5)
c   92 CONTINUE
CC
   88 DO 71 KK=1,NKG
      KS=1
      KZ(1,KK,1)=KG(1,KK)
      KZ(2,KK,1)=KG(2,KK)
      KZ(3,KK,1)=KG(3,KK)
      DO 72 IG=1,NG
      DO 72 IW=1,-1,-2
      KK1=RG(1,1,IG)*KG(1,KK)+RG(2,1,IG)*KG(2,KK)+RG(3,1,IG)*KG(3,KK)
      KK2=RG(1,2,IG)*KG(1,KK)+RG(2,2,IG)*KG(2,KK)+RG(3,2,IG)*KG(3,KK)
      KK3=RG(1,3,IG)*KG(1,KK)+RG(2,3,IG)*KG(2,KK)+RG(3,3,IG)*KG(3,KK)
      KK1=KK1*IW
      KK2=KK2*IW
      KK3=KK3*IW
      DO 73 KX=1,KS
      IF((KK1.EQ.KZ(1,KK,KX)).AND.(KK2.EQ.KZ(2,KK,KX)).AND.
     &   (KK3.EQ.KZ(3,KK,KX))) GO TO 72
   73 CONTINUE
      KS=KS+1
      KZ(1,KK,KS)=KK1
      KZ(2,KK,KS)=KK2
      KZ(3,KK,KS)=KK3
   72 CONTINUE
      NNK(KK)=KS
   71 CONTINUE
c **** now generate irreducible R-vectors ***
c
c **** temp check
c      write(6,*)' Before taking copies '
c      write(6,*) '  nnk '
c      write(6,*)(nnk(kk),kk=1,nkg)
c      write(6,*)
c      write(6,*)' kz '
c      do 302 kk=1,nkg
c      write(6,*) '  kk = ',kk
c      do 302 ks=1,nnk(kk)
c  302 write(6,*)(kz(i,kk,ks),i=1,3),akk(kk)
c **** temp check end
c  ******  first, take backup copies ***
      do 101 kk=1,nkg
      nnk0(kk)=nnk(kk)
      akk0(kk)=akk(kk)
      do 101 ks=1,nnk(kk)
      kz0(1,kk,ks)=kz(1,kk,ks) 
      kz0(2,kk,ks)=kz(2,kk,ks) 
      kz0(3,kk,ks)=kz(3,kk,ks) 
  101 continue
c **** temp check
c      write(6,*)' Check after taking copies '
c      write(6,*) '  nnk0 '
c      write(6,*)(nnk0(kk),kk=1,nkg)
c      write(6,*)
c      write(6,*)' kz0 '
c      do 301 kk=1,nkg
c      write(6,*) '  kk = ',kk
c      do 301 ks=1,nnk(kk)
c  301 write(6,*)(kz0(i,kk,ks),i=1,3),akk0(kk)
c **** temp check end
c
c  ******  second, look for equivalent R-vectors ***
      kseq=1
      do 102 kk=2,nkg
      kzx=kz0(1,kk,1)
      kzy=kz0(2,kk,1)
      kzz=kz0(3,kk,1)
      ieq=0
      do 103 kk0=1,kk-1
      do 103 ks0=1,nnk0(kk0)
      if (kzx.eq.kz0(1,kk0,ks0) .and.
     &    kzy.eq.kz0(2,kk0,ks0) .and.
     &    kzz.eq.kz0(3,kk0,ks0) ) then
      ieq=1
      goto 104
      end if
  103 continue
c**
  104 continue
c******   Finally, renumber the R-vectors
      if ( ieq.eq.0 ) then
      kseq=kseq+1
      if ( kseq.gt.latq ) then
       kseq=kseq-1
       goto 112
      endif
      nnk(kseq)=nnk0(kk)
      akk(kseq)=akk0(kk)
      kg(1,kseq)=kz0(1,kk,1)
      kg(2,kseq)=kz0(2,kk,1)
      kg(3,kseq)=kz0(3,kk,1)
      do 201 ks=1,nnk(kseq)
      kz(1,kseq,ks)=kz0(1,kk,ks)
      kz(2,kseq,ks)=kz0(2,kk,ks)
      kz(3,kseq,ks)=kz0(3,kk,ks)
  201 continue
      end if 
  102 continue
  112 continue
      nkg=kseq
C
      IF(IPRINT.NE.0) WRITE(6,100) N
  100 FORMAT(8X,
     &'              N = ',I3,'   NO  KR1 KR2 KR3    ADR ')
      IF(IPRINT) 80,88,80
   80 write(6,*)' R-vectors'
      DO 83 KK=1,NKG
      write(6,*)' seq. #   # of stars     length'
      WRITE(6,2000) KK,nnk(kk),AKK(KK)
      do 82 ks=1,nnk(kk)
      WRITE(6,2010)(Kz(I,KK,ks),I=1,3)
   82 CONTINUE
   83 CONTINUE
 2000 FORMAT(3X,I3,9x,i3,7x,D13.5)
 2010 FORMAT(2X,3x,2X,3I3,'       R-vector')
CC
      RETURN
      END
