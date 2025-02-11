#!/bin/bash

#apt-get install -y -q bc bison device-tree-compiler flex gcc-arm-linux-gnueabihf libssl-dev python3-cryptography python3-dev python3-jsonschema python3-pycryptodome python3-pyelftools python3-setuptools python3-yaml swig yamllint

#wget https://pocketbeagle.beagleboard.io/u-boot-pocketbeagle2/get_n_install.sh ; chmod +x get_n_install.sh ; sudo ./get_n_install.sh

CC32=arm-linux-gnueabihf-
CC64=aarch64-linux-gnu-

${CC32}gcc --version
${CC64}gcc --version

DIR=$PWD

TI_FIRMWARE="11.00.02"
TRUSTED_FIRMWARE="v2.12.0"
OPTEE="4.5.0"
#UBOOT="v2025.01-pocketbeagle2"
UBOOT="v2025.04-rc2-pocketbeagle2"

#rm -rf ./ti-linux-firmware/ || true
if [ ! -d ./ti-linux-firmware/ ] ; then
	if [ -f .gitlab-runner ] ; then
		echo "git clone -b ${TI_FIRMWARE} https://git.gfnd.rcn-ee.org/TexasInstruments/ti-linux-firmware.git"
		git clone -b ${TI_FIRMWARE} https://git.gfnd.rcn-ee.org/TexasInstruments/ti-linux-firmware.git --depth=10 ./ti-linux-firmware/
	else
		echo "git clone -b ${TI_FIRMWARE} https://github.com/beagleboard/ti-linux-firmware.git"
		git clone -b ${TI_FIRMWARE} https://github.com/beagleboard/ti-linux-firmware.git --depth=10 ./ti-linux-firmware/
	fi
fi

#rm -rf ./trusted-firmware-a/ || true
if [ ! -d ./trusted-firmware-a/ ] ; then
	if [ -f .gitlab-runner ] ; then
		echo "git clone -b ${TRUSTED_FIRMWARE} https://git.gfnd.rcn-ee.org/mirror/trusted-firmware-a.git"
		git clone -b ${TRUSTED_FIRMWARE} https://git.gfnd.rcn-ee.org/mirror/trusted-firmware-a.git --depth=10 ./trusted-firmware-a/
	else
		echo "git clone -b ${TRUSTED_FIRMWARE} https://github.com/TrustedFirmware-A/trusted-firmware-a.git"
		git clone -b ${TRUSTED_FIRMWARE} https://github.com/TrustedFirmware-A/trusted-firmware-a.git --depth=10 ./trusted-firmware-a/
	fi
fi

#rm -rf ./optee_os/ || true
if [ ! -d ./optee_os/ ] ; then
	if [ -f .gitlab-runner ] ; then
		echo "git clone -b ${OPTEE} https://git.gfnd.rcn-ee.org/mirror/optee_os.git"
		git clone -b ${OPTEE} https://git.gfnd.rcn-ee.org/mirror/optee_os.git --depth=10 ./optee_os/
	else
		echo "git clone -b ${OPTEE} https://github.com/OP-TEE/optee_os.git"
		git clone -b ${OPTEE} https://github.com/OP-TEE/optee_os.git --depth=10 ./optee_os/
	fi
fi

if [ -d ./u-boot/ ] ; then
	rm -rf ./u-boot/
fi

global="https://github.com/beagleboard/u-boot.git"
#local="https://gitlab.gfnd.rcn-ee.org/beagleboard/u-boot-pocketbeagle2.git"
mirror="${global}"

echo "git clone -b ${UBOOT} ${mirror} --depth=10 ./u-boot/"
git clone -b ${UBOOT} ${mirror} --depth=10 ./u-boot/

#echo "git clone -b ${UBOOT} ${mirror} ./u-boot/"
#git clone -b ${UBOOT} ${mirror} ./u-boot/

#echo "*************************************************"
#cd ./u-boot/
#git bisect start
## good: [6d41f0a39d6423c8e57e92ebbe9f8c0333a63f72] Prepare v2025.01
#git bisect good 6d41f0a39d6423c8e57e92ebbe9f8c0333a63f72
## bad: [636fcc96c3d7e2b00c843e6da78ed3e9e3bdf4de] Prepare v2025.04-rc2
#git bisect bad 636fcc96c3d7e2b00c843e6da78ed3e9e3bdf4de
#git bisect good 1c2ffcd5e622031fa1c05335d0db839de14bf0e9
#git bisect good 8707ea0360046522d0784135b6c9a7c564f9515c
#git bisect good 5a287cf07aed6a60e25af903ea24bc0030d493b1
#git bisect good bfaed6969c119673c3087ffd778b8e3e324c3202
#git bisect good c2e00482d0058908014014b1c703e0eaaf1490d7
#git bisect bad a081512cbde71b70e32f2cfb36291e03726fec3f
#echo "*************************************************"
#git bisect log
#echo "*************************************************"
#git am ../patches/0001-add-k3-am6232-pocketbeagle2.patch
#git am ../patches/0002-PocketBeagle-2-drop-CONFIG_TI_AM65_CPSW_NUSS.patch
#git am ../patches/0003-PocketBeagle-2-try-label.patch
#cd ${DIR}/
#echo "*************************************************"

mkdir -p ${DIR}/public/

#pocketbeagle2
SOC_NAME=am62x
SECURITY_TYPE=hs-fs
SIGNED=
TFA_BOARD="lite"
TFA_EXTRA_ARGS="K3_USART=0x6"
OPTEE_PLATFORM="k3-am62x"
OPTEE_EXTRA_ARGS="CFG_WITH_SOFTWARE_PRNG=y CFG_CONSOLE_UART=0x6"
UBOOT_CFG_CORTEXR="am6232_pocketbeagle2_r5_defconfig"
UBOOT_CFG_CORTEXA="am6232_pocketbeagle2_a53_defconfig"

