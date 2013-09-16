if [ "$1" != "without_build" ] 
then
  ./build_war.sh $1 $2
fi

echo "transfer Panorama.war"
scp Panorama.war ramm@ramm-1.osp-dd.de:rails/Panorama

ssh ramm@ramm-1.osp-dd.de "cd rails/Panorama; ~/glassfish3/bin/asadmin undeploy Panorama; ~/glassfish3/bin/asadmin deploy Panorama.war; ~/glassfish3/bin/asadmin stop-domain; ~/glassfish3/bin/asadmin start-domain"

open "http://ramm-1.osp-dd.de:8080/Panorama"
