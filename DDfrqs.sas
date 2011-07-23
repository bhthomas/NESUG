%*----------------------------------------------------------------
Program Name:       DDfrqs.sas

Project:            data dictionaries

purpose:            generate frequency distributions
                    for all variiables in INDS

author:             Bruce Thomas

inputs:             INDS in WORK library

outputs:            PDF anchored proc freq results

usage:              Called by DataDictionary.sas macro

revisions:
6.7.2011 BT added handler for null label.
------------------------------------------------------------------;
%macro DDfrqs(inds=inds_,contents=&inds,namefmt=$12.,section=contents);

    **********************************************************;
    **  Discrete Variables                                  **;
    **********************************************************;
   %LET nm_=0;

   proc sql NOPRINT;
       create table cont_ as
        select * from &contents;
        select count(*),lowcase(name),compress(label,"'"),format,type
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

   %IF &NM_ gt 0 %THEN  %do i= 1 %to &nm_;
           %let go=NO;
           data _null_;
            if  "&&nme&i" in (&names) then do;
                put " FOUND &&nme&i";
                call symput('go','YES');
                stop;
            end;
           RUN;

         %if &go eq YES %then %do;

            %put Variable: &&nme&i FORMAT: &&fmt&i &&typ&i;


            %if %str("&&lbl&i") eq %str("") %then %do;
                ods proclabel="&&nme&i";
            %end;
            %else %do;
                ods proclabel="&&lbl&i";
            %end;

                       title3 "Frequencies for Variable: &&nme&i";
                       title4 " &&lbl&i ";

                       %let nummiss=;
                       %let allobs=;

                       proc sql noprint;
                               select count(*) "# Missing for &&nme&i" into :nummiss
                               from &inds
                               where &&nme&i is missing;
                               select trim(left(put(count(*),best.)))
                               into :allobs from &inds;
                       quit;
                    %let fmt=%sysfunc(putc(&&nme&i,&namefmt..));

                    ods pdf anchor="&fmt" startpage=now;

                       title5 "Missing values : &nummiss / &allobs";
                       %if %eval(&nummiss = &allobs ) %then %do;
                       *ods pdf text="^S={just=C }All missing Values for this variable ";

                       data &&nme&i;
                               length var $10 varlabel $200 ;
                               retain var "&&nme&i" varlabel "&&lbl&i"  count 0;
                               label var="Variable Name" varlabel="Variable Label" ;
                               var="&&nme&i";
                               count=0;
                               percent=0;
                               value="all values FOR &&nme&i are missing";
                               output;
                         run;

                       %end;
                       %else %do;

                       ** some observations found?**;
                       proc freq data =&inds NOPRINT;
                            tables &&nme&i /list nofreq  nocum out=frq_;
                            where &&nme&i is not missing;
                       run;


                       data &&nme&i;
                               length var $10 varlabel $200 ;
                               retain var "&&nme&i" varlabel "&&lbl&i";
                                set frq_;
                               label var="Variable Name" varlabel="Variable Label";
                               rename &&nme&i=value;

                               %if &&fmt&i ne  %then %str(format &&nme&i &&fmt&i;);
                       run;
                       %end;

                       proc print data=&&nme&i label noobs contents='';
                         var value count percent;
                       run;

                    ods pdf text="^S={just=C URL='#&section' linkcolor=white}Return to ^S={color=blue}Contents   .";

               %FINI:
        %end;
    %END;
%mend;
