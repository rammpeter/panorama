#!/bin/bash
# run DB by runOracle.sh
# link preinstalled database from VOLUME $ORACLE_BASE/oradata at first startup

# Start database

PERSISTENT_DATA=/opt/oracle/app/oracle/oradata
export ORACLE_HOME=/opt/oracle/app/oracle/product/11.2.0.4/dbhome_1
export ORACLE_SID=ORCL


$ORACLE_HOME/bin/lsnrctl start

mkdir -p /opt/oracle/app/oracle/admin/ORCL/adump
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
startup pfile=$PERSISTENT_DATA/init_ORCL.ora
@/home/oracle/modify_instance_settings.sql
@/home/oracle/create_panorama_test_user.sql
@/home/oracle/create_awr_snapshots.sql

exec DBMS_STATS.Gather_Schema_Stats('SYS');

shutdown abort
exit
EOF



