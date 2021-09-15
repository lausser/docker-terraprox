set -ex
USERNAME=lausser
IMAGE=terraprox
podman build -t $USERNAME/$IMAGE:latest .
