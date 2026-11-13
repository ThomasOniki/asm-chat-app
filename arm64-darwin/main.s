.section __TEXT,__text
.globl _start
_start:
	cmp x0, 2
	b.eq server
	cmp x0, 3
	b.ne usage

// client:

	ldp x19, x20, [x1, 8]

// socket(AF_INET, SOCK_STREAM, 0)
	mov w0, 2
	mov w1, 1
	mov w2, 0
	mov x16, 97
	svc 0x80

// get ip to w1
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

// little endian stuff
	lsl w4, w4, 24
	orr w1, w1, w4

	sub w2, w2, 1
	cbz w2, ip_end

	cmp w5, -2 // '.' - 0x30
	b.ne usage

	lsr w1, w1, 8
	b byte_start

ip_end:
	cmp w5, -0x30 // '\0' - 0x30
	b.ne usage

// get port to w2
	ldrb w5, [x20], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs usage
	mov w2, w5

	mov w4, 4

client_port_digit:
	ldrb w5, [x20], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs client_port_end
	mul w2, w2, w3
	add w2, w2, w5

	sub w4, w4, 1
	cbnz w4, client_port_digit

	ldrb w5, [x20], 1
	sub w5, w5, 0x30

client_port_end:
	cmp w5, -0x30
	b.ne usage
	mov w3, 1
	cmp w2, w3, lsl 16
	b.hs usage

	lsl w2, w2, 16
	movk w2, 2 // AF_INET
	stp w2, w1, [sp, -0x10]!
	str xzr, [sp, 0x8]

	mov w19, w0

// connect(sockfd, &sockaddr, socklen)
	mov x1, sp
	mov w2, 16
	mov x16, 98
	svc 0x80

	cbnz x0, connect_err

	b poll_loop

server:
	ldr x20, [x1, 8]
// socket(AF_INET, SOCK_STREAM, 0)
	mov w0, 2
	mov w1, 1
	mov w2, 0
	mov x16, 97
	svc 0x80

// get port to w2
	ldrb w5, [x20], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs usage
	mov w2, w5

	mov w3, 10
	mov w4, 4

server_port_digit:
	ldrb w5, [x20], 1
	sub w5, w5, 0x30
	cmp w5, 10
	b.hs server_port_end
	mul w2, w2, w3
	add w2, w2, w5

	sub w4, w4, 1
	cbnz w4, server_port_digit

	ldrb w5, [x20], 1
	sub w5, w5, 0x30

server_port_end:
	cmp w5, -0x30
	b.ne usage
	mov w3, 1
	cmp w2, w3, lsl 16
	b.hs usage

	mov w19, w0

	lsl x2, x2, 16
	movk x2, 2 // AF_INET
	stp x2, xzr, [sp, -0x10]!

// bind(sockfd, &sockaddr, socklen)
	mov x1, sp
	mov w2, 16
	mov x16, 104
	svc 0x80
	cbnz w0, bind_err

// listen(sockfd, backlog)
	mov w0, w19
	mov w1, 10
	mov x16, 106
	svc 0x80

// accept(sockfd, NULL, NULL)
	mov w0, w19
	mov x1, 0
	mov x2, 0
	mov x16, 30
	svc 0x80

	mov w19, w0

poll_loop:
	sub sp, sp, 0x110

	add x0, sp, 0x100
	mov w1, 1 // POLLIN
	stp w19, w1, [x0]
	stp wzr, w1, [x0, 8]

continue_poll:
// poll(fds, nfds, timeout)
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

	b continue_poll

read_sock:
// read(sockfd, sp, 0x100)
	mov w0, w19
	mov x1, sp
	mov x2, 0x100
	mov x16, 3
	svc 0x80

// write(1, sp, bytes_read)
	mov x1, sp
	mov x2, x0
	mov w0, 1
	mov x16, 4
	svc 0x80

	ldrh w0, [sp]
	cmp w0, 0x0a71 // "q\n"
	b.ne continue_poll

// exit(0)
	mov w0, 0 
	mov x16, 1
	svc 0x80

read_stdin:
// read(0, sp, 0x100)
	mov w0, 0
	mov x1, sp
	mov x2, 0x100
	mov x16, 3
	svc 0x80

// write(sockfd, sp, bytes_read)
	mov x1, sp
	mov x2, x0
	mov w0, w19
	mov x16, 4
	svc 0x80

	ldrh w0, [sp]
	cmp w0, 0x0a71 // "q\n"
	b.ne continue_poll

// exit(0)
	mov w0, 0
	mov x16, 1
	svc 0x80


connect_err:
	cmp w0, 61
	b.eq econrefused
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

econrefused:
	mov w0, 2
	adrp x1, econrefused_msg@page
	add x1, x1, econrefused_msg@pageoff
	mov x2, 91
	mov x16, 4
	svc 0x80
	mov w0, 1
	mov x16, 1
	svc 0x80

bind_err:
	cmp w0, 48
	b.eq eaddrinuse
	mov w19, w0
	mov w0, 2
	adrp x1, bind_err_msg@page
	add x1, x1, bind_err_msg@pageoff
	mov x2, 51
	mov x16, 4
	svc 0x80
	mov w0, w19
	mov x16, 1
	svc 0x80

eaddrinuse:
	mov w0, 2
	adrp x1, eaddrinuse_msg@page
	add x1, x1, eaddrinuse_msg@pageoff
	mov x2, 85
	mov x16, 4
	svc 0x80
	mov w0, 1
	mov x16, 1
	svc 0x80

usage:
	mov w0, 2
	adrp x1, usage_msg@page
	add x1, x1, usage_msg@pageoff
	mov x2, 58
	mov x16, 4
	svc 0x80
	mov w0, 1
	mov x16, 1
	svc 0x80

.section __TEXT,__const
connect_err_msg:
	.ascii "connect(2) failed, its error number will be returned.\n"
econrefused_msg:
	.ascii "connect(2) failed: ECONNREFUSED. Check that a host is running at the specified ip and port.\n"
bind_err_msg:
	.ascii "bind(2) failed, its error number will be returned.\n"
eaddrinuse_msg:
	.ascii "bind(2) failed: EADDRINUSE. Check that no other process is using the specified port.\n"
usage_msg:
	.ascii "host:\nasm-chat-app <port>\nguest:\nasm-chat-app <ip> <port>\n"
