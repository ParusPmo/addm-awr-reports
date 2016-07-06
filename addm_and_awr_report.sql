set long 999999999 pagesize 0 linesize 8000 feedback off echo off verify off trims on termout off heading off
set termout on
PROMPT ************************************
PROMPT *       Genereate AWR report       *
PROMPT * Created on 29.01.2013 by IGOR-GO *
PROMPT ************************************
PROMPT
ACCEPT DDATE date format 'YYYY-MM-DD HH24:MI' PROMPT 'Enter report date (YYYY-MM-DD): '
ACCEPT NINSTANCE number format '0' PROMPT 'Enter instance (default=1): '  default '1'
ACCEPT REPPATH PROMPT 'Enter path to report without trailing "\" (default=D:): ' default 'D:'
VARIABLE DB_ID NUMBER
VARIABLE START_SNAP NUMBER
VARIABLE END_SNAP number
VARIABLE taskname varchar2(60)
set termout off
column awr_filename new_val awr_filename
column addm_filename new_val addm_filename
select '&REPPATH'||'\AWR#'||'&DDATE'||'#'||trim('&NINSTANCE')||'.html' awr_filename from dual;
select '&REPPATH'||'\ADDM#'||'&DDATE'||'#'||trim('&NINSTANCE')||'.txt' addm_filename from dual;
--set echo on
set termout on
begin
  select DBID
    into :DB_ID
    from V$DATABASE;
  select min(SNAP_ID),
         max(SNAP_ID)
    into :START_SNAP,
         :END_SNAP
    from DBA_HIST_SNAPSHOT
   where BEGIN_INTERVAL_TIME between date '&DDATE' and (date '&DDATE' + 1)
     and INSTANCE_NUMBER = &NINSTANCE
	 and begin_interval_time >= (select max(startup_time) from DBA_HIST_SNAPSHOT);
   if  :START_SNAP is null  then
     RAISE_APPLICATION_ERROR(-20000,
        'Sorry! There was a instance shutdown/startup after date you entered.'); 
  end if;  
end;
/
PROMPT 
PROMPT Genereate AWR report to &awr_filename ...
set termout off
spool &awr_filename
select *
    from table(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(:DB_ID, &NINSTANCE, :START_SNAP, :END_SNAP, 0));
spool off;
DECLARE
  tname VARCHAR2 (60);
  taskid NUMBER;
BEGIN
  dbms_advisor.create_task('ADDM', taskid, tname);
  dbms_advisor.set_task_parameter(tname, 'START_SNAPSHOT',:START_SNAP);
  dbms_advisor.set_task_parameter(tname, 'END_SNAPSHOT', :END_SNAP);
  dbms_advisor.set_task_parameter(tname, 'INSTANCE', &NINSTANCE);
  dbms_advisor.execute_task(tname);
  :taskname := tname;
END;
/
set termout on
PROMPT Genereate ADDM report to &addm_filename ...
set termout off
spool &addm_filename
SELECT dbms_advisor.get_task_report(:taskname, 'TEXT', 'ALL', 'ALL') 
FROM   DBA_ADVISOR_TASKS t
WHERE  t.task_name = :taskname
AND    t.owner = SYS_CONTEXT ('USERENV', 'session_user');
spool off;