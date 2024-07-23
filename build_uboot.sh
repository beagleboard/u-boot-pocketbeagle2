#!/bin/bash

#apt-get install -y -q bc bison device-tree-compiler flex gcc-arm-linux-gnueabihf libssl-dev python3-cryptography python3-dev python3-jsonschema python3-pycryptodome python3-pyelftools python3-setuptools python3-yaml swig yamllint

CC32=arm-linux-gnueabihf-
CC64=aarch64-linux-gnu-

${CC32}gcc --version
${CC64}gcc --version

DIR=$PWD

if [ ! -d ./ti-linux-firmware/ ] ; then
	git clone -b ti-linux-firmware https://openbeagle.org/beagleboard/ti-linux-firmware.git --depth=10
else
	cd ./ti-linux-firmware/
	git pull --rebase
	cd ../
fi

if [ ! -d ./trusted-firmware-a/ ] ; then
	git clone -b master https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git --depth=10
else
	cd ./trusted-firmware-a/
	git pull --rebase
	cd ../
fi

if [ ! -d ./optee_os/ ] ; then
	git clone -b master https://github.com/OP-TEE/optee_os.git --depth=10
else
	cd ./optee_os/
	git pull --rebase
	cd ../
fi

if [ -d ./ti-u-boot/ ] ; then
	rm -rf ./ti-u-boot/
fi
git clone -b v2023.04-ti-09.02.00.009-BeagleY-AI https://github.com/beagleboard/u-boot.git ./ti-u-boot/ --depth=10

mkdir -p ${DIR}/public/

SOC_NAME=j722s
SECURITY_TYPE=hs-fs

#TFA_TAG=v2.10.0
TFA_BOARD=lite

#OPTEE_TAG=4.1.0
OPTEE_PLATFORM=k3-am62x
OPTEE_EXTRA_ARGS="CFG_WITH_SOFTWARE_PRNG=y CFG_TEE_CORE_LOG_LEVEL=1"

UBOOT_CFG_CORTEXR="j722s_evm_r5_defconfig"
UBOOT_CFG_CORTEXA="j722s_evm_a53_defconfig"

echo "make -C ./trusted-firmware-a/ -j4 CROSS_COMPILE=$CC64 CFLAGS= LDFLAGS= ARCH=aarch64 PLAT=k3 SPD=opteed $TFA_EXTRA_ARGS TARGET_BOARD=${TFA_BOARD} all"
make -C ./trusted-firmware-a/ -j4 CROSS_COMPILE=$CC64 CFLAGS= LDFLAGS= ARCH=aarch64 PLAT=k3 SPD=opteed $TFA_EXTRA_ARGS TARGET_BOARD=${TFA_BOARD} all

if [ ! -f ./trusted-firmware-a/build/k3/${TFA_BOARD}/release/bl31.bin ] ; then
	echo "Failure in ./trusted-firmware-a/"
else
	cp -v ./trusted-firmware-a/build/k3/${TFA_BOARD}/release/bl31.bin ${DIR}/public/
fi

echo "make -C ./optee_os/ -j4 O=../optee CROSS_COMPILE=$CC32 CROSS_COMPILE64=$CC64 CFLAGS= LDFLAGS= CFG_ARM64_core=y $OPTEE_EXTRA_ARGS PLATFORM=${OPTEE_PLATFORM} all"
make -C ./optee_os/ -j4 O=../optee CROSS_COMPILE=$CC32 CROSS_COMPILE64=$CC64 CFLAGS= LDFLAGS= CFG_ARM64_core=y $OPTEE_EXTRA_ARGS PLATFORM=${OPTEE_PLATFORM} all

if [ ! -f ./optee/core/tee-pager_v2.bin ] ; then
	echo "Failure in ${OPTEE_DIR}"
else
	cp -v ./optee/core/tee-pager_v2.bin ${DIR}/public/
fi

rm -rf ${DIR}/optee/ || true

echo "make -C ./ti-u-boot/ -j1 O=../CORTEXR CROSS_COMPILE=$CC32 $UBOOT_CFG_CORTEXR"
make -C ./ti-u-boot/ -j1 O=../CORTEXR CROSS_COMPILE=$CC32 $UBOOT_CFG_CORTEXR

echo "make -C ./ti-u-boot/ -j4 O=../CORTEXR CROSS_COMPILE=$CC32 BINMAN_INDIRS=${DIR}/ti-linux-firmware/"
make -C ./ti-u-boot/ -j4 O=../CORTEXR CROSS_COMPILE=$CC32 BINMAN_INDIRS=${DIR}/ti-linux-firmware/

if [ ! -f ${DIR}/CORTEXR/tiboot3-${SOC_NAME}-${SECURITY_TYPE}-evm.bin ] ; then
	echo "Failure in u-boot $UBOOT_CFG_CORTEXR"
else
	cp -v ${DIR}/CORTEXR/tiboot3-${SOC_NAME}-${SECURITY_TYPE}-evm.bin ${DIR}/public/tiboot3.bin
fi

rm -rf ${DIR}/CORTEXR/ || true

if [ -f ${DIR}/public/bl31.bin ] ; then
	if [ -f ${DIR}/public/tee-pager_v2.bin ] ; then
		echo "make -C ./ti-u-boot/ -j1 O=../CORTEXA CROSS_COMPILE=$CC64 $UBOOT_CFG_CORTEXA"
		make -C ./ti-u-boot/ -j1 O=../CORTEXA CROSS_COMPILE=$CC64 $UBOOT_CFG_CORTEXA

		echo "make -C ./ti-u-boot/ -j4 O=../CORTEXA CROSS_COMPILE=$CC64 BL31=${DIR}/public/bl31.bin TEE=${DIR}/public/${DEVICE}/tee-pager_v2.bin BINMAN_INDIRS=${DIR}/ti-linux-firmware/"
		make -C ./ti-u-boot/ -j4 O=../CORTEXA CROSS_COMPILE=$CC64 BL31=${DIR}/public/bl31.bin TEE=${DIR}/public/tee-pager_v2.bin BINMAN_INDIRS=${DIR}/ti-linux-firmware/

		if [ ! -f ${DIR}/CORTEXA/tispl.bin ] ; then
			echo "Failure in u-boot $UBOOT_CFG_CORTEXA"
		else
			cp -v ${DIR}/CORTEXA/tispl.bin ${DIR}/public/tispl.bin || true
			cp -v ${DIR}/CORTEXA/u-boot.img ${DIR}/public/u-boot.img || true
		fi
	else
		echo "Missing ${DIR}/public/tee-pager_v2.bin"
	fi
else
	echo "Missing ${DIR}/public/bl31.bin"
	exit 2
fi

rm -rf ${DIR}/CORTEXA/ || true
#

