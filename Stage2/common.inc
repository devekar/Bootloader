
%ifndef __COMMON_INC__
%define __COMMON_INC__

; where the kernel is to be loaded to in protected mode
%define IMAGE_PMODE_BASE 0x100000

; where the kernel is to be loaded to in real mode
%define IMAGE_RMODE_BASE 0x3000
%define KERNEL_SIZE 0x1

; The linux kernel - vmlinuz image
%define KERNEL_BASE 0x1000
%define KERNEL_BOOT_OFFSET 0x0
%define KERNEL_SETUP_OFFSET 0x200

;%define FALSE_KERNEL_SECTOR 0x3
%define KERNEL_BOOT_SECTOR 0x4
%define KERNEL_SETUP_SECTOR 0x5


%define SETUP_SECTORS_OFFSET 0x1f1
%define PROTECTED_SECTORS_OFFSET 0x1f4


ProtectedKernelSize dd 0
MoveBlockSectors dw 0

CurrentSector dw 0
CurrentPmLocation dd 0x100000

CopyStart db 1
CopyComplete db 1


%define MOVE_SECTORS 0x80
%define MOVE_BYTES 0x10000
;%define INITRD_OFFSET 0x4eb600
;%define INITRD_SIZE   0xe81050
;%define DATA_SIZE 0x136c80
%endif
