%*----------------------------------------------------------------
Program Name:       DDconts.sas

Project:            data dictionaries

purpose:            generate  distributions
                    for all  identified continuous varibles
                    in INDS

author:             Bruce Thomas

inputs:             INDS in WORK library

outputs:            PDF anchored proc freq results

usage:              Called by DataDictionary.sas macro

revisions:
6.7.2011 BT added handler for null label. Set maxdec=2.
------------------------------------------------------------------;

%MACRO DDCONTS(inds=conts_,category=,by=,contents=meta_,namefmt=$12.,section=contents);

      **********************************************************;
      **Continuous Variables add boxplot                      **;
      **********************************************************;
        %let nm_=0;
        proc sql NOPRINT;
                   create table cont_ as
                    select * from &contents;
                    select count(*),lowcase(name),label,format,type
                        into :nm_,:nme1-:nme999,:lbl1-:lbl999,:fmt1-:fmt999 ,:typ1-:typ999
                        from cont_;
           drop table cont_;

            *** WHICH VARS ARE WE INTERESTED IN HERE? **;
            select "'"||compress(lowcase(name))||"'"
                into :names separated by ' '
                from dictionary.columns
                where libname eq 'WORK' and
                    memname eq "%upcase(&inds)";
        quit;

    %IF &nm_ gt 0 %THEN %DO;
        %do i= 1 %to &nm_;

            %let go=NO;
            data _null_;
             if  "&&nme&i" in (&names) then do;
                 put " FOUND &&nme&i";
                 call symput('go','YES');
                 stop;
             end;
            RUN;

            %if &go eq YES %then %do;
                  **********************************************************;
                  **Basic distribution Statistics                         **;
                  **********************************************************;
                proc means data=&inds nway noprint maxdec=2;
                  var &&nme&i;
                  output out=&&nme&i nmiss=nmiss n=n mean=mean std=std median=median
                                  q1=q1 q3=q3 p10=p10 p90=p90 min=min max=max;
                    where &&nme&i gt 0 ;*** get rid of zeroes;
                  &by;
                run;

                data &&nme&i;
                  length var $10 varlabel $200;
                  retain var "&&nme&i" varlabel "&&lbl&i";
                  set &&nme&i;
                  label var="Variable Name" varlabel="Variable Label" nmiss="# Missing"
                  n= "N" mean="mean" median="Median" std="Standard Deviation"
                  q1="Q1" q3="Q3" P10="P10" p90="P90" min="Minimum" max="Maximum";
                  drop _:;
                  format mean std 10.2;
                run;

                %let fmt=%sysfunc(putc(&&nme&i,&namefmt..));
                ods pdf anchor="&fmt" startpage=now;
                ods proclabel="&&nme&i";

                %if %str("&&lbl&i") eq %str("") %then %do;
                             ods proclabel="&&nme&i";
                 %end;
                 %else %do;
                     ods proclabel="&&lbl&i";
                 %end;


                title3 "Distribution for &&lbl&i";
                footnote3 ' ';

                proc print data=&&nme&i;
                &by;
                run;

                %let mean=;
                proc sql noprint;
                select distinct mean into :mean
                from &&nme&i;
                quit;

                ods pdf startpage=NO;
                ods noptitle;
                ods proclabel="Plot for &&nme&i";
                ods graphics on/ height=5in width=5in;

                goptions interpol=boxt device=SVG ;*pdfc;

                axis1   label=(height=1.25 "&&lbl&i" )
                      minor=(number=1);
                axis2   label=(height=1.25 '' );
                symbol  value=dot
                      height=0.5;

                proc sgplot data=&inds;
                vbox &&nme&i %if &category ne %then %str(/category=&category);;
                where &&nme&i gt 0 ;
                &by;
                refline &mean /transparency=0.5 Label=("Mean");
                inset "Source: &pgmname"/position=TOPRIGHT Border;
                run;

               ods pdf text="^S={just=C URL='#&section' linkcolor=white}Return to ^S={color=blue}Contents   .";
                ODS GRAPHICS OFF;

            %END;
        %END;
     %END; %** OF  NM_>0;
%MEND;
