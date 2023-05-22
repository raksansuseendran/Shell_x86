     name "shell"


; directive to create bin file:
#make_bin#


#load_segment=0800#
#load_offset=0000#


#al=0b#
#ah=00#
#bh=00#
#bl=00#
#ch=00#
#cl=02#
#dh=00#
#dl=00#
#ds=0800#
#es=0800#
#si=7c02#
#di=0000#
#bp=0000#
#cs=0800#
#ip=0000#
#ss=07c0#
#sp=03fe#



; this macro prints a char in al and advances
; the current cursor position:
putc    macro   char
        push    ax
        mov     al, char
        mov     ah, 0eh
        int     10h     
        pop     ax
endm


; sets current cursor position:
gotoxy  macro   col, row
        push    ax
        push    bx
        push    dx
        mov     ah, 02h
        mov     dh, row
        mov     dl, col
        mov     bh, 0
        int     10h
        pop     dx
        pop     bx
        pop     ax
endm


print macro x, y, attrib, sdat
LOCAL   s_dcl, skip_dcl, s_dcl_end
    pusha
    mov dx, cs
    mov es, dx
    mov ah, 13h
    mov al, 1
    mov bh, 0
    mov bl, attrib
    mov cx, offset s_dcl_end - offset s_dcl
    mov dl, x
    mov dh, y
    mov bp, offset s_dcl
    int 10h
    popa
    jmp skip_dcl
    s_dcl DB sdat
    s_dcl_end DB 0
    skip_dcl:    
endm




org 0000h


jmp start 

           



;==== data section =====================

; welcome message:
msg  db "MICRO OS SHELL", 0      
mousemsg  db "press any where to continue..", 0 

cmd_size        equ 20    ; size of command_buffer
command_buffer  db cmd_size dup("b")
clean_str       db cmd_size dup(" "), 0
prompt          db ">", 0       

dir1 db "c:\test1", 0
dir2 db "new", 0
dir3 db "newname", 0
file1 db "c:\test1\file1.txt", 0
file2 db "file", 0
file3 db "new.txt", 0
handle dw ?

text db ""
text_size = $ - offset text
text2 db "good morning"
text2_size = $ - offset text2

; commands:
chelp    db "help", 0
chelp_tail:
ccls     db "cls", 0
ccls_tail:
ccreate    db "create", 0
ccreate_tail:
cedit    db "edit", 0
cedit_tail:
cdel    db "del", 0
cdel_tail:
creboot  db "reboot", 0
creboot_tail:

help_msg db "The short list of supported commands:", 0Dh,0Ah
         db "help   - print out this list.", 0Dh,0Ah
         db "cls    - clear the screen.", 0Dh,0Ah
         db "reboot - reboot the machine.", 0Dh,0Ah
         db "create  - create file.", 0Dh,0Ah  
         db "edit  - write in file.", 0Dh,0Ah
         db "del   - delete file.", 0Dh,0Ah, 0

unknown  db "unknown command: " , 0    
                                    
;======================================

start:

; set data segment:
push    cs
pop     ds

; set default video mode 80x25:
mov     ah, 00h
mov     al, 03h
int     10h 


; blinking disabled for compatibility with dos/bios,
; emulator and windows prompt never blink.
mov     ax, 1003h
mov     bx, 0      ; disable blinking.
int     10h         

lea si,mousemsg
call print_string


; reset mouse and get its status:
mov ax, 0
int 33h
cmp ax, 0
jne ok


ok:

mov ax, 1
int 33h
check_mouse_buttons:
mov ax, 3
int 33h
cmp bx, 3  ; both buttons
je  hide
jmp ok

hide:
mov ax, 2  ; hide mouse cursor.
int 33h 

mov     ah, 00h
mov     al, 03h
int     10h 



