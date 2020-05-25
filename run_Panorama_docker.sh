#!/bin/bash

# Docker-executable
# Peter Ramm, 28.12.2016

# Allow overriding of environment by docker run
if [ -z "$PANORAMA_HOME" ]; then
  export PANORAMA_HOME=$PWD
fi

if [ -z "$HTTP_PORT" ]; then
  export HTTP_PORT=8080
fi

# Writable directory for work area, usage-log and client_info-store, used by Panorama internally
if [ -z "$PANORAMA_VAR_HOME" ]; then
  export PANORAMA_VAR_HOME=/var/opt/panorama
fi

# Remove all possible old work areas
rm -rf $PANORAMA_HOME/work

# Ensure existence of work dir
mkdir -p $PANORAMA_HOME/work

if [ -z "$MAX_JAVA_HEAP_SPACE_MB" ]
then
  MAX_JAVA_HEAP_SPACE_MB=1024
fi
echo "max. Java heap space set to $MAX_JAVA_HEAP_SPACE_MB megabytes"

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
CMD="java -Xmx${MAX_JAVA_HEAP_SPACE_MB}m \
     -XX:ReservedCodeCacheSize=80M \
     -Djruby.compile.fastest=true \
     -Djruby.compile.threadless=true \
     -Djava.io.tmpdir=$PANORAMA_HOME/work \
     -Dwarbler.port=$HTTP_PORT \
     -jar $PANORAMA_HOME/Panorama.war "

echo "Starting $CMD"
exec $CMD 

# docker stop will cancel running jetty

