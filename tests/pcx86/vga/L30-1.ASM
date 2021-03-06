; Demonstrates the VGA/EGA split screen in action.
;
;*********************************************************************
IS_VGA		equ	1	;set to 0 to assemble for EGA
;
VGA_SEGMENT	equ	0a000h
SCREEN_WIDTH	equ	640
SCREEN_HEIGHT	equ	350
CRTC_INDEX	equ	3d4h	;CRT Controller Index register
OVERFLOW		equ	7	;index of Overflow reg in CRTC
MAXIMUM_SCAN_LINE equ	9	;index of Maximum Scan Line register
				; in CRTC
START_ADDRESS_HIGH equ	0ch	;index of Start Address High register
				; in CRTC
START_ADDRESS_LOW equ	0dh	;index of Start Address Low register
				; in CRTC
LINE_COMPARE	equ	18h	;index of Line Compare reg (bits 7-0
				; of split screen start scan line)
				; in CRTC
INPUT_STATUS_0	equ	3dah	;Input Status 0 register
WORD_OUTS_OK	equ	1	;set to 0 to assemble for
				; computers that can't handle
				; word outs to indexed VGA registers
;*********************************************************************
; Macro to output a word value to a port.
;
OUT_WORD	macro
if WORD_OUTS_OK
	out	dx,ax
else
	out	dx,al
	inc	dx
	xchg	ah,al
	out	dx,al
	dec	dx
	xchg	ah,al
endif
	endm
;*********************************************************************
MyStack segment para stack 'STACK'
	db	512 dup (0)
MyStack ends
;*********************************************************************
Data	segment
SplitScreenLine dw	?	;line the split screen currently
				; starts after
StartAddress	dw	?	;display memory offset at which
				; scanning for video data starts
; Message displayed in split screen.
SplitScreenMsg	db	'Split screen text row #'
DigitInsert	dw	?
		db	'...$'
Data	ends
;*********************************************************************
Code	segment
	assume	cs:Code, ds:Data
;*********************************************************************
Start	proc	near
	mov	ax,Data
	mov	ds,ax
;
; Select mode 10h, 640x350 16-color graphics mode.
;
	mov	ax,0010h	;AH=0 is select mode function
				;AL=10h is mode to select,
				; 640x350 16-color graphics mode
	int	10h
;
; Put text into display memory starting at offset 0, with each row
; labelled as to number. This is the part of memory that will be
; displayed in the split screen portion of the display.
;
	mov	cx,25		;# of lines of text we'll draw into
				; the split screen part of memory
FillSplitScreenLoop:
	mov	ah,2		;set cursor location function #
	sub	bh,bh		;set cursor in page 0
	mov	dh,25
	sub	dh,cl		;calculate row to draw in
	sub	dl,dl		;start in column 0
	int	10h		;set the cursor location
	mov	al,25
	sub	al,cl		;calculate row to draw in again
	sub	ah,ah		;make the value a word for division
	mov	dh,10
	div	dh		;split the row # into two digits
	add	ax,'00'		;convert the digits to ASCII
	mov	[DigitInsert],ax ;put the digits into the text
				; to be displayed
	mov	ah,9
	mov	dx,offset SplitScreenMsg
	int	21h		;print the text
	loop	FillSplitScreenLoop
;
; Fill display memory starting at 8000h with a diagonally striped
; pattern.
;
	mov	ax,VGA_SEGMENT
	mov	es,ax
	mov	di,8000h
	mov	dx,SCREEN_HEIGHT ;fill all lines
	mov	ax,8888h	;starting fill pattern
	cld
RowLoop:
	mov	cx,SCREEN_WIDTH/8/2 ;fill 1 scan line a word at a time
    rep stosw			;fill the scan line
	ror	ax,1		;shift pattern word
	dec	dx
	jnz	RowLoop
;
; Set the start address to 8000h and display that part of memory.
;
	mov	[StartAddress],8000h
	call	SetStartAddress
