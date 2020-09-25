
all: dev

dev: server-install-dev.dd.bz2

prod: server-install-prod.dd.bz2

prodtest: server-install-prodtest.dd

%.bz2: %
	bzip2 $<

.date_files/%.img: create_server_image.sh $(shell find repo_files -type f) $(shell find conf_files -type f)
	./create_server_image.sh $* && touch $@

server-install-%.dd: .date_files/%.img create_server_dd.sh
	./create_server_dd.sh $* server-install-$*.dd

server-install-%.dd.serial: .date_files/%.img create_server_dd.sh
	SERIAL=1 ./create_server_dd.sh $* server-install-$*.dd.serial

test: test-dev

test-%: server-install-%.dd.serial
	cp $< /tmp/server-install.dd.test
	truncate -s 8G /tmp/server-install.dd.test
	rm -f /tmp/big.dd.test
	dd of=/tmp/big.dd.test bs=1G seek=100 count=0
	@echo "test like this:"
	@echo -n "$$ kvm -serial mon:stdio -m 2048 -nographic -cpu host "
	@echo -n "-drive file=/tmp/server-install.dd.test,media=disk,index=0,format=raw "
	@echo -n "-drive file=/tmp/big.dd.test,media=disk,index=1,format=raw "
	@echo    "-netdev user,id=user0,hostfwd=::5556-:22 -device virtio-net,netdev=user0"
	@echo "and once the firstboot has completed (root password set):"
	@echo "$$ ssh -p 5556 root@localhost"

# do not remove intermediary files
.SECONDARY:
