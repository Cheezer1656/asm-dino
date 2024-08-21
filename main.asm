section .text
    global _start

    _start:
        ; Set up terminal
        call echo_off
        call canonical_off

        ; Set obstacles for testing
        mov eax, obstacles
        add eax, 2
        mov BYTE [eax], 0xFF

        .loop:
        call redraw

        ; Pause for one second
        mov eax, 162
        lea ebx, [sleepTs]
        xor ecx, ecx
        int 0x80

        call updateDino
        call updateObstacles
        call checkCollision

        jmp .loop

        ; Exit
        mov eax, 1
        mov ebx, 0
        int 0x80
    
    updateDino:
        .start:
        mov ah, 01h
        int 16h
        jz .start

        xor ah, ah
        int 16h

        cmp al, 49
        jne .start

        mov BYTE [dinoPos], 1

        .end:
        ret

    updateObstacles:
        mov eax, obstacles
        mov ecx, 9

        .loop:
        movzx ebx, BYTE [eax]
        shr ebx, 1
        movzx edx, BYTE [eax + 1]
        and edx, 1
        shl edx, 7
        or ebx, edx
        mov [eax], bl

        inc eax

        loop .loop

        shr BYTE [eax], 1

        ret

    checkCollision:
        cmp BYTE [dinoPos], 0
        jne .end

        mov BYTE [obIndex], 8
        call checkOb

        cmp eax, 0x1
        jne .end

        mov eax, 1
        mov ebx, 0
        int 0x80

        .end:
        ret

    redraw:
        mov eax, 4
        mov ebx, 1
        mov ecx, clear
        mov edx, clearLen
        int 0x80

        ; Print obstacles
        call drawObstacles

        ; Adjust dinoCursor pointer using dinoChar
        mov eax, [dinoPos]
        mov ebx, 0x8
        mul ebx
        mov ecx, dinoCursor
        add ecx, eax

        ; Print dinoCursor and dinoChar
        mov eax, 4
        mov ebx, 1
        mov edx, 0x8
        int 0x80

        mov eax, 4
        mov ebx, 1
        mov ecx, dinoChar
        mov edx, 0x1
        int 0x80

        ; Reset cursor to home (0,0)
        mov eax, 4
        mov ebx, 1
        mov ecx, resetCursor
        mov edx, resetCursorLen
        int 0x80

        ret

    drawObstacles:
        mov BYTE [obIndex], 0x0

        .loop:
        call checkOb
        cmp eax, 0x1
        je .draw
        jmp .move
    
        .incr:
        add BYTE [obIndex], 0x1
        cmp BYTE [obIndex], 0x51
        jne .loop
        jmp .end
    
        .draw:
        mov eax, 4
        mov ebx, 1
        mov ecx, obstacleChar
        mov edx, 1
        int 0x80

        jmp .incr

        .move:
        mov eax, 4
        mov ebx, 1
        mov ecx, moveCursor
        mov edx, moveCursorLen
        int 0x80

        jmp .incr

        .end:
        ret

    ; Put the value of the bit at obIndex in eax
    checkOb:
        ; Divide obIndex by the size of a byte
        mov eax, [obIndex]
        mov ebx, 0x8
        xor edx, edx
        div ebx

        ; Get the value of the bit at obIndex (Starting from the left)
        mov ebx, obstacles
        add ebx, eax
        movzx eax, BYTE [ebx]
        mov cl, dl
        shr eax, cl
        and eax, 0x1

        ret

canonical_off:
        call read_stdin_termios

        ; clear canonical bit in local mode flags
        and dword [termios+12], ~ICANON

        call write_stdin_termios
        ret

echo_off:
        call read_stdin_termios

        ; clear echo bit in local mode flags
        and dword [termios+12], ~ECHO

        call write_stdin_termios
        ret

; clobbers RAX, RCX, RDX, R8..11 (by int 0x80 in 64-bit mode)
; allowed by x86-64 System V calling convention    
read_stdin_termios:
        push rbx

        mov eax, 36h
        mov ebx, 0
        mov ecx, 5401h
        mov edx, termios
        int 80h            ; ioctl(0, 0x5401, termios)

        pop rbx
        ret

write_stdin_termios:
        push rbx

        mov eax, 36h
        mov ebx, 0
        mov ecx, 5402h
        mov edx, termios
        int 80h            ; ioctl(0, 0x5402, termios)

        pop rbx
        ret

section .data
    ICANON: equ 1<<1
    ECHO: equ 1<<3

    sleepTs:
        dd 0
        dd 300000000

    clear: db 0x1B, "[2J", 0x1B, "[2", 0x3B, "5H", "ASCII Dino v1", 0x1B, "[20", 0x3B, "10H", "________________________________________________________________________________", 0x1B, "[19", 0x3B, "10H"
    clearLen: equ $-clear

    resetCursor: db 0x1B, "[H"
    resetCursorLen: equ $-resetCursor

    moveCursor: db 0x1B, "[1C"
    moveCursorLen: equ $-moveCursor

    obstacleChar: db '.'

    dinoCursor: db 0x1B, "[19", 0x3B, "18H", 0x1B, "[18", 0x3B, "18H", 0x1B, "[17", 0x3B, "18H"
    dinoChar: db '/' ; Just a forward slash for now

    dinoPos: db 0

section .bss
    termios: resb 36

    input: resb 1

    obstacles: resb 10 ; Platform is 80 characters long, so it'll take 10 bytes to represent all the possible x positions
    obIndex: resb 1