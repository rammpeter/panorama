# Build new war file from template 
# Ensure gems are installed localy in vendor/bundle: bundle config path 'vendor/bundle' --local

echo "Build new war file from template"

BUILD_DIR=tmp/war_build
JRUBY_VERSION=`cat .ruby-version | grep "jruby" | cut -c 7-20`
JRUBY_RACK_VERSION=`cat Gemfile.lock | grep jruby-rack | grep "(" | cut -d"(" -f2-2 | cut -d ")" -f 1-1`

echo "JRUBY_VERSION      = $JRUBY_VERSION"
echo "JRUBY_RACK_VERSION = $JRUBY_RACK_VERSION"

mkdir -p $BUILD_DIR
rm -rf $BUILD_DIR/*
rm -rf $BUILD_DIR/.*

rm -f $BUILD_DIR/Panorama.war
cp -f Panorama_Template.war $BUILD_DIR/Panorama.war
cd $BUILD_DIR
unzip Panorama.war

rm Panorama.war
rm -rf WEB-INF/app
rm -rf WEB-INF/config
rm -rf WEB-INF/lib

echo "Replace content"

cp ../../Gemfile WEB-INF/
cp ../../Gemfile.lock WEB-INF/
cp ../../jetty-runner-9.4.49.v20220914.jar WEB-INF/webserver.jar
cp -r ../../config WEB-INF/
cp -r ../../app WEB-INF/
cp -r ../../lib WEB-INF/
cp -r ../../vendor/bundle/jruby/3.1.0/* WEB-INF/gems
cp ../../vendor/bundle/jruby/3.1.0/gems/jruby-jars-${JRUBY_VERSION}/lib/jruby-core-${JRUBY_VERSION}-complete.jar WEB-INF/lib/
cp ../../vendor/bundle/jruby/3.1.0/gems/jruby-jars-${JRUBY_VERSION}/lib/jruby-stdlib-${JRUBY_VERSION}.jar WEB-INF/lib/
cp ../../vendor/bundle/jruby/3.1.0/gems/jruby-rack-${JRUBY_RACK_VERSION}/lib/jruby-rack-${JRUBY_RACK_VERSION}.jar WEB-INF/lib/

echo "ENV['GEM_PATH']=File.expand_path(File.join('..', '..', '/WEB-INF/gems'), __FILE__)" >> META-INF/init.rb

zip -r Panorama.war *


