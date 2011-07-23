%*----------------------------------------------------------------
Program Name:           dataDictionary.sas

Project:                General

purpose:                create a PDF Table of contents linked to
                        basic frequencies for Discrete Vars
                        and distributions and boxplots for
                        Continuous vars

inputs:                 &DSLIB  = library
                        &DSNAME = dataset name

author:                 Bruce Thomas

usage:                  use complete lists of variables. '-' signs are a problem

revisions:

7/23/2010- BT Dropped InsetGroup from plot , lengthen VARLABEL
7.29.2010 BT Added error trapping to missing routine for all missing values
of key, now reading freq output to add frequencies for 5 highest and 5 lowest.
Also added where >0 to boxplot for better imaging.
7.30.2010 BT Added better styling to contents URL
9.14.2010 BT updated missrange to handle all missings. Link now works.
Also corrected rtag link problem where efy0x vars were not linking by removing 0.
10/21/2010 BT added category for sgplot of continuous vars
11/17/2020 BT corrected footnote and pdf text to pick up full strings.
5/6/2011 BT Now a set of macros. added BY if category is used.
5/20/2011 BT added automatic cutoff to differentiate discrete variables
5/21/2011 BT Optimistically added handler to stringify long discrete vars
to prevent mixup with MEANVARs.
6/2/2011 BT added null quotes for strLongDiscreteVars
7/22/2011 BT added nobookmarkgen
------------------------------------------------------------------;
%macro dataDictionary(
         dslib = WORK            /** Optional Libname                               **/
        ,dsname=                 /** Dataset to document                             **/
        ,title = Data Dictionary /** Title for Page 1 i                              **/
        ,phi   =                 /** Protected information do not show               **/
        ,category=               /** optional by group for continuous vars           **/
        ,cutoff=10               /** split between freq and missrange if nlevels>this**/
        ,LONGDISCRETEVARS=       /** zip code etc                                    **/
        );

%*-------------------------------
Stringify the long Discrete
Variables. These will be removed
from the Continuous
data in a statement
---------------------------------;
%LET strLongDiscreteVars="Dummy";

%IF &longdiscretevars NE %THEN %DO;
    %let longdiscretevars=%upcase(&longdiscretevars);
    %LET tst=1;
    %LET string='Dummy';
    %LET VARS=;
    %DO %UNTIL (&string EQ);
        %LET string=%SCAN(&LongDiscreteVars,&tst);
        %IF &string NE %THEN %LET strLongDiscreteVars=&strLongDiscreteVars "&string";
        %LET tst=%EVAL(&tst+1);
    %END;
    %PUT STRINGIFIED: &strLongDiscreteVars;

%END;

%*---------------------------------------
Remove PHI and other unwanted variables.

Determine the number of discrete levels
for each remaining variable.  Use this number to
compare with the CUTOFF Parameter.

The variables with  > CUTOFF values will
be treated as continuous variables, unless
specified as LONG DISCRETE variables in
the LONGDIOSCRETE parameter.
----------------------------------------;
data in_ ;
    set &dslib..&dsname(drop= &phi);
run;

ods output nlevels=nlevelsds;
proc freq data=IN_ nlevels;
tables _all_/noprint;
run;

ods listing; *turn on printing;
%LET Freqvars=;
%LET Meansvars=;

*2. Create contents data set;
proc sql noprint;
    create table meta_ as
    select  trim(lowcase(name)) as name,type,label,format,varnum,nlevels
    from dictionary.columns,nlevelsds
    where libname='WORK' and memname='IN_' and name=tablevar
    order by name;

*3A. Store names of all variables with NLEVELS <= cutoff
in macro variable FREQvars;
    select name into :FREQvars separated by ' '
    from meta_
    where nlevels <= &cutoff;

*3B. Store names of numeric variables with NLEVELS > cutoff
    in macro variable MEANSvars;
    select coalesce(" ",name) into :MEANSvars separated by ' '
    from meta_
    where nlevels > &cutoff and type="num" AND
    upcase(name) not in (&strlongdiscretevars);

*3C. Conditionally store names of character variables with NLEVELS > cutoff
in macro variable PRINTvars;

%let PRINTvars=; *initialize macro variable;
    select name into :PRINTvars separated by ' '
    from meta_
    where nlevels > &cutoff and type="char";

quit;

%LET PRINTVARS=&PRINTVARS &LONGDISCRETEvARS;

******************************************************;
*** Distributions for discrete vars              ***;
******************************************************;
data missrange_;
    set in_(keep=&printvars);
    length typevar $20;
    retain typevar 'Discrete';
