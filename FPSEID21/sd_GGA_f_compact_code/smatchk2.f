C ********************************************************************
C        CHECK OF S-MATRIX AND CONSISTENCY WITH ACTUAL COORDINATES.
C                        A. OSHIYAMA  6/22/93
C ********************************************************************
      SUBROUTINE SMATCHK2( S, TAU, CTAU, B1, B2, B3, ALAT,
     &                    NTOT, NTAUQ )
      IMPLICIT REAL*8 (A-H, O-Z)
      INTEGER  S(3,3,48), IS(3,3)
      DIMENSION TAU(3,NTAUQ), CTAU(3,NTAUQ), B1(3), B2(3), B3(3)
      DATA  ONE/1.0D+00/, ZERO/0.0D+00/
C
      WRITE(6,1000)
 1000 FORMAT(/
     &'   **** SMATCHK: THIS VERSION DOES NOT RECOGNIZE ATOM TYPE.')
C
      DO 1 I = 1, NTOT
      DO 2 J = 1, NTOT
          DO 3 K1 = 1, 3
          DO 3 K2 = 1, 3
    3     IS(K1,K2) = 0
          DO 4 K1 = 1, 3
          DO 4 K2 = 1, 3
    4     IS(K1,K2) = IS(K1,K2) + S(K1,1,I) * S(1,K2,J)
     &                          + S(K1,2,I) * S(2,K2,J)
     &                          + S(K1,3,I) * S(3,K2,J)
      NUM = 0
          DO 5 JP = 1, NTOT
             DO 6 K1 = 1, 3
             DO 6 K2 = 1, 3
             IF( IS(K1,K2) .NE. S(K1,K2,JP) ) GO TO 5
    6        CONTINUE
          NUM = NUM + 1
    5     CONTINUE
C
      IF( NUM .NE. 1 ) THEN
         WRITE(6,1010) NUM, I, J,
     &    ( (S(K1,K2,I), K2=1,3), (S(K1,K2,J), K2=1,3),
     &      (IS(K1,K2), K2=1,3),  K1 = 1, 3             )
 1010    FORMAT(10X,'  SOMETHING WRONG FOR S MATRIX: ',
     &              '  NUM I J = ',3I3/
     &   (15X,3I3,3X,3I3,3X,3I3) )
         STOP
      END IF
C
    2 CONTINUE
    1 CONTINUE
C ***
C    CHECK OF CLOSED ALGEBRA FOR  MATRICES IS COMPLETED
C ***
      DO 10 IAT = 1, NTAUQ
      C1 = (  TAU(1,IAT)*B1(1) + TAU(2,IAT)*B1(2)
     &                         + TAU(3,IAT)*B1(3) ) / ALAT
      C2 = (  TAU(1,IAT)*B2(1) + TAU(2,IAT)*B2(2)
     &                         + TAU(3,IAT)*B2(3) ) / ALAT
      C3 = (  TAU(1,IAT)*B3(1) + TAU(2,IAT)*B3(2)
     &                         + TAU(3,IAT)*B3(3) ) / ALAT
c                                  CTAU(1,IAT) = MOD(C1,ONE)
c      IF( CTAU(1,IAT) .LT. ZERO ) CTAU(1,IAT) = CTAU(1,IAT) + ONE
c                                  CTAU(2,IAT) = MOD(C2,ONE)
c      IF( CTAU(2,IAT) .LT. ZERO ) CTAU(2,IAT) = CTAU(2,IAT) + ONE
c                                  CTAU(3,IAT) = MOD(C3,ONE)
c      IF( CTAU(3,IAT) .LT. ZERO ) CTAU(3,IAT) = CTAU(3,IAT) + ONE
c *** Modified rescaling
      do i=1,3
      call rescale( ctau(i,IAT ) )
      enddo
   10 CONTINUE
C
      DO 12 IAT = 1, NTAUQ
      DO 14 IOP = 1, NTOT
      CP1 =  CTAU(1,IAT) * DBLE( S(1,1,IOP) )
     &     + CTAU(2,IAT) * DBLE( S(2,1,IOP) )
     &     + CTAU(3,IAT) * DBLE( S(3,1,IOP) )
      CP2 =  CTAU(1,IAT) * DBLE( S(1,2,IOP) )
     &     + CTAU(2,IAT) * DBLE( S(2,2,IOP) )
     &     + CTAU(3,IAT) * DBLE( S(3,2,IOP) )
      CP3 =  CTAU(1,IAT) * DBLE( S(1,3,IOP) )
     &     + CTAU(2,IAT) * DBLE( S(2,3,IOP) )
     &     + CTAU(3,IAT) * DBLE( S(3,3,IOP) )
c                          C1 = MOD(CP1,ONE)
c      IF( C1 .LT. ZERO )  C1 = C1 + ONE
c                          C2 = MOD(CP2,ONE)
c      IF( C2 .LT. ZERO )  C2 = C2 + ONE
c                          C3 = MOD(CP3,ONE)
c      IF( C3 .LT. ZERO )  C3 = C3 + ONE
c **** Modified rescaling
       c1=cp1
       c2=cp2
       c3=cp3
       call rescale(c1)
       call rescale(c2)
       call rescale(c3)
C
           NUM = 0
        DO 16 JAT = 1, NTAUQ
        IF( ABS(C1-CTAU(1,JAT)) .GT. 0.1D-04 ) GO TO 16
        IF( ABS(C2-CTAU(2,JAT)) .GT. 0.1D-04 ) GO TO 16
        IF( ABS(C3-CTAU(3,JAT)) .GT. 0.1D-04 ) GO TO 16
           NUM = NUM + 1
C          WRITE(6,1020) IAT, JAT, IOP
C1020      FORMAT(10X,3X,I4,'-TH ATOM IS MAPPED ON ',I4,'-TH ATOM ',
C    &                      ' BY ',I2,'-TH OPERATION.')
   16   CONTINUE
C
      IF(NUM.EQ.0) THEN
      WRITE(6,1040) IOP, IAT, C1, C2, C3
 1040 FORMAT(10X,'   SYMMETRY OPERATION ',I3,' ON ',I4,'TH ATOM NOT',
     &           ' TRANSFORM ANOTHER ATOM.'/
     &       10X,'     C1 C2 C3 = ',3D18.10)
      STOP
      END IF
C
   14 CONTINUE
   12 CONTINUE
C
      WRITE(6,1100)
 1100 FORMAT(
     &'                 NORMAL END')
C
      RETURN
      END
c
      subroutine rescale(a1)
      implicit double precision (a-h,o-z)
  998 continue
      mcyc=0
      if ( a1.ge. 0.5d0 ) then
        a1=a1-1.d0
        mcyc=mcyc+1
      elseif ( a1.lt. -0.5d0 ) then
        a1=a1+1.d0
        mcyc=mcyc+1
      endif
      if ( mcyc.eq.0 ) then
       return
      else
      goto 998
      endif
      end
