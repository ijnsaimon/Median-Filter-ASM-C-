option casemap:none
_TEXT SEGMENT


; Macro for sorting two vector registers
; After execution, the lower register contains the smaller values
SORT_VEC MACRO REG1:REQ, REG2:REQ
    vpminub zmm15, REG1, REG2 ; zmm15 = min(REG1, REG2)
    vpmaxub REG2, REG1, REG2 ; REG2 = max(REG1, REG2)
    vmovdqa64 REG1, zmm15 ; REG1 = min(REG1, REG2)
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
    sub eax, 19 ; width - 1 (technically unsafe but the images aren't corrupted and processor ignores the out-of-bounds reads I think)
    cmp r14d, eax ; if x >= width - 1, jump to next Y line
    jge NextY
    ; Loading 9 vectors of 32 bytes each
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
    vmovdqu8 zmm0, zmmword ptr [rbx - 3] ; (x-1, y-1)
    vmovdqu8 zmm1, zmmword ptr [rbx] ; (x, y-1)
    vmovdqu8 zmm2, zmmword ptr [rbx + 3] ; (x+1, y-1)
    ; Middle row (y)
    vmovdqu8 zmm3, zmmword ptr [rax - 3] ; (x-1, y)
    vmovdqu8 zmm4, zmmword ptr [rax] ; (x, y)
    vmovdqu8 zmm5, zmmword ptr [rax + 3] ; (x+1, y)
    ; Lower row (y+1)
    mov rbx, rax
    add rbx, r10 ; adding stride to move to (y+1)
    vmovdqu8 zmm6, zmmword ptr [rbx - 3] ; (x-1, y+1)
    vmovdqu8 zmm7, zmmword ptr [rbx] ; (x, y+1)
    vmovdqu8 zmm8, zmmword ptr [rbx + 3] ; (x+1, y+1)
    ; Sorting network to find median for each color channel
    ; Median should be in xmm4 after sorting
    ; xmm15 is used as temporary storage

    ; Sorting columns
    SORT_VEC <zmm0>, <zmm1>
    SORT_VEC <zmm3>, <zmm4>
    SORT_VEC <zmm6>, <zmm7>

    SORT_VEC <zmm1>, <zmm2>
    SORT_VEC <zmm4>, <zmm5>
    SORT_VEC <zmm7>, <zmm8>

    SORT_VEC <zmm0>, <zmm1>
    SORT_VEC <zmm3>, <zmm4>
    SORT_VEC <zmm6>, <zmm7>

    ; Results after sorting columns:
    ; Min: xmm0, xmm1, xmm2
    ; Med: xmm3, xmm4, xmm5
    ; Max: xmm6, xmm7, xmm8
    ; Now sorting rows to get median of medians in xmm4

    SORT_VEC <zmm0>, <zmm3>
    SORT_VEC <zmm3>, <zmm6>

    SORT_VEC <zmm1>, <zmm4>
    SORT_VEC <zmm4>, <zmm7>

    SORT_VEC <zmm2>, <zmm5>
    SORT_VEC <zmm5>, <zmm8>

    ; Median is in the middle category
    ; Comparing xmm4 to neighbours to finalize median

    SORT_VEC <zmm4>, <zmm7>
    SORT_VEC <zmm4>, <zmm2>
    SORT_VEC <zmm6>, <zmm4>
    SORT_VEC <zmm4>, <zmm2>

    ; Output saving
    mov rax, r13 ; y
    imul rax, r10 ; y * stride
    mov rdi, r14 ; x
    imul rdi, 3 ; x * 3
    add rax, rdi ; y offset + x offset
    add rax, rdx ; out + offset, rax - output pixel address

    vmovdqu8 zmmword ptr [rax], zmm4 ; store 21 pixels
    
    add r14d, 21 ; x += 21 (21,33 but round to int)

    jmp LoopX
NextY:
    inc r13d ; y++
    jmp LoopY
EndLoopY:
    vzeroupper
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

	
