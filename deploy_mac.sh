if [ "$1" != "without_build" ] 
then
  ./build_war.sh $1 $2
fi

GF_HOME=~/Library/glassfish4

$GF_HOME/bin/asadmin start-domain
$GF_HOME/bin/asadmin undeploy Panorama
$GF_HOME/bin/asadmin deploy Panorama.war
$GF_HOME/bin/asadmin stop-domain 
$GF_HOME/bin/asadmin start-domain

open "http://localhost:8080"
