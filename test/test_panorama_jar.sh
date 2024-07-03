# Test the Panorama jar file
# Should be started in RAILS_ROOT directory

# raise error if file does not exist
if [ ! -f "Panorama.jar" ]; then
  echo "Panorama.jar does not exist in `pwd`"
  exit 1
fi

# Start Panorama.jar in background
java -jar Panorama.jar > panorama.log 2>&1 &



echo "Waiting for InitializationJob to be performed"
MAX_WAIT=120
typeset -i LOOPS=0
while [ $LOOPS -lt $MAX_WAIT ]; do
  retval=0
  grep "Performed InitializationJob" panorama.log >/dev/null || retval=$?
  if [ $retval -eq 0 ]; then
    break
  fi
  LOOPS=LOOPS+1
  echo -n .
  sleep 1
done
if [ $LOOPS -eq $MAX_WAIT ]; then
  echo "InitializationJob not finished after $MAX_WAIT seconds"
  echo "retval = $retval"
  echo "===== log output from Panorama.jar ====="
  cat panorama.log
  exit 1
else
  echo "InitializationJob finished after $LOOPS seconds"
fi
typeset -i LOOPS=0
while [ $LOOPS -lt $MAX_WAIT ]; do
  retval=0
  curl http://localhost:8080/ 2>/dev/null >/dev/null || retval=$?
  if [ $retval -eq 0 ]; then
    break
  fi
  LOOPS=LOOPS+1
  echo -n .
  sleep 1
done
if [ $LOOPS -eq $MAX_WAIT ]; then
  echo "No access to port 8080 after $MAX_WAIT seconds"
  echo "retval = $retval"
  curl http://localhost:8080/
  echo "===== log output from Panorama.jar ====="
  cat panorama.log
  exit 1
else
  echo "Access to port 8080 after $LOOPS seconds"
fi

# Check the content
