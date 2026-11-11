.section __TEXT,__text
.globl _start
_start:
	mov w0, 2 ; AF_INET (ipv2)
	mov w1, 1 ; SOCK_STREAM (tcp)
	mov w2, 0 ; protocol
	mov x16, 97 ; SYS_socket
	svc 0x80

	mov w19, w0

	mov x1, 2 ; AF_INET
	movk x1, 1234, lsl 16 ; port
	; ip 127.0.0.1
	movk x1, 127, lsl 32
	movk x1, 0x0100, lsl 48
	stp x1, xzr, [sp, -0x10]!

	; x0 is already the sockfd
	mov x1, sp ; sockaddr*
	mov w2, 16 ; socklen
	mov x16, 98 ; SYS_connect
	svc 0x80

	;mov w0, 0
	mov x16, 1 ; SYS_exit
	svc 0x80