run;

******************************************************;
*** Distributions for discrete vars              ***;
*** Nlevels less than cutoff                     ***;
******************************************************;
data frqs_;
    set in_(keep=&freqvars);
    length typevar $20;
    retain typevar 'Range';
run;

******************************************************;
*** Distributions for continuous vars              ***;
******************************************************;
%IF &meansvars NE %THEN %DO;
    data CONTS_ ;
        set in_(keep=&meansvars &category);
        length typevar $20;
        retain typevar 'Continuous';
    run;
%END;
%ELSE %DO;
    data CONTS_ ;
        length typevar $20;
        retain typevar 'Continuous';
        result= "No Continuous variables";
    RUN;
%END;


******************************************************;
** Proc contents: Build links to frequency tables  ***;
** Based on general data type                      ***;
******************************************************;
proc sql;
    create table meta1_ as
    select distinct a.*,
    case (b.memname)
    when ('FRQS_') then 'Discrete'
    when ('CONTS_') then 'Continuous'
    when ('MISSRANGE_') then 'Range'
    else ''
    end as typevar,monotonic() as varnumbr
    from
    (
        (select  * from meta_
        )a
    inner join
        (select lowcase(name) as name,memname from dictionary.columns where libname eq 'WORK' and memname in('FRQS_','CONTS_','MISSRANGE_')
        )b
    on a.name=b.name)
    order by varnumbr;
quit;

%*----------------------------------------------------------------
Create formats to apply to each general data type that exists in
these data. These formats will create PDF destinations named
#IDX<<nn>>,  these will be the targets of the table of contents
-----------------------------------------------------------------;
%***URL Format #IDX+var number is the label of the pdf destination ;
%** HLO=multiples for the same name**;

%IF &meansvars ne %then %dO;
    PROC SQL NOPRINT;
        create table contfmt as
        select  name, varnumbr, trimn(lowcase(name)) as start,
        '$CFMT' as fmtname, 'C' as type,'M' as HLO,
        cats("#idx",trim(left(put(varnumbr,best.)))) as label from meta1_
        where
        typevar eq 'Continuous' AND
        name in(select distinct lowcase(name) from sashelp.vcolumn where libname eq 'WORK' and memname eq 'CONTS_')
        order by varnumbr;
    QUIT;

    PROC FORMAT CNTLIN=contfmt;
    RUN;

%END;
%IF &printvars ne %then %dO;
    PROC SQL NOPRINT;
        create table rngfmt as
        select  name, varnumbr, trimn(lowcase(name)) as start,
        '$RNGFMT' as fmtname, 'C' as type,'M' as HLO,
        cats("#idx",compress(put(varnumbr,best.))) as label from meta1_
        where
        typevar eq 'Range' AND
        name in(select distinct lowcase(name) from sashelp.vcolumn where libname eq 'WORK' and memname eq 'MISSRANGE_')
        order by varnumbr;
    QUIT;
    PROC FORMAT CNTLIN=rngfmt ;
    RUN;
%END;
%IF &freqvars ne %then %dO;
    PROC SQL NOPRINT;
        create table Frqfmt as
        select  name, varnumbr, trimn(lowcase(name)) as start,
        '$FRQFMT' as fmtname, 'C' as type,'M' as HLO,
        cats("#idx",trim(left(put(varnumbr,best.)))) as label from meta1_
        where
        typevar eq 'Discrete' AND
        name in(select distinct lowcase(name) from sashelp.vcolumn where libname eq 'WORK' and memname eq 'FRQS_')
        order by varnumbr;
    QUIT;
    PROC FORMAT CNTLIN=frqfmt ;
    RUN;
%END;


******************************************************;
** PDF output. ODS Style                           ***;
******************************************************;
proc template;
        define style work.newprinter;
        parent=styles.printer;
        style body from document /
                  linkcolor=blue;

        replace color_list "Colors used in the default style"
        / 'link'= blue 'bgH'= white /* default is graybb */ 'fg' = black 'bg' = white; end;
        edit base.freq.onewayfreqs;
        contents=off; /* to get rid of "One-Way Frequencies" subbookmark in PDF */
        end;

run;

ODS NOPTITLE;
GOPTIONS RESET=ALL DEV=SASPRTC FTEXT="Courier/oblique";

ODS LISTING CLOSE;

ODS PDF BODY="../documentation/&pgmname..pdf"  style=newprinter
                TITLE="&title Data Dictionary" UNIFORM
                AUTHOR="Bruce Thomas, VAMC Providence"
                KEYWORDS="CLC,Nursing Homes"
                bookmarklist=show pdftoc=1
                ;

