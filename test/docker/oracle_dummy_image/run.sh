# run until SIGTERM

echo "`date` Starting docker container with no function"
while [ true ]; do
  sleep 1
done

trap finish TERM
trap finish INT

function finish {
  echo "`date` Stopped docker container with no function"
  sleep 3
}
