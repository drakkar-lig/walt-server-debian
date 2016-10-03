#!/bin/bash
eval "$(docker run waltplatform/dev-master env)"
THIS_DIR=$(cd $(dirname $0); pwd)
DOCKER_CACHE_PRESERVE_DIR=$THIS_DIR/.docker_cache
TMP_DIR=$(mktemp -d)

cd $TMP_DIR

cat > sources.list << EOF
deb $DEBIAN_SERVER_REPO_URL $DEBIAN_SERVER_REPO_VERSION $DEBIAN_SERVER_REPO_SECTIONS
deb $DEBIAN_SERVER_REPO_URL $DEBIAN_SERVER_REPO_VERSION-backports main

deb http://security.debian.org/ jessie/updates main
deb http://ftp.ch.debian.org/debian/ jessie-updates main
EOF
docker-preserve-cache sources.list $DOCKER_CACHE_PRESERVE_DIR

cp -ar $THIS_DIR/conf_files files
mkdir -p files/var/lib/walt/boot
cp -ar $THIS_DIR/build/rpi.uboot files/var/lib/walt/boot/
for rpi_type in rpi-b rpi-b-plus rpi-2-b rpi-3-b
do
    ln -s rpi.uboot files/var/lib/walt/boot/${rpi_type}.uboot
done

BACKPORTS_PACKAGES=docker.io

PACKAGES=$(echo python-pip binfmt-support qemu-user-static \
		lldpd snmp snmpd sqlite3 gdisk linux-image-amd64 lvm2 \
		grub-pc isc-dhcp-client vim net-tools \
		keyboard-configuration openssh-server console-setup \
		ifupdown iputils-ping iputils-arping locales dialog \
		snmp-mibs-downloader snimpy isc-dhcp-server \
		nfs-kernel-server ntpdate ntp lockfile-progs \
		uuid-runtime postgresql python-psycopg2 \
        firmware-linux-nonfree ptpd tftpd)

APT_GET_INSTALL="DEBIAN_FRONTEND=noninteractive \
		apt-get install -y --no-install-recommends"

cat > Dockerfile << EOF
FROM debian:$DEBIAN_SERVER_REPO_VERSION
MAINTAINER $DOCKER_IMAGE_MAINTAINER

# update apt sources
ADD sources.list /etc/apt/sources.list

# install packages
RUN apt-get update && \
	$APT_GET_INSTALL $PACKAGES && \
	$APT_GET_INSTALL -t $DEBIAN_SERVER_REPO_VERSION-backports $BACKPORTS_PACKAGES && \
	apt-get clean 

# install python packages
RUN pip install --upgrade pip walt-server walt-client # server: 0.7-5; client: 0.6-1; common: 0.6-2

# the following is the same as running 'systemctl enable walt-server'
# on a system that is really running
RUN ln -s /etc/systemd/system/walt-server.service \
	/etc/systemd/system/multi-user.target.wants/walt-server.service
RUN ln -s /etc/systemd/system/walt-server-console.service \
	/etc/systemd/system/multi-user.target.wants/walt-server-console.service

# dhcpd should not start automatically
# (it is managed by walt-server-daemon)
RUN update-rc.d isc-dhcp-server disable

# copy static files 
ADD files /

# generate an ssh keypair
RUN ssh-keygen -q -t dsa -f /root/.ssh/id_dsa -N ''

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

