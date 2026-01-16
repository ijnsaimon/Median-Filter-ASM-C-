option casemap:none
_TEXT SEGMENT

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
    ; Offset - stride was rsp + 40 but after 8 pushes (8*8 bytes = 64 bytes) it becomes rsp + 40 + 64, so rsp + 104
    mov r10d, dword ptr [rbp+104] ; stride
    mov r11d, dword ptr [rbp+112] ; startY
    mov r12d, dword ptr [rbp+120] ; endY
    ; r13 - current Y (loop counter)
    mov r13d, r11d        ; currentY = startY
LoopY:
    cmp r13d, r12d ; if y >= endY, jump to EndLoopY    
    jge EndLoopY      
    ; r14 - current x (loop counter)
    ; With SSE, there are 16 pixels processed at once, so the loop needs to end at width - 16 in order to be aligned
    mov r14d, 1 ; x = 1
LoopX:
    mov eax, r8d ; eax - width
    sub eax, 17 ; width - 1 - 16 (becacuse of processing 16 pixels at once)
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
    add rbx, r10 ; subtracting stride to move to (y-1)
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
    SORT_VEC xmm0, xmm3
    SORT_VEC xmm3, xmm6
    SORT_VEC xmm0, xmm3

    SORT_VEC xmm1, xmm4
    SORT_VEC xmm4, xmm7
    SORT_VEC xmm1, xmm4

    SORT_VEC xmm2, xmm5
    SORT_VEC xmm5, xmm8
    SORT_VEC xmm2, xmm5

    ; Results after sorting columns:
    ; Min: xmm0, xmm1, xmm2
    ; Med: xmm3, xmm4, xmm5
    ; Max: xmm6, xmm7, xmm8
    ; Now sorting rows to get median of medians in xmm4

    SORT_VEC xmm0, xmm1
    SORT_VEC xmm3, xmm4
    SORT_VEC xmm6, xmm7

    SORT_VEC xmm1, xmm2
    SORT_VEC xmm4, xmm5
    SORT_VEC xmm7, xmm8

    ; Loading color channels [B, G, R]
    ; Blue
    mov r11b, byte ptr [rax]; B
    mov byte ptr [rsp + rsi], r11b ; copy to chanB[k] on the stack (offset 0)
    ;Green
    mov r11b, byte ptr [rax + 1]; G
    mov byte ptr [rsp + rsi + 9], r11b ; copy to chanG[k] on the stack (offset 9)
    ;Red
    mov r11b, byte ptr [rax + 2]; R
    mov byte ptr [rsp + rsi + 18], r11b ; copy to chanR[k] on the stack (offset 18)
    
    inc rsi ; k++
    inc rbx ; dx++
    jmp LoopDX
NextDY:
    inc r15 ; dy++
    jmp LoopDY
NeighborsDone:
    ; 9 values in chanB, chanG, chanR on the stack
    ; Sorting each channel with sort function

    ; Sorting Blue channel (rsp + 0)
    lea rdi, [rsp] ; pointer to chanB
    call BubbleSort9

    ; Sorting Green channel (rsp + 9)
    lea rdi, [rsp + 9] ; pointer to chanG
    call BubbleSort9

    ; Sorting Red channel (rsp + 18)
    lea rdi, [rsp + 18] ; pointer to chanR
    call BubbleSort9

    ; Storing median values to output pixel
    ; output = out + y * stride + x * 3
    mov rax, r13 ; y
    imul rax, r10 ; y * stride
    mov rbx, r14 ; x
    imul rbx, 3 ; x * 3
    add rax, rbx ; y offset + x offset
    add rax, rdx ; out + offset, rax - output pixel address
    ; Store median values
    mov bl, byte ptr [rsp + 4] ; median Blue (chanB[4])
    mov byte ptr [rax], bl ; store Blue
    mov bl, byte ptr [rsp + 9 + 4] ; median Green (chanG[4])
    mov byte ptr [rax + 1], bl ; store Green
    mov bl, byte ptr [rsp + 18 + 4] ; median Red (chanR[4])
    mov byte ptr [rax + 2], bl ; store Red

    ; Next x
    inc r14d ; x++
    jmp LoopX
NextY:
    inc r13d ; y++
    jmp LoopY
EndLoopY:
    add rsp, 32 ; deallocate stack space
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
; ---------------------------------------------------------------
; BubbleSort9 - sorts 9 bytes pointed by RDI in ascending order
; void BubbleSort9(byte* arr)
; destroys: RAX, RBX, RCX, RDX
; ---------------------------------------------------------------
BubbleSort9 PROC
    push rdx
    mov cx, 8 ; outer loop counter (n-1)
OuterSort:
    mov rdx, rdi ; rdx - pointer to array start
    mov al, cl ; inner loop counter
InnerSort:
    mov ah, byte ptr [rdx] ; load arr[i]
    mov bl, byte ptr [rdx + 1] ; load arr[i+1]
    cmp ah, bl
    jbe NoSwap ; Swap arr[i] and arr[i+1] if arr[i] > arr[i+1]
    ; Swap
    mov byte ptr [rdx], bl
    mov byte ptr [rdx + 1], ah
NoSwap:
    inc rdx ; move to next element
    dec al
    jnz InnerSort
    dec cx
    jnz OuterSort
    pop rdx
    ret
BubbleSort9 ENDP
; Macro for sorting two vector registers
; After execution, the lower register contains the smaller values
SORT_VEC MACRO REG1, REG2
    movdqa xmm15, REG1 ; copy REG1 to xmm15
    pminub REG1, REG2  ; REG1 = min(REG1, REG2)
    pmaxub REG2, xmm15 ; REG2 = max(old REG1, REG2)
ENDM

_TEXT ENDS
END

	
