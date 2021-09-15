set -ex
USERNAME=lausser
IMAGE=terraprox
git pull
# bump version
podman run --rm -v "$PWD":/app treeder/bump patch
version=`cat VERSION`
echo "version: $version"
# run build
./build.sh
# tag it
git add -A
git commit -m "version $version"
git tag -a "$version" -m "version $version"
git push
git push --tags
podman tag $USERNAME/$IMAGE:latest $USERNAME/$IMAGE:$version
# push it
podman push $USERNAME/$IMAGE:latest
podman push $USERNAME/$IMAGE:$version
