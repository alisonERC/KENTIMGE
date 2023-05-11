$SETGLOBAL modeldata    "1model.xlsx"

$call "gdxxrw i=%modeldata% o=modeldatab.gdx index=index2!a5 checkdate"
$gdxin modeldatab.gdx

SETS
 AC                      global set for model accounts - aggregated microsam accounts
 ACNT(AC)                all elements in AC except TOTAL
 A(AC)                   activities
 H(AC)                   households
;

PARAMETER
 SAM(AC,AC)              standard SAM
 SAMBALCHK(AC)           column minus row total for SAM
;

$load AC A H
$loaddc SAM

ALIAS
 (AC,ACP), (ACNT,ACNTP), (A, AP), (H, HP);

 ACNT(AC)               = YES;
 ACNT('TOTAL')          = NO;

*-------------------------------------------------------------------------------
*1. SAM adjustments
*-------------------------------------------------------------------------------
 SAM('aelec','celec')=SAM('aelec','celec')-SAM('celec','aelec');
 SAM('celec','aelec')=0;

 SAM('TOTAL',AC) = SUM(ACNT, SAM(ACNT,AC));
 SAM(AC,'TOTAL') = SUM(ACNT, SAM(AC,ACNT));
 SAMBALCHK(AC)   = SAM('TOTAL',AC) - SAM(AC,'TOTAL');

*-------------------------------------------------------------------------------
*2. Potential for natural gas
*-------------------------------------------------------------------------------
* SAM('angas','cngas')=0.000001;
* SAM(ACNT,'angas')=0.000001*(SAM(ACNT,'amine')/sum(ACNTP,SAM(ACNTP,'amine')));

 SAM('row','cngas')    = 0.001;
* SAM('cngas','aelec') = SAM('angas','cngas')+SAM('row','cngas');
 SAM('cngas','aelec')  = SAM('row','cngas');
 SAM('aelec','celec')  = SAM('aelec','celec')+SAM('cngas','aelec');
 SAM('celec','dstk')   = SAM('cngas','aelec');
 SAM('dstk','s-i')     = SAM('dstk','s-i')-SAM('cngas','aelec');
 SAM('s-i','row')      = SAM('s-i','row')-SAM('cngas','aelec');

$include includes/1sambal.inc

 SAM('TOTAL',AC) = SUM(ACNT, SAM(ACNT,AC));
 SAM(AC,'TOTAL') = SUM(ACNT, SAM(AC,ACNT));
 SAMBALCHK(AC)   = SAM('TOTAL',AC) - SAM(AC,'TOTAL');

*-------------------------------------------------------------------------------
*3. Adjusting SAM to account for energy volumes
*-------------------------------------------------------------------------------
Sets
 ea
 meaac(ea,ac)
;

Parameter
 xprice(ac)      power price
 ebal(ea)        power use
 edie(*)         diesel used by power sector
 eval(ea)        expected energy value (energy aggregate)
 eval2(ac)       expected energy value (SAM accounts)
 eval3(*)        expected energy value (SAM accounts) - trade
 eutax(ac)       difference in energy values
;

$load EA MEAAC
$loaddc XPRICE EBAL EDIE

 eval(ea)=ebal(ea)*xprice('celec');
 eval2(a)$SAM('celec',a)=sum(ea$meaac(ea,a),eval(ea))*(SAM('celec',a)/sum(ea$meaac(ea,a),sum(ap$meaac(ea,ap),SAM('celec',ap))));
 eval2(h)$SAM('celec',h)=sum(ea$meaac(ea,h),eval(ea))*(SAM('celec',h)/sum(ea$meaac(ea,h),sum(hp$meaac(ea,hp),SAM('celec',hp))));

 eutax(ac)$eval2(ac)=SAM('celec',ac)-eval2(ac);

 SAM('celec',a)=eval2(a);
 SAM('celec',h)=eval2(h);

 SAM('utax',ac)=eutax(ac);

 SAM('ent','utax')=sum(ACNT,SAM('utax',ACNT));

 SAM('TOTAL',AC) = SUM(ACNT, SAM(ACNT,AC));
 SAM(AC,'TOTAL') = SUM(ACNT, SAM(AC,ACNT));
 SAMBALCHK(AC)   = SAM('TOTAL',AC) - SAM(AC,'TOTAL');
display SAMBALCHK;

*-------------------------------------------------------------------------------
*4. Capital account for electricity
*-------------------------------------------------------------------------------
*$ontext
 SAM('fegy','aelec')=SAM('fcap','aelec');
 SAM('ent','fegy')=SAM('fegy','aelec');

 SAM('fcap','aelec')=SAM('fcap','aelec')-SAM('fegy','aelec');
 SAM('ent','fcap')=SAM('ent','fcap')-SAM('ent','fegy');
*$offtext

 SAM('TOTAL',AC) = SUM(ACNT, SAM(ACNT,AC));
 SAM(AC,'TOTAL') = SUM(ACNT, SAM(AC,ACNT));
 SAMBALCHK(AC)   = SAM('TOTAL',AC) - SAM(AC,'TOTAL');

*-------------------------------------------------------------------------------
*5. Separating out diesel used for power
*-------------------------------------------------------------------------------
 SAM('cpetr_d','aelec')=XPRICE('cpetr_d')*edie('elec');
 SAM('row','cpetr_d')=SAM('cpetr_d','aelec');

 SAM('cchem','aelec')=SAM('cchem','aelec')-SAM('cpetr_d','aelec');
 SAM('row','cchem')=SAM('row','cchem')-SAM('row','cpetr_d');

 SAM('TOTAL',AC) = SUM(ACNT, SAM(ACNT,AC));
 SAM(AC,'TOTAL') = SUM(ACNT, SAM(AC,ACNT));
 SAMBALCHK(AC)   = SAM('TOTAL',AC) - SAM(AC,'TOTAL');

 execute_unload "boom.gdx" SAM;
 execute 'gdxxrw.exe i=boom.gdx o=%modeldata% index=index2!a80';
