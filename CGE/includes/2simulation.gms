*r=model s=simulation gdx=simulation solvelink=1
DISPLAY alphainv;

$OFFSYMLIST OFFSYMXREF
$ONEMPTY
OPTIONS ITERLIM=10000, LIMROW=3, LIMCOL=3, SOLPRINT=OFF, MCP=PATH, NLP=MINOS, SOLVELINK=1;

SETS
*Simulations
 X                       simulations
 XC(X)                   active simulations
 XNB(X)                  nonbase simulations
*Time periods
 T                       time periods
 TC(T)                   active time periods
 TCN1(T)                 TC except base year
 T1(T)                   base year of simulation
 T2(T)                   second year of simulation
 TN(T)                   final year
*Model management sets
 XBASINIT(X,T)           simulations with variables initialized at base and yr level
 MISCAC                  miscellaneous simulation data elements
  / QG, GTRH, HREM, FSAV, GSAV, PWE, PWM, MPS, DTAX /
*Sector-specific closures
 FL(A)                   sector-specific (fixed) land demand
 AFX(A,RD)               sectors with calibrated capital stock growth
 ANFX(A,RD)              sectors without calibrated capital stock growth
;

ALIAS (T,TP), (TC,TCP);

PARAMETERS
 XNUM                    number of simulations
 TNUM                    number of active years (used for reporting)
*Macroeconomic and factor market closures
 CLOSURES(AC,X)          closure selection from Excel
 NUMERAIRE(X)            numeraire
 SICLOS(X)               value for savings-investment closure
 ROWCLOS(X)              value for rest-of-world closure
 GOVCLOS(X)              value for government closure
 MPS01SIM(X,INS)         0-1 par for potential flexing of savings rates
 TINS01SIM(X,INS)        0-1 par for potential flexing of direct tax rates
 FMOBFE(X,F)             factor is fully employed and mobile
 FACTFE(X,F)             factor is fully employed and activity-specific
 FMOBUE(X,F)             factor is unemployed and mobile
*Capital composition and price of capital good
 BMAT(C,FCAP)            capital composition matrix by type of capital
 PKAP(FCAP)              price of capital good by type
 GFCF                    nominal gross fixed capital formation
;

$call    "gdxxrw i=%basedata% o=basedata index=index!a6 checkdate"
$gdxin   basedata.gdx

$load    X T
$loaddc  XC TC FL AFX CLOSURES

 T1(TC)$(ORD(TC) EQ SMIN(TCP, ORD(TCP))) = YES;
 T2(TC)$(ORD(TC) EQ 2)                   = YES;
 TN(TC)$(ORD(TC) EQ SMAX(TCP, ORD(TCP))) = YES;
 TNUM = SUM(T$TN(T), ORD(T)) - SUM(T$T1(T), ORD(T));

 XC('INIT') = NO;
 XNUM = MAX(CARD(XC)-1,1) ;
 XNB(XC) = YES;
 XNB('BASE') = NO;

 XBASINIT(XC,TC) = NO;

 ANFX(A,RD)$(NOT AFX(A,RD)) = YES;


*------------------------------------------------------------------------------
*1. Excel inputted scenario calibration
*------------------------------------------------------------------------------

$include includes\2projection.inc

*----------------------------------------------------------------------
*2. Non-excel inputted scenario calibration
*----------------------------------------------------------------------



*----------------------------------------------------------------------
*3. Closures
*----------------------------------------------------------------------

*Macroeconomic closures
 NUMERAIRE(XC) = CLOSURES('DUM',XC);
 ROWCLOS(XC)   = CLOSURES('ROW',XC);
 GOVCLOS(XC)   = CLOSURES('GOV',XC);
 SICLOS(XC)    = CLOSURES('S-I',XC);

*Institutional savings and tax rate adjustments
 MPS01SIM(XC,INSDNG)  = 1;
 TINS01SIM(XC,INSDNG) = 1;

*Identify factors with upward-sloping supply curves
 FLS(F) = NO;
LOOP(XC,
 FLS(F)$(CLOSURES(F,XC) EQ 4) = YES;
);

*Factor markets closures
 FMOBFE(XC,F)$(CLOSURES(F,XC) EQ 1) = 1;
 FACTFE(XC,F)$(CLOSURES(F,XC) EQ 2) = 1;
 FMOBUE(XC,F)$(CLOSURES(F,XC) EQ 3) = 1;
 FMOBFE(XC,F)$(CLOSURES(F,XC) EQ 4) = 1;

*If no value is specified for a factor, impose FMOBFE:
 FMOBFE(XC,F)$(FMOBFE(XC,F) + FACTFE(XC,F) + FMOBUE(XC,F) EQ 0) = 1;

*----------------------------------------------------------------------
*4. Time period loop
*----------------------------------------------------------------------

$include includes\2initialize.inc

 TAPSX(X,T) = 0;

LOOP(XC,

$include includes\2varinit.inc

  LOOP(TC,
    IF(NOT T1(TC),

*     Long term TFP growth
      alphava(A,RD) = alphava(A,RD) * (1+TFPGR(A,RD,XC,TC));

*     Long term factor-specific productivity growth
      fprd(F,A,RD)$(NOT AFX(A,RD)) = fprd(F,A,RD) * (1+FPRDGR(F,XC,TC));

*     World price changes
*      pwebar(C,RW) = pwebar(C,RW) * (1+PWEGR(C,XC,TC));
      PWE.L(C,RW)  = PWE.L(C,RW)  * (1+PWEGR(C,XC,TC));
      PWM.L(C,RW)  = PWM.L(C,RW)  * (1+PWMGR(C,XC,TC));

*     Population growth
      hpop(H) = hpop(H) * (1+POPGR(H,XC,TC));

*     Exgenous transfer changes
      trnsfr(INS,ACNT) = trnsfr(INS,ACNT) * (1+TRNSFRGR(INS,ACNT,XC,TC));

*     Capital stock accumulation and allocation
$include includes\2capital.inc

*     Labor supply growth
      QF.L(FLAB,A,RD)$(NOT T1(TC)) = QF.L(FLAB,A,RD)*(1+FACGR(FLAB,XC,TC));
      QF.L('FEGY',A,RD)$(NOT T1(TC)) = QF.L('FEGY',A,RD)*(1+FACGR('FEGY',XC,TC));
      QF.L('FLND',A,RD)$(NOT T1(TC)) = QF.L('FLND',A,RD)*(1+FACGR('FLND',XC,TC));

*     Total factor supply
      QFS.L(F) = SUM((RD,A), QF.L(F,A,RD));

    );

$include includes\2closures.inc

 STANDCGE.SOLVELINK = 2;
 SOLVE standcge USING MCP ;

$include includes\2results.inc

  );
);
