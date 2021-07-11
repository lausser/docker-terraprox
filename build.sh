set -ex
USERNAME=lausser
IMAGE=terraprox
docker build -t $USERNAME/$IMAGE:latest .
