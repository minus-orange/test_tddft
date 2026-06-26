C ******************************************************************
C **********************************************************                    
C *                                                        *                    
C *  THIS PROGRAM IS MADE FOR CALCULATING                  *                    
C *                                                        *                    
C *              THE DENSITY OF STATE                      *                    
C *                                     1989/07/25         *                    
c *  PE: En(R) : Fourier component of En(K)  (eV)
c *  EF: Fermi level            (eV)
c *  EF1: upper limit of energy (eV)
c *  EF2: lower limit of energy (eV)
c *  EDD: energy resolution     (eV)
c *  Y  : work
c *  NB1: lowest band of interest
c *  NB2: highest band of interest
c *  NKR: # of lattice vectors for interpoation
c *  KZ : indices of lattice vectors
c * IIL,IRL:  set to be one
c * NNG : # of symmetry operations  -- >
c * DIMENSION OF KZ -- > lattice vectors
c
c   DOS output file # 99:
c
C **********************************************************                    
      SUBROUTINE DOSGEN(PE,EF,EF1,EF2,Y,NDIM                                    
     &              ,NDX,NDY,NDZ,NB1,NB2,NKR,NNG,IIL,IRL                        
     &              ,NSY,KZ,LATQ,EDD                                      
     &              )                                                           
      IMPLICIT REAL*8(A-H,O-Z)                                                  
      DIMENSION PE(NB1:NB2,NKR)                                                 
C *****  FOR GAUSSIAN TYPE BASES **********                                     
CCC   DIMENSION KZ(3,NKR,NNG),NSY(NKR)                                          
      DIMENSION KZ(3,LATQ,NNG),NSY(LATQ)                                        
      REAL*8 Y(NDIM)                                                            
C                                                                               
c *** temp check
      write(6,*)' EDD = ',edd
      write(6,*)' EF1 = ',ef1
      write(6,*)' EF2 = ',ef2
      miya=12
      if ( miya.eq.13 ) stop
c *** temp check end
      I1=1                                                                      
      I2=I1+IRL*(2*NDX+1)*(2*NDY+1)*(NDZ+1)*(NB2-NB1+1)                         
      I3=I2+IRL*(4*NDX+1)*(4*NDY+1)*(2*NDZ+1)*(NB2-NB1+1)                       
      I4=I3+(IIL*NKR-1)/2+1                                                     
      I5=I4+(IIL*3*NKR*NNG-1)/2+1                                               
