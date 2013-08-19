
# Abgranzung von Rails 3.12 gegen Rails 4
export JRUBY_HOME=/Users/ramm/Library/jruby-1.7.2
export PATH=$JRUBY_HOME/bin:$PATH


if [ "$1" != "without_clean_cache" ]
then
  echo "Clean Cache"
  rm -r tmp/cache/assets/*
fi

if [ "$1" != "without_assets" ]
then
  echo "Compile assets"
  jruby -S rake assets:precompile
fi

echo "Create Panorama.war"
jruby -S warble

echo "Entfernen der assets unter public"
rm -r public/assets/*
