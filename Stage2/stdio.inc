
%ifndef __STDIO_INC__
%define __STDIO_INC__


;---------------------------------------
;	Puts16 - Print string in Real mode
;---------------------------------------
bits	16

Puts16:
		pusha				
.Loop1:
		lodsb				
		or	al, al			
		jz	Puts16Done		
		mov	ah, 0eh			
		int	10h				
		jmp	.Loop1			
Puts16Done:
		popa				
		ret				


;==========================================================		
;	 32 Bit VGA (Mode 7) routines
;==========================================================

bits 32

%define		VIDMEM	0xB8000			
%define		COLS	80
%define		COLS_END 79
%define		LINES	25
%define		CHAR_ATTRIB 18			; green text on blue background

_CurX db 0					; current x/y location
_CurY db 0


;----------------------------------------------------
;	Putch32 - Prints a character to screen 
;	BL => Character to print
;-----------------------------------------------------

Putch32:
	pusha		
	mov	edi, VIDMEM		; get pointer to video memory
	xor	eax, eax

	; Current Position = X + Y*ScreenWidth
	mov	ecx, COLS*2		
	mov	al, byte [_CurY]	
	mul	ecx
	push eax

	mov	al, byte [_CurX]	
	mov	cl, 2
	mul	cl
	pop	ecx
	add	eax, ecx

	; Add offset to base address of Video memory
	xor	ecx, ecx
	add	edi, eax

	; Goto next row if char is newline
	cmp	bl, 0x0A
	je	.Row			

	mov	dl, bl			; Get character
	mov	dh, CHAR_ATTRIB		; the character attribute
	mov	word [edi], dx		; write to video display

	;  Update next position        
	inc	byte [_CurX] 
	cmp	byte [_CurX], COLS		; are we at the end of the line?
	je	.Row
	jmp	.done
	
.Row:
	mov	byte [_CurX], 0		; go back to col 0
	inc	byte [_CurY]		; go to next row

.done:
	popa
	ret

	
;-------------------------------------------------
;	Puts32 - Prints a string
;	EBX = address of string to print
;-------------------------------------------------

Puts32:
	pusha
	push ebx 
	pop	edi 		; move string address from EBX to EDI

.loop:
	mov	bl, byte [edi]		; get next character
	cmp	bl, 0			; is it Null char?
	je	.done
	call	Putch32
	inc	edi			; go to next character
	jmp	.loop

.done:
	;   Update hardware cursor      
	mov	bh, byte [_CurY]
	mov	bl, byte [_CurX]
	call MovCur	

	popa
	ret

	
;-------------------------------------------------
;	MoveCur - Update hardware cursor
;	bh = Y pos
;	bl = x pos
;--------------------------------------------------
bits 32

MovCur:
	pusha
	xor	eax, eax
	mov	ecx, COLS
	mov	al, bh			; get y pos
	mul	ecx				; y*COLS
	add	al, bl			; add x
	mov	ebx, eax

	; Set low byte index to VGA register 0x03D4
	mov	al, 0x0f
	mov	dx, 0x03D4
	out	dx, al

	mov	al, bl
	mov	dx, 0x03D5
	out	dx, al			; low byte

	;   Set high byte index to VGA register 0x03D5
	xor	eax, eax
	mov	al, 0x0e
	mov	dx, 0x03D4
	out	dx, al

	mov	al, bh
	mov	dx, 0x03D5
	out	dx, al			; high byte

	popa
	ret

	
;----------------------------------------------------
;	ClrScr32 - Clears screen by placing ' ' all over
;----------------------------------------------------
bits 32

ClrScr32:
	pusha
	cld
	mov	edi, VIDMEM
	mov	cx, 2000
	mov	ah, CHAR_ATTRIB
	mov	al, ' '	
	rep	stosw

	mov	byte [_CurX], 0
	mov	byte [_CurY], 0
	popa
	ret

;---------------------------------------------
;	GotoXY - Set current X/Y location
;	AL=X position
;	AH=Y position
;---------------------------------------------
bits 32

GotoXY:
	pusha
	mov	[_CurX], al
	mov	[_CurY], ah
	popa
	ret




%endif ;__STDIO_INC__