; *** the integrity check  ***
cmp [0000], 0E9h
jz integrity_check_ok
integrity_failed:  
mov     al, 'F'
mov     ah, 0eh
int     10h  
; wait for any key...
mov     ax, 0
int     16h
; reboot...
mov     ax, 0040h
mov     ds, ax
mov     w.[0072h], 0000h
jmp	0ffffh:0000h	 
integrity_check_ok:
nop
; *** ok ***
              


; clear screen:
call    clear_screen
                     
                       
; print out the message:
lea     si, msg
call    print_string


eternal_loop:
call    get_command

call    process_cmd

; make eternal loop:
jmp eternal_loop


get_command proc near

; set cursor position to bottom
; of the screen:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]

gotoxy  0, al

; clear command line:
lea     si, clean_str
call    print_string

gotoxy  0, al

; show prompt:
lea     si, prompt 
call    print_string


; wait for a command:
mov     dx, cmd_size    ; buffer size.
lea     di, command_buffer
call    get_string


ret
get_command endp


process_cmd proc    near


; set es to ds
push    ds
pop     es

cld     ; forward compare.

; compare command buffer with 'help'
lea     si, command_buffer
mov     cx, chelp_tail - offset chelp   ; size of ['help',0] string.
lea     di, chelp
repe    cmpsb
je      help_command

; compare command buffer with 'cls'
lea     si, command_buffer
mov     cx, ccls_tail - offset ccls  ; size of ['cls',0] string.
lea     di, ccls
repe    cmpsb
jne     not_cls
jmp     cls_command
not_cls: 

; compare command buffer with 'edit'
lea     si, command_buffer
mov     cx, cedit_tail - offset cedit  ; size of ['cls',0] string.
lea     di, cedit
repe    cmpsb 

 

mov ah, 3ch
mov cx, 0
mov dx, offset file3
int 21h
jc processed
mov handle, ax
; seek:
mov ah, 42h
mov bx, handle
mov al, 0
mov cx, 0
mov dx, 10
int 21h
; write to file:
mov ah, 40h
mov bx, handle
mov dx, offset text
mov cx, text_size
int 21h
; seek:
mov ah, 42h
mov bx, handle
mov al, 0
mov cx, 0
mov dx, 2
int 21h
; write to file:
mov ah, 40h
mov bx, handle
mov dx, offset text2
mov cx, text2_size
int 21h
; close c:\emu8086\MyBuild\t1.txt
mov ah, 3eh
mov bx, handle
int 21h

jmp processed     
            
            
; compare command buffer with 'create'
lea     si, command_buffer
mov     cx, ccreate_tail - offset ccreate ; size of ['quit',0] string.
lea     di, ccreate
repe    cmpsb                        
jmp     cls_command

; wait for a command:
mov     dx, cmd_size    ; buffer size.
lea     di, command_buffer
call    get_string 

mov dx, offset file3
mov ah, 39h
int 21h 
jmp     processed

; compare command buffer with 'exit'
lea     si, command_buffer
mov     cx, cdel_tail - offset cdel ; size of ['exit',0] string.
lea     di, cdel
repe    cmpsb  
; wait for a command:
mov     dx, cmd_size    ; buffer size.
lea     di, command_buffer
 

mov ah, 41h
mov dx, offset dir2
int 21h
je      reboot_command

; compare command buffer with 'reboot'
lea     si, command_buffer
mov     cx, creboot_tail - offset creboot  ; size of ['reboot',0] string.
lea     di, creboot
repe    cmpsb
je      reboot_command

; ignore empty lines
cmp     command_buffer, 0
jz      processed




; if gets here, then command is
; unknown...

mov     al, 1
call    scroll_t_area

; set cursor position just
; above prompt line:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]
dec     al
gotoxy  0, al

lea     si, unknown
call    print_string

lea     si, command_buffer
call    print_string

mov     al, 1
call    scroll_t_area

jmp     processed

; +++++ 'help' command ++++++
help_command:

; scroll text area 9 lines up:
mov     al, 9
call    scroll_t_area

; set cursor position 9 lines
; above prompt line:
mov     ax, 40h
mov     es, ax
mov     al, es:[84h]
sub     al, 9
gotoxy  0, al

