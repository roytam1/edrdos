; DOS7.ASM - Functions for DOS 7 compatibility
;
; This file is part of
; The DR-DOS/OpenDOS Enhancement Project - http://www.drdosprojects.de
; Copyright (c) 2002-2004 Udo Kuhnt

	include	pcmode.equ
	include	fdos.equ
	include	dos7.equ

PCM_CODE	cseg	byte

	extrn	get_path_drive:near
	extrn	fdos_diskinfo:near
	extrn	mul32:near

	public	func73
func73:
	cmp	al,3			; function 7303h?
	 je	func7303		; yes
	mov	ax,7300h		; function not supported
	clc
	ret

;	*************************************
;	***    DOS Function 7303h         ***
;	***    Extended Free Disk Space   ***
;	*************************************
;
;Entry:	DS:DX	= pointer to ASCIZ string for path
;	ES:DI	= pointer to buffer for extended free space structure
;	CX	= length of buffer
;Exit:	ES:DI	preserved
;	CF clear
;Error:	CF set
;	AX	= error code

	Public	func7303
func7303:
	les	bp,int21regs_ptr	; ES:DI = pointer to drive path
	mov	di,es:reg_DX[bp]
	mov	es,es:reg_DS[bp]
	call	get_path_drive
	 jnc	f7303_10
	mov	ax,0fh			; return 0fh (invalid drive)
	stc
	jmp	f7303_exit		; error if invalid drive
f7303_10:
	mov	dl,al			; drive number
	inc	dl
	xor	dh,dh
	call	fdos_DISKINFO		; get drive info, ES:BX -> DDSC
	 jnc	f7303_20
	mov	ax,0fh			; return 0fh (invalid drive)
	stc
	jmp	f7303_exit		; error if invalid drive
f7303_20:
	cmp	cx,FREED_LEN		; enough buffer space for data?
	 jbe	f7303_30
	mov	ax,18h			; return 18h (bad request structure length)
	stc
	jmp	f7303_exit		; no, then exit with error
f7303_30:
	push	ds
	lds	bp,int21regs_ptr	; DS:DI -> free space structure
	mov	di,ds:reg_DI[bp]
	mov	ds,ds:reg_ES[bp]
	xor	dx,dx
	mov	ax,FREED_LEN		; length of data
	mov	FREED_SIZE[di],ax
	xor	ax,ax			; structure version
	mov	FREED_VER[di],ax
	xor	ah,ah			; sector per cluster
	mov	al,es:DDSC_CLMSK[bx]	; this is minus one
	inc	ax			; so add one again
	mov	word ptr FREED_SECPCLUS[di],ax
	mov	word ptr FREED_SECPCLUS+2[di],dx
	mov	ax,es:DDSC_SECSIZE[bx]	; bytes per sector
	mov	word ptr FREED_BYTEPSEC[di],ax
	mov	word ptr FREED_BYTEPSEC+2[di],dx
	cmp	es:DDSC_DIRENT[bx],0	; is this a FAT32 drive?
	 je	f7303_40		; yes
	mov	ax,es:DDSC_FREE[bx]	; free clusters on drive (16-bit)
	mov	word ptr FREED_FREECL[di],ax
	mov	word ptr FREED_FREEPCL[di],ax
	mov	word ptr FREED_FREECL+2[di],dx
	mov	word ptr FREED_FREEPCL+2[di],dx
	mov	ax,es:DDSC_NCLSTRS[bx]	; total clusters on drive (16-bit)
	mov	word ptr FREED_NCLUSTER[di],ax
	mov	word ptr FREED_NPCLUS[di],ax
	mov	word ptr FREED_NCLUSTER+2[di],dx
	mov	word ptr FREED_NPCLUS+2[di],dx
	jmps	f7303_50
f7303_40:
	mov	ax,es:word ptr DDSC_BFREE[bx]	; free clusters on drive (32-bit)
	mov	word ptr FREED_FREECL[di],ax
	mov	word ptr FREED_FREEPCL[di],ax
	mov	ax,es:word ptr DDSC_BFREE+2[bx]
	mov	word ptr FREED_FREECL+2[di],ax
	mov	word ptr FREED_FREEPCL+2[di],ax
	mov	ax,es:word ptr DDSC_BCLSTRS[bx]	; total clusters on drive (32-bit)
	mov	word ptr FREED_NCLUSTER[di],ax
	mov	word ptr FREED_NPCLUS[di],ax
	mov	ax,es:word ptr DDSC_BCLSTRS+2[bx]
	mov	word ptr FREED_NCLUSTER+2[di],ax
	mov	word ptr FREED_NPCLUS+2[di],ax
f7303_50:
	push	word ptr FREED_FREEPCL+2[di]	; number of free physical clusters
	push	word ptr FREED_FREEPCL[di]
	push	word ptr FREED_SECPCLUS+2[di]	; number of sectors per cluster
	push	word ptr FREED_SECPCLUS[di]
	sub	sp,8			; reserve space on stack
	call	mul32			; multiply these values
	pop	ax			; to get free physical sectors
	mov	word ptr FREED_FREESEC[di],ax
	pop	ax
	mov	word ptr FREED_FREESEC+2[di],ax
	add	sp,12			; clean up the stack again
	push	word ptr FREED_NPCLUS+2[di]	; number of total physical clusters
	push	word ptr FREED_NPCLUS[di]
	push	word ptr FREED_SECPCLUS+2[di]	; number of sectors per cluster
	push	word ptr FREED_SECPCLUS[di]
	sub	sp,8			; reserve space on stack
	call	mul32			; multiply these values
	pop	ax			; to get total physical sectors
	mov	word ptr FREED_NSECS[di],ax
	pop	ax
	mov	word ptr FREED_NSECS+2[di],ax
	add	sp,12			; clean up the stack again
	pop	ds
	push	ds
	lds	bp,int21regs_ptr
	xor	ax,ax
	mov	ds:reg_AX[bp],ax	; return AX
	pop	ds
	clc
f7303_exit:
	ret
f7303_error1:
;	call	error_exit		; generate critical error
	mov	ax,0fh			; return 0fh (invalid drive)
	stc
	ret
f7303_error2:
;	call	error_exit		; generate critical error
	mov	ax,18h			; return 18h (bad request structure length)
	jmps	f7303_exit

PCMODE_DATA	dseg	word

	extrn	int21regs_ptr:dword