CCC ********************                                                        
C     Y(I3)= NSY(LATQ)                                                          
C     Y(I4)= KZ(3,LATQ,48)                                                      
CCC ********************                                                        
C     ISEQ=I4                                                                   
C     DO 894 IK=1,NKR                                                           
C     Y(I3+IK-1)=NSY(IK)                                                        
C     DO 894 ISY=1,NNG                                                          
C     Y(ISEQ  )=KZ(1,IK,ISY)                                                    
C     Y(ISEQ+1)=KZ(2,IK,ISY)                                                    
C     Y(ISEQ+2)=KZ(3,IK,ISY)                                                    
C     ISEQ=ISEQ+3                                                               
C 894 CONTINUE                                                                  
CCC ********************                                                        
C ****  TEMP CEHCK                                                              
C     WRITE(6,*)                                                                
C     WRITE(6,*)' AFTER CALLING "DOS" '                                         
C     WRITE(6,*)'***  LATTICE VECTORS ******'                                   
C     DO 593 IK=1,NKR                                                           
C     DO 593 IR=1,NSY(IK)                                                       
C     WRITE(6,*)KZ(1,IK,IR),KZ(2,IK,IR),KZ(3,IK,IR)                             
C 593 CONTINUE                                                                  
C ****  TEMP CEHCK END                                                          
CCC   CALL       EDEF(PE,Y(I1),Y(I2),Y(I3),Y(I4)                                
      CALL       EDEF(PE,Y(I1),Y(I2),NSY,KZ,LATQ                                
     &               ,NDX,NDY,NDZ,NB1,NB2,NKR,NNG                               
     &               )                                                          
C                                                                               
      I5=I4+(IIL*3*NKR-1)/2+1                                                   
      IDIM=NDIM-I4+1                                                            
C  ************  TEMP CHECK  ***************                                    
      WRITE(6,*)                                                                
      WRITE(6,*)'  IN SUB. DOSGEN    IDIM = ',IDIM                              
      IF( IDIM.LT.0 ) STOP                                                      
      WRITE(6,*)                                                                
C  ************  TEMP CHECK END ************                                    
CCC   CALL     DOSGEN2(PE,Y(I1),Y(I2),Y(I5),IDIM,EF,EF1,EF2                     
      CALL     DOSGEN2(Y(I1),Y(I2),Y(I5),IDIM,EF,EF1,EF2                        
CCC  &               ,NDX,NDY,NDZ,NB1,NB2,NKR)                                  
     &               ,NDX,NDY,NDZ,NB1,NB2,EDD)                             
C                                                                               
      RETURN                                                                    
      END                                                                       
C                                                                               
C                                                                               
CCC   SUBROUTINE DOSGEN2(PE,EMESH1,EMESH2,Y,NDIM,EF,EF1,EF2                     
      SUBROUTINE DOSGEN2(EMESH1,EMESH2,Y,NDIM,EF,EF1,EF2                        
CCC  &                ,NDX,NDY,NDZ,NB1,NB2,NKR)                                 
     &                ,NDX,NDY,NDZ,NB1,NB2,EDD)                            
      IMPLICIT REAL*8(A-H,O-Z)                                                  
      DIMENSION EMESH1(  -NDX:NDX,    -NDY:NDY,  0:NDZ  ,NB1:NB2)               
      DIMENSION EMESH2(-NDX*2:NDX*2,-NDY*2:NDY*2,0:NDZ*2,NB1:NB2)               
      DATA PAI/3.14159265358979324D0/                                           
      REAL*8 Y(NDIM)                                                            
      DATA MCYCL,EPS /100,1.0D-8/                                               
CC                                                                              
C                                                                               
c      NXY6=(4*(NDX+NDY)+2)*6                                                
       NXY6=(2*NDX+1)*(2*NDY+1)*NDZ
c      NXY60=(8*(NDX+NDY)+2)*6                                            
       NXY60=(4*NDX+1)*(4*NDY+1)*2*NDZ
C                                                                               
CCC   I10=NXY60*22                                                              
      I10=NXY60*13                                                              
C                                                                               
C ********  TEMP CHECK  *******************                                     
C     WRITE(6,*)                                                                
C     WRITE(6,*)'  IN SUB. DOSGEN2    I10 = ',I10,' NDIM = ',NDIM               
C     WRITE(6,*)                                                                
C ********  TEMP CHECK END  ***************                                     
C                                                                               
c      READ(5,*)EDD                      
c      EDD=EDD/13.6D0                    
      EE=EF1-EDD                                                                
      ISEQ=-1                                                                   
 1000 CONTINUE                                                                  
      EE=EE+EDD                                                                 
c **** temp check
c      write(6,*)' EE = ',EE
c **** temp check end
C     EH=EE+EDD*0.5D0                                                           
C     EL=EE-EDD*0.5D0                                                           
      EH=EE                                                                     
      EL=EE-EDD                                                                 
      ISEQ=ISEQ+2                                                               
      IF(   EL.GT.EF2  .OR. ISEQ.GT.NDIM-I10 ) GO TO 2000                       
      S=0.0D0                                                                   
      DO 10 IB=NB1,NB2                                                          
      EMIN= 9999.9D0                                                            
      EMAX=-9999.9D0                                                            
      CALL DFMXMN(EMESH1(-NDX  ,-NDY  ,0,IB),(2*NDX+1)*(2*NDY+1)*NDZ            
     &           ,EMAX,EMIN )                                                   
      CALL DFMXMN(EMESH2(-NDX*2,-NDY*2,0,IB),(4*NDX+1)*(4*NDY+1)*NDZ*2          
     &           ,EMAX,EMIN )                                                   
      IF ( EH.LT.EMIN .OR. EL.GT.EMAX ) GO TO 10                                
      S1=0.0D0                                                                  
      S2=0.0D0                                                                  
      CALL FERGEN2(EMESH1(-NDX  ,  -NDY,0,IB),Y,S1,EH,EL                        
     &           ,NDX  ,NDY  ,NDZ  ,NXY6 )                                      
      CALL FERGEN2(EMESH2(-NDX*2,-NDY*2,0,IB),Y,S2,EH,EL                        
     &           ,NDX*2,NDY*2,NDZ*2,NXY60)                                      
      SS=(4.0D0*S2-S1)/3.0D0                                                    
      S=S+SS                                                                    
   10 CONTINUE                                                                  
      Y( I10+ISEQ   )=EE                                                        
      Y( I10+ISEQ+1 )=S                                                         
      GO TO 1000                                                                
 2000 WRITE(6,*)'  MAX ENERGY = ',EE                                            
C                                                                               
      WRITE( 6,1212)( Y(I10+II),Y(I10+II+1),II=1,ISEQ-2,2)                      
 1212 FORMAT(2(' E=',D11.4,' ED=',D14.6))                                       
C  ******* TEMP CHECK FOR TOTAL NUMBER ***********                              
      WRITE(6,*)                                                                
      WRITE(6,*)' IN SUB.DOSGEN  EF = ',EF                                      
      SZVAL=0                                                                   
      DO 1414 II=1,ISEQ-2,2                                                     
      IF( Y(I10+II).GT.EF ) GO TO 1415                                          
      SZVAL=SZVAL+Y(I10+II+1)                                                   
 1414 CONTINUE                                                                  
 1415 CONTINUE                                                                  
      WRITE(6,*)' TOTAL NUMBER  = ',SZVAL                                       
C  ******* TEMP CHECK FOR TOTAL NUMBER END *******                              
c 
c   type DOS !!!!!
c
c
      REWIND 99                                                                 
      WRITE(99,*)ISEQ                                                           
      do ii=1,iseq-2,2
      WRITE(99,1213) Y(I10+II),Y(I10+II+1)                      
      enddo
c                     Energy    Dos             # data points
 1213 FORMAT(2D15.7)                                                            
C                                                                               
      RETURN                                                                    
      END                                                                       
C                                                                               
      SUBROUTINE DFMXMN(E,M,EMAX,EMIN )                                         
      IMPLICIT REAL*8(A-H,O-Z)                                                  
      DIMENSION E(M)                                                            
      DO 10 I=1,M                                                               
       EMAX=MAX( EMAX,E(I) )                                                    
       EMIN=MIN( EMIN,E(I) )                                                    
   10 CONTINUE                                                                  
      RETURN                                                                    
      END                                                                       
C                                                                               
C *************************************************************                 
C *  DENSITY OF STATE      END                                *                 
C *************************************************************                 
C *****************************************************                         
C *                                                   *                         
C *  CALCULATING THE DENDITY OF STATES                *                         
C *                                                   *                         
C *                  1989/07/04                       *                         
C *                                                   *                         
C *****************************************************                         
      SUBROUTINE FERGEN2(EMESH,E,S,EH,EL,NDX,NDY,NDZ,NXY6 )                     
      IMPLICIT REAL*8(A-H,O-Z)                                                  
      DIMENSION EMESH(-NDX:NDX,-NDY:NDY,0:NDZ)                                  
      DIMENSION E(NXY6,13)                                                      
CCCC  DATA PI2/6.28318530717958648D0/                                           
C                                                                               
      DO 20 IZ=0,NDZ-1                                                          
      NIS=0                                                                     
      DO 30 IY=-NDY,NDY-1                                                       
      DO 30 IX=-NDX,NDX-1                                                       
C                                                                               
      A1=MAX(EMESH(IX,IY  ,IZ  ),EMESH(IX+1,IY  ,IZ  ))                         
      A2=MAX(EMESH(IX,IY+1,IZ  ),EMESH(IX+1,IY+1,IZ  ))                         
      A1=MAX(A1,A2)                                                             
      A2=MAX(EMESH(IX,IY  ,IZ+1),EMESH(IX+1,IY  ,IZ+1))                         
      A1=MAX(A1,A2)                                                             
      A2=MAX(EMESH(IX,IY+1,IZ+1),EMESH(IX+1,IY+1,IZ+1))                         
      A1=MAX(A1,A2)                                                             
C                                                                               
      A2=MIN(EMESH(IX,IY  ,IZ  ),EMESH(IX+1,IY  ,IZ  ))                         
      A3=MIN(EMESH(IX,IY+1,IZ  ),EMESH(IX+1,IY+1,IZ  ))                         
      A2=MIN(A2,A3)                                                             
      A3=MIN(EMESH(IX,IY  ,IZ+1),EMESH(IX+1,IY  ,IZ+1))                         
      A2=MIN(A2,A3)                                                             
      A3=MIN(EMESH(IX,IY+1,IZ+1),EMESH(IX+1,IY+1,IZ+1))                         
      A2=MIN(A2,A3)                                                             
C                                                                               
      IF(EL.GT.A1 .OR. EH.LT.A2) GO TO 30                                       
      NIS=NIS+1                                                                 
      E(NIS,1)=EMESH(IX  ,IY  ,IZ  )                                            
      E(NIS,2)=EMESH(IX  ,IY+1,IZ  )                                            
      E(NIS,3)=EMESH(IX  ,IY  ,IZ+1)                                            
      E(NIS,4)=EMESH(IX  ,IY+1,IZ+1)                                            
      E(NIS,5)=EMESH(IX+1,IY  ,IZ  )                                            
      E(NIS,6)=EMESH(IX+1,IY+1,IZ  )                                            
      E(NIS,7)=EMESH(IX+1,IY  ,IZ+1)                                            
      E(NIS,8)=EMESH(IX+1,IY+1,IZ+1)                                            
   30 CONTINUE                                                                  
      IF(NIS.GT.NXY6) GO TO 900                                                 
      IF(NIS.EQ.0) GO TO 20                                                     
      CALL EFINTP2(E(1,1),E(1,2),E(1,3),E(1,4)                                  
     &            ,E(1,5),E(1,6),E(1,7),E(1,8)                                  
     &           ,E(1,9),E(1,10),E(1,11),E(1,12),E(1,13),EH,EL,S,NIS )          
   20 CONTINUE                                                                  
      S=S/DFLOAT(8*NDX*NDY*NDZ)                                                 
C ****  TEMP CHECK                                                              
C     IF( NIS.NE.0 ) THEN                                                       
C     WRITE(6,*)                                                                
C     WRITE(6,*)' IN SUB.FERGEN2: NIS = ',NIS                                   
C     WRITE(6,*)'               :   S = ',S                                     
C     END IF                                                                    
C ****  TEMP CHECK                                                              
      RETURN                                                                    
  900 WRITE(6,*) 'NXY6 IS TOO SMALL'                                            
      STOP                                                                      
      END                                                                       
      SUBROUTINE EFINTP2(E1,E2,E3,E4,E5,E6,E7,E8                                
     &                 ,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS  )                       
      IMPLICIT REAL*8(A-H,O-Z)                                                  
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)                                 
      DIMENSION E5(NIS),E6(NIS),E7(NIS),E8(NIS)                                 
      DIMENSION EE1(NIS),EE2(NIS),EE3(NIS),EE4(NIS)                             
      LOGICAL LB(NIS,2)                                                         
