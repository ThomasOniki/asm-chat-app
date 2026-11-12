.section __TEXT,__text
.globl _start
_start:
	cmp x0, 3
	b.ne usage

	ldp x19, x20, [x1, 8]

; socket(AF_INET, SOCK_STREAM, 0)
	mov w0, 2
	mov w1, 1
	mov w2, 0
	mov x16, 97
	svc 0x80

; get ip to w1
	mov w1, 0
	mov w2, 4
	mov w3, 10

byte_start:
	ldrb w5, [x19], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs usage
	mov w4, w5

	ldrb w5, [x19], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs byte_end
	mul w4, w4, w3
	add w4, w4, w5

	ldrb w5, [x19], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs byte_end
	mul w4, w4, w3
	add w4, w4, w5

	ldrb w5, [x19], 1
	sub w5, w5, 0x30

byte_end:
	cmp w4, 256
	b.hs usage

; little endian stuff
	lsl w4, w4, 24
	orr w1, w1, w4

	sub w2, w2, 1
	cbz w2, ip_end

	cmp w5, -2 ; '.' - 0x30
	b.ne usage

	lsr w1, w1, 8
	b byte_start

ip_end:
	cmp w5, -0x30 ; '\0' - 0x30
	b.ne usage

; get port to w2
	ldrb w5, [x20], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs usage
	mov w2, w5

	mov w4, 4

digit:
	ldrb w5, [x20], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs port_end
	mul w2, w2, w3
	add w2, w2, w5

	sub w4, w4, 1
	cbnz w4, digit

	ldrb w5, [x20], 1
	sub w5, w5, 0x30

port_end:
	cmp w5, -0x30
	b.ne usage
	mov w3, 1
	cmp w2, w3, lsl 16
	b.hs usage

	lsl w2, w2, 16
	movk w2, 2 ; AF_INET
	stp w2, w1, [sp, -0x10]!
	str xzr, [sp, 0x8]

	mov w19, w0

; connect(sockfd, &sockaddr, socklen)
	mov x1, sp
	mov w2, 16
	connect:
	mov x16, 98
	svc 0x80

	cbnz x0, connect_err

	sub sp, sp, 0x110

	add x0, sp, 0x100
	mov w1, 1 ; POLLIN
	stp w19, w1, [x0]
	stp wzr, w1, [x0, 8]

loop:
; poll(fds, nfds, timeout)
	add x0, sp, 0x100
	mov w1, 2
	mov w2, 0
	mov x16, 230
	svc 0x80

	ldrh w0, [sp, 0x106]
  cmp w0, 1
	b.eq read_sock
	ldrh w0, [sp, 0x10e]
  cmp w0, 1
	b.eq read_stdin

	b loop

read_sock:
; read(sockfd, sp, 0x100)
	mov w0, w19
	mov x1, sp
	mov x2, 0x100
	mov x16, 3
	svc 0x80

; write(1, sp, bytes_read)
	mov x1, sp
	mov x2, x0
	mov w0, 1
	mov x16, 4
	svc 0x80

	ldrh w0, [sp]
	cmp w0, 0x0a71 ; "q\n"
	b.ne loop

; exit(0)
	mov w0, 0 
	mov x16, 1
	svc 0x80

read_stdin:
; read(0, sp, 0x100)
	mov w0, 0
	mov x1, sp
	mov x2, 0x100
	mov x16, 3
	svc 0x80

; write(sockfd, sp, bytes_read)
	mov x1, sp
	mov x2, x0
	mov w0, w19
	mov x16, 4
	svc 0x80

	ldrh w0, [sp]
	cmp w0, 0x0a71 ; "q\n"
	b.ne loop

; exit(0)
	mov w0, 0
	mov x16, 1
	svc 0x80

connect_err:
	mov w19, w0
	mov w0, 2
	adrp x1, connect_err_msg@page
	add x1, x1, connect_err_msg@pageoff
	mov x2, 54
	mov x16, 4
	svc 0x80
	mov w0, w19
	mov x16, 1
	svc 0x80

