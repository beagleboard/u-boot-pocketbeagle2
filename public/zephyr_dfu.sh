#!/bin/sh

dfu-util -R -a bootloader -D ./tiboot3-usbdfu.bin
sleep 1
dfu-util -R -a tispl.bin -D ./tispl.bin
sleep 1
dfu-util -R  -a u-boot.img -D ./u-boot-zephyrdfu.img
sleep 2
dfu-util -R  -a zephyr.bin -D $1
