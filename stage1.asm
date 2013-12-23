; BIOS block

; Functions:
; Print 
; ReadSectors 
; LBAtoCHS
; ClustertoLBA

; MAIN:
; Set up registers
; LOAD_ROOT
; SEARCH_ROOT
; LOAD_FAT
; LOAD_STAGE2


bits 16
org 0

jmp MAIN

; BIOS Parameter Block with dummy data
;------------------------------------------
bpbOEM			db "MyLoader"		;8 
bpbBytesPerSector:  	DW 512		;2
bpbSectorsPerCluster: 	DB 1		;1
bpbReservedSectors: 	DW 1		;2
;-----------
bpbNumberOfFATs: 	DB 2			;1
bpbRootEntries: 	DW 224			;2
bpbTotalSectors: 	DW 2880			;2
bpbMedia: 		DB 0xf8  ;; 0xF1	;1
bpbSectorsPerFAT: 	DW 9			;2
bpbSectorsPerTrack: 	DW 18		;2
bpbHeadsPerCylinder: 	DW 2		;2
bpbHiddenSectors: 	DD 0			;4
;------------
bpbTotalSectorsBig:     DD 0		;4
bsDriveNumber: 	        DB 0		;1
bsUnused: 		DB 0				;1
bsExtBootSignature: 	DB 0x29		;1
bsSerialNumber:	        DD 0xa0a1a2a3	;4
bsVolumeLabel: 	        DB "MOS FLOPPY "	;11
bsFileSystem: 	        DB "FAT12   "		;8


; Print message referred by SI register
;--------------------------------------
Print:
	lodsb	
	or al, al
	jz PrintReturn
	mov ah, 0eh
	int 10h
	jmp Print
PrintReturn:
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
	;jmp FAILURE

	.SUCCESS
		mov     si, msgProgress
		call    Print
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

	

; Convert CHS to LBA
; LBA = (cluster - 2) * sectors per cluster
;--------------------------------------------
ClustertoLBA:
	sub     ax, 0x0002                          
	xor     cx, cx
	mov     cl, BYTE [bpbSectorsPerCluster]     
	mul     cx
	add     ax, WORD [datasector]               ; base data sector
	ret

	
	
	
	
	
;====================================================================
; MAIN	
;====================================================================	
MAIN:
	; Set up registers
	cli
	mov ax, 0x07c0
	mov ds, ax 
	mov es, ax
	mov fs, ax
	mov gs, ax
	
	mov     ax, 0x0000				; set the stack
    mov     ss, ax
    mov     sp, 0xFFFF
	sti
	mov BYTE [bsDriveNumber], dl		; save boot drive number
	
	mov si, msg						; print "Registers set up"
	call Print

	
; stage2_sec = 1
; stage2_num_secs = 3	
LOAD_STAGE2:
	; destination for image in memory (0050:0000)
	mov     si, msgCRLF
	call    Print

	xor     cx, cx
	xor     dx, dx

	mov     ax, 0x0050
	mov     es, ax                              
	mov     bx, 0x0000                          
	
	mov		ax, 0x3  ; num of sectors to read into CX
	xchg	ax, cx
	mov		ax, 0x1  ; Starting sector in AX
	call    ReadSectors


		  
DONE:
	mov     si, msgStage1
	call    Print
	mov 	dl, BYTE [bsDriveNumber]
	push    WORD 0x0050							; load Stage 2 address
	push    WORD 0x0000                         
	retf										; simulate function return to Stage 2

		
			
FAILURE:
	mov     si, msgFailure
	call    Print
	mov     ah, 0x00
	int     0x16                                ; wait for key press
	int     0x19                                ; reset computer

	

	absoluteSector db 0x00
    absoluteHead   db 0x00
    absoluteTrack  db 0x00
    datasector	dw 0x0000
    cluster     dw 0x0000
    ImageName   db "STAGE2  BIN"
	;BootDrive	db 0
	
	msg db "Registers setup", 0Dh, 0Ah, 0	
	msgCRLF     db 0x0D, 0x0A, 0x00   ;newline
	msgStage1 db 0x0D, 0x0A,"Stage1 complete", 0Dh, 0Ah, 0
    msgProgress db ".", 0x00
	msgLOAD_ROOT db 0x0D, 0x0A, "Root loaded", 0x0A, 0x00
    msgFailure  db 0x0D, 0x0A, "ERROR : Press Any Key to Reboot", 0x0A, 0x00
	
	times 510 - ($-$$) db 0
	DW 0xAA55