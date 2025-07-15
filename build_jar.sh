if [ "$1" != "without_clean_cache" ]
then
  echo "Clean Cache and logs"
  rm -rf tmp/*
  rm -rf log/*
fi

echo "Remove the assets at public"
rm -rf public/assets/*
rm -rf public/assets/.sprockets*
# Remove mini profile files
find . -name mp_views* -exec rm -f {} \;

# Use the Gemfile.lock as it is and don't update the gems
bundle config set deployment 'true'

# Ensures that after no test or development dependecies are initialized at 'bundle exec rake assets:precompile'
export RAILS_ENV=production

# Avoid installing the gems in the development and test group and omit them in the jar
# Does the same like  export BUNDLE_WITHOUT="development:test"
bundle config set without 'development:test'

bundle install --jobs 4
gem install jarbler

if [ "$1" != "without_assets" ]
then
  echo "Compile assets"
  bundle exec rake assets:precompile
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
JARBLE_RC=$?

# reset previous state
bundle config unset deployment
bundle config unset without

if [ $JARBLE_RC -ne 0 ]
then
  echo "######### Error creating jar file"
  exit 1
fi

echo "Entfernen der assets unter public"
rm -r public/assets/*
rm -r public/assets/.sprockets*
