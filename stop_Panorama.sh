echo "Killing java process with Panorama.war"
kill $(ps aux | grep Panorama.war | grep java | awk '{print $2}')

