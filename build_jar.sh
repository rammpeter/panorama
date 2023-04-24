if [ "$1" != "without_clean_cache" ]
then
  echo "Clean Cache"
  rm -rf tmp/*
fi

echo "Remove the assets at public"
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

echo "Create Panorama.jar"
jarble
if [ $? -ne 0 ]
then
  echo "######### Error creating jar file"
  exit 1
fi

echo "Entfernen der assets unter public"
rm -r public/assets/*
rm -r public/assets/.sprockets*
