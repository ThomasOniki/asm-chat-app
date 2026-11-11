.PHONY: build clean rebuild

build: server

clean:
	rm -rf obj server

rebuild: clean build

server: obj/server.o
	# MacOS ld doesn't support linking without libSystem, which is why lld is used.
	# If you link with an SDK version > 15.3 but not with libSystem, dyld will abort at runtime.
	ld64.lld -s -platform_version macos 27.2 15.3 -arch arm64 -e _start -o server obj/server.o

obj/server.o: obj server.s
	clang -march=native -o obj/server.o -c server.s

obj:
	mkdir obj

