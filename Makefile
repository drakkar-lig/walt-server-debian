
all: server.dd

.date_files/server_image: create_server_image.sh
	./create_server_image.sh && touch $@

server.dd: .date_files/server_image create_server_dd.sh
	./create_server_dd.sh server.dd

test: server.dd
	test_dd=/tmp/server.dd.$$$$; \
	cp server.dd $$test_dd; \
	truncate -s 8G $$test_dd; \
	#kvm -nographic -serial mon:stdio -hda $$test_dd -m 2048; \
	#rm $$test_dd
