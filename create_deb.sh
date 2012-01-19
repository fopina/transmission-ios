#!/bin/bash

. configuration

export BUILD_DIR="$PWD/out/${ARCH}/transmission"
export TEMP_DIR="$PWD/deb"
export DEBFILE="transmission-${TRANSMISSION_VERSION}-${ARCH}.deb"

rm -fr ${TEMP_DIR}
mkdir -p ${TEMP_DIR}

mkdir -p ${TEMP_DIR}/DEBIAN
cp control ${TEMP_DIR}/DEBIAN
echo "Version: ${TRANSMISSION_VERSION}" >> ${TEMP_DIR}/DEBIAN/control
cp -Rp ${BUILD_DIR} ${TEMP_DIR}/usr
dpkg-deb -b ${TEMP_DIR} ${DEBFILE}
