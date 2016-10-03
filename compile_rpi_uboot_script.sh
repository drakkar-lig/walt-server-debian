#!/bin/bash
eval "$(docker run waltplatform/dev-master env)"
THIS_DIR=$(cd $(dirname $0); pwd)
TMP_DIR=$(mktemp -d)

cleanup()
{
    rm -rf $TMP_DIR
}

trap cleanup EXIT
set -e

cd "$THIS_DIR"
cp -rp rpi.uboot.txt $TMP_DIR

cd $TMP_DIR

cat > Dockerfile << EOF
FROM $DOCKER_RPI_BUILDER_IMAGE
MAINTAINER $DOCKER_IMAGE_MAINTAINER

# Download and extract u-Boot source in /opt/u-boot
RUN $INSTALL_UBOOT_SOURCE
WORKDIR /opt/u-boot

# create /bin/uboot-mkimage
RUN make rpi_defconfig && \
    make tools && \
    cp tools/mkimage /bin/uboot-mkimage && \
    make clean

# create u-boot startup script
ADD rpi.uboot.txt /tmp
RUN mkdir /out && \
    /bin/uboot-mkimage -A arm -O linux -T script -C none -n rpi-boot.scr \
         -d /tmp/rpi.uboot.txt /out/rpi.uboot

WORKDIR /out
EOF
docker build -t "rpi-boot-script-compiler" .

mkdir -p "$THIS_DIR/build"
docker run --rm rpi-boot-script-compiler cat rpi.uboot > "$THIS_DIR/build/rpi.uboot"

