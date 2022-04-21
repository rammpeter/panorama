# bundle update --source Panorama_Gem

# ensure all dependencies are refreshed now including Panorama_Gem
rm -f Gemfile.lock
bundle install
