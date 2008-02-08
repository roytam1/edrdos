; LFN.ASM - Functions for Long Filename and 64-bit file size support
;
; This file is part of
; The DR-DOS/OpenDOS Enhancement Project - http://www.drdosprojects.de
; Copyright (c) 2002-2008 Udo Kuhnt

	include	bdos.equ
	include	fdos.equ
	include	pcmode.equ
	include doshndl.def
	include	lfn.equ
	include	fdos.def

BDOS_CODE	cseg	word

	extrn	rd_pcdir:near
	extrn	flush_dirbuf:near

;Entry:		DS:BX = pointer to dir entry
;
;Exit:		carry flag set if LFN entry
	Public	is_lfn
is_lfn:
	cmp	DATTS[bx],DA_LFN	; attribute combination of LFN entry?
	 jne	is_lfn10		; no, must something else
	cmp	word ptr BLOCK1[bx],0	; no cluster chain?
	 jne	is_lfn10		; perhaps it is a Delwatch entry
	stc				; it is probably a Long Filename
	jmps	is_lfn20
is_lfn10:
	clc				; no LFN entry
is_lfn20:
	ret

	Public	del_lfn
del_lfn:
	push	dcnt			; save dir count
del_lfn10:
	cmp	dcnt,0			; first entry in dir?
	 je	del_lfn20		; then no LFN can exist before it
	dec	dcnt			; point dir count to previous entry
	dec	dcnt
	call	rd_pcdir		; read dir entry
	mov	bx,ax
	call	is_lfn			; check if it is a long filename
	 jnc	del_lfn20		; no further LFN entries, done
	mov	DNAME[bx],0e5h		; else mark this entry as deleted
	call	flush_dirbuf		; and copy it to the buffer
	jmps	del_lfn10		; repeat with next entry
del_lfn20:
	pop	dcnt			; restore dir count
	dec	dcnt
	call	rd_pcdir		; and old dir entry
	ret

PCM_CODE	cseg	byte
	extrn	return_AX_CLC:near
	extrn	vfy_dhndl_ptr_AX:near
	extrn	check_handle:near
	extrn	redir_dhndl_offer:near
	extrn	verify_handle:near
	extrn	mul32:near
	extrn	mul64:near
	extrn	dos_entry:near

	Public	func71
func71:
	cmp	al,42h			; function 7142h?
	 je	func7142		; yes
	cmp	al,0a6h			; function 71a6h?
	 jne	func71_a7
	jmp	func71a6
func71_a7:
	cmp	al,0a7h			; function 71a7h?
	 jne	func71_error
	jmp	func71a7		; yes
func71_error:
	mov	ax,7100h		; function not supported
	push	ds
	lds	bp,int21regs_ptr	; set carry flag
	or	ds:reg_FLAGS[bp],CARRY_FLAG
	pop	ds
	stc
	ret

func7142:
	mov	ax,bx
	call	vfy_dhndl_ptr_AX	; check file handle number
	call	redir_dhndl_offer
	test	es:DHNDL_ATTR[bx],DHAT_DEV
	 jz	f7142_05
	jmp	f7142_dev		; skip if character device
f7142_05:
	call	check_handle		; check if valid file handle
	push	ds
	lds	bp,int21regs_ptr	; DS:SI -> QWORD for position offset and result
	mov	ax,ds:reg_CX[bp]	; AL = original CL
	mov	si,ds:reg_DX[bp]
	mov	ds,ds:reg_DS[bp]
	or	al,al
	 je	f7142_10		; seek from beginning
	dec	al
	 je	f7142_20		; seek from current position
	dec	al
	 je	f7142_30		; seek from end
	mov	ax,1			; error: invalid function number
	pop	ds
	push	ds
	lds	bp,int21regs_ptr	; set carry flag
	or	ds:reg_FLAGS[bp],CARRY_FLAG
	pop	ds
	stc
	ret

f7142_10:				; mode 0: set absolute position
	mov	ax,[si]			; copy 64-bit offset to position
	mov	es:DHNDL_POSLO[bx],ax
	mov	ax,2[si]
	mov	es:DHNDL_POSHI[bx],ax
	mov	ax,4[si]
	mov	es:DHNDL_POSXLO[bx],ax
	mov	ax,6[si]
	mov	es:DHNDL_POSXHI[bx],ax
	jmps	f7142_40

f7142_20:				; mode 1: relative to current position
	mov	ax,[si]			; add 64-bit offset to position
	add	ax,es:DHNDL_POSLO[bx]
	mov	es:DHNDL_POSLO[bx],ax
	mov	[si],ax			; and store new position as result
	mov	ax,2[si]
	adc	ax,es:DHNDL_POSHI[bx]
	mov	2[si],ax
	mov	ax,4[si]
	adc	ax,es:DHNDL_POSXLO[bx]
	mov	4[si],ax
	mov	ax,6[si]
	adc	ax,es:DHNDL_POSXHI[bx]
	mov	6[si],ax
	jmps	f7142_40