;
; Slide the split screen half way up the screen and then back down
; a quarter of the screen.
;
	mov	[SplitScreenLine],SCREEN_HEIGHT-1
					;set the initial line just off
					; the bottom of the screen
	mov	cx,SCREEN_HEIGHT/2
	call	SplitScreenUp
	mov	cx,SCREEN_HEIGHT/4
	call	SplitScreenDown
;
; Now move up another half a screen and then back down a quarter.
;
	mov	cx,SCREEN_HEIGHT/2
	call	SplitScreenUp
	mov	cx,SCREEN_HEIGHT/4
	call	SplitScreenDown
;
; Finally move up to the top of the screen.
;
	mov	cx,SCREEN_HEIGHT/2-2
	call	SplitScreenUp
;
; Wait for a key press (don't echo character).
;
	mov	ah,8	;DOS console input without echo function
	int	21h
;
; Turn the split screen off.
;
	mov	[SplitScreenLine],0ffffh
	call	SetSplitScreenScanLine
;
; Wait for a key press (don't echo character).
;
	mov	ah,8	;DOS console input without echo function
	int	21h
;
; Display the memory at 0 (the same memory the split screen displays).
;
	mov	[StartAddress],0
	call	SetStartAddress
;
; Flip between the split screen and the normal screen every 10th
; frame until a key is pressed.
;
FlipLoop:
	xor	[SplitScreenLine],0ffffh
	call	SetSplitScreenScanLine
	mov	cx,10
CountVerticalSyncsLoop:
	call	WaitForVerticalSyncEnd
	loop	CountVerticalSyncsLoop
	mov	ah,0bh	;DOS character available status
	int	21h
	and	al,al	;character available?
	jz	FlipLoop ;no, toggle split screen on/off status
	mov	ah,1
	int	21h	;clear the character
;
; Return to text mode and DOS.
;
	mov	ax,0003h	;AH=0 is select mode function
				;AL=3 is mode to select, text mode
	int	10h		;return to text mode
	mov	ah,4ch
	int	21h		;return to DOS
Start	endp
;*********************************************************************
; Waits for the leading edge of the vertical sync pulse.
;
; Input: none
;
; Output: none
;
; Registers altered: AL, DX
;
WaitForVerticalSyncStart	proc	near
	mov	dx,INPUT_STATUS_0
WaitNotVerticalSync:
	in	al,dx
	test	al,08h
	jnz	WaitNotVerticalSync
WaitVerticalSync:
	in	al,dx
	test	al,08h
	jz	WaitVerticalSync
	ret
WaitForVerticalSyncStart	endp
;*********************************************************************
; Waits for the trailing edge of the vertical sync pulse.
;
; Input: none
;
; Output: none
;
; Registers altered: AL, DX
;
WaitForVerticalSyncEnd	proc	near
	mov	dx,INPUT_STATUS_0
WaitVerticalSync2:
	in	al,dx
	test	al,08h
	jz	WaitVerticalSync2
WaitNotVerticalSync2:
	in	al,dx
	test	al,08h
	jnz	WaitNotVerticalSync2
	ret
WaitForVerticalSyncEnd	endp
;*********************************************************************
; Sets the start address to the value specifed by StartAddress.
; Wait for the trailing edge of vertical sync before setting so that
; one half of the address isn't loaded before the start of the frame
; and the other half after, resulting in flicker as one frame is
; displayed with mismatched halves. The new start address won't be
; loaded until the start of the next frame; that is, one full frame
; will be displayed before the new start address takes effect.
;
; Input: none
;
; Output: none
;
; Registers altered: AX, DX
;
SetStartAddress proc	near
	call	WaitForVerticalSyncEnd
	mov	dx,CRTC_INDEX
	mov	al,START_ADDRESS_HIGH
	mov	ah,byte ptr [StartAddress+1]
	cli		;make sure both registers get set at once
	OUT_WORD
	mov	al,START_ADDRESS_LOW
	mov	ah,byte ptr [StartAddress]
	OUT_WORD
	sti
	ret
SetStartAddress endp
;*********************************************************************
; Sets the scan line the split screen starts after to the scan line
; specified by SplitScreenLine.
;
; Input: none
;
; Output: none
;
; All registers preserved
;
SetSplitScreenScanLine	proc	near
	push	ax
	push	cx
	push	dx
;
; Wait for the leading edge of the vertical sync pulse. This ensures
; that we don't get mismatched portions of the split screen setting
; while setting the two or three split screen registers (register 18h
; set but register 7 not yet set when a match occurs, for example),
; which could produce brief flickering.
;
	call	WaitForVerticalSyncStart
;
; Set the split screen scan line.
;
	mov	dx,CRTC_INDEX
	mov	ah,byte ptr [SplitScreenLine]
	mov	al,LINE_COMPARE
	cli		;make sure all the registers get set at once
	OUT_WORD	;set bits 7-0 of the split screen scan line
	mov	ah,byte ptr [SplitScreenLine+1]
	and	ah,1
	mov	cl,4
	shl	ah,cl	;move bit 8 of the split split screen scan
			; line into position for the Overflow reg
	mov	al,OVERFLOW
if IS_VGA
;
; The Split Screen, Overflow, and Line Compare registers all contain
; part of the split screen start scan line on the VGA. We'll take
; advantage of the readable registers of the VGA to leave other bits
; in the registers we access undisturbed.
;
	out	dx,al	;set CRTC Index reg to point to Overflow
	inc	dx	;point to CRTC Data reg
	in	al,dx	;get the current Overflow reg setting
	and	al,not 10h ;turn off split screen bit 8
	or	al,ah	;insert the new split screen bit 8
			; (works in any mode)
	out	dx,al	;set the new split screen bit 8
	dec	dx	;point to CRTC Index reg
	mov	ah,byte ptr [SplitScreenLine+1]
	and	ah,2
	mov	cl,3
	ror	ah,cl	;move bit 9 of the split split screen scan
			; line into position for the Maximum Scan
			; Line register
	mov	al,MAXIMUM_SCAN_LINE
	out	dx,al	;set CRTC Index reg to point to Maximum
			; Scan Line
	inc	dx	;point to CRTC Data reg
	in	al,dx	;get the current Maximum Scan Line setting
	and	al,not 40h ;turn off split screen bit 9
	or	al,ah	;insert the new split screen bit 9
			; (works in any mode)
	out	dx,al	;set the new split screen bit 9
else
;
; Only the Split Screen and Overflow registers contain part of the
; Split Screen start scan line and need to be set on the EGA.
; EGA registers are not readable, so we have to set the non-split
; screen bits of the Overflow register to a preset value, in this
; case the value for 350-scan-line modes.
;
	or	ah,0fh	;insert the new split screen bit 8
			; (only works in 350-scan-line EGA modes)
	OUT_WORD	;set the new split screen bit 8
endif
	sti
	pop	dx
	pop	cx
	pop	ax
	ret
SetSplitScreenScanLine	endp
;*********************************************************************
; Moves the split screen up the specified number of scan lines.
;
; Input: CX = # of scan lines to move the split screen up by
;
; Output: none
;
; Registers altered: CX
;
SplitScreenUp	proc	near
SplitScreenUpLoop:
	dec	[SplitScreenLine]
	call	SetSplitScreenScanLine
	loop	SplitScreenUpLoop
	ret
SplitScreenUp	endp
;*********************************************************************
; Moves the split screen down the specified number of scan lines.
;
; Input: CX = # of scan lines to move the split screen down by
;
; Output: none
;
; Registers altered: CX
;
SplitScreenDown proc	near
SplitScreenDownLoop:
	inc	[SplitScreenLine]
	call	SetSplitScreenScanLine
	loop	SplitScreenDownLoop
	ret
SplitScreenDown endp
;*********************************************************************
Code	ends
	end	Start
