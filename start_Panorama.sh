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

# Optional Parameter:
# -XX:ReservedCodeCacheSize=48M			Default = 48M, Buffer for JIT compiled code
# -XX:+ UseCodeCacheFlushing			Flush old / unused code to enable JIT compilation of current code
# -Xmx1024m					Maximum heap space
# -Xms1024m					Initial heap space
# -Djruby.compile.fastest=true			(EXPERIMENTAL) Turn on all experimental compiler optimizations.
# -Djruby.compile.threadless=true               (EXPERIMENTAL) Turn on compilation without polling for "unsafe" thread events. 
# -Djruby.compile.invokedynamic=true		Use invokedynamic for optimizing Ruby code., erroneous with Panorama

# Variant for Jetty app-server
java -Xmx1024m \
     -Xms1024m \
     -XX:+CMSClassUnloadingEnabled \
     -XX:+CMSPermGenSweepingEnabled \
     -XX:+UseCodeCacheFlushing \
     -XX:ReservedCodeCacheSize=80M \
     -Djruby.compile.fastest=true \
     -Djruby.compile.threadless=true \
     -Djava.io.tmpdir=./work \
     -jar $PANORAMA_HOME/Panorama.war 2>&1 | tee -a $LOG 


