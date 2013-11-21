if [ "$1" != "without_build" ] 
then
  ./build_war.sh $1 $2
fi

echo "transfer Panorama.war"
scp Panorama.war sbfapp@sbfappserver.ov.otto.de:/opt/panorama/Panorama.war.new

# Variante jetty
ssh sbfapp@sbfappserver.ov.otto.de "
  cd /opt/panorama 
  rm -f Panorama.war.old2 
  mv Panorama.war.old1 Panorama.war.old2 
  ./stop_Panorama_jetty.sh 
  mv Panorama.war Panorama.war.old1 
  mv Panorama.war.new Panorama.war 
  ./start_Panorama_jetty.sh
  cat /var/opt/panorama/Panorama_jetty.log
"


open "http://sbfappserver.ov.otto.de:8080/Panorama"
