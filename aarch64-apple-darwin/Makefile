.PHONY: build clean rebuild

build: asm-chat

clean:
	rm -rf obj asm-chat

rebuild: clean build

asm-chat: obj/main.o
	# MacOS ld doesn't support linking without libSystem, which is why lld is used.
	# If you link with an SDK version > 15.3 but not with libSystem, dyld will abort at runtime.
	ld64.lld -s -platform_version macos 27.2 15.3 -arch arm64 -e _start -o asm-chat obj/main.o

obj/main.o: obj main.s
	clang -o obj/main.o -c main.s

obj:
	mkdir obj

