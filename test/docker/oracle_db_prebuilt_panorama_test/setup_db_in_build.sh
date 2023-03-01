# Setup database instance during "docker build" by wrapping runOracle.sh
# Terminates install process after finishing

# Start database in background, use script that at first links data files to /opt/oradata
$ORACLE_BASE/run_db_in_container.sh &

sleep 1                                                                         # ensure that $ORACLE_BASE/$RUN_FILE has started
# Wait until tail -f on alert.log occurs
while [ true ]
do
  ps -ef | grep -v grep | grep -e "tail -f.*diag/rdbms.*trace/alert.*.log" > /dev/null
  if [ $? -eq 0 ]; then
    echo "tail -f on alert.log now occurs"
    break
  fi

  ps -ef | grep -v grep | grep $RUN_FILE > /dev/null
  if [ $? -ne 0 ]; then
    echo "ERROR: process $RUN_FILE has terminated before waiting on tail -f on alert.log"
    exit 1
  fi

  sleep 1
done

echo "running shell in docker as user:"
id

# Switch user to oracle if running as root
if [ `id -u` -eq 0 ]
then
  EXEC_CMD="su oracle -c"
else
  EXEC_CMD="sh -c"
fi

echo "Execute setup script modify_instance_settings.sql"
cat $ORACLE_BASE/modify_instance_settings.sql | $EXEC_CMD "sqlplus -s / as sysdba"

echo "Execute setup script create_panorama_test_user.sql"
cat $ORACLE_BASE/create_panorama_test_user.sql | $EXEC_CMD "sqlplus -s / as sysdba"

echo "Execute create_awr_snapshots.sql to ensure filled AWR tables before analyze"
cat $ORACLE_BASE/scripts/startup/create_awr_snapshots.sql | $EXEC_CMD "sqlplus -s / as sysdba"

echo "Execute setup script analyze_sys_schemas.sql"
cat $ORACLE_BASE/analyze_sys_schemas.sql       | $EXEC_CMD "sqlplus -s / as sysdba"

echo "Terminates waiting process runOracle.sh by killing tail -f"
kill `ps -ef | grep -v grep | grep -e "tail -f.*diag/rdbms.*trace/alert.*.log" | awk '{ print $2 }'`

# All o.k. if reaching this point
exit 0
