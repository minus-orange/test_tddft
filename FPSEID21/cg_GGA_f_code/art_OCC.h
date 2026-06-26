c  *** NV-1 state with cb 3x3x cell (216 atom cell)
c           DO 122 I=1,430
c            OCC(I,K)=1.d0
c  122      CONTINUE
c           OCC(431,K)=0.5d0
c           OCC(432,K)=0.5d0
c  *** Cu step Gamma (63 atom cell)
c           DO 122 I=1,345
c            OCC(I,K)=1.d0
c  122      CONTINUE
c           do ib=346,348
c           OCC(ib,K)=0.5d0
c	   enddo
c  *** Cu step 2k (63 atom cell)
	   if ( K.eq.1 ) then
           DO I=1,346
            OCC(I,K)=1.d0
	   ENDDO
            OCC(347,K)=0.5d0
            OCC(348,K)=0.5d0
	   else
	   DO I=1,345
            OCC(I,K)=1.d0
	   ENDDO
            OCC(346,K)=0.5d0
            OCC(347,K)=0.5d0
	   endif
