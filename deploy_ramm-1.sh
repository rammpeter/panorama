if [ "$1" != "without_build" ] 
then
  ./build_war.sh $1 $2
fi

echo "transfer Panorama.war"
scp Panorama.war ramm@ramm-1.osp-dd.de:rails/Panorama

# Variante jetty
ssh ramm@ramm-1.osp-dd.de "cd rails/Panorama; ./stop_Panorama_jetty.sh; ./start_Panorama_jetty.sh"

# Variante Glassfish
# ssh ramm@ramm-1.osp-dd.de "cd rails/Panorama; ~/glassfish4/bin/asadmin undeploy Panorama; ~/glassfish4/bin/asadmin deploy Panorama.war; ~/glassfish4/bin/asadmin stop-domain; ~/glassfish4/bin/asadmin start-domain"

sleep 10

open "http://ramm-1.osp-dd.de:8080/Panorama"
