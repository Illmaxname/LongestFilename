.386
data segment use16
BootSector	db 512 dup (0)
PathArr	db 5 dup (11 dup (' '))
PathInp db 57, 58 dup (0)
LDnum	db ?
DirNums	db ?
ClusterSz	db ?
RezSects	dw ? ;fat-table begin
RootSz	dw ?
RootSzCount	dw ?
FatSz	dw ?
RootLoc	dd ?
CurrentSect	db 512 dup (?)
Dir1Loc	dw ?
Dir2Loc dw ?
Dir3Loc	dw ?
Dir4Loc	dw ?
Dir5Loc	dw ?
DirCounter	db 0
FinalLoc	dd ?
LastRecordFl	db 0
InSectCounter	db 16
RecLetCounter	db 0
MaxLong	db 0
BootSPaket	dd 0
	dw 1
	dw BootSector
	dw data
DirSPaket	dd ?
	dw 1
	dw CurrentSect
	dw data
Paket	dd ?
	dw 1
	dw CurrentSect
	dw data
LName	db 50 dup (?)
LNameMax	db 50 dup (?)

MessInput	db 0Dh, 0Ah, 'Enter directory path: $'
ErMessLD	db 0Dh, 0Ah, 'Wrong root letter! $'
ErReadingBoot	db 0Dh, 0Ah, 'Boot sector reading error! $'
ErReadingSect	db 0Dh, 0Ah, 'Sector reading error! $'
ErFS	db 0Dh, 0Ah, 'Unknown file system! $'
ErNotFound db 0Dh, 0Ah, 'Directory not found! $'
NewLine db 0Dh, 0Ah, '$'
MessOut	db 0Dh, 0Ah, 'Most long name: $'
MessNoFiles	db 0Dh, 0Ah, 'Files not found! $'

data ends

print macro mess
	mov ah, 9h
	lea dx, mess
	int 21h
endm

readS macro logDisk, paket
	mov al, logDisk
	mov cx, 0ffffh
	lea bx, paket
	int 25h
	pop ax
endm

code segment use16
assume cs:code, ds:data
commands: mov dx, data
	mov ds, dx

	print MessInput
	mov ah, 0Ah
	lea dx, PathInp
	int 21h

	mov dl, [PathInp+2]
	mov LDnum, dl
	lea si, LDnum
	call GetLDnum
	jnc short cs1
	print ErMessLD
	jmp final

cs1: ;creating names array
	lea si, PathInp
	lea di, PathArr
	call NameArrCreating
	
	cmp bl, 5
	ja final
	mov DirNums, bl

	;reading boot sector
	readS LDnum, BootSPaket
	jnc short cs2

	print ErReadingBoot
	jmp final

cs2:
	;checking FAT16
	lea si, ds:[BootSector+36h]
	cmp byte ptr ds:[si+4], 36h
	je short cs3

	print ErFS
	jmp final

cs3:
	mov dl, ds:[BootSector+0Dh]
	mov ClusterSz, dl

	mov dx, word ptr ds:[BootSector+0Eh]
	mov RezSects, dx

	mov dx, word ptr ds:[BootSector+11h]
	mov RootSz, dx
	mov RootSzCount, dx

	mov dx, word ptr ds:[BootSector+16h]
	mov FatSz, dx

	;calc root sect
	mov dx, FatSz
	shl dx, 1
	add dx, RezSects
	movzx eax, dx
	mov RootLoc, eax

	mov dword ptr ds:DirSPaket, eax
	lea si, Dir1Loc
	call GetDirLoc ;Dir1Loc - 1 dir cluster num
	call CalcDirLoc ;ebx - 1 dir sector num
	mov FinalLoc, ebx

	inc DirCounter
	cmp byte ptr DirNums, 0
	je short cs5

	movzx cx, byte ptr DirNums
	lea si, Dir2Loc
cs4:
	push cx
	mov dword ptr ds:DirSPaket, ebx
	push si
	call GetDirLoc
	call CalcDirLoc
	mov FinalLoc, ebx
	pop si
	add si, 2
	pop cx
	inc DirCounter
	dec cx
	cmp cx, 0
	jne short cs4 

cs5: ;finding long name file
	call GetLongName
	movzx bp, byte ptr MaxLong
	cmp bp, 0
	je short cs6
	lea si, LNameMax

	mov byte ptr ds:[si+bp], '$'
	print MessOut
	print NewLine
	print LNameMax
	jmp short final
cs6:
	print MessNoFiles

final:
	mov ah, 4Ch
	int 21h

proc GetLDnum ;input params: si - LD letter
	sub byte ptr ds:si, byte ptr 43h
	cmp byte ptr ds:si, byte ptr 0
	jl short a1
	cmp byte ptr ds:si, byte ptr 23
	jg short a1
	add byte ptr ds:si, byte ptr 2
	clc
	jmp short a2
a1:
	stc
a2:
	ret
GetLDnum endp ;output: si - LD num, CF = 1(error)

proc NameArrCreating ;input: si - input path, di - names array
	mov bp, 0	;num of letter
	mov bl, 0	;num of directory
	movzx cx, byte ptr ds:[si+1]
	add si, 5
	sub cx, 3

