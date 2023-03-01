#!/bin/bash
# Create database instance during "docker build" by wrapping runOracle.sh
# Terminates install process after finishing

PERSISTENT_DATA=/opt/oracle/app/oracle/oradata
export ORACLE_HOME=/opt/oracle/app/oracle/product/11.2.0.4/dbhome_1
export ORACLE_SID=ORCL

create_pfile() {
        $ORACLE_HOME/bin/sqlplus -S / as sysdba << EOF
        set echo off pages 0 lines 200 feed off head off sqlblanklines off trimspool on trimout on
        spool $PERSISTENT_DATA/init_ORCL.ora
        select 'spfile="'||value||'"' from v\$parameter where name = 'spfile';
        spool off
        exit
EOF
}

printf "LISTENER=(DESCRIPTION_LIST=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=0.0.0.0)(PORT=1521))(ADDRESS=(PROTOCOL=IPC)(KEY=EXTPROC1521))))\n" > $ORACLE_HOME/network/admin/listener.ora
$ORACLE_HOME/bin/lsnrctl start

sed -i "s/{{ db_create_file_dest }}/\/opt\/oracle\/app\/oracle\/oradata\/ORCL/" /home/oracle/db_install.dbt
sed -i "s/{{ oracle_base }}/\/opt\/oracle\/app\/oracle/" /home/oracle/db_install.dbt
sed -i "s/{{ database_name }}/ORCL/" /home/oracle/db_install.dbt
$ORACLE_HOME/bin/dbca -silent -createdatabase -templatename /home/oracle/db_install.dbt -gdbname ORCL -sid ORCL -syspassword oracle -systempassword oracle -dbsnmppassword oracle
if [ $? -ne 0 ]; then
  echo "Error executing dbca"
  exit 1
fi
create_pfile

$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
shutdown abort
exit
EOF

