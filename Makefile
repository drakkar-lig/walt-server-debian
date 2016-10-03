
all: server-install.tar.bz2

server-install.tar.bz2: server.dd archive/README.txt
	mkdir -p /tmp/server-install
	cp server.dd /tmp/server-install
	cp archive/README.txt /tmp/server-install
	tar -cj -f server-install.tar.bz2 -C /tmp server-install
	rm -rf /tmp/server-install

.date_files/server_image: create_server_image.sh build/rpi.uboot
	./create_server_image.sh && touch $@

build/rpi.uboot: rpi.uboot.txt
	./compile_rpi_uboot_script.sh

server.dd: .date_files/server_image create_server_dd.sh
	./create_server_dd.sh server.dd

server.dd.serial: .date_files/server_image create_server_dd.sh
	SERIAL=1 ./create_server_dd.sh server.dd.serial

test: server.dd.serial
	cp server.dd.serial /tmp/server.dd.test
	truncate -s 8G /tmp/server.dd.test
	rm -f /tmp/big.dd.test
	dd of=/tmp/big.dd.test bs=1G seek=100 count=0
	@echo test like this:
	@echo kvm -serial mon:stdio -hda /tmp/server.dd.test -hdb /tmp/big.dd.test -m 2048
