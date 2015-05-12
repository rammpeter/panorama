export PANORAMA_HOME=$PWD
export HTTP_PORT=8090
export PANORAMA_USAGE_LOG=$PANORAMA_HOME/Usage.log
export LOG=$PANORAMA_HOME/Panorama.log
echo "Starting Panorama, logfile is $LOG"

# Entfernen evtl. aller work-Relikte
rm -rf ./work/*

# -Xcompile.invokedynamic=true sichert für Java7, dass folgender Fehler eliminiert wird: java.lang.ClassNotFoundException: org.jruby.ext.krypt.asn1.RubyAsn1
# -Djruby.compile.invokedynamic=true statt -Xcompile.invokedynamic=true da dies für IBM-JRE 7 nicht erlaubt ist
# -XX:MaxPermSize=512M ab Java 8 nicht mehr relevant

# Variante fuer Jetty
#java -Xmx1024m -XX:MaxPermSize=512M -XX:+CMSClassUnloadingEnabled -XX:+CMSPermGenSweepingEnabled -Djruby.compile.invokedynamic=true -Djetty.port=8090 -Djetty.requestHeaderSize=8192 -Djava.io.tmpdir=./work -jar $PANORAMA_HOME/Panorama.war 2>&1 | tee -a $LOG 

# Variante fuer Winstone
java -Xmx1024m -XX:+CMSClassUnloadingEnabled -XX:+CMSPermGenSweepingEnabled -Djruby.compile.invokedynamic=true -Djava.io.tmpdir=./work -jar $PANORAMA_HOME/Panorama.war --httpPort=$HTTP_PORT 2>&1 | tee -a $LOG 

