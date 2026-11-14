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

// socket(AF_INET, SOCK_STREAM, 0)
	mov edi, 2
	mov esi, 1
	xor edx, edx
	mov eax, 0x2000000 + 97
	syscall

// get ip to edi
	xor edi, edi
	mov ecx, 4

byte_start:
	movzx edx, byte ptr[rbx]
	sub edx, 0x30
	cmp edx, 10
	jae usage
	inc rbx
	mov esi, edx

	movzx edx, byte ptr[rbx]
	inc rbx
	sub edx, 0x30
	cmp edx, 10
	jae byte_end
	imul esi, 10
	add esi, edx

	movzx edx, byte ptr[rbx]
	inc rbx
	sub edx, 0x30
	cmp edx, 10
	jae byte_end
	imul esi, 10
	add esi, edx

	movzx edx, byte ptr[rbx]
	inc rbx
	sub edx, 0x30

byte_end:
	cmp esi, 256
	jae usage

// little endian stuff
	shl esi, 24
	or edi, esi

	dec ecx
	jecxz ip_end

	cmp edx, -2 // '.' - 0x30
	jne usage

	shr edi, 8
	jmp byte_start

ip_end:
	cmp edx, -0x30 // '\0' - 0x30
	jne usage

// get port to esi
	movzx edx, byte ptr[rbp]
	sub edx, 0x30
	cmp edx, 10
	jae usage
	inc rbp
	mov esi, edx

	mov ecx, 4

client_port_digit:
	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, 0x30
	cmp edx, 10
	jae client_port_end
	imul esi, 10
	add esi, edx

	loop client_port_digit

	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, 0x30

client_port_end:
	cmp edx, -0x30
	jne usage
	cmp esi, 0xFFFF
	ja usage

	sub rsp, 16
	mov word ptr[rsp], 2
	mov [rsp + 2], si
	mov [rsp + 4], edi
	mov qword ptr[rsp + 8], 0

	mov ebx, eax

// connect(sockfd, &sockaddr, socklen)
  mov edi, eax
	mov rsi, rsp
	mov edx, 16
	mov eax, 0x2000000 + 98
	syscall

	cmp eax, 0
	jne connect_err

	jmp poll_loop

server:
	mov rbp, [rsi + 8]
// socket(AF_INET, SOCK_STREAM, 0)
	mov edi, 2
	mov esi, 1
	xor edx, edx
	mov eax, 0x2000000 + 97
	syscall

// get port to esi
	movzx edx, byte ptr[rbp]
	sub edx, 0x30
	cmp edx, 10
	jae usage
	inc rbp
	mov esi, edx

	mov ecx, 4

server_port_digit:
	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, 0x30
	cmp edx, 10
	jae server_port_end
	imul esi, 10
	add esi, edx

	loop server_port_digit

	movzx edx, byte ptr[rbp]
	inc rbp
	sub edx, 0x30

server_port_end:
	cmp edx, -0x30
	jne usage
	cmp esi, 0xFFFF
	ja usage

	mov ebx, eax

	sub rsp, 16
	mov qword ptr[rsp], 2
	mov qword ptr[rsp + 8], 0
	mov [rsp + 2], si

// bind(sockfd, &sockaddr, socklen)
	mov edi, eax
	mov rsi, rsp
	mov edx, 16
	mov eax, 0x2000000 + 104
	syscall
	cmp eax, 0
	jne bind_err

// listen(sockfd, backlog)
	mov edi, ebx
	mov esi, 10
	mov eax, 0x2000000 + 106
	syscall

// accept(sockfd, NULL, NULL)
	mov edi, ebx
	xor esi, esi
	xor edx, edx
	mov eax, 0x2000000 + 30
	syscall

	mov ebx, eax

poll_loop:
	sub rsp, 0x100 + 16
	mov rbp, rsp
	add rbp, 0x100

	mov [rbp], ebx
	mov word ptr[rbp + 4], 1 // POLLIN
	mov dword ptr[rbp + 8], 0 // stdin
	mov word ptr[rbp + 12], 1 // POLLIN

continue_poll:
// poll(fds, nfds, timeout)
	mov rdi, rbp
	mov esi, 2
	xor edx, edx
	mov eax, 0x2000000 + 230
	syscall

	movzx ecx, word ptr[rbp + 6]
	cmp ecx, 1
	je read_sock
	movzx ecx, word ptr[rbp + 14]
	cmp ecx, 1
	je read_stdin

	jmp continue_poll

read_sock:
// read(sockfd, sp, 0x100)
	mov edi, ebx
	mov rsi, rsp
	mov edx, 0x100
	mov eax, 0x2000000 + 3
	syscall

// write(1, sp, bytes_read)
  mov edi, 1
	mov rsi, rsp
	mov edx, eax
	mov eax, 0x2000000 + 4
	syscall

	movzx ecx, word ptr[rsp]
	cmp ecx, 0x0a71 // "q\n"
	jne continue_poll

// exit(0)
	xor edi, edi
	mov eax, 0x2000000 + 1
	syscall

read_stdin:
// read(0, sp, 0x100)
	xor edi, edi
	mov rsi, rsp
	mov edx, 0x100
	mov eax, 0x2000000 + 3
	syscall

// write(sockfd, sp, bytes_read)
	mov edi, ebx
	mov rsi, rsp
	mov edx, eax
	mov eax, 0x2000000 + 4
	syscall

	movzx ecx, word ptr[rsp]
	cmp ecx, 0x0a71 // "q\n"
	jne continue_poll

// exit(0)
	xor edi, edi
	mov eax, 0x2000000 + 1
	syscall

connect_err:
	cmp eax, 61
	je econrefused
	mov ebx, eax
	mov edi, 2
	lea rsi, [rip + connect_err_msg]
	mov edx, 54
	mov eax, 0x2000000 + 4
	syscall
	mov edi, ebx
	mov eax, 0x2000000 + 1
	syscall

econrefused:
	mov edi, 2
	lea rsi, [rip + econrefused_msg]
	mov edx, 92
	mov eax, 0x2000000 + 4
	syscall
	mov edi, 1
	mov eax, 0x2000000 + 1
	syscall

bind_err:
	cmp eax, 48
	je eaddrinuse
	mov ebx, eax
	mov edi, 2
	lea rsi, [rip + bind_err_msg]
	mov edx, 51
	mov eax, 0x2000000 + 4
	syscall
	mov edi, ebx
	mov eax, 0x2000000 + 1
	syscall

eaddrinuse:
	mov edi, 2
	lea rsi, [rip + eaddrinuse_msg]
	mov edx, 85
	mov eax, 0x2000000 + 4
	syscall
	mov edi, 1
	mov eax, 0x2000000 + 1
	syscall

usage:
	mov edi, 2
	lea rsi, [rip + usage_msg]
	mov edx, 58
	mov eax, 0x2000000 + 4
	syscall
	mov edi, 1
	mov eax, 0x2000000 + 1
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
