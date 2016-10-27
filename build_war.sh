if [ "$1" != "without_clean_cache" ]
then
  echo "Clean Cache"
  rm -r tmp/cache/assets/*
fi

echo "Entfernen der assets unter public"
rm -rf public/assets/*
rm -rf public/assets/.sprockets*

if [ "$1" != "without_assets" ]
then
  echo "Compile assets"
  jruby -S rake assets:precompile
fi

# NoMethodError: protected method `pathmap_replace' called for "public/404.html":String
# Fixen durch auskommentieren des protection-Flags für pathmap_replace in gems/rake-11.3.0/lib/rake/ext/string.rb

echo "Create Panorama.war"
jruby -S warble 

echo "Entfernen der assets unter public"
rm -r public/assets/*
rm -r public/assets/.sprockets*
