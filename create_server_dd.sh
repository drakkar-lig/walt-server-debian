#!/bin/bash
if [ $(id -u) -ne 0 ]; then
    # this should be run as root
    exec sudo "$0" "$@"
fi

eval "$(docker run waltplatform/dev-master env)"
THIS_DIR=$(cd $(dirname $0); pwd)
CONTAINER_DIR=$(mktemp -d)

image_path="$1"

# export the filesystem of the image
# (we need an intermediate container for this)
docker run --name tmpcontainer_$$ $DOCKER_SERVER_IMAGE true
cd $CONTAINER_DIR
docker export tmpcontainer_$$ | tar xf -
docker rm tmpcontainer_$$   # not needed anymore

# docker images have an empty hosts file
# (the one from the host is bind-mounted)
# let's restore an appropriate one
cat > etc/hosts << EOF
127.0.0.1	localhost
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters
EOF

# call debootstick
cd "$THIS_DIR"
debootstick --config-grub-on-serial-line "$CONTAINER_DIR" "$image_path"

