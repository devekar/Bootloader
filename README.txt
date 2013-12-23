devekar.1@osu.edu
=======
README
=======

Development Tools used:
-----------------------
Netwide Assembler (NASM)
Bochs x86 emulator
Note: bochs-sdl library may be required for display. Accordingly, choose sdl library for VGA display in bochs configuration.



How to use bootloader:
----------------------
1) Compile stage1.asm and stage2.asm as well as init.c
   nasm -f bin stage1.asm -o STAGE1.BIN
   nasm -f bin stage2.asm -o STAGE2.BIN
   gcc -static init.c -o init
   
2) Create two 20 MB filesystem images
	dd if=/dev/zero of=sda.img bs=1024 count=20480
	dd if=/dev/zero of=sdb.img bs=1024 count=20480
   
   Format the sdb.img as an ext3 image
   mkfs.ext3 -F -b 1024 sdb.img 20480
   
3) Use dd command to copy STAGE1.BIN to the MBR sector, followed by STAGE2 and vmlinuz.
   dd if=STAGE1.BIN of=sda.img bsconv=notrunc
   dd if=STAGE2.BIN of=sda.img seek=1 bsconv=notrunc
   dd if=vmlinuz of=sda.img seek=4 bsconv=notrunc
   
4) Mount sdb.img as loopback device, create /sbin directory and copy init to it.
   mkdir /tmp/sdb
   mount -t ext3 -o loop sdb.img /tmp/sdb
   mkdir /tmp/sdb/sbin
   cp init /tmp/sdb/init
   umount /tmp/sdb

5) Configure Bochs with following parameters and run.

   Disk and Boot:
     ATA channel 0:
	     First HD/CD on channel 0:
	          Device type: disk
			  Path: sda.img
			  Cylinders: 40
			  Heads: 16
			  Sectors per track: 64
		 Second HD/CD on channel 0:
		 	  Device type: disk
			  Path: sdb.img
			  Cylinders: 40
			  Heads: 16
			  Sectors per track: 64
			  
	 Boot Options:
         First boot-device: Disk
   
