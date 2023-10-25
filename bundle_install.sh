# Ensure newest releases for dependencies are used 
# Different Java -versions are supported

rm Gemfile.lock
bundle install

bundle lock --add-platform universal-java-19
bundle lock --add-platform universal-java-21
