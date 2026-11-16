SYS_socket  = 0x2000000 + 97
SYS_connect = 0x2000000 + 98
SYS_bind    = 0x2000000 + 104
SYS_listen  = 0x2000000 + 106
SYS_accept  = 0x2000000 + 30
SYS_poll    = 0x2000000 + 230
SYS_read    = 0x2000000 + 3
SYS_write   = 0x2000000 + 4
SYS_exit    = 0x2000000 + 1

AF_INET = 2
SOCK_STREAM = 1
POLLIN = 1

ECONNREFUSED = 61
EADDRINUSE = 48

BUF_SIZE = 256

.intel_syntax noprefix
.section __TEXT,__text
.globl _start
_start:
	cmp edi, 2
	je server
	cmp edi, 3
	jne usage

// client:

	mov rbx, [rsi + 8]
	mov rbp, [rsi + 16]

	mov edi, AF_INET
	mov esi, SOCK_STREAM
	xor edx, edx
	mov eax, SYS_socket
	syscall

// get ip to edi
	xor edi, edi
	mov ecx, 4

byte_start:
	movzx edx, byte ptr[rbx]
	sub edx, '0'
	cmp edx, 10
	jae usage
	inc rbx
	mov esi, edx

	movzx edx, byte ptr[rbx]
	inc rbx
	sub edx, '0'
	cmp edx, 10
	jae byte_end
	imul esi, 10
	add esi, edx

	movzx edx, byte ptr[rbx]
	inc rbx
	sub edx, '0'
	cmp edx, 10
	jae byte_end
	imul esi, 10
	add esi, edx

	movzx edx, byte ptr[rbx]
	inc rbx
	sub edx, '0'

byte_end:
	cmp esi, 256
	jae usage

// little endian stuff
	shl esi, 24
	or edi, esi

	dec ecx
	jecxz ip_end

	cmp edx, '.' - '0'
	jne usage

	shr edi, 8
	jmp byte_start

ip_end:
	cmp edx, 0 - '0'
	jne usage

// get port to esi
	movzx edx, byte ptr[rbp]
	sub edx, '0'
	cmp edx, 10
	jae usage
	inc rbp
	mov esi, edx

	mov ecx, 4

client_port_digit:
	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, '0'
	cmp edx, 10
	jae client_port_end
	imul esi, 10
	add esi, edx

	loop client_port_digit

	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, '0'

client_port_end:
	cmp edx, -'0'
	jne usage
	cmp esi, 0xFFFF
	ja usage

	sub rsp, 16
	mov word ptr[rsp], 2
	mov [rsp + 2], si
	mov [rsp + 4], edi
	mov qword ptr[rsp + 8], 0

	mov ebx, eax

  mov edi, eax
	mov rsi, rsp
	mov edx, 16
	mov eax, SYS_connect
	syscall

	cmp eax, 0
	jne connect_err

	jmp poll_loop

server:
	mov rbp, [rsi + 8]
	mov edi, AF_INET
	mov esi, SOCK_STREAM
	xor edx, edx
	mov eax, SYS_socket
	syscall

// get port to esi
	movzx edx, byte ptr[rbp]
	sub edx, '0'
	cmp edx, 10
	jae usage
	inc rbp
	mov esi, edx

	mov ecx, 4

server_port_digit:
	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, '0'
	cmp edx, 10
	jae server_port_end
	imul esi, 10
	add esi, edx

	loop server_port_digit

	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, '0'

server_port_end:
	cmp edx, 0 - '0'
	jne usage
	cmp esi, 0xFFFF
	ja usage

	mov ebx, eax

	sub rsp, 16
	mov qword ptr[rsp], 2
	mov qword ptr[rsp + 8], 0
	mov [rsp + 2], si

	mov edi, eax
	mov rsi, rsp
	mov edx, 16
	mov eax, SYS_bind
	syscall
	cmp eax, 0
	jne bind_err

	mov edi, ebx
	mov esi, 10
	mov eax, SYS_listen
	syscall

	mov edi, ebx
	xor esi, esi
	xor edx, edx
	mov eax, SYS_accept
	syscall

	mov ebx, eax

poll_loop:
	sub rsp, BUF_SIZE + 16
	mov rbp, rsp
	add rbp, BUF_SIZE

	mov [rbp], ebx
	mov word ptr[rbp + 4], POLLIN
	mov dword ptr[rbp + 8], 0
	mov word ptr[rbp + 12], POLLIN

continue_poll:
	mov rdi, rbp
	mov esi, 2
	xor edx, edx
	mov eax, SYS_poll
	syscall

	movzx ecx, word ptr[rbp + 6]
	cmp ecx, 1
	je read_sock
	movzx ecx, word ptr[rbp + 14]
	cmp ecx, 1
	je read_stdin

	jmp continue_poll

read_sock:
	mov edi, ebx
	mov rsi, rsp
	mov edx, BUF_SIZE
	mov eax, SYS_read
	syscall

  mov edi, 1
	mov rsi, rsp
	mov edx, eax
	mov eax, SYS_write
	syscall

	movzx ecx, word ptr[rsp]
	cmp ecx, 'q' + ('\n' << 8)
	jne continue_poll

	xor edi, edi
	mov eax, SYS_exit
	syscall

read_stdin:
	xor edi, edi
	mov rsi, rsp
	mov edx, BUF_SIZE
	mov eax, SYS_read
	syscall

	mov edi, ebx
	mov rsi, rsp
	mov edx, eax
	mov eax, SYS_write
	syscall

	movzx ecx, word ptr[rsp]
	cmp ecx, 'q' + ('\n' << 8)
	jne continue_poll

	xor edi, edi
	mov eax, SYS_exit
	syscall

connect_err:
	cmp eax, ECONNREFUSED
	je econrefused
	mov ebx, eax
	mov edi, 2
	lea rsi, [rip + connect_err_msg]
	mov edx, 54
	mov eax, SYS_write
	syscall
	mov edi, ebx
	mov eax, SYS_exit
	syscall

econrefused:
	mov edi, 2
	lea rsi, [rip + econrefused_msg]
	mov edx, 92
	mov eax, SYS_write
	syscall
	mov edi, 1
	mov eax, SYS_exit
	syscall

bind_err:
	cmp eax, EADDRINUSE
	je eaddrinuse
	mov ebx, eax
	mov edi, 2
	lea rsi, [rip + bind_err_msg]
	mov edx, 51
	mov eax, SYS_write
	syscall
	mov edi, ebx
	mov eax, SYS_exit
	syscall

eaddrinuse:
	mov edi, 2
	lea rsi, [rip + eaddrinuse_msg]
	mov edx, 85
	mov eax, SYS_write
	syscall
	mov edi, 1
	mov eax, SYS_exit
	syscall

usage:
	mov edi, 2
	lea rsi, [rip + usage_msg]
	mov edx, 58
	mov eax, SYS_write
	syscall
	mov edi, 1
	mov eax, SYS_exit
	syscall

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
