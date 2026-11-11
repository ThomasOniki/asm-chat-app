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
	; ip 127.0.0.1
	movk x1, 127, lsl 32
	movk x1, 0x0100, lsl 48
	stp x1, xzr, [sp, -0x10]!

; connect(sockfd, &sockaddr, socklen)
	mov x1, sp
	mov w2, 16
	mov x16, 98
	svc 0x80

; exit(0)
	mov w0, 0
	mov x16, 1
	svc 0x80
