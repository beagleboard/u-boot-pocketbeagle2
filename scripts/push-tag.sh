#!/bin/bash

wfile=$(mktemp /tmp/builder.XXXXXXXXX)

. version.sh

echo "****************************************************"
echo [${UBOOT}:${TFA}:${OPTEE}:${TI_FIRMWARE}:${REBUILD}]
echo "****************************************************"

cp public/base.sh public/get_n_install.sh
sed -i -e 's:TAG:'${UBOOT}'-'${TI_FIRMWARE}'-'${REBUILD}':g' public/get_n_install.sh

echo "${UBOOT}-${TI_FIRMWARE}-${REBUILD} release" > ${wfile}

git commit -a -F ${wfile} -s

git tag -a ${UBOOT}-${TI_FIRMWARE}-${REBUILD} -m "${UBOOT}-${TI_FIRMWARE}-${REBUILD}"

git push origin main --tags
