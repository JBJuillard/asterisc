; Hardcoded FAT12 Bootable floppy disk image
; Made by InitScreen


%define			FDSK_144
%include		"fat12macro.asm"


; VBR
;
; Sector 1 of image
[ORG			0x0000]
[BITS			16]

; BIOS Parameters Block
_bpb:
	.BS_jmpBoot:		db 0xE9							; hardcoded jump
						dw _start						;	to _start
	.BS_OEMName:		db FAT_OEMNAME					; Nom du programme qui a formaté le disque (« MSWIN4.1 » par exemple).
	.BPB_BytsPerSec:	dw FAT_BYTSPERSEC				; Nombre d'octets par secteur (512, 1 024, 2 048 ou 4 096).
	.BPB_SecPerClus:	db FAT_SECPERCLUS				; Nombre de secteurs par cluster (1, 2, 4, 8, 16, 32, 64 ou 128).
	.BPB_ResvdSecCnt:	dw RESERVED_SECTORS				; Nombre de secteurs réservés en comptant le secteur de boot (32 par défaut pour FAT32, 1 par défaut pour FAT12/16).
	.BPB_NumFATs:		db FAT_NUMFATS					; Nombre de FATs sur le disque (2 par défaut)
	.BPB_RootEntCnt:	dw ROOTDIR_ENTRIECNT			; Taille du répertoire racine en nombre d'entrées (0 par défaut pour FAT32).
	.BPB_TotSec16:		dw FAT_TOTSEC16					; Nombre total de secteurs 16-bit (0 par défaut pour FAT32).
	.BPB_Media:			db FAT_MEDIA					; Type de disque (0xF8 pour les disques durs, 0xF0 pour les disquettes).
	.BPB_FATSz16:		dw FAT_SIZE_16					; Taille d'une FAT en secteurs (0 par défaut pour FAT32).
	.BPB_SecPerTrk:		dw FAT_SECPERTRK				; Nombre de secteurs par piste.
	.BPB_NumHeads:		dw FAT_NUMHEADS					; Nombre de têtes.
	.BPB_HiddSec:		dd 0							; Secteurs cachés (0 par défaut si le disque n'est pas partitionné).
	.BPB_TotSec32:		dd 0							; Nombre total de secteurs 32-bit (Contient une valeur si le nombre total de secteurs 16-bits est égal à 0)
	.BS_DrvNum:			db 0x00							; Identifiant du disque (à partir de 0x00 pour les disques amovibles et à partir de 0x80 pour les disques fixes).
	.BS_Reserved1:		db 0							; Réservé pour usage ultérieur.
	.BS_BootSig:		db 0x29							; Signature (0x29 par défaut).
	.BS_VolID:			db FAT_VOLID					; Numéro de série du disque.
	.BS_VolLab:			db FAT_VOLLAB					; Nom du disque sur 11 caractères ('NO NAME' si pas de nom).
	.BS_FilSysTyp:		db 'FAT12   '					; Type de système de fichiers (FAT, FAT12, FAT16).
_bpb_end:

; Main code
_start:
			cli											; disable interrupt
			or byte [atladdr(BS_DrvNum)], dl			; Save disk ID
			xor cx, cx									; clean CX
			mov ss, cx									; set up stack
			mov sp, VBR_LOADADDR						; SS:SP -> 0x0:0x7C00
			mov ds, cx									; DS=0x00
			mov es, cx									; ES=0x00
			sti											; enable interrupt
			cld											; String operation inc
			mov si, VBR_LOADADDR						; DS:SI -> 0x0:0x7C00
			mov di, VBR_RELOCADDR						; ES:DI -> 0x0:0x0800
			inc ch										; CX = 0x100
			rep movsw									; copy CX word from DS:SI to ES:DI
			jmp 0x0:reloc(_load_dvr)					; jump in relocate VBR

	_load_dvr:
			; Print banner
			mov si, reloc(_banner)
			call _put

			; load FAT driver into memory
			mov cx, 1									; CX = Sector count
			mov ax, 2									; AX = Sector index
			mov bx, FATDVR_LOADADDR						; data buffer offset
			call _intx13

	_load_fat:
			; TotalFATsSize = (BPB_NumFATs * BPB_FATSz16)
			xor dx, dx									; clean DX
			xor ax, ax
			mov al, [bpbaddr(BPB_NumFATs)]				; AX=BPB_NumFATs
			mov cx, [bpbaddr(BPB_FATSz16)]				; CX=BPB_FATSz16
			mul cx										; DX:AX = (BPB_NumFATs * BPB_FATSz16)
			mov word [bpbaddr(TotalFATsSize)], ax

			; load FAT1 into memory
			mov cx, [bpbaddr(BPB_FATSz16)]				; CX = Sector count
			mov ax, [bpbaddr(BPB_ResvdSecCnt)]			; AX = BPB_ResvdSecCnt
			inc ax										; Sector index = BPB_ResvdSecCnt + 1
			mov bx, FAT_LOADADDR						; data buffer offset
			call _intx13

	_load_root_dir:
			; FirstRootDirSecNum = BPB_ResvdSecCnt + TotalFATsSize
			mov ax, [bpbaddr(TotalFATsSize)]			; AX = TotalFATsSize
			mov cx, [bpbaddr(BPB_ResvdSecCnt)]			; CX = BPB_ResvdSecCnt
			add ax, cx									; AX = BPB_ResvdSecCnt + TotalFATsSize
			inc ax										; sector start at index 1
			mov word [bpbaddr(FirstRootDirSecNum)], ax

			; RootDirSectors = ((BPB_RootEntCnt * 32) + (BPB_BytsPerSec – 1)) / BPB_BytsPerSec
			xor dx, dx									; clean DX
			mov ax, [bpbaddr(BPB_RootEntCnt)]			; AX = BPB_RootEntCnt
			mov cx, 32
			mul cx										; DX:AX = (BPB_RootEntCnt * 32)
			mov cx, [bpbaddr(BPB_BytsPerSec)]			; CX = BPB_BytsPerSec
			dec cx										; CX = (BPB_BytsPerSec – 1)
			add ax, cx									; AX = ((BPB_RootEntCnt * 32) + (BPB_BytsPerSec – 1))
			div cx										; AX = RootDirSectors
			mov word [bpbaddr(RootDirSectors)], ax

			; load RootDir into memory
			mov ax, [bpbaddr(FirstRootDirSecNum)]		; AX = Sector index
			mov bx, ROOTDIR_LADDR						; data buffer offset
			mov cx, [bpbaddr(RootDirSectors)]			; Sector count
			call _intx13

	_load_file:
			; FirstDataSector = BPB_ResvdSecCnt + TotalFATsSize + RootDirSectors
			mov ax, [bpbaddr(RootDirSectors)]
			mov cx, [bpbaddr(TotalFATsSize)]			; CX = TotalFATsSize
			add ax, cx									; AX = TotalFATsSize + RootDirSectors
			mov cx, [bpbaddr(BPB_ResvdSecCnt)]			; CX = BPB_ResvdSecCnt
			add ax, cx									; AX = FirstDataSector
			inc ax										; sector start at index 1
			mov word [bpbaddr(FirstDataSector)], ax

			; CountDataSector = BPB_TotSec16 – FirstDataSector
			mov ax, [bpbaddr(FirstDataSector)]			; AX = FirstDataSector
			mov cx , [bpbaddr(BPB_TotSec16)]			; CX = BPB_TotSec16
			sub cx, ax									; CX = CountDataSector = BPB_TotSec16 – FirstDataSector
			mov word [bpbaddr(CountDataSector)], cx

			; CountofDataClusters = CountDataSector / BPB_SecPerClus
			xor dx, dx									; clean DX
			mov ax, [bpbaddr(CountDataSector)]			; AX = CountDataSector
			xor cx, cx
			mov cl, [bpbaddr(BPB_SecPerClus)]			; CX = BPB_SecPerClus
			div cx										; AX = CountofDataClusters = CountDataSector / BPB_SecPerClus
			mov word [bpbaddr(CountofDataClusters)], ax

			; load file if exist
			push word reloc(_loader_file)				; file name offset
			push word VBR_LOADADDR						; data buffer offset
			call _read_rootdir
			add sp, 4									; clean stack

			or ax, ax									; file has been loadded ?
			jz short _filemismatch						; no jump to _filemismatch
	_jmp_loader:
			mov dl, [bpbaddr(BS_DrvNum)]				; Retore disk ID
			jmp 0x0000:VBR_LOADADDR						; jump in loader file

	_filemismatch:
			mov si, reloc(_filenotfound)				; print message
			call _put
			mov si, reloc(_systemrestart)
			call _put
			; init timer
			xor ah, ah
			int 0x1A									; INT 0x1A ; AH=0x00 - TIME - GET SYSTEM TIME
			add dx, ltimeout(LOADER_TIMEOUT)			; set timeout (timeout = T + LOADER_TIMEOUT second)
			xchg cx, dx									; CX = timeout
		.wait_4_reboot:
			push cx										; save timeout
			xor ah, ah
			int 0x1A									; INT 0x1A ; AH=0x00 - TIME - GET SYSTEM TIME
			pop cx
			cmp dx, cx									; timeout ?
			jb .wait_4_reboot							; if DX < timeout, jump to .wait_4_reboot
		.reboot:
			jmp REBOOT_ADDR								; reboot system
	_filemismatch_end:

; Low Layer Function (Hard Disk)
_intx13:
; IN:	AX = Sector index (logical, not real; can be compute by LBA+1 with block_size == sector_size)
;		CX = Sector count
;		ES:BX -> Data Buffer
; OUT:	AH = status
;		AL = number of sectors transferred
		.mkchsaddr:
				push bp								; save BP
				sub sp, 6							; reserve 3 word for fonction (word array)
				mov bp, sp							; BP -> first element of word array
			
				xor dx, dx							; clean DX
				mov byte [ds:bp+4], cl				; save sector count (word_array[2])
				mov cx, [bpbaddr(BPB_SecPerTrk)]	; CX = BPB_SecPerTrk
				div cx								; AX =cylinder:head ; DX = sector number
				push dx								; save sector number
				xor dx, dx
				mov cx, [bpbaddr(BPB_NumHeads)]		; CX = BPB_NumHeads
				div cx								; AX =cylinder number ; DX = head number
				mov byte [ds:bp+2], dl				; save head number for int 0x13 (word_array[1])
				xchg ah, al							; AH = heigh low bit cylinder for int 0x13, AL = cylinder number
				shl al, 6							; AX = cylinder number for int 0x13
				pop cx								; CX = sector number
				or cx, ax							; CX =cylinder:sector for int 0x13
				mov word [ds:bp], cx				; save cylinder:sector (word_array[0])
		.init:		
				mov cx, 0x2							; limit number of loop
		.readdisk:
				dec cx								; count this loop
				push cx								; save counter
				mov dl, byte [bpbaddr(BS_DrvNum)]	; disk id
				mov cx, word [ds:bp]				; cylinder:sector (word_array[0])
				mov dh, byte [ds:bp+2]				; head (word_array[1])
				mov al, byte [ds:bp+4]				; sector count (word_array[2])
				mov ah, 0x2							; read func
				pusha								; don't trust the BIOS
				int 0x13							; BIOS: Disk I/O
				popa
				pop cx								; restore counter
				jcxz .return						; Protect to infinite loop
				jc short .readdisk					; remake if error
		.return:
				add sp, 6							; clean stack
				pop bp								; restore BP
				ret
_intx13_end:

; Low Layer Function (Output)
_put:
				pusha					; don't trust the BIOS
		.get_cursor:
				mov AH, 0x3				; Place dans AH le numéro de fonction.
				xor BX, BX				; RAZ de BX qui contient la page d'affichage.
				int 0x10				; Appele de l'interrupteur 0x10
				mov CX, 0X1				; CX contient le nombre d'affichage de chaque caractère
		.write_char:
				lodsb					; SI pointe vers le caractère à afficher, lodsb place le caractère dans AL et incrémente SI.
				or AL, AL				; Un OU logique au niveau du bit de AL avec lui même permet de le comparrer à zéro et de modifier ZF en conséquence.
				jz short .end			; Si ZF est à 1, alors AL vaut zéro. Fin de la fonction.
				cmp AL, 0xA				; Al est comparré à 0x0A (10) au caractère de fin de ligne Unix/Linux.
				jz short .inc_line		; Si AL vaut 0x0A (10), alors la fonction Int0x10_IncrementeLine est appelé.
				mov AH, 0xA				; Place dans AH le numéro de fonction.
				int 0x10				; Appele de l'interrupteur 0x10
				inc DL					; Incremente DL qui contient l'index de la colonne courrante
		.set_cursor:
				mov AH, 0x2				; Place dans AH le numéro de fonction.
				int 0x10				; Appele de l'interrupteur 0x10
				jmp short .write_char	; Saut court inconditionnel vers Int0x10_WriteCharacterAtCursor
		.inc_line:
				inc DH					; Incremente DL qui contient l'index de la ligne courrante.
				xor DL, DL				; RAZ de DL qui contient l'index de la colonne courrante.
				jmp short .set_cursor	; Saut court inconditionnel vers Int0x10_SetCursorPosition
		.end:
				popa					; Restauration des registres
				ret
_put_end:

; Data of VBR
_banner:		db 'ASTERIX BOOTDISK', 0x0A, 0x0
_filenotfound:	db 'File not found: /'
_loader_file:	db LOADER_NAME
_lf:			db 0x0A, 0x0
_systemrestart:	db REBOOT_PROMPT, 0x0
; Align VBR magic number
				times 0x1FE-($-$$) db 0x0
_magic:			dw 0xAA55










; FAT Driver
;
; Align on sector 2 of image
				times (FAT_BYTSPERSEC - ($ - $$)) db 0x00

_read_rootdir:
; [ss:bp+0x8] file name offset
; [ss:bp+0x6] data buffer offset
; [ss:bp+0x2] first (or current) cluster of file
; [ss:bp+0x0] next cluster of file
				sub sp, 4									; reserve 2 word
				push bp										; save BP
				mov bp, sp									; BP =SP
				add bp, 2									; BP -> first word of function structure
				mov di, ROOTDIR_LADDR						; ES:DI -> first entrie of root dir
				jmp short .firstentrie						; jump to .firstentrie
	.nextentrie:
				add di, cx									; ES:DI ->  last byte of current root dir entrie file name
				add di, 22									; ES:DI ->  next root dir entrie file name
	.firstentrie:
				mov si, [ss:bp+0x8]							; DS:SI -> search file name
				mov cx, 10									; length of name
				cmp byte [es:di], 0x0						; end of root dir ?
				jz short .endrootdir						; yes, jump to .endrootdir
				cmp byte [es:di], 0xE5						; dir entrie is empty ?
				jz short .nextentrie						; yes, jump to .nextentrie
	.match:
				lodsb										; AL = [DS:SI], SI++
				cmp al, [es:di]								; compare current char of search file name and root dir entrie file name
				jnz short .nextentrie						; if different, pass to the next entrie
				inc di										; ES:DI ->  next byte in file name of current root dir entrie
				loop .match									; process for next char or read file if match completed
	.read_file:
				sub di, 10									; ES:DI ->  first byte of current root dir entrie
				mov ax, word [es:di+26]						; AX = first cluster of file
				
	.nextcluster:
				mov word [ss:bp+0x2], ax					; save current cluster of file
				mov ax, [ss:bp+0x2]
				push ax
				call _read_fat
				add sp, 2
				mov word [ss:bp], ax						; save next cluster of file
				mov ax, [ss:bp+0x2]							; AX = current cluster of file
				mov bx, [ss:bp+0x6]							; data buffer offset
				call _read_cluster							; read cluster
				cmp word [ss:bp], 0xFF8						; end of file ?
				jge short .end								; yes, jump to .end
				mov cx, FAT_BYTSPERSEC						; CX = size of secteur
				xor dx, dx									; clean DX
				xor ah, ah									; clean AH
				mul cx										; AX = displacement to the end of data in buffer
				add word [ss:bp+0x6], ax					; save new offset
				mov ax, [ss:bp]								; AX = next cluster of file
				jmp short .nextcluster						; jump to .nextcluster
	.endrootdir:
				mov ax, 0x0									; File not found
				jmp short .end
	.endreadfile:
				mov ax, 0x1									; File loaded
	.end:
				pop bp
				add sp, 4									; clean stack
				ret
_read_rootdir_end:


; Offset du cluster N dans la FAT
; FATOffset = N + (N / 2)	; Multiply by 1.5 without using floating point, the divide by 2 rounds DOWN
; Secteur contenant l'entrée FAT pour le cluster N
; ThisFATSecNum = BPB_ResvdSecCnt + (FATOffset / BPB_BytsPerSec);
; Offset dans le secteur contenant l'entrée FAT pour le cluster N (REM est le reste de la division FATOffset / BPB_BytsPerSec)
; ThisFATEntOffset = REM(FATOffset / BPB_BytsPerSec);
	;.FATentrieoffset:
				;mov cx, [bpbaddr(BPB_BytsPerSec)]			; CX = BPB_BytsPerSec
				;div cx										; AX = (FATOffset / BPB_BytsPerSec); DX = REM
				;mov cx, ax									; CX = AX
				;mul dx										; AX = ThisFATEntOffset
				;add cx, [bpbaddr(BPB_ResvdSecCnt)]			; CX = ThisFATSecNum
; Conserver uniquement le contenut de l'entrée FAT
; FAT12ClusEntryVal = *((WORD *) &SecBuff[ThisFATEntOffset]);
; If(N & 0x0001)
	; FAT12ClusEntryVal = FAT12ClusEntryVal >> 4; /* Cluster number is ODD */
; Else
	; FAT12ClusEntryVal = FAT12ClusEntryVal & 0x0FFF; /* Cluster number is EVEN */
_read_fat:
; IN:	SS:BP+2 -> N
; OUT:	AX = FAT entrie
				push bp										; save BP
				mov bp, sp									; BP -> Old BP
	.FAToffset:
				mov ax, [ds:bp+4]							; AX =N
				xor dx, dx									; clean dx
				mov cx, 2									; CX = 2
				div	cx										; AX = (N / 2)
				add ax, [ds:bp+4]							; AX = N + (N / 2)
	.computeaddr:
				mov bx, FAT_LOADADDR						; BX = FAT_LOADADDR
				add bx, ax									; DS:BX -> FAT entrie
	.readFATentrie:
				mov ax, [ds:bx]								; AX = FAT entrie
				test word [ds:bp+4], 0x1					; N is odd or even ?
				jz short .evenentrie						; if ZF, N is even, jump to .evenentrie
	.oddentrie:
				shr ax, 4									; bits 4-15 are the FAT entrie
				jmp short .return
	.evenentrie:
				and ax, 0x0FFF								; bits 0-11 are the FAT entrie
	.return:
				pop bp										; restore BP
				ret
_read_fat_end:


_read_cluster:
; IN:	ES:BX -> Data Buffer
;		AX = Cluster Number (N)
; OUT:	AH = status
;		AL = number of sectors transferred
; FirstSectorofCluster = ((N – 2) * BPB_SecPerClus) + FirstDataSector
				sub	ax, 2									; AX = (N – 2)
	.mksectorindex:
				xor cx, cx									; clean CX
				mov cl, byte [bpbaddr(BPB_SecPerClus)]		; CX = BPB_SecPerClus
				xor dx, dx									; clean DX
				mul cx										; AX = ((N – 2) * BPB_SecPerClus)
				mov cx, [bpbaddr(FirstDataSector)]			; CX = FirstDataSector
				add ax, cx									; AX= Sector Index
				inc ax										; sector start at index 1
	.readcluster:
				xor cx, cx
				mov cl, byte [bpbaddr(BPB_SecPerClus)]		; Sector count
				call _intx13
	.return:
				ret
_read_cluster_end:
; end of Reserved Region










; FATs
;
; Align start of FATs (FAT Region)
				times ((RESERVED_SECTORS * FAT_BYTSPERSEC) - ($ - $$)) db 0x00
_fatregion:
%assign i		1
%rep FAT_NUMFATS
				FAT_RESERVEDCLUSTER				; Reserved Cluster (static value)
; Align FATi End
				times (((RESERVED_SECTORS * FAT_BYTSPERSEC) + ((FAT_SIZE_16 * FAT_BYTSPERSEC) * i)) - ($-$$)) db 0x00
	%assign i	(i+1)
%endrep
_fatregion_end:
; End of FATs










; Root Directory Region
; 
_rootdirregion:
%ifdef FAT_VOLLAB
	_volumeid_entrie:
		.VolumeID:				db FAT_VOLLAB	; Identifiant du volume (complétée à 11 caractères avec des espaces)
		.Attrubts				db ATTR_VOLUME_ID; Attributs du fichier
		.Reserved				db 0x00			; Réservé, utilisé par NT
		.MSCreatTime			db 0x00			; Heure de création : par unité de 10 ms (0 à 199).
		.CreateTime				dw DEFAULT_TIME	; Heure de création
		.CreateDate				dw DEFAULT_DATE	; Date de création
		.AccessDate				dw DEFAULT_DATE	; Date du dernier accès ; voir offset 0x10 pour la description.
		.EAIndex				dw 0x0000		; Index EA (utilisé par OS/2 et NT) pour FAT12 et FAT16 ; 2 octets de poids fort du numéro du premier cluster pour FAT32
		.ModifTime				dw DEFAULT_TIME	; Heure de dernière modification
		.ModifDate				dw DEFAULT_DATE	; Date de dernière modification
		.FirstClus				dw 0x0			; Numéro du premier cluster du fichier (FAT12 et FAT16) ; 2 octets de poids faible de ce numéro (FAT32).
		.FileSize				dd 0x0			; Taille du fichier
	_volumeid_entrie_end:
%endif
; Align Root Directory End
				times (((RESERVED_SECTORS * FAT_BYTSPERSEC) + ((FAT_SIZE_16 * FAT_BYTSPERSEC) * FAT_NUMFATS) + (ROOTDIR_SECCNT * FAT_BYTSPERSEC)) - ($-$$)) db 0x00
_rootdirregion_end:










; File and Directory Data Region
;
_fsdataregion:
; Align FS End
				times (FAT_TOTSEC16 * FAT_BYTSPERSEC)-($-$$) db 0x00
_fsdataregion_end:

