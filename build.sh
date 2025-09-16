#!/bin/sh
nasm -f bin boot/stage0.asm -o build/stage0.bin
nasm -f bin boot/stage1.asm -o build/stage1.bin
dd if=/dev/zero of=build/image.dd bs=1048576 count=128
fdisk build/image.dd << EOF
g
n p
1
2048
+16M
t 1
1
w
EOF
lo_path=$(sudo losetup -o $[2048*512] --sizelimit $[16*1024*1024] -f build/image.dd --show)
sudo mkfs.vfat -F 16 -n "EFI System" "$lo_path"
# upload files to fs
mkdir build/mnt
sudo mount "$lo_path" build/mnt
sudo cp build/stage1.bin build/mnt
sudo umount build/mnt
rm -r build/mnt
sudo losetup -d "$lo_path"
# inject bootloader to sector 0
dd if=build/stage0.bin of=build/image.dd conv=notrunc bs=446 count=1
dd if=build/stage0.bin of=build/image.dd conv=notrunc bs=1 count=2 skip=510 seek=510

