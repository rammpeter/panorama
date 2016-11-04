# Unix-start-script for Panorama.war
# Peter Ramm, 07.12.2015

export PANORAMA_HOME=$PWD
export HTTP_PORT=8080

# Writable directory for work area, usage-log and client_info-store, used by Panorama internally
export PANORAMA_VAR_HOME=$PANORAMA_HOME

export LOG=$PANORAMA_VAR_HOME/Panorama.log
echo "Starting Panorama, logfile is $LOG"

# Start with new logfile
rm -f $LOG

# Remove all possible old work areas
rm -rf $PANORAMA_VAR_HOME/work/*

# Ensure existence of work dir
mkdir -p $PANORAMA_VAR_HOME/work

# Optional Parameter:
# -XX:ReservedCodeCacheSize=48M			Default = 48M, Buffer for JIT compiled code
# -XX:+ UseCodeCacheFlushing			Flush old / unused code to enable JIT compilation of current code
# -Xmx1024m					Maximum heap space
# -Xms1024m					Initial heap space
# -Djruby.compile.fastest=true			(EXPERIMENTAL) Turn on all experimental compiler optimizations.
# -Djruby.compile.threadless=true               (EXPERIMENTAL) Turn on compilation without polling for "unsafe" thread events. 
# -Xcompile.invokedynamic=true                  Use invokedynamic for optimizing Ruby code., erroneous with Panorama
# -Dwarbler.port=<port>                         Set http-port to use

# Variant for Jetty app-server, start Panorama-server in Background
java -Xmx1024m \
     -Xms1024m \
     -XX:ReservedCodeCacheSize=80M \
     -Djruby.compile.fastest=true \
     -Djruby.compile.threadless=true \
     -Djava.io.tmpdir=./work \
     -Dwarbler.port=$HTTP_PORT \
     -jar $PANORAMA_HOME/Panorama.war 2>>$LOG >>$LOG &

export MAX_WAIT=300
export URL="http://localhost:$HTTP_PORT/Panorama/"

typeset -i LOOP_COUNT=0
while [ $LOOP_COUNT -lt $MAX_WAIT ]
do
  echo -n '.'
  curl $URL 2>/dev/null >/dev/null
  if [ $? -eq 0 ]
  then
    echo
    echo "Panorama can be used now at $URL after $LOOP_COUNT seconds startup time"
    exit 0
  fi

  LOOP_COUNT=LOOP_COUNT+1
  sleep 1
done
echo
echo "Problem: Panorama not reachable after $MAX_WAIT seconds at $URL"
exit 1


