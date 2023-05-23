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

# Remove temporary objects from previous runs, especially the pid-file if the container was stopped by docker stop -t 0
rm -rf $PANORAMA_HOME/tmp

if [ -z "$MAX_JAVA_HEAP_SPACE_MB" ]
then
  MAX_JAVA_HEAP_SPACE_MB=1024
fi
echo "max. Java heap space set to $MAX_JAVA_HEAP_SPACE_MB megabytes"
export RAILS_LOG_TO_STDOUT_AND_FILE=true
export RAILS_SERVE_STATIC_FILES=true
export RAILS_MIN_THREADS=10
# Default for RAILS_MAX_THREADS is set as ENV in Dockerfile

# Optional Parameter:
# -XX:ReservedCodeCacheSize=48M			Default = 48M, Buffer for JIT compiled code
# -XX:+ UseCodeCacheFlushing			Flush old / unused code to enable JIT compilation of current code
# -Xmx1024m					Maximum heap space
# -Xms1024m					Initial heap space
# -Djruby.compile.fastest=true			(EXPERIMENTAL) Turn on all experimental compiler optimizations.
# -Djruby.compile.threadless=true               (EXPERIMENTAL) Turn on compilation without polling for "unsafe" thread events.
# -Xcompile.invokedynamic=true                  Use invokedynamic for optimizing Ruby code., erroneous with Panorama
# -Dwarbler.port=<port>                         Set http-port to use

# If you run Panorama on virtualized headless Linux server (e.g. in cloud environment) and your browser hangs after first request:
# Reason: Your server does not generate enough entropy values in /dev/random, so read on /dev/random blocks during encryption operation
# Solution: Start Panorama with non-blocking entropy generator by option java.security.egd=file:/dev/urandom
# -Djava.security.egd=file:/dev/urandom
# On Read Hat Linux and clones (Oracle Linux etc.) you can install rng-tools instead of using /dev/urandom like described here:
#  yum install -y rng-tools
#  systemctl enable rngd.service
#  systemctl start rngd.service

export JAVA_OPTS="-Xmx${MAX_JAVA_HEAP_SPACE_MB}m \
                  -XX:ReservedCodeCacheSize=80M \
                  -Djruby.compile.fastest=true \
                  -Djruby.compile.threadless=true"

CMD="bundle exec bin/rails server --port $HTTP_PORT --environment production"
echo "Starting $CMD"
# "exec ..." ensures that rails server runs in the same process like shell script before
# this ensures that application is gracefully shut down at docker stop
exec $CMD
