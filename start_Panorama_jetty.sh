export PANORAMA_HOME=$PWD
export PANORAMA_USAGE_LOG=$PANORAMA_HOME/Usage.log
export LOG=$PANORAMA_HOME/Panorama_jetty.log
echo "Starting Panorama with jetty, logfile is $LOG"
java -XX:MaxPermSize=256M -XX:+CMSClassUnloadingEnabled -XX:+CMSPermGenSweepingEnabled -jar $PANORAMA_HOME/Panorama.war 2>&1 | tee -a $LOG

