#!/bin/bash

#apt-get install -y -q bc bison device-tree-compiler flex gcc-arm-linux-gnueabihf libssl-dev python3-cryptography python3-dev python3-jsonschema python3-pycryptodome python3-pyelftools python3-setuptools python3-yaml swig yamllint

check_command() {
    command -v -- "$1" >/dev/null 2>&1
}

# Check for debian compiler
if check_command arm-linux-gnueabihf-gcc; then
	CC32=arm-linux-gnueabihf-
# Check for fedora compiler
elif check_command arm-linux-gnu-gcc; then
	CC32=arm-linux-gnu-
else
	echo "CC32 not found"
	exit 1
fi

CC64=aarch64-linux-gnu-
if ! check_command ${CC64}gcc; then
	echo "CC64 not found"
	exit 1
fi

${CC32}gcc --version
${CC64}gcc --version

DIR=$PWD

. version.sh

echo "****************************************************"
echo [${UBOOT}:${TFA}:${OPTEE}:${TI_FIRMWARE}]
echo "****************************************************"

#rm -rf ./ti-linux-firmware/ || true
if [ ! -d ./ti-linux-firmware/ ] ; then
	if [ -f .gitlab-runner ] ; then
		echo "git clone -b ${TI_FIRMWARE} http://forgejo.gfnd.rcn-ee.org:3000/TexasInstruments/ti-linux-firmware.git"
		git clone -b ${TI_FIRMWARE} http://forgejo.gfnd.rcn-ee.org:3000/TexasInstruments/ti-linux-firmware.git --depth=1 ./ti-linux-firmware/
	else
		echo "git clone -b ${TI_FIRMWARE} https://github.com/TexasInstruments/ti-linux-firmware.git"
		git clone -b ${TI_FIRMWARE} https://github.com/TexasInstruments/ti-linux-firmware.git --depth=1 ./ti-linux-firmware/
	fi
fi

#rm -rf ./trusted-firmware-a/ || true
if [ ! -d ./trusted-firmware-a/ ] ; then
	if [ -f .gitlab-runner ] ; then
		echo "git clone -b ${TFA} http://forgejo.gfnd.rcn-ee.org:3000/mirror/trusted-firmware-a.git"
		git clone -b ${TFA} http://forgejo.gfnd.rcn-ee.org:3000/mirror/trusted-firmware-a.git --depth=1 ./trusted-firmware-a/
	else
		echo "git clone -b ${TFA} ${TFA_GIT}"
		git clone -b ${TFA} ${TFA_GIT} --depth=1 ./trusted-firmware-a/
	fi
fi

#rm -rf ./optee_os/ || true
if [ ! -d ./optee_os/ ] ; then
	if [ -f .gitlab-runner ] ; then
		echo "git clone -b ${OPTEE} http://forgejo.gfnd.rcn-ee.org:3000/mirror/optee_os.git"
		git clone -b ${OPTEE} http://forgejo.gfnd.rcn-ee.org:3000/mirror/optee_os.git --depth=1 ./optee_os/
	else
		echo "git clone -b ${OPTEE} https://github.com/OP-TEE/optee_os.git"
		git clone -b ${OPTEE} https://github.com/OP-TEE/optee_os.git --depth=1 ./optee_os/
	fi
fi

#rm -rf ./u-boot/ || true
if [ ! -d ./u-boot/ ] ; then
	echo "git clone -b ${UBOOT} ${UBOOT_GIT} --depth=1 ./u-boot/"
	git clone -b ${UBOOT} ${UBOOT_GIT} --depth=1 ./u-boot/
fi

mkdir -p ${DIR}/public/

#pocketbeagle2
SOC_NAME=am62x
SECURITY_TYPE=hs-fs
SIGNED=
TFA_BOARD="lite"
TFA_EXTRA_ARGS="K3_USART=0x6"
OPTEE_PLATFORM="k3-am62x"
OPTEE_EXTRA_ARGS="CFG_WITH_SOFTWARE_PRNG=y CFG_CONSOLE_UART=0x6"
UBOOT_CFG_CORTEXR="am62_pocketbeagle2_r5_defconfig"
UBOOT_CFG_CORTEXA="am62_pocketbeagle2_a53_defconfig"

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
