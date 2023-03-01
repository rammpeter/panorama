# Create github runner
# syntax: create_runner.sh <id> <token>

# edit only at https://git.osp-dd.de/pramm/panorama_gem_ci/-/tree/master/ansible
# File will be overwritten by ansible-playbook if modified locally!


ID=$1
TOKEN=$2
RELEASE=2.295.0
FILE=actions-runner-linux-x64-$RELEASE.tar.gz

mkdir runner$ID
cd runner$ID
curl -o $FILE -L https://github.com/actions/runner/releases/download/v$RELEASE/$FILE
tar xzf $FILE
rm $FILE
./config.sh --url https://github.com/rammpeter/Panorama_Gem --token $TOKEN --name runner${ID} --unattended

# ./run.sh should be started by systemctl