f7142_30:				; mode 2: relative to end of file
	mov	ax,[si]			; add 64-bit offset to file size
	add	ax,es:DHNDL_SIZELO[bx]
	mov	es:DHNDL_POSLO[bx],ax	; and store as new position
	mov	[si],ax			; and result
	mov	ax,2[si]
	adc	ax,es:DHNDL_SIZEHI[bx]
	mov	es:DHNDL_POSHI[bx],ax
	mov	2[si],ax
	mov	ax,4[si]
	adc	ax,es:DHNDL_SIZEXLO[bx]
	mov	es:DHNDL_POSXLO[bx],ax
	mov	4[si],ax
	mov	ax,6[si]
	adc	ax,es:DHNDL_SIZEXHI[bx]
	mov	es:DHNDL_POSXHI[bx],ax
	mov	6[si],ax
f7142_40:
	pop	ds
	xor	ax,ax
	call	return_AX_CLC
	clc
f7142_dev:
	ret

func71a6:
	mov	ax,bx
	call	vfy_dhndl_ptr_AX	; check file handle number
	call	redir_dhndl_offer
	test	es:DHNDL_ATTR[bx],DHAT_DEV
	 jnz	f71a6_dev		; skip if character device
	call	verify_handle		; check if valid file handle
	push	ds
	lds	bp,int21regs_ptr	; DS:DI -> buffer for Get File Info structure
	mov	di,ds:reg_DX[bp]
	mov	ds,ds:reg_DS[bp]
	push	ds			; ES:DI -> buffer, DS:BX -> DHNDL
	push	es
	pop	ds
	pop	es
	xor	ah,ah
	mov	al,DHNDL_ATTR[bx]	; file attributes
	stosw
	xor	ax,ax
	stosw
	mov	cx,8
	rep	stosw			; creation time (0 = unsupported)
					; last access time (0 = unsupported)
	push	bx
	mov	dx,DHNDL_DATE[bx]	; last write time
	mov	cx,DHNDL_TIME[bx]
	xor	bx,bx			; 0 milliseconds
	call	f71a701_entry2
	pop	bx
	add	di,8
	push	ds			; save DS
	mov	bp,sp			; restore PCM DS
	mov	ds,2[bp]
	sub	sp,25			; reserve space on stack
	mov	bp,sp
	push	es			; save registers
	push	bx
	push	di
	mov	ax,ss			; ES:DX -> buffer for media info
	mov	es,ax
	mov	dx,bp
	xor	bx,bx			; current drive
	mov	ax,6900h		; Get Volume Serial Number
	call	dos_entry
	pop	di			; restore registers
	pop	bx
	pop	es
	mov	ax,2[bp]		; volume serial number
	stosw
	mov	ax,4[bp]
	stosw
	add	sp,25			; clean up stack again
	pop	ds			; restore DS
	mov	ax,DHNDL_SIZEXLO[bx]	; file size high
	stosw
	mov	ax,DHNDL_SIZEXHI[bx]
	stosw
	mov	ax,DHNDL_SIZELO[bx]	; file size low
	stosw
	mov	ax,DHNDL_SIZEHI[bx]
	stosw
	xor	ax,ax
	inc	ax			; links to file (1)
	stosw
	dec	ax
	stosw
	stosw				; file identifier
	stosw
	stosw
	stosw
	pop	ds
	call	return_AX_CLC
	clc
f71a6_dev:
	ret

func71a7:
	cmp	bl,01			; sub function 01?
	 je	f71a701			; yes
	jmp	func71_error
f71a701:				; Convert DOS time to Windows time
	call	f71a701_entry
	xor	ax,ax
	call	return_AX_CLC
	clc
	ret

f71a701_entry:
	les	bp,int21regs_ptr	; ES:DI -> 64-bit time
	mov	di,es:REG_DI[bp]
	mov	es,es:REG_ES[bp]
f71a701_entry2:
	mov	bp,sp
	push	dx			; save date
	push	cx			; save time
	xchg	bl,bh
	xor	bh,bh
	push	bx
	cmp	dx,0			; special case - date and time zero
	 jnz	f71a701_05
	cmp	cx,0
	 jnz	f71a701_05
	xor	ax,ax			; clear buffer
	cld
	mov	cx,4
	rep	stosw
	sub	di,8
	jmp	f71a701_80
f71a701_05:
	mov	ax,dx
	and	ax,0fe00h		; bits 9-15 contain the year - 1980
	mov	cl,9
	shr	ax,cl
	add	ax,379			; AX = year - 1601
	push	ax
	mov	cx,365
	mul	cx			; convert to days (without leap days)
	mov	es:[di],ax		; save to ES:DI
	mov	es:2[di],dx
	pop	ax
	xor	bx,bx			; compute leap days in 400 years
	xor	dx,dx
	mov	cx,400
	div	cx
	cmp	al,0			; at least 400 years?
	 jz	f71a701_10		; no
	mov	bl,97			; 97 leap days
