; Macro for Hardcoded FAT12 Bootable floppy disk image
; Made by InitScreen


%ifndef FAT12MACRO_ASM
	%define			FAT12MACRO_ASM

	; VBR macro
	%define			VBR_LOADADDR		0x7C00
	%define			laddr(x)			(VBR_LOADADDR + (x))
	%define			VBR_RELOCADDR		0x0600
	%define			reloc(x)			(VBR_RELOCADDR + (x))

	; BPB macro
	%define			BPB_LOADADDR		VBR_RELOCADDR
	struc			BPB
		.BS_jmpBoot:			resb 3	; jump
		.BS_OEMName:			resb 8	; programme name
		.BPB_BytsPerSec:		resw 1	; byte per sector
		.BPB_SecPerClus:		resb 1	; sector per cluster
		.BPB_ResvdSecCnt:		resw 1	; reserved sector
		.BPB_NumFATs:			resb 1	; number of FATs
		.BPB_RootEntCnt:		resw 1	; root dir size
		.BPB_TotSec16:			resw 1	; 16-bit sector count
		.BPB_Media:				resb 1	; disk type
		.BPB_FATSz16:			resw 1	; FAT size
		.BPB_SecPerTrk:			resw 1	; sector per track
		.BPB_NumHeads:			resw 1	; head count
		.BPB_HiddSec:			resd 1	; hidden sector
		.BPB_TotSec32:			resd 1	; 32-bit sector count
		.BS_DrvNum:				resb 1	; disk id
		.BS_Reserved1:			resb 1	; reserved
		.BS_BootSig:			resb 1	; signature
		.BS_VolID:				resd 1	; serial number
		.BS_VolLab:				resb 11	; volume name
		.BS_FilSysTyp:			resb 8	; filesystem type string
	; This part of BPB is non-standard and a personnal implementation, she is
	; initialised at setup, not hardcoded, and she is rewrite on the first byte of code
	; for optimize size of data.
	;
	; TotalFATsSize			(BPB_NumFATs * BPB_FATSz16)
	; FirstRootDirSecNum	BPB_ResvdSecCnt + TotalFATsSize
	; RootDirSectors		((BPB_RootEntCnt * 32) + (BPB_BytsPerSec – 1)) / BPB_BytsPerSec
	; FirstDataSector		BPB_ResvdSecCnt + TotalFATsSize + RootDirSectors
	; CountDataSector		BPB_TotSec16 – FirstDataSector
	; CountofDataClusters	CountDataSector / BPB_SecPerClus
		.TotalFATsSize:			resw 1	; total FATs size in secteur
		.FirstRootDirSecNum:	resw 1	; first root directory sector number
		.RootDirSectors:		resw 1	; root directory sectors count
		.FirstDataSector:		resw 1	; first data sector number
		.CountDataSector:		resw 1	; data sectors count
		.CountofDataClusters:	resw 1	; data cluster count
	endstruc
	%define			atladdr(x)			(VBR_LOADADDR + BPB. %+ x)
	%define			bpbaddr(x)			(BPB_LOADADDR + BPB. %+ x)

	; FAT macro
	;
	; Usual value for floppy disk simulation (source: el-torito spec)
	;
	; Size		Tracks * Heads * SectorsPerTracks
	; 1.2 Meg	0x50 * 0x2 * 0x0F
	; 1.44 Meg	0x50 * 0x2 * 0x12
	; 2.88 Meg	0x50 * 0x2 * 0x24
	%define			FAT_BYTSPERSEC		0x200
	%define			RESERVED_SECTORS	2
	%ifdef FDSK_120
		%define		FAT_TRKCNT			0x50
		%define		FAT_NUMHEADS		0x2
		%define		FAT_SECPERTRK		0x0F
		%define		FAT_SECPERCLUS		0x1
	%elifdef FDSK_144
		%define		FAT_TRKCNT			0x50
		%define		FAT_NUMHEADS		0x2
		%define		FAT_SECPERTRK		0x12
		%define		FAT_SECPERCLUS		0x1
	%elifdef FDSK_288
		%define		FAT_TRKCNT			0x50
		%define		FAT_NUMHEADS		0x2
		%define		FAT_SECPERTRK		0x24
		%define		FAT_SECPERCLUS		0x2
	%else
		%error		"Please define an allow type of floppy disk."
	%endif
	%define			FAT_TOTSEC16		(FAT_TRKCNT * FAT_NUMHEADS * FAT_SECPERTRK)
	%define			FAT_SIZE_16			((((FAT_TOTSEC16 / 2) + FAT_TOTSEC16) / FAT_BYTSPERSEC) + 1)
	%define			FAT_NUMFATS			0x2
	%define			FAT_MEDIA			0xF0
	%define			FATDVR_LOADADDR		(VBR_RELOCADDR + FAT_BYTSPERSEC)
	%define			FAT_LOADADDR		(FATDVR_LOADADDR + ((RESERVED_SECTORS - 1) * FAT_BYTSPERSEC))
	%define			FAT_RESERVEDCLUSTER	db FAT_MEDIA, 0xFF, 0xFF		; Reserved Cluster (static value)
	%define			fataddr(x)			(FAT_LOAD_ADDR + (x))
	%ifdef MSCOMPAT
		%define		FAT_OEMNAME			'MSWIN4.1'
		%define		FAT_VOLID			0x11, 0x22, 0x44, 0x88
		%define		FAT_VOLLAB			'NO NAME    '
	%else
		%define		FAT_OEMNAME			'INITFFS '
		%define		FAT_VOLID			'INIT'
		%define		FAT_VOLLAB			'INITSCREEN '
	%endif

	; ROOT DIR macro
	%define			ROOTDIR_LADDR		(FAT_LOADADDR + (FAT_SIZE_16 * FAT_BYTSPERSEC))
	%define			ROOTDIR_ENTRIECNT	0x200
	;%define			ROOTDIR_SECCNT		((ROOTDIR_ENTRIECNT * 32) / FAT_BYTSPERSEC)
	;%define			ROOTDIR_SECCNT		(((ROOTDIR_ENTRIECNT * 32) / FAT_BYTSPERSEC) + 1)
	%define			ROOTDIR_SECCNT		(((ROOTDIR_ENTRIECNT * 32) + (FAT_BYTSPERSEC - 1)) / FAT_BYTSPERSEC)
	struc ROOT_DIR_ENTRIE
		.FileName				resb 8	; Nom du fichier (complété à 8 caractères avec des espaces)
		.Extension				resb 3	; Extension (complétée à 3 caractères avec des espaces)
		.Attrubts				resb 1	; Attributs du fichier
		.Reserved				resb 1	; Réservé, utilisé par NT
		.MSCreatTim				resb 1	; Heure de création : par unité de 10 ms (0 à 199).
		.CreateTime				resw 1	; Heure de création
		.CreateDate				resw 1	; Date de création
		.AccessDate				resw 1	; Date du dernier accès ; voir offset 0x10 pour la description.
		.EAIndex				resw 1	; Index EA (utilisé par OS/2 et NT) pour FAT12 et FAT16 ; 2 octets de poids fort du numéro du premier cluster pour FAT32
		.ModifTime				resw 1	; Heure de dernière modification
		.ModifDate				resw 1	; Date de dernière modification
		.FirstClus				resw 1	; Numéro du premier cluster du fichier (FAT12 et FAT16) ; 2 octets de poids faible de ce numéro (FAT32).
		.FileSize				resd 1	; Taille du fichier
	endstruc
	%define			rtdr(x)				(ROOT_DIR_ENTRIE. %+ x)
	%define			ATTR_READ_ONLY		0x01
	%define			ATTR_HIDDEN			0x02
	%define			ATTR_SYSTEM			0x04
	%define			ATTR_VOLUME_ID		0x08
	%define			ATTR_DIRECTORY		0x10
	%define			ATTR_ARCHIVE		0x20
	%define			ATTR_LONG_NAME		(ATTR_READ_ONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_VOLUME_ID)
	%define			ATTR_LONG_NAME_MASK	(ATTR_READ_ONLY | ATTR_HIDDEN | ATTR_SYSTEM | ATTR_VOLUME_ID | ATTR_DIRECTORY | ATTR_ARCHIVE)
	%define			DEFAULT_SECOND		((__UTC_TIME_NUM__ % 100) & 0x1F)
	%define			DEFAULT_MINUTES		((((__UTC_TIME_NUM__ / 100) % 100) & 0x3F) << 5)
	%define			DEFAULT_HOURS		(((__UTC_TIME_NUM__ / 10000) & 0x1F) << 11)
	%define			DEFAULT_DAYOFMONTH	((__UTC_DATE_NUM__ % 100) & 0x1F)
	%define			DEFAULT_MONTHOFYEAR	((((__UTC_DATE_NUM__ / 100) % 100) & 0x0F) << 5)
	%define			DEFAULT_YEAR		((((__UTC_DATE_NUM__ / 10000) - 1980) & 0x7F) << 9)
	%define			DEFAULT_TIME		(DEFAULT_HOURS | DEFAULT_MINUTES | DEFAULT_SECOND)
	%define			DEFAULT_DATE		(DEFAULT_DAYOFMONTH | DEFAULT_MONTHOFYEAR | DEFAULT_YEAR)

	; LOADER macro
	%define			LOADER_LADRR		(ROOTDIR_LADDR + (32 * ROOTDIR_ENTRIECNT))
	%define			LOADER_JMPADDR(x)	(VBR_LOADADDR - ($ + VBR_RELOCADDR))
	%ifndef LOADER_NAME
		%define		LOADER_NAME			'LOADER     '
	%endif ; !LOADER_NAME
	%ifndef LOADER_TIMEOUT
		%define		LOADER_TIMEOUT		3
	%endif ; !LOADER_TIMEOUT
	%define			ltimeout(x)			((182 * x) / 10)
	
	%define			REBOOT_ADDR			0xF000:0xFFF0
	%defstr			REBOOT_TIMESTR		LOADER_TIMEOUT
	%strcat			REBOOT_PROMPT		'The system will be restart in ', REBOOT_TIMESTR,' seconds.'

%endif ; !FAT12MACRO_ASM
