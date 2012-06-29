#!/bin/bash

. configuration

export BUILD_DIR="$PWD/out/${ARCH}/transmission"
export TEMP_DIR="$PWD/deb"
export DEBFILE="transmission-${TRANSMISSION_VERSION}-${ARCH}.deb"

rm -fr ${TEMP_DIR}

mkdir -p ${TEMP_DIR}/DEBIAN
cp deblayout/control deblayout/postinst deblayout/prerm ${TEMP_DIR}/DEBIAN
echo "Version: ${TRANSMISSION_VERSION}" >> ${TEMP_DIR}/DEBIAN/control
chmod 755 ${TEMP_DIR}/DEBIAN/postinst ${TEMP_DIR}/DEBIAN/prerm

mkdir -p ${TEMP_DIR}/Library/LaunchDaemons
cp deblayout/cc.fopina.transmission.plist ${TEMP_DIR}/Library/LaunchDaemons

cp -Rp ${BUILD_DIR} ${TEMP_DIR}/usr

#ldid - why wasnt this required prior to iOS 5.1...?
ldid -S ${TEMP_DIR}/usr/bin/transmission*

dpkg-deb -b ${TEMP_DIR} ${DEBFILE}
