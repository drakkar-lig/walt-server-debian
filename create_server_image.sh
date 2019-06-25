#!/bin/bash
eval "$(docker run waltplatform/dev-master env)"
THIS_DIR=$(cd $(dirname $0); pwd)
DOCKER_CACHE_PRESERVE_DIR=$THIS_DIR/.docker_cache
TMP_DIR=$(mktemp -d)

cd $TMP_DIR

cp -ar $THIS_DIR/conf_files files
cp -a $THIS_DIR/docker.gpg $THIS_DIR/docker.apt .

PACKAGES=$(echo apt-transport-https ca-certificates gnupg2 \
        curl software-properties-common gcc python-dev \
        binfmt-support qemu-user-static \
		lldpd snmp snmpd sqlite3 gdisk linux-image-amd64 lvm2 \
		grub-pc isc-dhcp-client vim net-tools \
		keyboard-configuration openssh-server console-setup \
		ifupdown iputils-ping iputils-arping locales dialog \
		snmp-mibs-downloader libsmi-dev isc-dhcp-server \
		nfs-kernel-server ntpdate ntp lockfile-progs \
		uuid-runtime postgresql python-psycopg2 \
        firmware-linux-nonfree ptpd tftpd-hpa ebtables kvm \
        bridge-utils screen linux-headers-amd64 aufs-dkms)

APT_GET_INSTALL="DEBIAN_FRONTEND=noninteractive \
		apt-get install -y --no-install-recommends"

cat > Dockerfile << EOF
FROM debian:stretch
MAINTAINER $DOCKER_IMAGE_MAINTAINER

# get docker GPG key and apt conf
# not enabled yet because extension is not ".list".
# we need to have apt-transport-https installed first.
ADD docker.gpg docker.apt /etc/apt/sources.list.d/

# install packages
RUN sed -i -e 's/main/main non-free/g' /etc/apt/sources.list && \
    apt-get update && \
	$APT_GET_INSTALL $PACKAGES && \
    cat /etc/apt/sources.list.d/docker.gpg | apt-key add - >/dev/null 2>&1 && \
    mv /etc/apt/sources.list.d/docker.apt /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    $APT_GET_INSTALL docker-engine && \
	apt-get clean && rm -f /etc/apt/sources.list.d/docker.gpg

# reinstall aufs to allow NFS export
RUN sed -i -e "s/CONFIG_AUFS_EXPORT =.*/CONFIG_AUFS_EXPORT = y/g" /usr/src/aufs-4.9+20161219/config.mk
RUN sed -i -e "s/CONFIG_AUFS_INO_T_64 =.*/CONFIG_AUFS_INO_T_64 = y/g" /usr/src/aufs-4.9+20161219/config.mk
RUN dkms uninstall aufs/4.9+20161219 -k 4.9.0-8-amd64 && \
    dkms remove aufs/4.9+20161219 -k 4.9.0-8-amd64 && \
    dkms build aufs/4.9+20161219 -k 4.9.0-8-amd64 && \
    dkms install aufs/4.9+20161219 -k 4.9.0-8-amd64

# install python packages
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python get-pip.py && \
    pip install walt-server walt-client

# copy static files 
ADD files /

# install services
RUN walt-server-setup

# generate and select an UTF-8 locale
RUN sed -i -e 's/# \\(en_US.UTF-8\\)/\\1/' /etc/locale.gen && \
        locale-gen && echo LANG=en_US.UTF-8 >> /etc/default/locale

# Increase the console font size
RUN sed -i -e 's/\\(FONTSIZE\\)=.*$/\\1=12x24/' /etc/default/console-setup

# re-enable service startup
# (docker containers are not expected to start services,
# thus they are disabled on docker official images.
# But since we will convert this into a real system,
# we re-enable this)
RUN rm /usr/sbin/policy-rc.d
RUN dpkg-divert --remove /sbin/initctl
EOF
docker build -t "$DOCKER_SERVER_IMAGE" .
result=$?

rm -rf $TMP_DIR

exit $result

