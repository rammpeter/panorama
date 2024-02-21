# Create github runner
# syntax: create_runner.sh <id> <token>

# edit only at test/ansible
# File will be overwritten by ansible-playbook if modified locally!


ID=$1
TOKEN=$2
RELEASE=2.313.0
FILE=actions-runner-linux-x64-$RELEASE.tar.gz

mkdir runner$ID
cd runner$ID
curl -o $FILE -L https://github.com/actions/runner/releases/download/v$RELEASE/$FILE
tar xzf $FILE
rm $FILE
./config.sh --url https://github.com/rammpeter/Panorama --token $TOKEN --name runner${ID} --unattended

# ./run.sh should be started by systemctl
