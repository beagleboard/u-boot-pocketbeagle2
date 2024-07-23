#!/bin/bash

#apt-get install -y -q bc bison device-tree-compiler flex gcc-arm-linux-gnueabihf libssl-dev python3-cryptography python3-dev python3-jsonschema python3-pycryptodome python3-pyelftools python3-setuptools python3-yaml swig yamllint

#wget https://robertcnelson.beagleboard.io/u-boot-bisect/get_n_install.sh ; chmod +x get_n_install.sh ; sudo ./get_n_install.sh

CC32=arm-linux-gnueabihf-
CC64=aarch64-linux-gnu-

${CC32}gcc --version
${CC64}gcc --version

DIR=$PWD

#rm -rf ./ti-linux-firmware/ || true
if [ ! -d ./ti-linux-firmware/ ] ; then
	#git clone -b 10.00.06 https://openbeagle.org/beagleboard/ti-linux-firmware.git --depth=10
	git -c http.sslVerify=false clone -b 10.00.06 https://git.gfnd.rcn-ee.org/TexasInstruments/ti-linux-firmware.git --depth=10
fi

#rm -rf ./trusted-firmware-a/ || true
if [ ! -d ./trusted-firmware-a/ ] ; then
	#git clone -b master https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git --depth=10
	git -c http.sslVerify=false clone -b master https://git.gfnd.rcn-ee.org/mirror/trusted-firmware-a.git --depth=10
fi

#rm -rf ./optee_os/ || true
if [ ! -d ./optee_os/ ] ; then
	#git clone -b 4.3.0 https://github.com/OP-TEE/optee_os.git --depth=10
	git -c http.sslVerify=false clone -b 4.3.0 https://git.gfnd.rcn-ee.org/mirror/optee_os.git --depth=10
fi

if [ -d ./u-boot/ ] ; then
	rm -rf ./u-boot/
fi
#git clone -b v2024.10-rc1 https://github.com/u-boot/u-boot.git
git -c http.sslVerify=false clone -b master https://git.gfnd.rcn-ee.org/mirror/u-boot.git
#git -c http.sslVerify=false clone -b v2024.10-rc1 https://git.gfnd.rcn-ee.org/mirror/u-boot.git
#git -c http.sslVerify=false clone -b v2024.07 https://git.gfnd.rcn-ee.org/mirror/u-boot.git

cd ./u-boot/
git bisect start
git bisect good 3f772959501c99fbe5aa0b22a36efe3478d1ae1c
git bisect bad 123f6f75dfcb5f88d821e4eb91ddedfb7718d601
git bisect bad 005105b11cefe694dcd40572639973fbb9b31646
git bisect bad d8c213c9c7f827a9de0096bb4e5247c9a07bb248
git bisect bad bf3d5baa868a658d4625aaf177096751b8597891

cd ${DIR}/

mkdir -p ${DIR}/public/

#beagleboneai64
SOC_NAME=j721e
SECURITY_TYPE=gp
SIGNED=_unsigned
TFA_BOARD=generic
OPTEE_PLATFORM=k3-j721e
OPTEE_EXTRA_ARGS=""
UBOOT_CFG_CORTEXR="j721e_beagleboneai64_r5_defconfig"
UBOOT_CFG_CORTEXA="j721e_beagleboneai64_a72_defconfig"

echo "make -C ./trusted-firmware-a/ -j4 CROSS_COMPILE=$CC64 CFLAGS= LDFLAGS= ARCH=aarch64 PLAT=k3 SPD=opteed $TFA_EXTRA_ARGS TARGET_BOARD=${TFA_BOARD} all"
make -C ./trusted-firmware-a/ -j4 CROSS_COMPILE="ccache $CC64" CFLAGS= LDFLAGS= ARCH=aarch64 PLAT=k3 SPD=opteed $TFA_EXTRA_ARGS TARGET_BOARD=${TFA_BOARD} all

if [ ! -f ./trusted-firmware-a/build/k3/${TFA_BOARD}/release/bl31.bin ] ; then
	echo "Failure in ./trusted-firmware-a/"
	ls -lha ${DIR}/trusted-firmware-a/
else
	cp -v ./trusted-firmware-a/build/k3/${TFA_BOARD}/release/bl31.bin ${DIR}/public/
fi

echo "make -C ./optee_os/ -j4 O=../optee CROSS_COMPILE=$CC32 CROSS_COMPILE64=$CC64 CFLAGS= LDFLAGS= CFG_ARM64_core=y $OPTEE_EXTRA_ARGS PLATFORM=${OPTEE_PLATFORM} all"
make -C ./optee_os/ -j4 O=../optee CROSS_COMPILE="ccache $CC32" CROSS_COMPILE64="ccache $CC64" CFLAGS= LDFLAGS= CFG_ARM64_core=y $OPTEE_EXTRA_ARGS PLATFORM=${OPTEE_PLATFORM} all

if [ ! -f ./optee/core/tee-pager_v2.bin ] ; then
	echo "Failure in ${OPTEE_DIR}"
	ls -lha ${DIR}/optee/
else
	cp -v ./optee/core/tee-pager_v2.bin ${DIR}/public/
fi

rm -rf ${DIR}/optee/ || true

echo "make -C ./u-boot/ -j1 O=../CORTEXR CROSS_COMPILE=$CC32 $UBOOT_CFG_CORTEXR"
make -C ./u-boot/ -j1 O=../CORTEXR CROSS_COMPILE=$CC32 $UBOOT_CFG_CORTEXR

echo "make -C ./u-boot/ -j4 O=../CORTEXR CROSS_COMPILE=$CC32 BINMAN_INDIRS=${DIR}/ti-linux-firmware/"
make -C ./u-boot/ -j4 O=../CORTEXR CROSS_COMPILE="ccache $CC32" BINMAN_INDIRS=${DIR}/ti-linux-firmware/

if [ ! -f ${DIR}/CORTEXR/tiboot3-${SOC_NAME}-${SECURITY_TYPE}-evm.bin ] ; then
	echo "Failure in u-boot CORTEXR build of [$UBOOT_CFG_CORTEXR]"
	ls -lha ${DIR}/CORTEXR/
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
		make -C ./u-boot/ -j4 O=../CORTEXA CROSS_COMPILE="ccache $CC64" BL31=${DIR}/public/bl31.bin TEE=${DIR}/public/tee-pager_v2.bin BINMAN_INDIRS=${DIR}/ti-linux-firmware/

		if [ ! -f ${DIR}/CORTEXA/tispl.bin${SIGNED} ] ; then
			echo "Failure in u-boot CORTEXA build of [$UBOOT_CFG_CORTEXA]"
			ls -lha ${DIR}/CORTEXA/
		else
			cp -v ${DIR}/CORTEXA/tispl.bin${SIGNED} ${DIR}/public/tispl.bin || true
			cp -v ${DIR}/CORTEXA/u-boot.img${SIGNED} ${DIR}/public/u-boot.img || true
		fi
	else
		echo "Missing ${DIR}/public/tee-pager_v2.bin"
	fi
else
	echo "Missing ${DIR}/public/bl31.bin"
	exit 2
fi

rm -rf ${DIR}/CORTEXA/ || true

cd ./u-boot/
git bisect log
cd ${DIR}/
#