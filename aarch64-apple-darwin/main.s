.section __TEXT,__text
.globl _start
_start:
	mov w0, 0 
	mov x16, 1 ; SYS_exit
	svc 0x80
