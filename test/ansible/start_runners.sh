# Start available runners from systemctl start github_runners.service
# edit only at https://git.osp-dd.de/pramm/panorama_gem_ci/-/tree/master/ansible
# File will be overwritten by ansible-playbook if modified locally!

for file in `ls -d runner*`; do
  cd $file
  echo "Starting runner in directory $file"
  ./run.sh >>run.log 2>>err.log &
  cd ..
done

echo "script $0 remains running as service alias to keep the parent of run.sh alive"
while [[ 0 -eq 0 ]]; do
 sleep 1000
done
