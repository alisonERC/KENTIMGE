*r=model s=simulation gdx=simulation solvelink=1
DISPLAY alphainv;

$OFFSYMLIST OFFSYMXREF
$ONEMPTY
OPTIONS ITERLIM=10000, LIMROW=3, LIMCOL=3, SOLPRINT=OFF, MCP=PATH, NLP=MINOS, SOLVELINK=1;
STANDCGE.SOLVELINK = 2;

SCALAR
   fail    track if a solve fails /0/
;

SETS
*Simulations
* X                       simulations
* XC(X)                   active simulations
* XNB(X)                  nonbase simulations
*Time periods
* T                       time periods
* TC(T)                   active time periods
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
 EFX(T,T)                CGE years (TP) when elec capital is fixed during TIMES years (T)
 CEGY(C)                 energy commodities   / cngas, cpetr_d,  celec /
*cngas to be added when part of SAM

  energy(c)       energy commodities     / cngas, cpetr_d,  celec /



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

 ICAX(C,A,RD,X,T,TT)     tracking input output coefficients

;

$call    "gdxxrw i=cge\%basedata% o=basedata index=index!a6 checkdate"
$gdxin   basedata.gdx

*$load    X T
$loaddc  FL AFX CLOSURES

 T1(TC)$(ORD(TC) EQ SMIN(TCP, ORD(TCP))) = YES;
 T2(TC)$(ORD(TC) EQ 2)                   = YES;
 TN(TC)$(ORD(TC) EQ SMAX(TCP, ORD(TCP))) = YES;
 TNUM = SUM(T$TN(T), ORD(T)) - SUM(T$T1(T), ORD(T));

* XC('INIT') = NO;
 XNUM = MAX(CARD(XC)-1,1) ;
 XNB(XC) = YES;
 XNB('BASE') = NO;

 XBASINIT(XC,TC) = NO;

 EFX(TC,TCP)$(TT(TC) AND (ORD(TCP) > 0 and ORD(TCP) LE ORD(TC))) = YES;

 ANFX(A,RD)$(NOT AFX(A,RD)) = YES;


*------------------------------------------------------------------------------
*1. Excel inputted scenario calibration
*------------------------------------------------------------------------------

$include cge\includes\2projection.inc




*----------------------------------------------------------------------
*2. Non-excel inputted scenario calibration
*----------------------------------------------------------------------
Parameter
 Yldshock(A,X,T)
 Worldprice(C,RW,X,T)
;

Set
 TSHOCK(T)       /2030*2050/
;

 Yldshock(A,X,T)=1;
* Yldshock('AMAIZ','YLDSHOCK',TSHOCK)=0.8;
* Yldshock('AMAIZ','COMBO',TSHOCK)=0.8;

 Worldprice(C,RW,X,T)=1;
* Worldprice('cmaiz',RW,'worldprice',TSHOCK)=1+(0.2/(2050-2030));
* Worldprice('cmaiz',RW,'COMBO',TSHOCK)=1+(0.2/(2050-2030));
* Worldprice('cgmll',RW,'worldprice',TSHOCK)=1+(0.2/(2050-2030));
* Worldprice('cgmll',RW,'COMBO',TSHOCK)=1+(0.2/(2050-2030));

Parameter
 COVID(F,X,T)      scalar to reduce labour available (mimic lockdown)
 COVIDCAP(A,F,X,T) scalar to reduce capital productivity (mimic lockdown)
;

SETS
 AGR(A)  /amaiz,arice,aocer,apuls,aoils,aroot,avege,asugr,atoba,acott,afrui,acoff,aocrp,acatt,apoul,aoliv,afore,afish/
 MIN(A)  /amine,angas /
 MAN(A)  /afood,abeve,atext,awood,achem,anmet,ametl,amach,aoman/
 UTIL(A) /aelec,awatr/
 CONS(A) /acons/
 TRD(A)  /atrad,ahotl/
 TRN(A)  /atran,acomm/
 FSRV(A) /afsrv,areal,absrv/
 OTH(A)  /apadm,aeduc,aheal,aosrv/
;

 COVID(F,X,T)=1;
 COVID('flab-n',X,'2020')=0.98;
 COVID('flab-p',X,'2020')=0.98;
 COVID('flab-s',X,'2020')=0.98;

$ontext
 COVID('flab-n',X,'2021')=0.99;
 COVID('flab-p',X,'2021')=0.99;
 COVID('flab-s',X,'2021')=0.99;

 COVID('flab-n',X,'2022')=1;
 COVID('flab-p',X,'2022')=1;
 COVID('flab-s',X,'2022')=1;
$offtext

 COVIDCAP(A,F,X,T)=1;
 COVIDCAP(AGR ,'FCAP',X,'2020')=1.05;
 COVIDCAP(MIN ,'FCAP',X,'2020')=1;
 COVIDCAP(MAN ,'FCAP',X,'2020')=0.95;
 COVIDCAP(UTIL,'FCAP',X,'2020')=1;
 COVIDCAP(CONS,'FCAP',X,'2020')=1.05;
 COVIDCAP(TRD ,'FCAP',X,'2020')=0.88;
 COVIDCAP(TRN ,'FCAP',X,'2020')=0.9;
 COVIDCAP(FSRV,'FCAP',X,'2020')=1;
 COVIDCAP(OTH ,'FCAP',X,'2020')=0.9;

$ontext
 COVIDCAP(AGR ,'FCAP',X,'2020')=1.3;
 COVIDCAP(MIN ,'FCAP',X,'2020')=1;
 COVIDCAP(MAN ,'FCAP',X,'2020')=0.95;
 COVIDCAP(UTIL,'FCAP',X,'2020')=1;
 COVIDCAP(CONS,'FCAP',X,'2020')=2;
 COVIDCAP(TRD ,'FCAP',X,'2020')=0.75;
 COVIDCAP(TRN ,'FCAP',X,'2020')=0.9;
 COVIDCAP(FSRV,'FCAP',X,'2020')=0.95;
 COVIDCAP(OTH ,'FCAP',X,'2020')=1;

 COVIDCAP(AGR ,'FCAP',X,'2021')=0.9;
 COVIDCAP(MIN ,'FCAP',X,'2021')=1.2;
 COVIDCAP(MAN ,'FCAP',X,'2021')=1;
 COVIDCAP(UTIL,'FCAP',X,'2021')=1;
 COVIDCAP(CONS,'FCAP',X,'2021')=1;
 COVIDCAP(TRD ,'FCAP',X,'2021')=1;
 COVIDCAP(TRN ,'FCAP',X,'2021')=1;
 COVIDCAP(FSRV,'FCAP',X,'2021')=1;
 COVIDCAP(OTH ,'FCAP',X,'2021')=1;

 COVIDCAP(AGR ,'FCAP',X,'2022')=1;
 COVIDCAP(MIN ,'FCAP',X,'2022')=1;
$offtext
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


$include cge\includes\2initialize.inc


*Initialise links to TIMES model
$include cge\includes\2energyinit.inc