usage:
	mov w0, 2
	adrp x1, usage_msg@page
	add x1, x1, usage_msg@pageoff
	mov x2, 26
	mov x16, 4
	svc 0x80
	mov w0, 1
	mov x16, 1
	svc 0x80

.p2align 2
log1:
sub sp, sp, 0x100
stp  x0,  x1, [sp, 0x000]
stp  x2,  x3, [sp, 0x010]
stp  x4,  x5, [sp, 0x020]
stp  x6,  x7, [sp, 0x030]
stp  x8,  x9, [sp, 0x040]
stp x10, x11, [sp, 0x050]
stp x12, x13, [sp, 0x060]
stp x14, x15, [sp, 0x070]
stp x16, x17, [sp, 0x080]
stp x18, x19, [sp, 0x090]
stp x20, x21, [sp, 0x100]
stp x22, x23, [sp, 0x110]
stp x24, x25, [sp, 0x120]
stp x26, x27, [sp, 0x130]
stp x28, x29, [sp, 0x140]
stp x30, x31, [sp, 0x150]
mov w0, 1
adr x1, msg
mov x2, 5
mov x16, 4
svc 0x80
ldp  x0,  x1, [sp, 0x000]
ldp  x2,  x3, [sp, 0x010]
ldp  x4,  x5, [sp, 0x020]
ldp  x6,  x7, [sp, 0x030]
ldp  x8,  x9, [sp, 0x040]
ldp x10, x11, [sp, 0x050]
ldp x12, x13, [sp, 0x060]
ldp x14, x15, [sp, 0x070]
ldp x16, x17, [sp, 0x080]
ldp x18, x19, [sp, 0x090]
ldp x20, x21, [sp, 0x100]
ldp x22, x23, [sp, 0x110]
ldp x24, x25, [sp, 0x120]
ldp x26, x27, [sp, 0x130]
ldp x28, x29, [sp, 0x140]
ldp x30, x31, [sp, 0x150]
add sp, sp, 0x100
ret
msg:
	.ascii "log1\n"

.p2align 2
log2:
sub sp, sp, 0x100
stp  x0,  x1, [sp, 0x000]
stp  x2,  x3, [sp, 0x010]
stp  x4,  x5, [sp, 0x020]
stp  x6,  x7, [sp, 0x030]
stp  x8,  x9, [sp, 0x040]
stp x10, x11, [sp, 0x050]
stp x12, x13, [sp, 0x060]
stp x14, x15, [sp, 0x070]
stp x16, x17, [sp, 0x080]
stp x18, x19, [sp, 0x090]
stp x20, x21, [sp, 0x100]
stp x22, x23, [sp, 0x110]
stp x24, x25, [sp, 0x120]
stp x26, x27, [sp, 0x130]
stp x28, x29, [sp, 0x140]
stp x30, x31, [sp, 0x150]
mov w0, 1
adr x1, msg2
mov x2, 5
mov x16, 4
svc 0x80
ldp  x0,  x1, [sp, 0x000]
ldp  x2,  x3, [sp, 0x010]
ldp  x4,  x5, [sp, 0x020]
ldp  x6,  x7, [sp, 0x030]
ldp  x8,  x9, [sp, 0x040]
ldp x10, x11, [sp, 0x050]
ldp x12, x13, [sp, 0x060]
ldp x14, x15, [sp, 0x070]
ldp x16, x17, [sp, 0x080]
ldp x18, x19, [sp, 0x090]
ldp x20, x21, [sp, 0x100]
ldp x22, x23, [sp, 0x110]
ldp x24, x25, [sp, 0x120]
ldp x26, x27, [sp, 0x130]
ldp x28, x29, [sp, 0x140]
ldp x30, x31, [sp, 0x150]
add sp, sp, 0x100
ret
msg2:
	.ascii "log2\n"

.section __TEXT,__const
connect_err_msg:
	.ascii "connect(2) failed, its error number will be returned.\n"
usage_msg:
	.ascii "usage: client <ip> <port>\n"
