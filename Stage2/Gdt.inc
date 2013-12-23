
%ifndef __GDT_INC__
%define __GDT_INC__

bits	16

;--------------------------------
; InstallGDT - Install GDT
;--------------------------------
InstallGDT:
	cli                  ; clear interrupts
	pusha                ; save registers
	lgdt 	[toc]        ; load GDT into GDTR
	sti	                 ; enable interrupts
	popa                 ; restore registers
	ret	                 ; All done!

	
;-------------------------------
; Global Descriptor Table (GDT)
;-------------------------------
gdt_data: 
	dd 0                ; null descriptor
	dd 0 

; gdt code:	            ; code descriptor
	dw 0FFFFh           ; limit low
	dw 0                ; base low
	db 0                ; base middle
	db 10011010b        ; access
	db 11001111b        ; granularity
	db 0                ; base high

; gdt data:	            ; data descriptor
	dw 0FFFFh           ; limit low 
	dw 0                ; base low
	db 0                ; base middle
	db 10010010b        ; access
	db 11001111b        ; granularity
	db 0                ; base high

;REAL mode gdt
; gdt code:	            ; code descriptor
	dw 0FFFFh           ; limit low
	dw 0                ; base low
	db 0                ; base middle
	db 0x9e		        ; access
	db 0		        ; granularity
	db 0                ; base high

; gdt data:	            ; data descriptor
	dw 0FFFFh           ; limit low 
	dw 0                ; base low
	db 0                ; base middle
	db 0x92		        ; access
	db 0		        ; granularity
	db 0                ; base high

	
end_of_gdt:
toc: 
	dw end_of_gdt - gdt_data - 1 	; limit (Size of GDT - 1)
	dd gdt_data 					; base of GDT

%define NULL_DESC 0
%define CODE_DESC 0x8
%define DATA_DESC 0x10
%define REAL_CODE_DESC 0x18
%define REAL_DATA_DESC 0x20

bits 32
LEAVE_PROTECTED:
	mov eax, [esp]
	mov [0x3000], eax
	
	mov	ax, REAL_DATA_DESC
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0xFFFE

	mov eax, [0x3000]
	mov [esp], eax
	
	jmp REAL_CODE_DESC:DISABLE_CR0
	
DISABLE_CR0:	
bits 16
	mov	eax, cr0		; unset bit 0 in cr0
	and	eax, 0xfffffffe
	mov	cr0, eax
	jmp 0:RESET

RESET:	
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	sti

	retf
	

%endif ;__GDT_INC__