CC                                                                              
      CALL TETRA32(E1,E2,E3,E5,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS)                  
      CALL TETRA32(E2,E3,E5,E7,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS)                  
      CALL TETRA32(E2,E5,E6,E7,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS)                  
      CALL TETRA32(E4,E3,E2,E8,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS)                  
      CALL TETRA32(E3,E2,E8,E6,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS)                  
      CALL TETRA32(E3,E8,E7,E6,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS)                  
      RETURN                                                                    
      END                                                                       
      SUBROUTINE TETRA32(E1,E2,E3,E4,EE1,EE2,EE3,EE4,LB,EH,EL,S,NIS)            
      IMPLICIT REAL*8(A-H,O-Z)                                                  
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)                                 
      DIMENSION EE1(NIS),EE2(NIS),EE3(NIS),EE4(NIS)                             
      LOGICAL LB(NIS,2)                                                         
C                                                                               
      DO 10 I=1,NIS                                                             
      A     =MAX(E1(I) ,E2(I) )                                                 
      EE2(I)=MAX(E3(I) ,E4(I) )                                                 
      EE3(I)=MIN(E1(I) ,E2(I) )                                                 
      B     =MIN(E3(I) ,E4(I) )                                                 
      EE1(I)=MAX(A     ,EE2(I))                                                 
      A     =MIN(A     ,EE2(I))                                                 
      EE4(I)=MIN(EE3(I),B     )                                                 
      B     =MAX(EE3(I),B     )                                                 
      EE2(I)=MAX(A     ,B     )                                                 
      EE3(I)=MIN(A     ,B     )                                                 
   10 CONTINUE                                                                  
