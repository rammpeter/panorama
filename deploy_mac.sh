if [ "$1" != "without_build" ] 
then
  ./build_war.sh $1 $2
fi

~/Library/glassfish3/bin/asadmin start-domain
~/Library/glassfish3/bin/asadmin undeploy Panorama
~/Library/glassfish3/bin/asadmin deploy Panorama.war
~/Library/glassfish3/bin/asadmin stop-domain 
~/Library/glassfish3/bin/asadmin start-domain

open "http://localhost:8080/Panorama"
