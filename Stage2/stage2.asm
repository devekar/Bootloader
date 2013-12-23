
bits	16
org 0x500
jmp	main	

%include "FloppyIO.inc"
%include "stdio.inc"
%include "Gdt.inc"			
%include "A20.inc"
%include "common.inc"


GDT_A20Msg db 0x0D, 0x0A, "GDT and A20 [OK]", 0x00
BootMsg db 0x0D, 0x0A, "Kernel boot sector", 0x00
SetupMsg db 0x0D, 0x0A, "Kernel setup", 0x00
LoadingMsg db 0x0D, 0x0A, "Loaded KERNEL...", 0x00
RealMsg db 0x0D, 0x0A, "Back to real mode", 0x00
ProceedMsg db 0x0D, 0x0A, "Copy complete", 0x00
ProgressMsg db "-", 0x00
msgFailure db 0x0D, 0x0A, "*** FATAL: MISSING KRNL.SYS. Press Any Key to Reboot", 0x0D, 0x0A, 0x0A, 0x00
cmd_line	db	'root=/dev/sdb init=/sbin/init', 0
cmd_length	equ	$ - cmd_line



;*******************************************************
;	STAGE 2 ENTRY POINT
;	-Install GDT
;	- Enable A20
;	- Load Root dir and FATs
;	- Find Kernel image and load
;	- Enter Pmode
;	- Copy Kernel image to 1MB
;	- Jump to Kernel
;*******************************************************
main:
	;mov BYTE [bsDriveNumber], dl		; save boot drive number
	
	;   Setup segments and stack	
	cli	
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	ax, 0x0			; stack begins at 0x9000-0xffff
	mov	ss, ax
	mov	sp, 0xFFFF
	sti				

	; Install our GDT	
	call	InstallGDT		
	; Enable A20
	call	EnableA20_KKbrd_Out

	mov		si, GDT_A20Msg
	call	Puts16

; Read the kernel boot sector	
LOAD_KERNEL_BOOT:	
	xor     cx, cx
	xor     dx, dx

	mov     ax,  KERNEL_BASE
	mov     es, ax                              
	mov     bx,  KERNEL_BOOT_OFFSET
	
	mov		ax, 0x1  				  ; num of sectors to read into CX
	xchg	ax, cx
	mov		ax, KERNEL_BOOT_SECTOR  	  ; Starting sector on disk in AX
	call    ReadSectors
	
	mov	si, BootMsg
	call	Puts16

	
LOAD_KERNEL_SETUP:	
	xor     cx, cx
	xor     dx, dx

	mov     ax,  KERNEL_BASE
	mov     es, ax                              
	
	xor 	ax, ax
	mov		al, [es:SETUP_SECTORS_OFFSET]  ; num of sectors to read into CX
	xchg	ax, cx
	
	mov     bx, KERNEL_SETUP_OFFSET	
	mov		ax, KERNEL_SETUP_SECTOR  	; Starting sector on disk in AX
	mov		word [CurrentSector], ax
	add		word [CurrentSector], cx
	call    ReadSectors
	
	mov		si, SetupMsg
	call	Puts16

	

PROTECTED_MODE:
	cli
	mov	eax, cr0			; set bit 0 in cr0
	or	eax, 1
	mov	cr0, eax
	
	jmp	CODE_DESC:PROTECTED_INIT	; far jump to fix CS. Code selector is 0x8
									; interrupts not enabled

bits 32
PROTECTED_INIT:				; Setup registers		
	mov	ax, DATA_DESC		; set data segments to data selector (0x10)
	mov	ds, ax
	mov	ss, ax
	mov	es, ax
	mov	esp, 90000h			; stack begins from 90000h
	
	xor al, al
	cmp byte [CopyStart], al
	je CopyToHigh		; Has copied from disk before,need to move it to High Memory
	
	; Prepare for copying, set CopyStart to 0, and jump for copying from disk
	;mov eax, DATA_SIZE
	mov eax, dword [es:0x101f4]	; Offset for protected mode code size in 16 byte paras
	shl eax, 4
	mov dword [ProtectedKernelSize], eax
	xor al, al
	mov byte [CopyStart], al
	jmp SectorsCopyRemaining

	
	
		; Copy kernel to 1MB		
