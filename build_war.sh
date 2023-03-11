if [ "$1" != "without_clean_cache" ]
then
  echo "Clean Cache"
  rm -r tmp/*
fi

echo "Entfernen der assets unter public"
rm -rf public/assets/*
rm -rf public/assets/.sprockets*

if [ "$1" != "without_assets" ]
then
  echo "Compile assets"
  rake assets:precompile
  if [ $? -ne 0 ]
  then
    echo "######### Error running rake assets:precompile"
    exit 1
  fi
fi

# NoMethodError: protected method `pathmap_replace' called for "public/404.html":String
# Fixen durch auskommentieren des protection-Flags für pathmap_replace in gems/rake-11.3.0/lib/rake/ext/string.rb

echo "Create Panorama.war"
# fix unavailable repo repo2.maven.org/
# export MAVEN_REPO=https://repo1.maven.org/maven2

# for debugging warbler use: java -Dwarbler.debug=true -jar Panorama.war

# Jetty version to use for warbler
# remove ~/.m2 if caching issues / file not found
export WEBSERVER_VERSION=9.4.49.v20220914
warble
if [ $? -ne 0 ]
then
  echo "######### Error creating war file"
  exit 1
fi


echo "Entfernen der assets unter public"
rm -r public/assets/*
rm -r public/assets/.sprockets*
