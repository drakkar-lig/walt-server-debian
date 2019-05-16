
all: server-install.dd.bz2

server-install.dd.bz2: server-install.dd
	bzip2 server-install.dd

.date_files/server_image: create_server_image.sh docker.apt docker.gpg $(shell find conf_files -type f)
	./create_server_image.sh && touch $@

server-install.dd: .date_files/server_image create_server_dd.sh
	./create_server_dd.sh server-install.dd

server-install.dd.serial: .date_files/server_image create_server_dd.sh
	SERIAL=1 ./create_server_dd.sh server-install.dd.serial

test: server-install.dd.serial
	cp server-install.dd.serial /tmp/server-install.dd.test
	truncate -s 8G /tmp/server-install.dd.test
	rm -f /tmp/big.dd.test
	dd of=/tmp/big.dd.test bs=1G seek=100 count=0
	@echo test like this:
	@echo kvm -serial mon:stdio -hda /tmp/server-install.dd.test -hdb /tmp/big.dd.test -m 2048
