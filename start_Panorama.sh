# Unix-start-script for Panorama.war
# Peter Ramm, 07.12.2015

export PANORAMA_HOME=$PWD
export HTTP_PORT=8080

# Writable directory for work area, usage-log and client_info-store, used by Panorama internally
export PANORAMA_VAR_HOME=$PANORAMA_HOME

export LOG=$PANORAMA_VAR_HOME/Panorama.log
echo "Starting Panorama, logfile is $LOG"

# Remove all possible old work areas
rm -rf $PANORAMA_VAR_HOME/work/*

# Variant for Jetty app-server
#java -Xmx1024m -XX:MaxPermSize=512M -XX:+CMSClassUnloadingEnabled -XX:+CMSPermGenSweepingEnabled -Djruby.compile.invokedynamic=true -Djetty.port=8090 -Djetty.requestHeaderSize=8192 -Djava.io.tmpdir=./work -jar $PANORAMA_HOME/Panorama.war 2>&1 | tee -a $LOG 

# Variant for Winstone app-server
java -Xmx1024m -Djava.io.tmpdir=$PANORAMA_VAR_HOME/work -jar $PANORAMA_HOME/Panorama.war --httpPort=$HTTP_PORT --debug=9  2>&1 | tee -a $LOG 