CopyToHigh:
	movzx	eax, word [MoveBlockSectors]	; num of sectors
	xor 	ebx, ebx						
	mov	ebx, 0x200							; bytes per sector
	mul	ebx
	mov	ebx, 4
	div	ebx									;no of movsd i.e 4-byte iterations
	cld
	mov    esi, 0x20000
	mov	edi, [CurrentPmLocation]
	mov	ecx, eax
	rep	movsd                   ; copy image to its protected mode address

	mov	ebx, 4
	mul ebx
	add dword [CurrentPmLocation], eax
	
	xor al, al
	cmp byte [CopyComplete], al
	je PROCEED				; Last piece just copied to High Mem, skip copy from disk
	
	
SectorsCopyRemaining:	
	mov eax, dword [ProtectedKernelSize]
	cmp eax, MOVE_BYTES
	jnb CalculateSizes
	
	
LastPiece:	
	mov eax, dword [ProtectedKernelSize]
	shr eax, 9						; Divide by 512
	add eax, 1						; An extra sector in case size is less than 512 bytes
	mov word [MoveBlockSectors], ax
	mov eax, 0
	mov dword [ProtectedKernelSize], eax
	
	xor al, al
	mov byte [CopyComplete], al			; Last piece to be copied, hence set flag to 0
	jmp REAL_MODE
	
	
	
CalculateSizes:
	mov eax, MOVE_SECTORS
	mov word [MoveBlockSectors], ax
	mov eax, MOVE_BYTES
	sub dword [ProtectedKernelSize], eax
	
	
REAL_MODE:	
	mov	ax, REAL_DATA_DESC
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0xFFFF
	
	jmp REAL_CODE_DESC:TO_REAL
	

TO_REAL:	
bits 16
	mov	eax, cr0		; unset bit 0 in cr0
	and	eax, 0xfffffffe
	mov	cr0, eax
	jmp 0:REAL_MODE_INIT

	
REAL_MODE_INIT:	
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	sti

	mov	si, RealMsg
	call	Puts16	

	
	
	
CopyFromDisk:
	xor     cx, cx
	xor     dx, dx

	mov     ax,  0x2000					; es:bx destination
	mov     es, ax                              
	
	mov		ax, word [MoveBlockSectors]  ; num of sectors to read into CX
	xchg	ax, cx
	
	mov     bx, 0x0						; es:bx desitination
	mov		ax, word [CurrentSector]  	; Starting sector on disk in AX
	call    ReadSectors
	
	mov 	ax, word [MoveBlockSectors] ;update current sector
	add		word [CurrentSector], ax
	
	mov	si, ProgressMsg
	call	Puts16	
	
	mov 	ax, word [MoveBlockSectors]
	mov 	ax, word [MoveBlockSectors]
	
	jmp		PROTECTED_MODE
	
	
	
	
PROCEED:
bits 32
	mov	ax, REAL_DATA_DESC
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0xFFFF
	
	jmp REAL_CODE_DESC:TO_REAL1
	
TO_REAL1:	
bits 16
	mov	eax, cr0		; unset bit 0 in cr0
	and	eax, 0xfffffffe
	mov	cr0, eax
	jmp 0:REAL_MODE_INIT1

	
REAL_MODE_INIT1:	
	xor	ax, ax
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	sti

	mov	si, ProceedMsg
	call	Puts16	
	


	 
; 0x10000 - 0x17fff	Real mode kernel
; 0x18000 - 0x1dfff	Stack and heap
; 0x1e000 - 0x1ffff	Kernel command line
; 0x20000 - 0x2fdff	temporal space for
;			protected-mode kernel

; base_ptr = 0x10000
; heap_end = 0xe000
; heap_end_ptr = heap_end - 0x200 = 0xde00
; cmd_line_ptr = base_ptr + heap_end = 0x1e000
SET_HEADERS:	
	mov     ax,  KERNEL_BASE
	mov     es, ax   
	
	mov	byte [es:0x210], 0xff		; set type_of_loader
	or	byte [es:0x211], 0x80		; set CAN_USE_HEAP
	;mov eax, INITRD_OFFSET			; initrd
	;mov dword[es:0x218], eax
	;mov eax, INITRD_SIZE
	;mov dword[es:0x21c], eax
	mov	word [es:0x224], 0xde00		; set heap_end_ptr
	mov	dword [es:0x228], 0x1e000	; set cmd_line_ptr
	cld					; copy cmd_line
	mov	si, cmd_line
	mov	di, 0xe000
	mov	cx, cmd_length
	rep	movsb

	
RUN_KERNEL:
	cli
	mov	ax, 0x1000
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	mov	sp, 0xe000
	jmp	0x1020:0

		


	cli
	hlt