C                                                                               
      CALL TETRA42(EE1,EE2,EE3,EE4,LB(1,1),S,EH,EL,NIS)                         
      RETURN                                                                    
      END                                                                       
C                                                                               
      SUBROUTINE TETRA42(E1,E2,E3,E4,LB,S,EH,EL,NIS)                            
      IMPLICIT REAL*8(A-H,O-Z)                                                  
      DIMENSION E1(NIS),E2(NIS),E3(NIS),E4(NIS)                                 
      LOGICAL LB(NIS,2)                                                         
      DATA THIRD/0.333333333333333333333333333333D0/                            
C                                                                               
      DO 1 IN=1,NIS                                                             
      IF ( EL.EQ.E1(IN) .AND. E1(IN).EQ.E2(IN) ) THEN                           
      LB(IN,1)=.FALSE.                                                          
      ELSE                                                                      
      LB(IN,1)=.TRUE.                                                           
      END IF                                                                    
    1 CONTINUE                                                                  
C                                                                               
      DO 2 IN=1,NIS                                                             
      IF ( EH.EQ.E3(IN) .AND. E3(IN).EQ.E4(IN) ) THEN                           
      LB(IN,2)=.FALSE.                                                          
      ELSE                                                                      
      LB(IN,2)=.TRUE.                                                           
      END IF                                                                    
    2 CONTINUE                                                                  