lea     si, help_msg
call    print_string

mov     al, 1
call    scroll_t_area

jmp     processed




; +++++ 'cls' command ++++++
cls_command:
call    clear_screen
jmp     processed







; +++ 'quit', 'exit', 'reboot' +++
reboot_command:
call    clear_screen
print 5,2,0011_1111b," please eject any floppy disks "
print 5,3,0011_1111b," and press any key to reboot... "
mov ax, 0  ; wait for any key....
int 16h

; store magic value at 0040h:0072h:
;   0000h - cold boot.
;   1234h - warm boot.
mov     ax, 0040h
mov     ds, ax
mov     w.[0072h], 0000h ; cold boot.
jmp	0ffffh:0000h	 ; reboot!



processed:
ret
process_cmd endp


; scroll all screen except last row
; up by value specified in al

scroll_t_area   proc    near

mov dx, 40h
mov es, dx  ; for getting screen parameters.
mov ah, 06h ; scroll up function id.
mov bh, 07  ; attribute for new lines.
mov ch, 0   ; upper row.
mov cl, 0   ; upper col.
mov di, 84h ; rows on screen -1,
mov dh, es:[di] ; lower row (byte).
dec dh  ; don't scroll bottom line.
mov di, 4ah ; columns on screen,
mov dl, es:[di]
dec dl  ; lower col.
int 10h

ret
scroll_t_area   endp




; get characters from keyboard and write a null terminated string 
; to buffer at DS:DI, maximum buffer size is in DX.
; 'enter' stops the input.
get_string      proc    near
push    ax
push    cx
push    di
push    dx

mov     cx, 0                   ; char counter.

cmp     dx, 1                   ; buffer too small?
jbe     empty_buffer            ;

dec     dx                      ; reserve space for last zero.


;============================
; eternal loop to get
; and processes key presses:

wait_for_key:

mov     ah, 0                   ; get pressed key.
int     16h

cmp     al, 0Dh                 ; 'return' pressed?
jz      exit


cmp     al, 8                   ; 'backspace' pressed?
jne     add_to_buffer
jcxz    wait_for_key            ; nothing to remove!
dec     cx
dec     di
putc    8                       ; backspace.
putc    ' '                     ; clear position.
putc    8                       ; backspace again.
jmp     wait_for_key

add_to_buffer:

        cmp     cx, dx          ; buffer is full?
        jae     wait_for_key    ; if so wait for 'backspace' or 'return'...

        mov     [di], al
        inc     di
        inc     cx
        
        ; print the key:
        mov     ah, 0eh
        int     10h

jmp     wait_for_key

exit:

; terminate by null:
mov     [di], 0

empty_buffer:

pop     dx
pop     di
pop     cx
pop     ax
ret
get_string      endp




; print a null terminated string at current cursor position, 
; string address: ds:si
print_string proc near
push    ax      ; store registers...
push    si      ;

next_char:      
        mov     al, [si]
        cmp     al, 0
        jz      printed
        inc     si
        mov     ah, 0eh ; teletype function.
        int     10h
        jmp     next_char
printed:

pop     si      ; re-store registers...
pop     ax      ;

ret
print_string endp



; clear the screen by scrolling entire screen window,
; and set cursor position on top.
; default attribute is set to white on blue.
clear_screen proc near
        push    ax      ; store registers...
        push    ds      ;
        push    bx      ;
        push    cx      ;
        push    di      ;

       mov ah,9
       mov cx,1000h 
       mov al,00h
       mov bl,74h
       int 10h

        ; set cursor position to top
        ; of the screen:
        mov     bh, 0   ; current page.
        mov     dl, 0   ; col.
        mov     dh, 0   ; row.
        mov     ah, 02
        int     10h

        pop     di      ; re-store registers...
        pop     cx      ;
        pop     bx      ;
        pop     ds      ;
        pop     ax      ;

        ret
clear_screen endp