b1:
	cmp byte ptr ds:si, byte ptr '\'
	jne short b2

	inc bl
	add di, 11
	mov bp, 0
	jmp short b3
b2:
	mov al, ds:si
	mov ds:[di+bp], al
	inc bp
b3:
	inc si
	loop short b1

	ret
NameArrCreating endp ;output: bl - num of directories

proc GetDirLoc ;input: DirSPaket, LDnum, (InSectCounter<-16)
	push si
	mov InSectCounter, 16
c1:	
	readS LDnum, DirSPaket; boot->CurrentSect(1sector)
	jnc short c12

	print ErReadingSect
	jmp cFin
c12:
	lea si, CurrentSect
	mov bx, 0
c2:
	mov ah, byte ptr ds:[si+11]
	cmp ah, 0Fh
	je short c4

	mov eax, dword ptr ds:[si+28]
	cmp eax, 0
	jne short c4

	mov bp, 0
	lea di, PathArr
	push dx
	movzx dx, byte ptr DirCounter
	mov ax, 11
	mul dx
	add di, ax
	pop dx
	mov cx, 8
c3:
	mov al, byte ptr ds:[di+bp]
	mov ah, byte ptr ds:[si+bp]
	cmp ah, al
	jne short c4
	inc bp
	loop short c3
	jmp short c5
c4:
	add bx, 32
	add si, 32
	mov cx, RootSzCount
	dec cx
	mov RootSzCount, cx
	cmp cx, 0
	je short cNF
	mov cl, InSectCounter
	dec cl
	mov InSectCounter, cl
	cmp cl, 0
	jne short c2
	mov ecx, dword ptr DirSPaket
	inc ecx
	mov DirSPaket, ecx
	mov InSectCounter, 16
	jmp c1
c5:
	mov dx, word ptr ds:[si+26]
	pop si
	mov ds:si, dx
	jmp short cFin
cNF:
	print ErNotFound
	jmp final
cFin:
	ret
GetDirLoc endp

proc CalcDirLoc ;si - directory cluster
	mov bx, FatSz
	shl bx, 1
	add bx, 1
	mov ax, RootSz
	shr ax, 4
	add bx, ax
	movzx ax, ClusterSz
	mov cx, ds:si
	mul cx
	shl edx, 16
	and eax, 0000FFFFh
	or eax, edx
	and ebx, 0000FFFFh
	add ebx, eax
	movzx eax, ClusterSz
	shl eax, 1
	sub ebx, eax

	ret
CalcDirLoc endp ;ebx - directory sector location

proc GetLongName
	mov InSectCounter, 16
	mov edx, FinalLoc
	mov dword ptr Paket, edx
d1:
	readS LDnum, Paket
	jnc short d2
	print ErReadingSect
	jmp dFin
d2:
	lea si, CurrentSect

d3:
	cmp byte ptr ds:[si], 0
	je dFin

	cmp byte ptr ds:[si+11], 0Fh
	jne short d5

	mov dl, byte ptr ds:[si]
	cmp dl, 0E5h
	je short d5

	mov dh, dl
	and dh, 00011111b ;======dh - num of second record
	cmp dh, 1
	ja short d31
	mov LastRecordFl, 1

d31:

	mov bp, 30
	lea di, LName
	mov al, 13
	mul dh
	add di, ax
	dec di
	mov cx, 13
d4:
	cmp cx, 12
	jb short d41o
	mov dx, word ptr ds:[si+bp]
	mov byte ptr ds:[di], dl
	jmp short d43
d41o:
	cmp cx, 11
	jne short d41
	sub bp, 2
d41:
	cmp cx, 6
	jb short d42o
	mov dx, word ptr ds:[si+bp]
	mov byte ptr ds:[di], dl
	jmp short d43
d42o:
	cmp cx, 5
	jne short d42
	sub bp, 3
d42:
	mov dx, word ptr ds:[si+bp]
	mov byte ptr ds:[di], dl
d43:
	cmp word ptr ds:[si+bp], 0FFh
	je short d43o
	inc RecLetCounter
d43o:
	dec bp
	dec bp
	dec di
	
	loop short d4
d5:
	add si, 32
	cmp LastRecordFl, 1
	jne short d6
	add si, 32
	mov LastRecordFl, 0
	mov bl, RecLetCounter
	mov RecLetCounter, 0
	cmp bl, MaxLong
	jb short d6
	mov MaxLong, bl
	movzx cx, bl
	call Copy

d6:
	mov cl, InSectCounter
	dec cl
	mov InSectCounter, cl
	cmp cl, 0
	jne d3
	mov ecx, dword ptr Paket
	inc ecx
	mov Paket, ecx
	mov InSectCounter, 16
	jmp d1
dFin:
	ret
GetLongName endp

proc Copy
	push di
	push si
	push dx
	lea di, LName
	lea si, LNameMax
e1:
	mov bp, cx
	mov dl, ds:[di+bp-1]
	mov ds:[si+bp-1], dl
	loop short e1
	pop di
	pop si
	pop dx
	ret
Copy endp

code ends
	end commands