C                                                                               
      DO 10 IN=1,NIS                                                            
      IF( EH.GT.E1(IN) .AND. E1(IN).GE.EL .AND. EL.GT.E2(IN)                    
     &                 .AND. LB(IN,1) )THEN                                     
      S=S+THIRD*( E1(IN)-EL     )*( E1(IN)-EL     )*( E1(IN)-EL     )           
     &         /( E1(IN)-E2(IN) )/( E1(IN)-E3(IN) )/( E1(IN)-E4(IN) )           
      END IF                                                                    
   10 CONTINUE                                                                  
      DO 20 IN=1,NIS                                                            
      IF ( E1(IN).GE.EH .AND. EL.GT.E2(IN) ) THEN                               
      S=S+THIRD*(                                                               
     &  ( E1(IN)-EL     )*( E1(IN)-EL     )*( E1(IN)-EL     )                   
     & /( E1(IN)-E2(IN) )/( E1(IN)-E3(IN) )/( E1(IN)-E4(IN) )                   
     & -( E1(IN)-EH     )*( E1(IN)-EH     )*( E1(IN)-EH     )                   
     & /( E1(IN)-E2(IN) )/( E1(IN)-E3(IN) )/( E1(IN)-E4(IN) )                   
     &           )                                                              
      END IF                                                                    
   20 CONTINUE                                                                  
      DO 30 IN=1,NIS                                                            
      IF ( E1(IN).GE.EH .AND. EH.GT.E2(IN) .AND. E2(IN).GE.EL                   
     &                  .AND. EL.GT.E3(IN) )THEN                                
      S=S+THIRD*(                                                               
     &   ( E2(IN)-EL     )*( E2(IN)-EL     )                                    
     &  /( E2(IN)-E3(IN) )/( E2(IN)-E4(IN) )                                    
     &  +( E2(IN)-EL     )*( E3(IN)-EL     )*( EL    -E1(IN) )                  
     &  /( E2(IN)-E4(IN) )/( E3(IN)-E2(IN) )/( E3(IN)-E1(IN) )                  
     &  +( EL    -E4(IN) )*( EL    -E1(IN) )*( EL    -E1(IN) )                  
     &  /( E2(IN)-E4(IN) )/( E3(IN)-E1(IN) )/( E4(IN)-E1(IN) )                  
     &  -( E1(IN)-EH     )*( E1(IN)-EH     )*( E1(IN)-EH     )                  
     &  /( E1(IN)-E2(IN) )/( E1(IN)-E3(IN) )/( E1(IN)-E4(IN) )                  
     &           )                                                              
      END IF                                                                    
   30 CONTINUE                                                                  
      DO 40 IN=1,NIS                                                            
      IF( E2(IN).GE.EL .AND. EL.GT.E3(IN) .AND. EH.GT.E1(IN) ) THEN             
      S=S+THIRD*(                                                               
     &  ( E2(IN)-EL     )*( E2(IN)-EL     )                                     
     & /( E2(IN)-E3(IN) )/( E2(IN)-E4(IN) )                                     
     & +( E2(IN)-EL     )*( E3(IN)-EL     )*( EL    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E2(IN) )/( E3(IN)-E1(IN) )                   
     & +( EL    -E4(IN) )*( EL    -E1(IN) )*( EL    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E1(IN) )/( E4(IN)-E1(IN) )                   
     &           )                                                              
      END IF                                                                    
   40 CONTINUE                                                                  
      DO 50 IN=1,NIS                                                            
      IF( E2(IN).GE.EH .AND. EL.GT.E3(IN) ) THEN                                
      S=S+THIRD*(                                                               
     &  ( E2(IN)-EL     )*( E2(IN)-EL     )                                     
     & /( E2(IN)-E3(IN) )/( E2(IN)-E4(IN) )                                     
     & +( E2(IN)-EL     )*( E3(IN)-EL     )*( EL    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E2(IN) )/( E3(IN)-E1(IN) )                   
     & +( EL    -E4(IN) )*( EL    -E1(IN) )*( EL    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E1(IN) )/( E4(IN)-E1(IN) )                   
     & -( E2(IN)-EH     )*( E2(IN)-EH     )                                     
     & /( E2(IN)-E3(IN) )/( E2(IN)-E4(IN) )                                     
     & -( E2(IN)-EH     )*( E3(IN)-EH     )*( EH    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E2(IN) )/( E3(IN)-E1(IN) )                   
     & -( EH    -E4(IN) )*( EH    -E1(IN) )*( EH    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E1(IN) )/( E4(IN)-E1(IN) )                   
     &            )                                                             
      END IF                                                                    
   50 CONTINUE                                                                  
      DO 60 IN=1,NIS                                                            
      IF ( E2(IN).GE.EH .AND. EH.GT.E3(IN) .AND. E3(IN).GE.EL                   
     &                  .AND. EL.GT.E4(IN)  )  THEN                             
      S=S+THIRD*( 1.D0                                                          
     & -( E2(IN)-EH     )*( E2(IN)-EH     )                                     
     & /( E2(IN)-E3(IN) )/( E2(IN)-E4(IN) )                                     
     & -( E2(IN)-EH     )*( E3(IN)-EH     )*( EH    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E2(IN) )/( E3(IN)-E1(IN) )                   
     & -( EH    -E4(IN) )*( EH    -E1(IN) )*( EH    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E1(IN) )/( E4(IN)-E1(IN) )                   
     & -( E4(IN)-EL     )*( E4(IN)-EL     )*( E4(IN)-EL     )                   
     & /( E4(IN)-E1(IN) )/( E4(IN)-E2(IN) )/( E4(IN)-E3(IN) )                   
     &           )                                                              
      END IF                                                                    
   60 CONTINUE                                                                  
      DO 70 IN=1,NIS                                                            
      IF ( E1(IN).GE.EH .AND. EH.GT.E2(IN) .AND. E3(IN).GE.EL                   
     &                  .AND. EL.GT.E4(IN)  )  THEN                             
      S=S+THIRD*( 1.D0                                                          
     & -( E1(IN)-EH     )*( E1(IN)-EH     )*( E1(IN)-EH     )                   
     & /( E1(IN)-E2(IN) )/( E1(IN)-E3(IN) )/( E1(IN)-E4(IN) )                   
     & -( E4(IN)-EL     )*( E4(IN)-EL     )*( E4(IN)-EL     )                   
     & /( E4(IN)-E1(IN) )/( E4(IN)-E2(IN) )/( E4(IN)-E3(IN) )                   
     &           )                                                              
      END IF                                                                    
   70 CONTINUE                                                                  
      DO 80 IN=1,NIS                                                            
      IF ( E3(IN).GE.EL .AND. EL.GT.E4(IN) .AND. EH.GT.E1(IN) ) THEN            
      S=S+THIRD*( 1.D0                                                          
     & -( E4(IN)-EL     )*( E4(IN)-EL     )*( E4(IN)-EL     )                   
     & /( E4(IN)-E1(IN) )/( E4(IN)-E2(IN) )/( E4(IN)-E3(IN) )                   
     &           )                                                              
      END IF                                                                    
   80 CONTINUE                                                                  
      DO 90 IN=1,NIS                                                            
      IF ( E2(IN).GE.EH .AND. EH.GT.E3(IN) .AND. E4(IN).GE.EL ) THEN            
      S=S+THIRD*( 1.D0                                                          
     & -( E2(IN)-EH     )*( E2(IN)-EH     )                                     
     & /( E2(IN)-E3(IN) )/( E2(IN)-E4(IN) )                                     
     & -( E2(IN)-EH     )*( E3(IN)-EH     )*( EH    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E2(IN) )/( E4(IN)-E1(IN) )                   
     & -( EH    -E4(IN) )*( EH    -E1(IN) )*( EH    -E1(IN) )                   
     & /( E2(IN)-E4(IN) )/( E3(IN)-E1(IN) )/( E4(IN)-E1(IN) )                   
     &           )                                                              
      END IF                                                                    
   90 CONTINUE                                                                  
      DO 100 IN=1,NIS                                                           
      IF ( E3(IN).GE.EH .AND. EL.GT.E4(IN) ) THEN                               
      S=S+THIRD*(                                                               
     &  ( E4(IN)-EH     )*( E4(IN)-EH     )*( E4(IN)-EH     )                   
     & /( E4(IN)-E1(IN) )/( E4(IN)-E2(IN) )/( E4(IN)-E3(IN) )                   
     & -( E4(IN)-EL     )*( E4(IN)-EL     )*( E4(IN)-EL     )                   
     & /( E4(IN)-E1(IN) )/( E4(IN)-E2(IN) )/( E4(IN)-E3(IN) )                   
     &           )                                                              
      END IF                                                                    
  100 CONTINUE                                                                  
      DO 110 IN=1,NIS                                                           
      IF ( E3(IN).GE.EH .AND. EH.GT.E4(IN) .AND. E4(IN).GE.EL                   
     &                  .AND. LB(IN,2) ) THEN                                   
      S=S+THIRD*(                                                               
     &  ( E4(IN)-EH     )*( E4(IN)-EH     )*( E4(IN)-EH     )                   
     & /( E4(IN)-E1(IN) )/( E4(IN)-E2(IN) )/( E4(IN)-E3(IN) )                   
     &           )                                                              
      END IF                                                                    
  110 CONTINUE                                                                  
      DO 120 IN=1,NIS                                                           
      IF( EH.GT.E1(IN) .AND. E4(IN).GE.EL .AND. LB(IN,2) ) THEN                 
      S=S+THIRD                                                                 
      END IF                                                                    
  120 CONTINUE                                                                  
      DO 130 IN=1,NIS                                                           
      IF ( E1(IN).GE.EH .AND. EH.GT.E2(IN) .AND. E4(IN).GE.EL ) THEN            
      S=S+THIRD*( 1.D0                                                          
     & -( E1(IN)-EH     )*( E1(IN)-EH     )*( E1(IN)-EH     )                   
     & /( E1(IN)-E2(IN) )/( E1(IN)-E3(IN) )/( E1(IN)-E4(IN) )                   
     &           )                                                              
      END IF                                                                    
  130 CONTINUE                                                                  
C                                                                               
C *********  TEMP CHECK  ************                                           
C     WRITE(6,*)'  IN SUB. TETRA42  S = ',S/DFLOAT(8*5*5*5)                     
C     IF ( S.GT.1.D0) STOP ' IN TETRA42 S IS TOO BIG '                          
C     IF ( S.LT.0 ) STOP ' IN TETRA42 S IS NEGATIVE '                           
C *********  TEMP CHECK END *********                                           
      RETURN                                                                    
      END                                                                       
C ************************************************************                  
C *                                                          *                  
C *     DOS CALCULATION END 1989/07/04                       *                  
C *                                                          *                  
C ************************************************************                  