OPTIONS ORIENTATION=LANDSCAPE;
OPTIONS OBS=MAX;

GOPTIONS RESET=ALL DEVICE=PDFC ;
ODS PROCLABEL='Title';

PROC GSLIDE ;
        NOTE HEIGHT=20;
        NOTE HEIGHT=3
        JUSTIFY=CENTER   COLOR="Green"   "&title"
            justify=center   "Data Dictionary";
RUN;

ODS PDF STARTPAGE=NOW;

%IF &freqvars NE %THEN %DO;

ODS PDF ANCHOR='contents';
ODS PROCLABEL="Discrete Variables";

title j=c 'Table of Contents' ;

footnote "^S={just=C URL='#contents' linkcolor=white}Return to ^S={color=blue}Top  ." ;

PROC REPORT DATA=meta1_(where=(typevar='Discrete')) headline headskip nowd contents=' ' out=tst;
       columns typevar name   varnumbr  /*varnum*/   label type format ;
       define varnumbr /order order=data noprint;
       define name/ order style={ color=blue };
        define type /display;
        define format /display;
        define label / display flow width=50 'Variable Label';
        COMPUTE name;
                rtag = "#"||trim(left(put(name,$frqfmt.)));
                ** will not handle sequences containing 01 02, etc;
              CALL DEFINE(_col_,'url',rtag);
       ENDCOMP;
RUN;
%END;

%IF &printvars ne %then %dO;
ODS PDF ANCHOR='RangeContents';

ods proclabel="Range Variables";
PROC REPORT DATA=meta1_(where=(typevar='Range')) headline headskip nowd contents=' ' out=tst;
       columns typevar name   varnumbr  /*varnum*/   label type format ;
       define varnumbr /order order=data noprint;
        define name/ display style={ color=blue};
        define type /display;
        define format /display;
        define label / display flow width=50 'Variable Label';
        COMPUTE name;
                rtag = "#"||trim(left(put(name,$rngfmt.)));
                ** will not handle sequences containing 01 02, etc;
              CALL DEFINE(_col_,'url',rtag);
       ENDCOMP;

RUN;
%END;

%IF &meansvars NE %THEN %DO;
ODS PDF ANCHOR='ContContents';

ods proclabel="Continuous Variables";
PROC REPORT DATA=meta1_(where=(typevar='Continuous')) headline headskip nowd contents=' ' out=tst;
       columns typevar name   varnumbr  /*varnum*/   label type format ;
       define varnumbr /order order=data noprint;
       define name/ order style={ color=blue };
        define type /display;
        define format /display;
        define label / display flow width=50 'Variable Label';
        COMPUTE name;
                rtag = "#"||trim(left(compress(lowcase(name),'0')));
                ** will not handle sequences containing 01 02, etc;
              CALL DEFINE(_col_,'url',rtag);
       ENDCOMP;

RUN;
%END;
TITLE ;
FOOTNOTE;
ods pdf nobookmarkgen;
%*-------------------------------------------
Frequencies for  Variables<NLEVELS
--------------------------------------------;
data meta1a;
set meta1_(where=(typevar='Discrete')) ;
run;

%DDFRQS(inds=frqs_,contents=meta1a,namefmt=$frqfmt.);

%*-------------------------------------------
Long Discrete Variables top/bottom <n>
--------------------------------------------;
data meta1b;
set meta1_(where=(typevar='Range')) ;
format name $rngfmt.;
run;

 %DDMISSRANGE(inds=missrange_,contents=meta1b,namefmt=$rngfmt.,section=RangeContents);

%*-----------------------------------------
group the continuous vars  if
CATEGORY is specified
Pass in a by statement if so.
------------------------------------------;
%let byct=;
%IF %STR(&category) NE %THEN %DO;

    PROC SORT DATA=conts_;
        by &category;
    RUN;

    %LET byct = %STR(BY &category;);

%END;

%*-----------------------------------------
reset graph options in cases there is a
graph requested. Pass along the vategory
and calculate distribution statistics for
Continuous variables
------------------------------------------;
GOPTIONS RESET=ALL;

data meta1c;
set meta1_(where=(typevar='Continuous')) ;
%IF &meansvars ne %then %str(format name $cfmt.;);
run;
%DDCONTS(inds=conts_,category=&category,by=&byct,contents=meta1c);

%FINI:

ODS PDF CLOSE;

%MEND;

