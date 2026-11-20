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
	lwu t0, (sp)
	li t1, 2
	beq t0, t1, server
	li t1, 3
	bne t0, t1, usage

# client:
	ld s0, 16(sp)
	ld s1, 24(sp)

	li a0, AF_INET
	li a1, SOCK_STREAM
	mv a2, zero
	li a7, SYS_socket
	ecall

# get ip to t0
	mv t0, zero
	li t1, 4
	li t2, 10

byte_start:
	lbu t4, (s0)
	add t4, t4, -'0'
	bgeu t4, t2, usage
	mv t3, t4

	add s0, s0, 1

	lbu t4, (s0)
	add s0, s0, 1
	add t4, t4, -'0'
	bgeu t4, t2, byte_end
	mul t3, t3, t2
	add t3, t3, t4

	lbu t4, (s0)
	add s0, s0, 1
	add t4, t4, -'0'
	bgeu t4, t2, byte_end
	mul t3, t3, t2
	add t3, t3, t4

	lbu t4, (s0)
	add s0, s0, 1
	add t4, t4, -'0'

byte_end:
	li t5, 256
	bgeu t3, t5, usage

# little endian stuff
	sll t3, t3, 24
	or t0, t0, t3

	add t1, t1, -1
	beqz t1, ip_end

	li t5, '.' - '0'
	bne t4, t5, usage

	srl t0, t0, 8
	j byte_start

ip_end:
	li t5, 0 - '0'
	bne t4, t5, usage

# get port to t1
	lbu t4, (s1)
	add t4, t4, -'0'
	bgeu t4, t2, usage
	add s1, s1, 1
	mv t1, t4

	li t3, 4

client_port_digit:
	lbu t4, (s1)
	add t4, t4, -'0'
	bgeu t4, t2, client_port_end
	mul t1, t1, t2
	add t1, t1, t4

	add s1, s1, 1

	add t3, t3, -1
	bnez t3, client_port_digit

 	add t4, t4, 1
	lbu t4, (s1)
	add t4, t4, -'0'

	add s1, s1, 1

client_port_end:
	add sp, sp, -(BUF_SIZE + 16)

	li t5, 0 - '0'
	bne t4, t5, usage
	li t5, 1<<16
	bgeu t1, t5, usage

	li t3, AF_INET
	sh t3, (sp)
	sh t1, 2(sp)
	sw t0, 4(sp)
	sd zero, 8(sp)

	mv s0, a0

	mv a1, sp
	li a2, 16
	li a7, SYS_connect
	ecall

	bnez a0, connect_err

	j poll_loop

server:
	ld s0, 16(sp)
	li a0, AF_INET
	li a1, 1
	mv a2, zero
	li a7, SYS_socket
	ecall

# get port to t1
	li t2, 10

	lbu t4, (s0)
	add t4, t4, -'0'
	bgeu t4, t2, usage
	mv t1, t4

	add s0, s0, 1

	li t3, 4

server_port_digit:
	lbu t4, (s0)
	add t4, t4, -'0'
	bgeu t4, t2, server_port_end
	mul t1, t1, t2
	add t1, t1, t4

	add s0, s0, 1

	add t3, t3, -1
	bnez t3, server_port_digit

	lbu t4, (s0)
	add t4, t4, -'0'
	add s0, s0, 1

server_port_end:
	li t5, -'0'
	bne t4, t5, usage
	li t5, 1 << 16
	bgeu t1, t5, usage

	add sp, sp, -(BUF_SIZE + 16)

 	li t5, 2
	sh t5, (sp)
	sh t1, 2(sp)
	sw zero, 4(sp)
	sd zero, 8(sp)

	mv s0, a0

	mv a1, sp
	li a2, 16
	li a7, SYS_bind
	ecall
	bnez a0, bind_err

	mv a0, s0
	li a1, 10
	li a7, SYS_listen
	ecall

	mv a0, s0
	mv a1, zero
	mv a2, zero
	li a7, SYS_accept
	ecall

	mv s0, a0

poll_loop:
	li t0, POLLIN
	sw s0, BUF_SIZE(sp)
	sw t0, BUF_SIZE + 4(sp)
	sw zero, BUF_SIZE + 8(sp)
	sw t0, BUF_SIZE + 12(sp)

continue_poll:
	add a0, sp, BUF_SIZE
	li a1, 2
	mv a2, zero
	mv a3, zero
	li a7, SYS_ppoll
	ecall

	lh t0, BUF_SIZE + 6(sp)
	li t1, 1
	beq t0, t1, read_sock
	lh t0, BUF_SIZE + 14(sp)
	beq t0, t1, read_stdin

	j continue_poll

read_sock:
	mv a0, s0
	mv a1, sp
	li a2, BUF_SIZE
	li a7, SYS_read
	ecall

	mv a1, sp
	mv a2, a0
	li a0, 1
	li a7, SYS_write
	ecall

	lh t0, (sp)
	li t1, 'q' + ('\n' << 8)
	bne t0, t1, continue_poll

	mv a0, zero
	li a7, SYS_exit
	ecall

read_stdin:
	mv a0, zero
	mv a1, sp
	li a2, BUF_SIZE
	li a7, SYS_read
	ecall

	mv a1, sp
	mv a2, a0
	mv a0, s0
	li a7, SYS_write
	ecall

	lh t0, (sp)
	li t1, 'q' + ('\n' << 8)
	bne t0, t1, continue_poll

	mv a0, zero
	li a7, SYS_exit
	ecall

connect_err:
	li t0, -ECONNREFUSED
	beq a0, t0, econrefused
	neg s0, a0
	li a0, 2
	la a1, connect_err_msg
	li a2, 54
	li a7, SYS_write
	ecall
	mv a0, s0
	li a7, SYS_exit
	ecall

econrefused:
	li a0, 2
	la a1, econrefused_msg
	li a2, 92
	li a7, SYS_write
	ecall
	li a0, 1
	li a7, SYS_exit
	ecall

bind_err:
	li t0, -EADDRINUSE
	beq a0, t0, eaddrinuse
	neg s0, a0
	li a0, 2
	la a1, bind_err_msg
	li a2, 51
	li a7, SYS_write
	ecall
	mv a0, s0
	li a7, SYS_exit
	ecall

eaddrinuse:
	li a0, 2
	la a1, eaddrinuse_msg
	li a2, 85
	li a7, SYS_write
	ecall
	li a0, 1
	li a7, SYS_exit
	ecall

usage:
	li a0, 2
	la a1, usage_msg
	li a2, 58
	li a7, SYS_write
	ecall
	li a0, 1
	li a7, SYS_exit
	ecall

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
