#!/bin/bash

if ! id | grep -q root; then
	echo "must be run as root"
	exit
fi

if [ -f ./tiboot3.bin ] ; then
	rm -rf ./tiboot3.bin || true
fi

if [ -f ./tispl.bin ] ; then
	rm -rf ./tispl.bin || true
fi

if [ -f ./u-boot.img ] ; then
	rm -rf ./u-boot.img || true
fi

wget https://beagley-ai.beagleboard.io/u-boot-beagley-ai/tiboot3.bin
wget https://beagley-ai.beagleboard.io/u-boot-beagley-ai/tispl.bin
wget https://beagley-ai.beagleboard.io/u-boot-beagley-ai/u-boot.img

if [ -d /boot/firmware/ ] ; then
	cp -v ./tiboot3.bin /boot/firmware/
	cp -v ./tispl.bin /boot/firmware/
	cp -v ./u-boot.img /boot/firmware/
	sync
fi

if [ -d /boot/efi/ ] ; then
	cp -v ./tiboot3.bin /boot/efi/
	cp -v ./tispl.bin /boot/efi/
	cp -v ./u-boot.img /boot/efi/
	sync
fi

if [ -b /dev/mmcblk0 ] ; then
	mmc bootpart enable 1 2 /dev/mmcblk0
	mmc bootbus set single_backward x1 x8 /dev/mmcblk0
	mmc hwreset enable /dev/mmcblk0

	echo "Clearing eMMC boot0"

	echo '0' >> /sys/class/block/mmcblk0boot0/force_ro

	echo "dd if=/dev/zero of=/dev/mmcblk0boot0 count=32 bs=128k"
	sudo dd if=/dev/zero of=/dev/mmcblk0boot0 count=32 bs=128k

	echo "dd if=/boot/firmware/tiboot3.bin of=/dev/mmcblk0boot0 bs=128k"
	sudo dd if=/boot/firmware/tiboot3.bin of=/dev/mmcblk0boot0 bs=128k
	sync
fi

#