echo "make -C ./trusted-firmware-a/ -j4 CROSS_COMPILE=$CC64 CFLAGS= LDFLAGS= ARCH=aarch64 PLAT=k3 SPD=opteed $TFA_EXTRA_ARGS TARGET_BOARD=${TFA_BOARD} all"
make -C ./trusted-firmware-a/ -j4 CROSS_COMPILE=$CC64 CFLAGS= LDFLAGS= ARCH=aarch64 PLAT=k3 SPD=opteed $TFA_EXTRA_ARGS TARGET_BOARD=${TFA_BOARD} all

if [ ! -f ./trusted-firmware-a/build/k3/${TFA_BOARD}/release/bl31.bin ] ; then
	echo "Failure in ./trusted-firmware-a/"
	ls -lha ${DIR}/trusted-firmware-a/
	exit 2
else
	cp -v ./trusted-firmware-a/build/k3/${TFA_BOARD}/release/bl31.bin ${DIR}/public/
fi

echo "make -C ./optee_os/ -j4 O=../optee CROSS_COMPILE=$CC32 CROSS_COMPILE64=$CC64 CFLAGS= LDFLAGS= CFG_ARM64_core=y $OPTEE_EXTRA_ARGS PLATFORM=${OPTEE_PLATFORM} all"
make -C ./optee_os/ -j4 O=../optee CROSS_COMPILE=$CC32 CROSS_COMPILE64=$CC64 CFLAGS= LDFLAGS= CFG_ARM64_core=y $OPTEE_EXTRA_ARGS PLATFORM=${OPTEE_PLATFORM} all

if [ ! -f ./optee/core/tee-pager_v2.bin ] ; then
	echo "Failure in ${OPTEE_DIR}"
	ls -lha ${DIR}/optee/
	exit 2
else
	cp -v ./optee/core/tee-pager_v2.bin ${DIR}/public/
fi

rm -rf ${DIR}/optee/ || true

echo "make -C ./u-boot/ -j1 O=../CORTEXR CROSS_COMPILE=$CC32 $UBOOT_CFG_CORTEXR"
make -C ./u-boot/ -j1 O=../CORTEXR CROSS_COMPILE=$CC32 $UBOOT_CFG_CORTEXR

echo "make -C ./u-boot/ -j4 O=../CORTEXR CROSS_COMPILE=$CC32 BINMAN_INDIRS=${DIR}/ti-linux-firmware/"
make -C ./u-boot/ -j4 O=../CORTEXR CROSS_COMPILE=$CC32 BINMAN_INDIRS=${DIR}/ti-linux-firmware/

if [ ! -f ${DIR}/CORTEXR/tiboot3-${SOC_NAME}-${SECURITY_TYPE}-evm.bin ] ; then
	echo "Failure in u-boot CORTEXR build of [$UBOOT_CFG_CORTEXR]"
	ls -lha ${DIR}/CORTEXR/
	exit 2
else
	cp -v ${DIR}/CORTEXR/tiboot3-${SOC_NAME}-${SECURITY_TYPE}-evm.bin ${DIR}/public/tiboot3.bin
	if [ -f ${DIR}/CORTEXR/sysfw-${SOC_NAME}-${SECURITY_TYPE}-evm.itb ] ; then
		cp -v ${DIR}/CORTEXR/sysfw-${SOC_NAME}-${SECURITY_TYPE}-evm.itb ${DIR}/public/sysfw.itb
	fi
fi

rm -rf ${DIR}/CORTEXR/ || true

if [ -f ${DIR}/public/bl31.bin ] ; then
	if [ -f ${DIR}/public/tee-pager_v2.bin ] ; then
		echo "make -C ./u-boot/ -j1 O=../CORTEXA CROSS_COMPILE=$CC64 $UBOOT_CFG_CORTEXA"
		make -C ./u-boot/ -j1 O=../CORTEXA CROSS_COMPILE=$CC64 $UBOOT_CFG_CORTEXA

		echo "make -C ./u-boot/ -j4 O=../CORTEXA CROSS_COMPILE=$CC64 BL31=${DIR}/public/bl31.bin TEE=${DIR}/public/${DEVICE}/tee-pager_v2.bin BINMAN_INDIRS=${DIR}/ti-linux-firmware/"
		make -C ./u-boot/ -j4 O=../CORTEXA CROSS_COMPILE=$CC64 BL31=${DIR}/public/bl31.bin TEE=${DIR}/public/tee-pager_v2.bin BINMAN_INDIRS=${DIR}/ti-linux-firmware/

		if [ ! -f ${DIR}/CORTEXA/tispl.bin${SIGNED} ] ; then
			echo "Failure in u-boot CORTEXA build of [$UBOOT_CFG_CORTEXA]"
			ls -lha ${DIR}/CORTEXA/
			exit 2
		else
			cp -v ${DIR}/CORTEXA/tispl.bin${SIGNED} ${DIR}/public/tispl.bin || true
			cp -v ${DIR}/CORTEXA/u-boot.img${SIGNED} ${DIR}/public/u-boot.img || true
		fi
	else
		echo "Missing ${DIR}/public/tee-pager_v2.bin"
		exit 2
	fi
else
	echo "Missing ${DIR}/public/bl31.bin"
	exit 2
fi

rm -rf ${DIR}/CORTEXA/ || true

#cd ./u-boot/
#git bisect log
#cd ${DIR}/
#
