# Common pitfalls using SQL*Net via Firewalls

Datum: 2017-06-12
URL: https://rammpeter.blogspot.com/2017/06/common-pitfalls-using-sqlnet-via.html
Labels: Analyze performance issue, Code templates

---

It's very common that firewalls are terminating idle TCP sessions after a limited time, often after approximately one hour.

Possible problem

If you have a long running SQL or PL/SQL program and the firewall terminates your apparently idle TCP session this may lead to the following scenario:

- the database is not able to send result to client. After reaching the TCP-timeout the database server terminates the DB-Session

- the client program stays in socket read forever waiting for the database response

Oracle's full solution: SQLNET.EXPIRE_TIME=x in sqlnet.ora

Oracle's solution for this problem is setting parameter SQLNET.EXPIRE_TIME=x in sqlnet.ora where x are the minutes between keep alive packets on idle sessions that inform the firewall that this session is always alive.

SQLNET.EXPIRE_TIME hast to be set in the sqlnet.ora of your RDBMS' ORACLE_HOME.

Normally $ORACLE_HOME/network/admin.

If you have a grid infrastructure setting SQLNET.EXPIRE_TIME in sqlnet.ora of your grid's ORACLE_HOME has no function.

Also setting SQLNET.EXPIRE_TIME in your client's sqlnet.ora has no function.

You should set SQLNET.EXPIRE_TIME=x to a value smaller than half the idle session timeout of your firewall because:

- The keep alive packets are sent exactly each x minutes like you declare

- but the first keep alive packet ist sent in a range until twice the time in minutes you declare

- common value is SQLNET.EXPIRE_TIME=10

Oracle's whitepaper describes some details.

Oracle's lightweight solution: (enable=broken)

There's an other approach for resolving connection termination by firewall:

Specify "enable=broken" in client's tnsnqmes.ora.

net_service_name=(DESCRIPTION=(enable=broken)(ADDRESS=...

This does not create keep alive packets that hold your TCP session open.

Instead it detects terminated TCP sessions and recreates them from client side.

This ensures that your idle connection remains functional but unfortunately it does not ensure that you can get the result of a long running query after connection termination by firewall.

So enable=broken is not a comparable solution to SQLNET.EXPIRE_TIME.

Troubleshooting

Keep alive packets are sent as real TCP packets within your TCP session and therefore you can check the function by scanning for keep alive packets with tcpdump or ethereal.

The following script initiates an idle session to your database and than scans your session's network connection for existence of keep alive packets (for Linux and Mac-OS, to be executed as root)

# Check idle SQL*Net-session for keep alive packets
# to switch off idle connection detection done by several firewall systems
# Execute as root!
# Peter Ramm, 2017-06-11

CONNECT=user/password@YOUR_DB

# Wait-time in seconds (more than one hour)
WAIT_TIME=4000

function date_echo {
 echo "`date "+%Y-%m-%d %H:%M:%S"`: $1"
}

echo "
 -- Pin execution at database without network traffic between sqlplus and database
 EXEC DBMS_LOCK.Sleep(10);
 prompt The next call should be recorded by tcpdump, than only keep alive packets should be recorded
 prompt until the call returns after WAIT_TIME seconds
 EXEC DBMS_LOCK.Sleep($WAIT_TIME-60);
" | sqlplus -s $CONNECT &

CLIENT_PID=`ps -ef | grep $$ | grep sqlplus | awk '{ print $2 }'`
date_echo "PID of sqlplus process = $CLIENT_PID"

# Wait until virtual scan adress has moved to real host address
sleep 3

date_echo "TCP-Connection betwenn sqlplus and database is:"
lsof -p $CLIENT_PID | grep TCP

CLIENT_PORT=`lsof -p $CLIENT_PID | grep TCP | awk '{ print $9}' | awk -F "->" '{print $1}' | awk -F ":" '{print $2}'`
date_echo "Client port = $CLIENT_PORT"

DATABASE_HOST=`lsof -p $CLIENT_PID | grep TCP | awk '{ print $9}' | awk -F "->" '{print $2}' | awk -F ":" '{print $1}'`
date_echo "Database host = $DATABASE_HOST"

if [ "`uname`" == "Linux" ]
then
 tcpdump --immediate-mode -i any -tttt "host $DATABASE_HOST and port $CLIENT_PORT" &
elif [ "`uname`" == "Darwin" ]
then
 tcpdump --immediate-mode -i pktap,all -t 4 "host $DATABASE_HOST and port $CLIENT_PORT" &
else
 echo "Unknown operating system"
fi

TCPDUMP_PID=`ps -ef | grep $$ | grep tcpdump | awk '{ print $2 }'`

sleep $WAIT_TIME

kill $TCPDUMP_PID
date_echo "tcpdump process with PID=$TCPDUMP_PID terminated"
date_echo "Finish ..."
