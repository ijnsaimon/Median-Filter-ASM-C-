option casemap:none
_TEXT SEGMENT


; Macro for sorting two vector registers
; After execution, the lower register contains the smaller values
SORT_VEC MACRO REG1:REQ, REG2:REQ
    movdqa xmm15, REG1 ; copy REG1 to xmm15
    pminub REG1, REG2  ; REG1 = min(REG1, REG2)
    pmaxub REG2, xmm15 ; REG2 = max(old REG1, REG2)
ENDM

; Function implementing median filter
; void MedianFilter(IntPtr src, IntPtr out, int width, int height, int stride, int startY, int endY)
; RCX - source pointer
; RDX - output pointer
; R8 - width
; R9 - height
; [RSP + 40h] - stride
; [RSP + 48h] - startY
; [RSP + 56h] - endY


MedianFilter PROC
    
    ; Pushing used registers on the stack
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    push rbp
    ; Setting register base pointer on top of the stack
    mov rbp, rsp
    ; Offset - 8 pushes (8x8 = 64) + return address (8) + shadow space (32) = 104
    mov r10d, dword ptr [rbp+104] ; stride
    mov r11d, dword ptr [rbp+112] ; startY
    mov r12d, dword ptr [rbp+120] ; endY
    ; r13 - current Y (loop counter)
    mov r13d, r11d        ; currentY = startY
LoopY:
    cmp r13d, r12d ; if y >= endY, jump to EndLoopY    
    jge EndLoopY      
    ; r14 - current x (loop counter)
    mov r14d, 1 ; x = 1
LoopX:
    mov eax, r8d ; eax - width
    sub eax, 1 ; width - 1 (technically unsafe but the images aren't corrupted and processor ignores the out-of-bounds reads I think)
    cmp r14d, eax ; if x >= width - 1, jump to next Y line
    jge NextY
    ; Loading 9 vectors of 16 bytes each
    ; Address of the center pixel (x,y)
    mov rax, r13 ; y
    imul rax, r10 ; y * stride
    mov rdi, r14 ; x
    imul rdi, 3 ; x * 3
    add rax, rdi ; y offset + x offset
    add rax, rcx ; src + offset, rax - center pixel address
    ; xmm0 - xmm8 will hold 3x3 neighborhood pixels for 16 pixels at once
    ; Matrix layout:
    ; xmm0 xmm1 xmm2
    ; xmm3 xmm4 xmm5
    ; xmm6 xmm7 xmm8
    ; Upper row (y-1)
    mov rbx, rax
    sub rbx, r10 ; subtracting stride to move to (y-1)
    movdqu xmm0, [rbx - 3] ; (x-1, y-1)
    movdqu xmm1, [rbx] ; (x, y-1)
    movdqu xmm2, [rbx + 3] ; (x+1, y-1)
    ; Middle row (y)
    movdqu xmm3, [rax - 3] ; (x-1, y)
    movdqu xmm4, [rax] ; (x, y)
    movdqu xmm5, [rax + 3] ; (x+1, y)
    ; Lower row (y+1)
    mov rbx, rax
    add rbx, r10 ; adding stride to move to (y+1)
    movdqu xmm6, [rbx - 3] ; (x-1, y+1)
    movdqu xmm7, [rbx] ; (x, y+1)
    movdqu xmm8, [rbx + 3] ; (x+1, y+1)
    ; Sorting network to find median for each color channel
    ; Median should be in xmm4 after sorting
    ; xmm15 is used as temporary storage

    ; Sorting columns
    SORT_VEC <xmm0>, <xmm3>
    SORT_VEC <xmm3>, <xmm6>
    SORT_VEC <xmm0>, <xmm3>

    SORT_VEC <xmm1>, <xmm4>
    SORT_VEC <xmm4>, <xmm7>
    SORT_VEC <xmm1>, <xmm4>

    SORT_VEC <xmm2>, <xmm5>
    SORT_VEC <xmm5>, <xmm8>
    SORT_VEC <xmm2>, <xmm5>

    ; Results after sorting columns:
    ; Min: xmm0, xmm1, xmm2
    ; Med: xmm3, xmm4, xmm5
    ; Max: xmm6, xmm7, xmm8
    ; Now sorting rows to get median of medians in xmm4

    SORT_VEC <xmm0>, <xmm1>
    SORT_VEC <xmm1>, <xmm2>
    SORT_VEC <xmm0>, <xmm1>

    SORT_VEC <xmm3>, <xmm4>
    SORT_VEC <xmm4>, <xmm5>
    SORT_VEC <xmm3>, <xmm4>

    SORT_VEC <xmm6>, <xmm7>
    SORT_VEC <xmm7>, <xmm8>
    SORT_VEC <xmm6>, <xmm7>

    ; Median is in the middle category
    ; Comparing xmm4 to neighbours to finalize median

    SORT_VEC <xmm1>, <xmm4>
    SORT_VEC <xmm4>, <xmm7>
    SORT_VEC <xmm4>, <xmm5>
    SORT_VEC <xmm3>, <xmm4>

    ; Output saving
    mov rax, r13 ; y
    imul rax, r10 ; y * stride
    mov rdi, r14 ; x
    imul rdi, 3 ; x * 3
    add rax, rdi ; y offset + x offset
    add rax, rdx ; out + offset, rax - output pixel address

    movdqu [rax], xmm4 ; store 16 pixels
    
    add r14d, 5 ; x += 5

    jmp LoopX
NextY:
    inc r13d ; y++
    jmp LoopY
EndLoopY:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret
MedianFilter ENDP
_TEXT ENDS
END

	