f71a701_10:
	mov	ax,dx			; divide remainder by 100
	mov	cl,100			; to compute leap days in 100 years
	div	cl
	cmp	al,3
	 jne	f71a701_20
	mov	ch,4
f71a701_20:
	push	ax
	mov	cl,24			; 24 leap days
	mul	cl
	add	bl,al
	pop	ax
	xchg	ah,al
	xor	ah,ah			; divide remainder by 4
	mov	cl,4			; to compute remaining leap days
	div	cl
	cmp	al,24
	 jne	f71a701_30
	or	ch,2
f71a701_30:
	add	bl,al			; remaining leap days in century
	cmp	ah,3
	 jne	f71a701_40
	or	ch,1
f71a701_40:
	xor	ax,ax			; add leap days
	mov	al,bl
	add	es:[di],ax
	adc	es:word ptr 2[di],0
	mov	ax,-2[bp]		; restore date
	and	ax,1e0h			; bits 5-8 contain the month
	mov	cl,5
	shr	ax,cl
	mov	bx,ax
	xor	si,si
	inc	si
	xor	dx,dx
	xor	ax,ax
f71a701_50:
	cmp	si,bx
	 je	f71a701_60
	mov	dl,cs:ndays[si]
	add	ax,dx
	inc	si
	jmps	f71a701_50
f71a701_60:
	cmp	bx,2			; has February already passed?
	 ja	f71a701_70		; no
	test	ch,1			; is the year a leap year?
	 jz	f71a701_70		; no
	cmp	ch,3			; 100/400-years rule
	 je	f71a701_70		; 100 but not 400, no leap year
	inc	ax			; yes, add one leap day
f71a701_70:
	mov	dx,-2[bp]		; restore date
	and	dx,1fh			; bits 0-4 contain the days
	add	ax,dx			; AX = days in year
	dec	ax			; minus one for the first day in 1601
	add	es:[di],ax		; date converted to days
	adc	es:word ptr 2[di],0

	push	es:word ptr 2[di]	; number of days
	push	es:word ptr [di]
	xor	ax,ax
	push	ax
	mov	ax,43200		; 2-seconds per day
	push	ax
	sub	sp,8			; reserve space on stack
	call	mul32			; convert to 2-seconds
	pop	es:word ptr [di]	; save subtotal
	pop	es:word ptr 2[di]
	pop	es:word ptr 4[di]
	pop	es:word ptr 6[di]
	add	sp,8			; clean up stack again
	mov	ax,-4[bp]		; restore time
	and	ax,0f800h		; bits 11-15 contain the hours
	mov	cl,11
	shr	ax,cl
	mov	cx,1800
	mul	cx			; convert to 2-seconds
	add	es:[di],ax		; and add subtotal
	adc	es:2[di],dx
	adc	es:word ptr 4[di],0
	adc	es:word ptr 6[di],0
	mov	ax,-4[bp]		; restore time
	and	ax,7e0h			; bits 5-10 contain the minutes
	mov	cl,5
	shr	ax,cl
	mov	cl,30
	mul	cl			; convert to 2-seconds
	add	es:[di],ax		; and add subtotal
	adc	es:2[di],dx
	adc	es:word ptr 4[di],0
	adc	es:word ptr 6[di],0
	mov	ax,-4[bp]		; restore time
	and	ax,1fh			; bits 0-4 contain the 2-seconds
	add	es:[di],ax		; and add subtotal
	adc	es:2[di],dx
	adc	es:word ptr 4[di],0
	adc	es:word ptr 6[di],0
f71a701_80:
	push	es:word ptr 6[di]	; number of 2-seconds
	push	es:word ptr 4[di]
	push	es:word ptr 2[di]
	push	es:word ptr [di]
	xor	ax,ax
	push	ax
	push	ax
	mov	ax,131h			; 1312d00h = 20000000 100-nanoseconds
	push	ax
	mov	ax,2d00h
	push	ax
	sub	sp,16			; reserve space on stack
	call	mul64			; convert to 100-nanoseconds
	pop	es:word ptr [di]	; save subtotal
	pop	es:word ptr 2[di]
	pop	es:word ptr 4[di]
	pop	es:word ptr 6[di]
	add	sp,24			; clean up stack again
	xor	ax,ax			; centiseconds
	push	ax
	push	word ptr -6[bp]
	mov	ax,1			; 186A0h = 100000 100-nanoseconds
	push	ax
	mov	ax,86a0h
	push	ax
	sub	sp,8			; reserve space on stack
	call	mul32
	pop	ax
	pop	dx
	add	sp,12			; clean up stack again
	add	es:[di],ax		; and add to result
	adc	es:2[di],dx
	adc	es:word ptr 4[di],0
	adc	es:word ptr 6[di],0
	add	sp,6
	ret

ndays	db	31,28,31,30,31,30,31,31,30,31,30,31


BDOS_DATA	dseg	word

	extrn	dcnt:word

PCMODE_DATA	dseg	word

	extrn	int21regs_ptr:dword
