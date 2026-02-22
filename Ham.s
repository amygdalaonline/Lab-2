# Ham.s
# Hamming distance = number of bit positions where two strings differ
# gcc -no-pie Ham.s -o ham
# ./ham

# commenting EVERYTHINGG so i can understand assembly better

    # starts data section for initialized global data
    .section .data

# null-terminated C strings, .asciz appends \0 automatically
prompt1:    .asciz "Enter first string: "
prompt2:    .asciz "Enter second string: "
result_msg: .asciz "Hamming distance: %d\n"

# reserve 256 bytes for each input, max input length 255 + 1 byte for \0
buffer1:    .space 256
buffer2:    .space 256

    # .bss for uninitialized storage
    .section .bss

    # .text starts executable code section
    .section .text
    # exports main so linker can find it as program entry point
    .globl main

main:
    # standard stack frame setup, save old base pointer %rbp and set %rbp to current stack pointer %rsp
    pushq %rbp
    movq %rsp, %rbp

    # ! prompt for first string !

    # loads address of prompt1 into %rdi
    leaq prompt1(%rip), %rdi
    # prints prompt
    call  print_str
    movq $0, %rdi
    # fflush flushes all output streams, flushes stdout so prompt appears immediately
    call fflush

    # %rsi is address of buffer1
    leaq buffer1(%rip), %rsi
    # edx = 255 max bytes to read
    movl $255, %edx
    # see read_input further down
    call  read_input

    # ! prompt for second string !
    leaq prompt2(%rip), %rdi
    call  print_str
    movq $0, %rdi
    call fflush

    leaq buffer2(%rip), %rsi
    movl $255, %edx
    call  read_input

    # ! compute Hamming distance !
    leaq buffer1(%rip), %rsi
    leaq buffer2(%rip), %rdi
    # see hamming_distance further down
    call  hamming_distance

    # ! print the result !
    movl %eax, %esi
    leaq result_msg(%rip), %rdi
    movl $0, %eax
    call printf

    # %eax = 0 return status
    movl $0, %eax
    # leave = shorthand for
    # mov %rbp, %rsp
    # pop %rbp
    leave
    # returns to caller
    ret

# print_str: calls printf("%s", str)
print_str:
    pushq %rbp
    movq %rsp, %rbp
    # move original string from %rdi into %rsi
    movq %rdi, %rsi
    leaq fmt_str(%rip), %rdi
    # clear %eax
    movl $0, %eax
    call printf
    popq %rbp
    ret

    # .rodata = read-only data
    .section .rodata
# fmt_str is printf format used by print_str
fmt_str: .asciz "%s"

    # switch back to code sections
    .text

# read_input(rsi = buffer, edx = maxlen)
read_input:
    pushq %rbp
    movq %rsp, %rbp
    movq $0, %rdi
    # sets syscall number to 0 (read)
    movq $0, %rax
    # my_read does syscall
    call  my_read
    popq %rbp
    ret

# my_read: syscall read, remove newline
my_read:
    # makes sure that %rax = 0
    movq $0, %rax            # sys_read
    syscall
    # %rax contains number of bytes read, 0 for end of file, or negative for error
    # if %rax <= 0, jump to end_read (EOF or error)
    cmpq $0, %rax
    jle end_read
    # %rcx walks thru buffer
    movq %rsi, %rcx          # pointer to buffer
    # %r8 counts down remaining bytes to look at
    movq %rax, %r8           # bytes read

# loop over bytes read looking for ascii 10
strip_nl:
    cmpb $10, (%rcx)
    # if current byte is 10, jump to replace_n1
    je replace_nl
    incq %rcx
    # keep looping while %r8 isn't 0
    decq %r8
    jnz strip_nl
    # finish if no newline found
    jmp end_read

# replace newline with \0 (null terminator), turns input into C string
replace_nl:
    movb $0, (%rcx)
end_read:
    ret

# hamming_distance(rsi = str1, rdi = str2)
# returns eax = distance
hamming_distance:
    pushq %rbp
    movq %rsp, %rbp
    # %eax holds return value
    movl $0, %eax            # distance
    # %cx is index into strings
    movl $0, %ecx            # counter

# load 1 byte from each string at index %rcx
loop:
    # mov = move/copy data
    # z = zero-extend, fill upper bits w zeros
    # b = byte, source size is 8 bits
    # q = quadword, destination size is 64 bits
    movzbq (%rsi,%rcx), %r8
    movzbq (%rdi,%rcx), %r9
    # checks if zero, stops if either char is 0 (null terminator)
    orq %r8, %r8
    jz done
    orq %r9, %r9
    jz done
    # xor the 2 bytes in %r9, bits that differ become 1
    xorq %r8, %r9
    # copy xor result into %rdx for bit counting
    movq %r9, %rdx
    
count_bits:
    # if %rdx==0, no more 1 bits -> go to next char
    testq %rdx, %rdx
    jz next_char
    # shift right 1 bit, bit that falls off goes into cpu carry flag (cf)
    shrq $1, %rdx
    # add with carry, adds 0 + cf into %rax
    # if bit shifted out == 1, cf = 1 and %rax++
    # if bit == 0, cf = 0 and %rax doesn't change
    # repeats until %rdx becomes 0
    adcq $0, %rax
    jmp count_bits

# increment index, repeat for next char
next_char:
    incq %rcx
    jmp loop

# return with distance in %eax / %rax
done:
    popq %rbp
    ret

# removes warning, tells linker that obj file does not require executable stack
.section .note.GNU-stack,"",@progbits
