# Oracle-DB: Run TPC benchmark with hammerdb on Standard Edition

Datum: 2025-11-04
URL: https://rammpeter.blogspot.com/2025/11/oracle-db-run-tpc-benchmark-with.html
Labels: HammerDB, Oracle Database

---

For a small demo I needed a synthetic workload at an Oracle DB.

We are running on Oracle Linux and want to execute a TPC benchmark at an SE2 instance. 

The tool of choice to do this quickly was HammerDB (https://www.hammerdb.com) which is also avaialble as Docker image.

Assuming an Oracle DB is already running on port 1521 of the Docker host, these are the steps:

Create a config script config.tcl:

echo "
# Select the Oracle database.
dbset db ora
# Select the TPC-C benchmark.
dbset bm TPC-C
# Oracle DBA user (e.g., SYSTEM)
diset connection system_user SYSTEM
# DBA user's password
diset connection system_password oracle
# Your DB connect string. Use IP of Docker host 
diset connection instance 10.214.3.3:1521/ORCLPDB1
# Scaling Factor (Number of Warehouses), e.g. 100
diset tpcc count_ware 100
# Virtual Users for schema build/load and run 
diset tpcc num_vu 8
# Benchmark schema user (will be created)
diset tpcc tpcc_user TPCC
# Benchmark schema password
diset tpcc tpcc_pass pdcc
# Tablespace name for data. 
diset tpcc tpcc_def_tab USERS
" > config.tcl

Create a schema build script build.tcl:

echo "
source /tcl_scripts/config.tcl
buildschema
" > build.tcl

Start the Docker container with interactive bash:

docker run --rm --network=host -it --name hammerdb -v $PWD:/tcl_scripts tpcorg/hammerdb:oracle bash

Excute the build script in the container:

./hammerdbcli auto /tcl_scripts/build.tcl

After exiting the container create the benchmark run script run.tcl

echo "
source /tcl_scripts/config.tcl

# --- Driver Script Settings ---
# Use the driver without AWR snapshots ('timed' is the alternative that generates AWR snapshots in EE)
diset tpcc ora_driver test

# Ramp-up time in minutes (ignored for result calculation)
diset tpcc ora_rampup 1
# Test duration in minutes (used for result calculation)
diset tpcc ora_duration 3

# Disable log output of idividual actions
vuset showoutput 0

# Load the TPC-C driver script
loadscript

# The number of virtual users
vuset vu 8 

# Create and connect the Virtual Users
vucreate

# Run the test workload
vurun
" > run.tcl

Start the Docker container again with interactive bash:

docker run --rm --network=host -it --name hammerdb -v $PWD:/tcl_scripts tpcorg/hammerdb:oracle bash

Run the benchmark in Docker container. This step can be repeated multiple times:

./hammerdbcli auto /tcl_scripts/run.tcl

Run the workload in non-interactive mode

Unfortuneately, running the HammerDB job from command line (e.g. as a cron job) failed for me up to now, because the Oracle client lib was reported as non-existent in this cases.

Failing example:

echo "./hammerdbcli auto /tcl_scripts/run.tcl" | docker run --rm --network=host -i --name hammerdb -v $PWD:/tcl_scripts tpcorg/hammerdb:oracle bash

fails with 

Vuser 1:RUNNING
Oratcl_Init(): Failed to load /home/instantclient_21_18/libclntsh.so with error libnnz21.so: cannot open shared object file: No such file or directory
Oratcl_Init(): ORACLE_LIBRARY = /home/instantclient_21_18/libclntsh.so : file not found.
Error in Virtual User 1: Failed to load Oratcl - 

A quick workaroud could be to start the Docker container as daemon, connect to the running container and start a looping script which repeates executing the benchmark until a stop of the container

Create the run script loop.sh

echo "
# Run the benchmark infinitely
while ( true)
do
 echo \"`date` Starting benchmark\"
 ./hammerdbcli auto /tcl_scripts/run.tcl
 echo \"`date` Finished benchmark, sleeping some time\"
 sleep 120
done
" > loop.sh
chmod a+s 

Start the Docker container as background daemon :

docker run --rm -d --network=host --name hammerdb -v $PWD:/tcl_scripts tpcorg/hammerdb:oracle

Open the bash in container:

docker exec -ti hammerdb bash

Run the loop script in background so that you may disconnect your session from container.

nohup /tcl_scripts/loop.sh &
