#!/bin/bash
eval "$(docker run waltplatform/dev-master env)"
MODE=$1
EXPECTED_WALT_VERSION=6
THIS_DIR=$(cd $(dirname $0); pwd)
DOCKER_CACHE_PRESERVE_DIR=$THIS_DIR/.docker_cache
TMP_DIR=$(mktemp -d)

cd $TMP_DIR

cp -ar $THIS_DIR/conf_files files
cp -ar $THIS_DIR/repo_files repo_files

DEBOOTSTICK_PACKAGES="gdisk lvm2 linux-image-amd64 init grub-pc"
OTHER_OS_PACKAGES=$(echo apt-transport-https ca-certificates gnupg2 \
        curl gnupg-agent software-properties-common isc-dhcp-client \
        vim net-tools keyboard-configuration console-setup \
        iputils-arping locales dialog "*microcode*")
WALT_DEPENDENCIES_PACKAGES=$(echo binfmt-support qemu-user-static \
        lldpd snmp snmpd openssh-server snmp-mibs-downloader iputils-ping \
        libsmi2-dev isc-dhcp-server nfs-kernel-server uuid-runtime postgresql \
        ntpdate ntp lockfile-progs ptpd tftpd-hpa ebtables qemu-kvm bridge-utils \
        screen ifupdown)
PIP_DEPENDENCIES_PACKAGES="gcc python3-dev"
WALT_DEV_PACKAGES="git make sudo expect netcat"
CONTAINER_PACKAGES="docker-ce docker-ce-cli containerd.io podman buildah skopeo"

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
                  cd walt-python-packages && git checkout -b dev origin/dev && make install"
    MANY_PACKAGES="$MANY_PACKAGES $WALT_DEV_PACKAGES"
fi

cat > Dockerfile << EOF
FROM debian:buster
MAINTAINER $DOCKER_IMAGE_MAINTAINER

# get docker GPG key and apt conf
# not enabled yet because extension is not ".list".
# we need to have apt-transport-https installed first.
ADD repo_files /etc/apt/sources.list.d/

# install packages
RUN sed -i -e 's/main/main contrib non-free/g' /etc/apt/sources.list && \
    apt-get update && \
	$APT_GET_INSTALL $MANY_PACKAGES && \
    cat /etc/apt/sources.list.d/docker.gpg | apt-key add - >/dev/null 2>&1 && \
    cat /etc/apt/sources.list.d/libcontainers.gpg | apt-key add - >/dev/null 2>&1 && \
    mv /etc/apt/sources.list.d/docker.apt /etc/apt/sources.list.d/docker.list && \
    mv /etc/apt/sources.list.d/libcontainers.apt /etc/apt/sources.list.d/libcontainers.list && \
    apt-get update && \
    $APT_GET_INSTALL $CONTAINER_PACKAGES && \
	apt-get clean && rm -f /etc/apt/sources.list.d/*.gpg

# install python packages
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py && \
    $WALT_INSTALL

# copy static files 
ADD files /

# install services
RUN walt-server-setup && walt-virtual-setup --type SERVER --init-system SYSTEMD

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

