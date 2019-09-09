SUBROUTINE WQSKE0

  !**********************************************************************C
  !
  !  Solve Kinetic Eq from K=KC (surface layer) to K=1 (bottom).
  !  Simplified version that only updates:
  !     IPARAM: 09 Dissolved Organic Phosphorus,
  !             14 Ammonia Nitrogen
  !             19 Dissolved Oxygen
  !    After computing new values, store WQVO+WQV into WQVO(L,K,NWQV) exce
  !    NWQV=15,19,21.
  !
  !  ORGINALLY CODED BY K.-Y. PARK
  !
  !  CHANGE RECORD
  !
  !**********************************************************************C

  USE GLOBAL

  INTEGER :: L,K,IZ,NS
  REAL    :: CNS1,TIMTMP,WQOBT0T,XMRM,WQKD0C,O2WQ_,WQTT1,WQKHN,RNH4NO3_,WQTTC,WQTTD,WQTTG,WQTTM
  REAL    :: TVAL1,TVAL2,TVAL3,TVAL4,RLNSAT1,RLNSAT2,WINDREA,WQWREA,UMRM,VMRM,YMRM,WQD6,WQR6,WQVREA
  
  CNS1=2.718
  NS=1
  DO L=2,LA
    WQI0BOT(L)=WQI0
  ENDDO
  !
  DO K=KC,1,-1
  !
    DO L=2,LA
      TWQ(L)=TEM(L,K)
      SWQ(L)=MAX(SAL(L,K), 0.0)
      DZWQ(L) = 1.0 / (HPK(L,K))
      VOLWQ(L) = DZWQ(L) / DXYP(L)
      IMWQZT(L)=IWQZMAP(L,K)
    ENDDO
  !
  ! FIND AN INDEX FOR LOOK-UP TABLE FOR TEMPERATURE DEPENDENCY
  !
    DO L=2,LA
  !          IWQT(L) = NINT( 4.*TWQ(L)+121.)
      IWQT(L)=NINT((TWQ(L)-WQTDMIN)/WQTDINC)  ! *** DS-INTL SINGLE L!INE
      IF( IWQT(L) < 1 .OR. IWQT(L) > NWQTD )THEN
        IF( ISDYNSTP == 0 )THEN
          TIMTMP=(DT*FLOAT(N)+TCON*TBEGIN)/86400.
        ELSE
          TIMTMP=TIMESEC/86400.
        ENDIF
        OPEN(2,FILE=OUTDIR//'ERROR.LOG',POSITION='APPEND' &
              ,STATUS='UNKNOWN')
        WRITE(2,*)' *** ERROR IN WATER QUALITY'
        WRITE(2,911) TIMTMP, L, IL(L), JL(L), K, TWQ(L)
        CLOSE(2)
        WRITE(6,600)IL(L),JL(L),K,TWQ(L)
        IWQT(L)=MAX(IWQT(L),1)
        IWQT(L)=MIN(IWQT(L),NWQTD)
  !           STOP 'ERROR!! INVALID WATER TEMPERATURE'
      ENDIF
    ENDDO
    600 FORMAT(' I,J,K,TEM = ',3I5,E13.4)
    911 FORMAT(/,'ERROR: TIME, L, I, J, K, TWQ(L) = ', F10.5, 4I4, F10.4)
  !
    DO L=2,LA
      IZ=IWQZMAP(L,K)
  !
  ! UPDATE SOLAR RADIATION AT BOTTOM OF THIS LAYER
  !
      !WQF2IM = WQF2IM * PSHADE(L)      PMC
  !
  ! ALGAL BASAL METABOLISM & PREDATION
  !
      WQBMC(L) = WQBMRC(IMWQZT(L)) * WQTDRC(IWQT(L))
      WQPRC(L) = WQPRRC(IMWQZT(L)) * WQTDRC(IWQT(L))
  !
  ! THE VARIABLE WQTDGP ADJUSTS PREDATION AND BASAL METABOLISM BASED ON A
  ! LOWER/UPPER OPTIMUM TEMPERATURE FUNCTION.  THIS WILL ALLOW DIATOMS TO
  ! BLOOM IN WINTER IF WQTDGP IS CLOSE TO ZERO.
  !
      WQOBT0T = WQVO(L,K,1)+WQVO(L,K,2)+WQVO(L,K,3)
      WQKRPC(L) = (WQKRC + WQKRCALG*WQOBT0T) * WQTDHDR(IWQT(L))
      WQKLPC(L) = (WQKLC + WQKLCALG*WQOBT0T) * WQTDHDR(IWQT(L))
      XMRM = 0.0
      IF( IDNOTRVA > 0 .AND. K == KSZ(L) )THEN
        XMRM = WQKDCALM(IZ) * WQVO(L,K,IDNOTRVA)
      ENDIF
  !
  ! M. MORTON 08/28/99: ADDED SPATIALLY VARIABLE DOC HYDROLYSIS RATE WQKDC
  !    TO ACHIEVE BETTER CONTROL IN SYSTEMS WITH A COMBINATION OF FRESHWAT
  !    STREAMS AND TIDAL RIVERS WITH DIFFERENT CHARACTERISTICS.
  !
      WQKD0C = (WQKDC(1) + WQKDCALG*WQOBT0T + XMRM)*WQTDMNL(IWQT(L))
      O2WQ_ = MAX(WQVO(L,K,19), 0.0)
      WQTT1 = WQKD0C / (WQKHORDO + O2WQ_+ 1.E-18)
      WQKHR(L) = WQTT1 * O2WQ_
      WQDENIT(L) = 0.0
  !
  ! 7-10 PHOSPHORUS
  ! 11-15 NITROGEN
  !
      WQKHN = (WQKHNC+WQKHND+WQKHNG) / 3.0
      RNH4WQ_ = MAX (WQVO(L,K,14), 0.0)
      RNO3WQ_ = MAX (WQVO(L,K,15), 0.0)
      RNH4NO3_ = RNH4WQ_ + RNO3WQ_
      WQTT1 = WQKHN / (WQKHN+RNH4NO3_+ 1.E-18) * WQOBT0T
      IF( RNH4NO3_ == 0.0 )THEN
        WQPNC(L)=0.0
        WQPND(L)=0.0
        WQPNG(L)=0.0
        WQPNM(L)=0.0
      ELSE
        WQTTC = RNH4WQ_/(WQKHNC+RNO3WQ_+ 1.E-18)
        WQTTD = RNH4WQ_/(WQKHND+RNO3WQ_+ 1.E-18)
        WQTTG = RNH4WQ_/(WQKHNG+RNO3WQ_+ 1.E-18)
        WQTTM = RNH4WQ_/(WQKHNM+RNO3WQ_+ 1.E-18)
        WQPNC(L) = (RNO3WQ_/(WQKHNC+RNH4WQ_+ 1.E-18) &
            + WQKHNC/(RNH4NO3_+ 1.E-18)) * WQTTC
        WQPND(L) = (RNO3WQ_/(WQKHND+RNH4WQ_+ 1.E-18) &
            + WQKHND/(RNH4NO3_+ 1.E-18)) * WQTTD
        WQPNG(L) = (RNO3WQ_/(WQKHNG+RNH4WQ_+ 1.E-18) &
            + WQKHNG/(RNH4NO3_+ 1.E-18)) * WQTTG
        WQPNM(L) = (RNO3WQ_/(WQKHNM+RNH4WQ_+ 1.E-18) &
            + WQKHNM/(RNH4NO3_+ 1.E-18)) * WQTTM
      ENDIF
      WQNIT(L) = WQTDNIT(IWQT(L)) * O2WQ(L) / (WQKHNDO + O2WQ(L) + 1.E-18) * RNH4WQ(L) / (WQKHNN + RNH4WQ(L) + 1.E-18)

  ! TT THE FOLLOWING MODIFICATION TO THE D.O. SATURATION CALCULATION MADE
  ! TT BY J.M. HAMRICK / M.R. MORTON ON 03/08/97.  SEE CHAPRA (1997) PG. 3
  !
      TVAL1=1./(TWQ(L)+273.15)
      TVAL2=TVAL1*TVAL1
      TVAL3=TVAL1*TVAL2
      TVAL4=TVAL2*TVAL2
      RLNSAT1=-139.3441+(1.575701E+5*TVAL1)-(6.642308E+7*TVAL2) &
          +(1.2438E+10*TVAL3)-(8.621949E+11*TVAL4)
      RLNSAT2=RLNSAT1-SWQ(L)*( 1.7674E-2-(1.0754E+1*TVAL1) &
          +(2.1407E+3*TVAL2) )
      WQDOS(L) = EXP(RLNSAT2)
      XDOSAT(L,K) = XDOSAT(L,K) + WQDOS(L)*DTWQ*HPK(L,K)
      IF( K == KC )THEN
  !
  ! DO NOT ALLOW WIND SPEEDS ABOVE 11 M/SEC IN THE FOLLOWING EQUATION:
  !
        WINDREA = WINDST(L)
        WQWREA=0.728*SQRT(WINDREA)+(0.0372*WINDREA-0.317)*WINDREA
  !
  !        WQWREA = 0.728*SQRT(WINDST(L))
  !
        IF( IWQKA(IZ)  ==  0 )THEN
          WQVREA = WQKRO(IZ)
          WQWREA = 0.0
        ENDIF
  !
  !                 WIND VELOCITY COMPUTED ABOVE:
  !
        IF( IWQKA(IZ)  ==  1 )THEN
          WQVREA = WQKRO(IZ)
        ENDIF
  !
  !    WQKRO = 3.933 TYPICALLY
  !
        IF( IWQKA(IZ)  ==  2 )THEN
          UMRM = 0.5*(U(L,K)+U(LEC(L),K))
          VMRM = 0.5*(V(L,K)+V(LNC(L),K))
          XMRM = SQRT(UMRM*UMRM + VMRM*VMRM)
          WQVREA = WQKRO(IZ) * XMRM**0.5 / HP(L)**0.5
        ENDIF
  !
  !    WQKRO = 5.32 TYPICALLY
  !
        IF( IWQKA(IZ)  ==  3 )THEN
          UMRM = MAX(U(L,K), U(LEC(L),K))
          VMRM = MAX(V(L,K), V(LNC(L),K))
          XMRM = SQRT(UMRM*UMRM + VMRM*VMRM)
          WQVREA = WQKRO(IZ) * XMRM**0.67 / HP(L)**1.85
        ENDIF
  !
  ! MODIFIED OWENS AND GIBBS REAERATION EQUATION:
  ! NOTE: NORMALIZED TO A DEPTH OF 1.0 FT, I.E., THIS EQUATION GIVES THE
  !       SAME REAERATION AS OWENS & GIBBS AT 1.0 FT DEPTH; AT HIGHER
  !       DEPTHS IT GIVES LARGER REAERATION THAN OWENS & GIBBS.
  ! WQKRO = 5.32 TYPICALLY
  !
        IF( IWQKA(IZ)  ==  4 )THEN
          UMRM = MAX(U(L,K), U(LEC(L),K))
          VMRM = MAX(V(L,K), V(LNC(L),K))
          XMRM = SQRT(UMRM*UMRM + VMRM*VMRM)
          YMRM = HP(L)*3.0*(1.0 - HP(L)/(HP(L)+0.1524))
          WQVREA = WQKRO(IZ) * XMRM**0.67 / YMRM**1.85
        ENDIF
        IF( IWQKA(IZ)  ==  5 )THEN
          UMRM = MAX(U(L,K), U(LEC(L),K))
          VMRM = MAX(V(L,K), V(LNC(L),K))
          XMRM = SQRT(UMRM*UMRM + VMRM*VMRM)
          WQVREA = 3.7*XMRM
        ENDIF
  !
  ! NOW COMBINE REAERATION DUE TO WATER VELOCITY AND WIND STRESS:
  !
        WQVREA = WQVREA * REAC(IZ)
        WQWREA = WQWREA * REAC(IZ)
        WQP19(L) = - (WQVREA + WQWREA) * DZWQ(L)* WQTDKR(IWQT(L),IZ)
        WQKRDOS(L) = - WQP19(L)*WQDOS(L)
      ELSE
        WQP19(L) = 0.0
      ENDIF
    666 FORMAT(' K,IWQ,IZ,WQTDKR = ',3I5,E12.4)
  ENDDO
  !
  ! TRAPEZOIDAL SOLUTION OF KINETIC EQS: AFTER COMPUTING NEW VALUES, STORE
  ! WQVO+WQV INTO WQVO(L,K,NWQV)
  !
    DO L=2,LA
      IZ=IWQZMAP(L,K)
      WQD6 = - WQKHR(L)
      WQKK(L) = 1.0 / (1.0 - DTWQO2*WQD6)
      WQR6 = (WQWDSL(L,K,6) + WQWPSL(L,K,6)) * VOLWQ(L)
      WQRR(L) = WQVO(L,K,6) + DTWQ*WQR6 +  DTWQO2*WQD6*WQVO(L,K,6)
      WQV(L,K,6)=SCB(L)*( WQRR(L)*WQKK(L) )+(1.-SCB(L))*WQVO(L,K,6)
      WQVO(L,K,6) = WQVO(L,K,6)+WQV(L,K,6)
    ENDDO
    DO L=2,LA
      WQRR(L) = (WQWDSL(L,K,14)+WQWPSL(L,K,14)) * VOLWQ(L)
    ENDDO
    DO L=2,LA
      WQKK(L) = 1.0 / (1.0 + DTWQO2*WQNIT(L))
      WQRR(L) = WQVO(L,K,14) + DTWQ*WQRR(L) &
          - DTWQO2*( WQNIT(L)*WQVO(L,K,14) )
      WQV(L,K,14)=SCB(L)*(WQRR(L)*WQKK(L))+(1.-SCB(L))*WQVO(L,K,14)
      WQVO(L,K,14) = WQVO(L,K,14)+WQV(L,K,14)
    ENDDO
    DO L=2,LA
      WQKK(L) = 1.0 / (1.0 - DTWQO2*WQP19(L))
      WQRR(L) = (WQWDSL(L,K,19)+WQWPSL(L,K,19)) * VOLWQ(L)
    ENDDO
    IF( K == KC )THEN
      DO L=2,LA
        WQRR(L) = WQRR(L) + WQKRDOS(L)
      ENDDO
    ENDIF
    IF( K == 1 )THEN
      DO L=2,LA
        WQRR(L) = WQRR(L) + WQBFO2(L)*DZWQ(L)
      ENDDO
    ENDIF
    DO L=2,LA
  !
  ! MODIFIED BY MRM 05/23/99 TO ALLOW DIFFERENT AOCR CONSTANTS TO BE APPLI
  !   TO PHOTOSYNTHESIS AND RESPIRATION TERMS FOR MACROALGAE:
  !
      WQRR(L) = WQVO(L,K,19) + DTWQ*WQRR(L) + DTWQO2*( &
          -WQAOCR*WQKHR(L)*WQVO(L,K,6)-WQAONT*WQNIT(L)*WQVO(L,K,14) &
          + WQP19(L)*WQVO(L,K,19) )
  !
  !          RZERO=0.
  !
      WQV(L,K,19)=SCB(L)*(WQRR(L)*WQKK(L))+(1.-SCB(L))*WQVO(L,K,19)
      WQV(L,K,19) = MAX (WQV(L,K,19), 0.0)
      WQVO(L,K,19) = WQVO(L,K,19)+WQV(L,K,19)
    ENDDO
  !
  ! WQTD1FCB=1+DTWQO2*WQS21,WQTD2FCB=1/(1-DTWQO2*S21)
  !
  ENDDO
  !
  ! INCREMENT COUNTER FOR LIMITATION AND XDOXXX DO COMPONENT ARRAYS:
  !
  IF( ISDYNSTP == 0 )THEN
    TIMTMP=DT*FLOAT(N)+TCON*TBEGIN
    TIMTMP=TIMTMP/TCTMSR
  ELSE
    TIMTMP=TIMESEC/TCTMSR
  ENDIF
  TIMESUM3 = TIMESUM3 + TIMTMP
  
  ! COMPUTE WQCHL,WQTAMP,WQPO4D,WQSAD AT A NEW TIME STEP: WQCHLX=1/WQCHLX
  ! COUPLING TO SEDIMENT MODEL
  !: EVALUATE DEP. FLUX USING NEW VALUES CAUSE IMPLICIT SCHEME IS USED IN SPM

  ! DIURNAL DO ANALYSIS
  ! LIGHT EXTINCTION ANALYSIS

   1111 FORMAT(I12,F10.4)
   1112 FORMAT(2I5,12F7.2)
   1113 FORMAT(2I5,12E12.4)
   1414 FORMAT(I12,11E12.4)
  RETURN
END