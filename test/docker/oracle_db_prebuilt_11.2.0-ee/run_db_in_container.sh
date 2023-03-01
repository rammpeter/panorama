#!/bin/bash
# run DB by runOracle.sh
# link preinstalled database from VOLUME $ORACLE_BASE/oradata at first startup

# Start database

PERSISTENT_DATA=/opt/oracle/app/oracle/oradata
export ORACLE_HOME=/opt/oracle/app/oracle/product/11.2.0.4/dbhome_1
export ORACLE_SID=ORCL

stop_database() {
        $ORACLE_HOME/bin/sqlplus / as sysdba << EOF
        shutdown abort
        exit
EOF
        exit
}

trap stop_database SIGTERM

$ORACLE_HOME/bin/lsnrctl start

mkdir -p /opt/oracle/app/oracle/admin/ORCL/adump
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
startup pfile=$PERSISTENT_DATA/init_ORCL.ora
exit
EOF

# Execute custom file
if [ -f /home/oracle/customize_instance.sql ]; then
    $ORACLE_HOME/bin/sqlplus / as sysdba << EOF
    @/home/oracle/customize_instance.sql
    exit
EOF
fi


tail -f /opt/oracle/app/oracle/diag/rdbms/orcl/ORCL/trace/alert_ORCL.log &
wait
