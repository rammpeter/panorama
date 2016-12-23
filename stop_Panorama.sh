echo "Killing java process with Panorama.war"

PID=`ps aux | grep Panorama.war | grep java | awk '{print $2}'`
if [ -z "$PID" ]
then
  echo "Nothing to do, Panorama is not running"
else
  echo "Killing Panorama with PID $PID"
  kill $PID
fi

