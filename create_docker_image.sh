# Deploy Panorama to Dockerhub.com and Dockerhub.osp-dd.de
# Peter Ramm, 21.09.2019

for FROM in `grep "^FROM" Dockerfile | grep -v scratch |  awk '{print $2}' | tail -n1`; do
  echo "Ensure using latest version of $FROM"
  docker pull $FROM
done

JRUBY_VERSION=`cat .ruby-version | cut -c 7-13`
echo JRUBY_VERSION=$JRUBY_VERSION

# Use "--progress=plain" to see the full console output
docker build --build-arg JRUBY_VERSION=$JRUBY_VERSION -t rammpeter/panorama .
RC=$?
if [ $RC -ne 0 ]
then
  echo "Error $RC during docker build, exit"
  exit $RC
fi




