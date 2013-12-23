
%ifndef __FLOPPY_IO_INC__
%define __FLOPPY_IO_INC__

bits	16

bsDriveNumber: 	        DB 0x80
bpbBytesPerSector:  	DW 512
bpbSectorsPerCluster: 	DB 1
bpbSectorsPerTrack: 	DW 63
bpbHeadsPerCylinder: 	DW 16



datasector  dw 0x0000
cluster     dw 0x0000

absoluteSector db 0x00
absoluteHead   db 0x00
absoluteTrack  db 0x00

msgProgress db ".", 0x00


; Print message referred by SI register
;--------------------------------------
Print1:
	lodsb	
	or al, al
	jz PrintReturn1
	mov ah, 0eh
	int 10h
	jmp Print1
PrintReturn1:
	ret


; Reads a series of sectors
; CX - Number of sectors to read
; AX - Starting sector
; ES:BX - Buffer to read to
;-----------------------------------
ReadSectors:
	.MAIN_LOOP
		mov     di, 0x0005                          ; five retries for error

	.SECTORLOOP
		push    ax
		push    bx
		push    cx
		call    LBAtoCHS                              ; convert sector to CHS

		mov     ah, 0x02                            ; BIOS read sector
		mov     al, 0x01                            ; read one sector
		mov     ch, BYTE [absoluteTrack]            
		mov     cl, BYTE [absoluteSector]           
		mov     dh, BYTE [absoluteHead]             
		mov     dl, BYTE [bsDriveNumber]            
		int     0x13                                ; invoke interrupt

		jnc     .SUCCESS                            ; test for read error
		xor     ax, ax                              ; BIOS reset disk
		int     0x13                                ; invoke interrupt
		dec     di                                  ; decrement error counter
		pop     cx
		pop     bx
		pop     ax
		jnz     .SECTORLOOP                         ; attempt to read again		
	int     0x18								  ; Cannot read disk, invoke ROM BASIC

	.SUCCESS
		mov     si, msgProgress
		call    Print1
		pop     cx
		pop     bx
		pop     ax
		add     bx, WORD [bpbBytesPerSector]        ; next buffer
		inc     ax                                  ; next sector
		loop    .MAIN_LOOP                          ; read next sector
	ret

	

; Convert LBA to CHS
; AX - LBA Address to convert
; absolute sector = (logical sector % sectors per track) + 1
; absolute head   = (logical sector / sectors per track) MOD number of heads
; absolute track  = (logical sector / sectors per track) / number of heads
;-----------------------------------------------------------------------------
LBAtoCHS:
	xor     dx, dx                              
	div     WORD [bpbSectorsPerTrack]            
	inc     dl                                   
	mov     BYTE [absoluteSector], dl
	xor     dx, dx                              
	div     WORD [bpbHeadsPerCylinder]           
	mov     BYTE [absoluteHead], dl
	mov     BYTE [absoluteTrack], al
	ret


%endif		;__FLOPPY_IO_INC__
