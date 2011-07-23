%*----------------------------------------------------------------
Program Name:       DDMISSRANGE.sas

Project:            data dictionaries

purpose:            generate  top/bottom distributions
                    of SIZE=5
                    for all  identified continuous varibles
                    in INDS

author:             Bruce Thomas

inputs:             INDS in WORK library
                    SIZE= top and bottom n

outputs:            PDF anchored proc freq results

usage:              Called by DataDictionary.sas macro

revisions:
6.7.2011 BT added handler for null label. Set maxdec=2.
------------------------------------------------------------------;


%MACRO DDMISSRANGE(inds=missrange_,contents=contents, size=5,namefmt=$12.,section=contents);

     **********************************************************;
     ** Long Discrete Variables top and bottom <SIZE>        **;
     **********************************************************;
    %let nm_=0;

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

    %IF &nm_ GT 0 %THEN %DO i= 1 %to &nm_;

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
        %let fmt=%sysfunc(putc(&&nme&i,&namefmt..));

        ods pdf anchor="&fmt" startpage=now;
        ods proclabel="&&nme&i";
        title3 "Ranges For Variable: &&nme&i";
        title4 " &&lbl&i ";

        %let label=%quote(&&lbl&i);

        %if &label eq %then %do;
            ods proclabel="&&nme&i";
        %end;
        %else %do;
            ods proclabel="&label";
        %end;
       title3 "Ranges For Variable: &&nme&i";
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

                title5 "Missing values : &nummiss / &allobs";
                %if %eval(&nummiss = &allobs ) %then %do;
                ods pdf text="^S={just=C }All missing Values for this variable ";

                data &&nme&i;
                        length var $10 varlabel $200 desc $20;
                        retain var "&&nme&i" varlabel "&&lbl&i" desc "&Nummiss Missing" count 0;
                        label var="Variable Name" varlabel="Variable Label" desc='Description ';
                        Desc="all values are missing" ;var="&&nme&i";count=0;percent=0;
                       value=.;
                  run;

                %end;
                %else %do;

                ** some observations found?**;
                proc freq data =&inds NOPRINT;
                    tables &&nme&i /list nofreq  nocum out=frq_;
                    where &&nme&i is not missing;
                run;

                proc sort data=frq_;
                    by DESCENDING count;
                run;

                data top;
                    set frq_(obs=&SIZE);
                run;

                proc sort data=frq_;
                    by count;
                run;

                data bot;
                set frq_(obs=&SIZE);
                run;

                data &&nme&i;
                        length var $10 varlabel $200 desc $20;
                        retain var "&&nme&i" varlabel "&&lbl&i";
                        set top (in=in1) bot (in=in2) ;
                        if in1 then desc="Highest &SIZE";
                        if in2 then desc="Lowest &SIZE";
                        label var="Variable Name" varlabel="Variable Label" desc='Description ';
                        rename &&nme&i=value;
                        %if &&fmt&i ne  %then %str(format &&nme&i &&fmt&i;);
                run;
                %end;

                proc print data=&&nme&i label noobs;
                var desc value count percent;
                run;
                ods pdf text="^S={just=C URL='#&section' linkcolor=white}Return to ^S={color=blue}Contents   .";

        %FINI:
    %END;
%END; ** end of NM_ > 0%;
%MEND;