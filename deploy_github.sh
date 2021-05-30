# Deploy a github release for Panorama

# Check if repository is up to date
git status | grep "nothing to commit, working tree clean"
if [ $? -ne 0 ]; then
  echo "Github repository is not up to date! Commit and push first."
  git status
  exit 1
fi

# Update Github command line tool
brew upgrade gh

# Panorama-Version
PANORAMA_VERSION=`grep "panorama_gem (" Gemfile.lock | sed 's/    panorama_gem (//' | sed 's/)//'`
echo "Panorama version = $PANORAMA_VERSION"

gh release create v$PANORAMA_VERSION './Panorama.war#war-file to start with java -jar Panorama.war' --notes "Continuous development" --title "Release $PANORAMA_VERSION"
if [ $? -ne 0 ]; then
  echo "Returncode != 0 for gh command"
fi


