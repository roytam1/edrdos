; LFN.ASM - Functions for Long Filename support
;
; This file is part of
; The DR-DOS/OpenDOS Enhancement Project - http://www.drdosprojects.de
; Copyright (c) 2002-2005 Udo Kuhnt

	include	bdos.equ
	include	fdos.equ

BDOS_CODE	cseg	byte

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

BDOS_DATA	dseg	word

	extrn	dcnt:word

