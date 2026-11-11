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

.section __TEXT,__const
connect_err_msg:
	.ascii "connect(2) failed, its error number will be returned.\n"
