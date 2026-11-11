.section __TEXT,__text
.globl _start
_start:
; socket(AF_INET, SOCK_STREAM, 0)
	mov w0, 2
	mov w1, 1
	mov w2, 0
	mov x16, 97
	svc 0x80

	mov w19, w0

	mov x1, 2 ; AF_INET
	movk x1, 1234, lsl 16 ; port
	stp x1, xzr, [sp, -0x10]!

; bind(sockfd, &sockaddr, socklen)
	mov x1, sp
	mov w2, 16
	mov x16, 104
	svc 0x80

; listen(sockfd, backlog)
	mov w0, w19
	mov w1, 10
	mov x16, 106
	svc 0x80

; accept(sockfd, NULL, NULL)
	mov w0, w19
	mov x1, 0
	mov x2, 0
	mov x16, 30
	svc 0x80

; read(sockfd, sp, 0x100)
	sub sp, sp, 0x100
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

; exit(0)
	mov w0, 0 
	mov x16, 1
	svc 0x80
