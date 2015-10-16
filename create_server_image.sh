#!/bin/bash
eval "$(docker run waltplatform/dev-master env)"
THIS_DIR=$(cd $(dirname $0); pwd)
DOCKER_CACHE_PRESERVE_DIR=$THIS_DIR/.docker_cache
TMP_DIR=$(mktemp -d)

cd $TMP_DIR

cat > sources.list << EOF
deb $DEBIAN_SERVER_REPO_URL $DEBIAN_SERVER_REPO_VERSION $DEBIAN_SERVER_REPO_SECTIONS
#deb $DEBIAN_SERVER_REPO_URL $DEBIAN_SERVER_REPO_VERSION-backports $DEBIAN_SERVER_REPO_SECTIONS
deb http://snapshot.debian.org/archive/debian/20150103T160317Z/ jessie main

deb http://security.debian.org/ jessie/updates main
deb http://ftp.ch.debian.org/debian/ jessie-updates main
EOF
docker-preserve-cache sources.list $DOCKER_CACHE_PRESERVE_DIR

cp -ar $THIS_DIR/conf_files conf_files

PACKAGES=$(echo python-pip docker.io binfmt-support qemu-user-static \
		lldpd snmp snmpd sqlite3 gdisk linux-image-amd64 lvm2 \
		grub-pc isc-dhcp-client vim net-tools \
		keyboard-configuration openssh-server console-setup \
		ifupdown iputils-ping iputils-arping locales dialog \
		snmp-mibs-downloader snimpy isc-dhcp-server \
		nfs-kernel-server ntpdate ntp lockfile-progs \
		uuid-runtime postgresql python-psycopg2)

APT_GET_INSTALL="DEBIAN_FRONTEND=noninteractive \
		apt-get install -y --no-install-recommends"

cat > Dockerfile << EOF
FROM debian:$DEBIAN_SERVER_REPO_VERSION
MAINTAINER $DOCKER_IMAGE_MAINTAINER

# update apt sources
ADD sources.list /etc/apt/sources.list

# we use an older docker version from snapshot.debian.org
# in order to be able to export container filesystem with
# nfs. Let apt ignore the older release date.
RUN echo 'Acquire::Check-Valid-Until "false";' > \
	/etc/apt/apt.conf.d/90walt-docker

# install packages
RUN apt-get update && \
	$APT_GET_INSTALL $PACKAGES && \
	apt-get clean 

# install python packages
RUN pip install --upgrade pip walt-server walt-client # 0.5

# the following is the same as running 'systemctl enable walt-server'
# on a system that is really running
RUN ln -s /etc/systemd/system/walt-server.service \
	/etc/systemd/system/multi-user.target.wants/walt-server.service
RUN ln -s /etc/systemd/system/walt-server-vt-switch.service \
	/etc/systemd/system/multi-user.target.wants/walt-server-vt-switch.service

# dhcpd should not start automatically
# (it is managed by walt-server-daemon)
RUN update-rc.d isc-dhcp-server disable

# copy static files 
ADD conf_files /

# generate an ssh keypair
RUN ssh-keygen -q -t dsa -f /root/.ssh/id_dsa -N ''

# generate and select an UTF-8 locale
RUN sed -i -e 's/# \\(en_US.UTF-8\\)/\\1/' /etc/locale.gen && \
        locale-gen && echo LANG=en_US.UTF-8 >> /etc/default/locale

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


