#!/bin/bash
MODE=$1
EXPECTED_WALT_VERSION=7
THIS_DIR=$(cd $(dirname $0); pwd)
DOCKER_CACHE_PRESERVE_DIR=$THIS_DIR/.docker_cache
TMP_DIR=$(mktemp -d)

cd $TMP_DIR

cp -ar $THIS_DIR/conf_files conf_files

DEBOOTSTICK_PACKAGES="gdisk lvm2 linux-image-amd64 init grub-pc"
OTHER_OS_PACKAGES=$(echo python3 isc-dhcp-client vim \
        net-tools keyboard-configuration console-setup iputils-arping \
        locales dialog curl "*microcode*")
PIP_DEPENDENCIES_PACKAGES="gcc python3-dev libsmi2-dev"
WALT_DEPENDENCIES_PACKAGES="python3-apt gpg"
WALT_DEV_PACKAGES="git make sudo expect netcat"

GET_FIRMWARE_PACKAGES="""\
apt-cache search --names-only 'firmware-.*' | awk '{print \$1}' | \
                    grep -v 'microbit' | \
                    grep -v firmware-ipw2x00 | \
                    grep -v firmware-ivtv \
"""

APT_GET_INSTALL="DEBIAN_FRONTEND=noninteractive \
		apt-get install -y --upgrade --no-install-recommends"

MANY_PACKAGES="$WALT_DEPENDENCIES_PACKAGES $DEBOOTSTICK_PACKAGES $OTHER_OS_PACKAGES"
MANY_PACKAGES="$MANY_PACKAGES $PIP_DEPENDENCIES_PACKAGES \$($GET_FIRMWARE_PACKAGES)"
if [ "$MODE" = "prod" ]
then
    WALT_INSTALL="pip3 install walt-server==$EXPECTED_WALT_VERSION \
                               walt-client==$EXPECTED_WALT_VERSION"
elif [ "$MODE" = "prodtest" ]
then
    WALT_INSTALL="pip3 install --index-url https://test.pypi.org/simple/         \
                         --extra-index-url https://pypi.org/simple \
                            walt-server==$EXPECTED_WALT_VERSION \
                            walt-client==$EXPECTED_WALT_VERSION"
else
    WALT_INSTALL="cd /root && git clone https://github.com/drakkar-lig/walt-python-packages && \
                  cd walt-python-packages && git checkout  -b etienne-dev origin/etienne-dev && make install"
    MANY_PACKAGES="$MANY_PACKAGES $WALT_DEV_PACKAGES"
fi

cat > Dockerfile << EOF
FROM debian:bullseye
LABEL author="etienne.duble@imag.fr"

# install packages
RUN sed -i -e 's/main/main contrib non-free/g' /etc/apt/sources.list && \
    apt-get update && \
	$APT_GET_INSTALL $MANY_PACKAGES && \
	apt-get clean

# install python packages
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py && \
    $WALT_INSTALL

# copy static conf files 
ADD conf_files /

# setup walt software
RUN walt-server-setup --mode image-install

# generate and select an UTF-8 locale
RUN sed -i -e 's/# \\(en_US.UTF-8\\)/\\1/' /etc/locale.gen && \
        locale-gen && echo LANG=en_US.UTF-8 >> /etc/default/locale

# re-enable service startup
# (docker containers are not expected to start services,
# thus they are disabled on docker official images.
# But since we will convert this into a real system,
# we re-enable this)
RUN rm /usr/sbin/policy-rc.d
EOF
docker build -t "waltplatform/server-$MODE" .
result=$?

rm -rf $TMP_DIR

exit $result

