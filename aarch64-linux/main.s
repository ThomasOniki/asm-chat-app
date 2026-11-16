SYS_socket = 198
SYS_connect = 203
SYS_bind = 200
SYS_listen = 201
SYS_accept = 202
SYS_ppoll = 73
SYS_read = 63
SYS_write = 64
SYS_exit = 93

AF_INET = 2
SOCK_STREAM = 1
POLLIN = 1

ECONNREFUSED = 111
EADDRINUSE = 98

BUF_SIZE = 256

.text
.globl _start
_start:
	ldr w0, [sp]
	cmp w0, 2
	b.eq server
	cmp w0, 3
	b.ne usage

// client:

	ldp x19, x20, [sp, 16]

	mov w0, AF_INET
	mov w1, SOCK_STREAM
	mov w2, 0
	mov x8, SYS_socket
	svc 0

// get ip to w1
	mov w1, 0
	mov w2, 4
	mov w3, 10

byte_start:
	ldrb w5, [x19], 1
	sub w5, w5, '0'
	cmp w5, 10
	b.hs usage
	mov w4, w5

	ldrb w5, [x19], 1
	sub w5, w5, '0'
	cmp w5, 10
	b.hs byte_end
	mul w4, w4, w3
	add w4, w4, w5

	ldrb w5, [x19], 1
	sub w5, w5, '0'
	cmp w5, 10
	b.hs byte_end
	mul w4, w4, w3
	add w4, w4, w5

	ldrb w5, [x19], 1
	sub w5, w5, '0'

byte_end:
	cmp w4, 256
	b.hs usage

// little endian stuff
	lsl w4, w4, 24
	orr w1, w1, w4

	sub w2, w2, 1
	cbz w2, ip_end

	cmp w5, '.' - '0'
	b.ne usage

	lsr w1, w1, 8
	b byte_start

ip_end:
	cmp w5, 0 - '0'
	b.ne usage

// get port to w2
	ldrb w5, [x20], 1
	sub w5, w5, '0'
	cmp w5, 10
	b.hs usage
	mov w2, w5

	mov w4, 4

client_port_digit:
	ldrb w5, [x20], 1
	sub w5, w5, '0'
	cmp w5, 10
	b.hs client_port_end
	mul w2, w2, w3
	add w2, w2, w5

	sub w4, w4, 1
	cbnz w4, client_port_digit

	ldrb w5, [x20], 1
	sub w5, w5, '0'

client_port_end:
	cmp w5, - '0'
	b.ne usage
	mov w3, 1
	cmp w2, w3, lsl 16
	b.hs usage

	lsl w2, w2, 16
	movk w2, AF_INET
	stp w2, w1, [sp, -16]!
	str xzr, [sp, 8]

	mov w19, w0

	mov x1, sp
	mov w2, 16
	mov x8, SYS_connect
	svc 0

	cbnz w0, connect_err

	b poll_loop

server:
	ldr x20, [sp, 16]
	mov w0, AF_INET
	mov w1, 1
	mov w2, 0
	mov x8, SYS_socket
	svc 0

// get port to w2
	ldrb w5, [x20], 1
	sub w5, w5, '0'
	cmp w5, 10
	b.hs usage
	mov w2, w5

	mov w3, 10
	mov w4, 4

server_port_digit:
	ldrb w5, [x20], 1
	sub w5, w5, '0'
	cmp w5, 10
	b.hs server_port_end
	mul w2, w2, w3
	add w2, w2, w5

	sub w4, w4, 1
	cbnz w4, server_port_digit

	ldrb w5, [x20], 1
	sub w5, w5, '0'

server_port_end:
	cmp w5, -'0'
	b.ne usage
	mov w3, 1
	cmp w2, w3, lsl 16
	b.hs usage

	mov w19, w0

	lsl x2, x2, 16
	movk x2, AF_INET
	stp x2, xzr, [sp, -16]!

	mov x1, sp
	mov w2, 16
	mov x8, SYS_bind
	svc 0
	cbnz w0, bind_err

	mov w0, w19
	mov w1, 10
	mov x8, SYS_listen
	svc 0

	mov w0, w19
	mov x1, 0
	mov x2, 0
	mov x8, SYS_accept
	svc 0

	mov w19, w0

poll_loop:
	sub sp, sp, BUF_SIZE + 16

	add x0, sp, BUF_SIZE
	mov w1, POLLIN
	stp w19, w1, [x0]
	stp wzr, w1, [x0, 8]

continue_poll:
	add x0, sp, BUF_SIZE
	mov w1, 2
	mov x2, 0
	mov x3, 0
	mov x8, SYS_ppoll
	svc 0

	ldrh w0, [sp, BUF_SIZE + 6]
	cmp w0, 1
	b.eq read_sock
	ldrh w0, [sp, BUF_SIZE + 14]
	cmp w0, 1
	b.eq read_stdin

	b continue_poll

read_sock:
	mov w0, w19
	mov x1, sp
	mov x2, BUF_SIZE
	mov x8, SYS_read
	svc 0

	mov x1, sp
	mov x2, x0
	mov w0, 1
	mov x8, SYS_write
	svc 0

	ldrh w0, [sp]
	cmp w0, 'q' + ('\n' << 8)
	b.ne continue_poll

	mov w0, 0 
	mov x8, SYS_exit
	svc 0

read_stdin:
	mov w0, 0
	mov x1, sp
	mov x2, BUF_SIZE
	mov x8, SYS_read
	svc 0

	mov x1, sp
	mov x2, x0
	mov w0, w19
	mov x8, SYS_write
	svc 0

	ldrh w0, [sp]
	cmp w0, 'q' + ('\n' << 8)
	b.ne continue_poll

	mov w0, 0
	mov x8, SYS_exit
	svc 0


connect_err:
	cmp w0, -ECONNREFUSED
	b.eq econrefused
	mov w19, w0
	mov w0, 2
	adrp x1, connect_err_msg
	add x1, x1, :lo12:connect_err_msg
	mov x2, 54
	mov x8, SYS_write
	svc 0
	mov w0, w19
	mov x8, SYS_exit
	svc 0

econrefused:
	mov w0, 2
	adrp x1, econrefused_msg
	add x1, x1, :lo12:econrefused_msg
	mov x2, 92
	mov x8, SYS_write
	svc 0
	mov w0, 1
	mov x8, SYS_exit
	svc 0

bind_err:
	cmp w0, -EADDRINUSE
	b.eq eaddrinuse
	mov w19, w0
	mov w0, 2
	adrp x1, bind_err_msg
	add x1, x1, :lo12:bind_err_msg
	mov x2, 51
	mov x8, SYS_write
	svc 0
	mov w0, w19
	mov x8, SYS_exit
	svc 0

eaddrinuse:
	mov w0, 2
	adrp x1, eaddrinuse_msg
	add x1, x1, :lo12:eaddrinuse_msg
	mov x2, 85
	mov x8, SYS_write
	svc 0
	mov w0, 1
	mov x8, SYS_exit
	svc 0

usage:
	mov w0, 2
	adrp x1, usage_msg
	add x1, x1, :lo12:usage_msg
	mov x2, 58
	mov x8, SYS_write
	svc 0
	mov w0, 1
	mov x8, SYS_exit
	svc 0

.section .rodata
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
