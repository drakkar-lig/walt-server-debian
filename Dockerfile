FROM debian:wheezy
MAINTAINER Etienne Duble <etienne.duble@imag.fr>

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y python3-pip nfs-kernel-server nfs-common isc-dhcp-server \
                        snmp sqlite3 lldpd
RUN ln -s $(dpkg-query -L python3-pip | grep 'bin/pip') /usr/bin/pip3
RUN pip3 install pyzmq u-msgpack-python

