; LFN.ASM - Functions for Long Filename and 64-bit file size support
;
; This file is part of
; The DR-DOS/OpenDOS Enhancement Project - http://www.drdosprojects.de
; Copyright (c) 2002-2006 Udo Kuhnt

	include	bdos.equ
	include	fdos.equ
	include	pcmode.equ
	include doshndl.def

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

	Public	func71
func71:
	cmp	al,42h			; function 7142h?
	 je	func7142		; yes
func71_error:
	mov	ax,7100h		; function not supported
	call	return_AX_CLC
	clc
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
	lds	bp,int21regs_ptr
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
	add	es:DHNDL_POSLO[bx],ax
	mov	[si],ax			; and store new position as result
	mov	ax,2[si]
	adc	es:DHNDL_POSHI[bx],ax
	mov	2[si],ax
	mov	ax,4[si]
	adc	es:DHNDL_POSXLO[bx],ax
	mov	4[si],ax
	mov	ax,6[si]
	adc	es:DHNDL_POSXHI[bx],ax
	mov	6[si],ax
	jmps	f7142_40

f7142_30:				; mode 2: relative to end of file
	mov	ax,[si]			; add 64-bit offset to file size
	add	es:DHNDL_SIZELO[bx],ax
	mov	es:DHNDL_POSLO[bx],ax	; and store as new position
	mov	[si],ax			; and result
	mov	ax,2[si]
	adc	es:DHNDL_SIZEHI[bx],ax
	mov	es:DHNDL_POSHI[bx],ax
	mov	2[si],ax
	mov	ax,4[si]
	adc	es:DHNDL_SIZEXLO[bx],ax
	mov	es:DHNDL_POSXLO[bx],ax
	mov	4[si],ax
	mov	ax,6[si]
	adc	es:DHNDL_SIZEXHI[bx],ax
	mov	es:DHNDL_POSXHI[bx],ax
	mov	6[si],ax
f7142_40:
	xor	ax,ax
	call	return_AX_CLC
	clc
	ret

f7142_dev:
	ret

BDOS_DATA	dseg	word

	extrn	dcnt:word

PCMODE_DATA	dseg	word

	extrn	int21regs_ptr:dword
