AS = as
ASFLAGS =
LDFLAGS =
STRIP = strip
kernel = $(shell uname -s | tr A-Z a-z)
arch = $(shell uname -m)
platform = $(arch)-$(kernel)

ifeq ($(kernel), darwin)
lld_path = $(shell command -v ld64.lld)
ifeq ($(lld_path),)
nolld = 1
sysroot = $(shell xcrun --show-sdk-path)
LD = /usr/bin/ld
REQUIRED_LDFLAGS = -arch $(arch) -e _start -syslibroot $(sysroot) -lSystem
else
LD = $(lld_path)
REQUIRED_LDFLAGS = -arch $(arch) -e _start -platform_version macos 27.2 15.3 
endif
else
LD := ld
REQUIRED_LDFLAGS =
endif

.PHONY: build clean rebuild

build: asm-chat-app

clean:
	rm -rf obj/ asm-chat-app

rebuild: clean build

asm-chat-app: obj/main.o
ifeq ($(nolld),1)
	@echo "WARNING: If you don't want to link with libSystem, ensure that lld is installed and ld64.lld is in PATH."
endif
	$(LD) $(REQUIRED_LDFLAGS) $(LDFLAGS) -o $@ $^
	$(STRIP) $@

obj/main.o: $(platform)/main.s obj
	$(AS) $(ASFLAGS) -o $@ -c $<

obj:
	mkdir $@
