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
	stp x1, xzr, [sp, -0x10]!

	; x0 is already the sockfd
	mov x1, sp ; sockaddr*
	mov w2, 16 ; socklen
	mov x16, 104 ; SYS_bind
	svc 0x80

	mov w0, w19 ; sockfd
	mov w1, 10 ; backlog
	mov x16, 106 ; SYS_listen
	svc 0x80

	mov w0, w19 ; sockfd
	mov x1, 0 ; name*
	mov x2, 0 ; namelen*
	mov x16, 30 ; SYS_accept
	svc 0x80

	mov w0, 0 
	mov x16, 1 ; SYS_exit
	svc 0x80
