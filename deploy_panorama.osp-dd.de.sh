if [ "$1" != "without_build" ] 
then
  ./build_war.sh $1 $2
fi

echo "transfer Panorama.war"
scp Panorama.war panorama@panorama.osp-dd.de:/opt/panorama/Panorama.war.new

# Variante jetty


# Variante jetty
ssh panorama@panorama.osp-dd.de "
  cd /opt/panorama
  rm -f Panorama.war.old2
  mv Panorama.war.old1 Panorama.war.old2
  ./stop_Panorama_jetty.sh
  mv Panorama.war Panorama.war.old1
  mv Panorama.war.new Panorama.war
  ./start_Panorama_jetty.sh
  cat P*.log
"

# Variante Glassfish
# ssh ramm@ramm-1.osp-dd.de "cd rails/Panorama; ~/glassfish4/bin/asadmin undeploy Panorama; ~/glassfish4/bin/asadmin deploy Panorama.war; ~/glassfish4/bin/asadmin stop-domain; ~/glassfish4/bin/asadmin start-domain"

# Austausch tnsnames.ora
scp ~/Library/oracle/instantclient/tnsnames.ora oracle@panorama.osp-dd.de:/opt/oracle/product/11gR1/db/network/admin

open "http://panorama.osp-dd.de:8080/Panorama"
