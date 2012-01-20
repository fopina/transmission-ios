#!/bin/bash

# script taken from iTransmission project
# (https://github.com/ccp0101/iTransmission/blob/master/make_depend/build.sh)
 
. configuration

export TEMP_DIR="$PWD/temp"
export PATCH_DIR="$PWD/patches"
export BUILD_FILTER="ssl,curl,trans,libev"

function do_abort {
	echo $1 >&2
	exit 1
}

function do_loadenv {
	export BUILD_DIR="$PWD/out/${ARCH}"
	export BUILD_DIR_TRANS="$BUILD_DIR/transmission"

	if [ ${ARCH} = "i386" ]
		then
		PLATFORM="iPhoneSimulator"
	elif [ ${ARCH} = "armv7" ]
		then
		PLATFORM="iPhoneOS"
	elif [ ${ARCH} = "armv6" ]
		then
		PLATFORM="iPhoneOS"
	elif [ ${ARCH} = "system" ]
		then
		PLATFORM="none"
	else
		do_abort "invalid arch ${ARCH} specified"
	fi
}

function do_export {
	unset CFLAGS
	if [[ ${ARCH} != "system" ]]; then
		export DEVROOT="/Developer/Platforms/${PLATFORM}.platform/Developer"
		export SDKROOT="/Developer/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}$SDK_VERSION.sdk"
		export LD=${DEVROOT}/usr/bin/ld
		export CPP=/usr/bin/cpp
		export CXX="${DEVROOT}/usr/bin/g++"
		unset AR
		unset AS
		export NM=${DEVROOT}/usr/bin/nm
		export CXXCPP=/usr/bin/cpp
		export RANLIB=${DEVROOT}/usr/bin/ranlib
		export CFLAGS="-arch ${ARCH} -isysroot ${SDKROOT}"
		export LDFLAGS="-L${SDKROOT}/usr/lib -L${DEVROOT}/usr/lib -isysroot ${SDKROOT} -Wl,-syslibroot $SDKROOT"
	fi
	export CC="${DEVROOT}/usr/bin/gcc"
	export CFLAGS="${CFLAGS} -I${BUILD_DIR}/include -I${BUILD_DIR_TRANS}/include -I${SDKROOT}/usr/include -pipe -no-cpp-precomp"
	export CXXFLAGS="${CFLAGS}"
	export LDFLAGS="-L${BUILD_DIR}/lib -L${BUILD_DIR_TRANS}/lib -pipe -no-cpp-precomp ${LDFLAGS}"
	export COMMON_OPTIONS="--disable-shared --enable-static --disable-ipv6 --disable-manual "
	
	if [ ${PLATFORM} = "iPhoneOS" ]
		then
		COMMON_OPTIONS="--host arm-apple-darwin ${COMMON_OPTIONS}"
	elif [ ${PLATFORM} = "iPhoneSimulator" ]
		then
		COMMON_OPTIONS="--host i386-apple-darwin ${COMMON_OPTIONS}"
	fi	

	export PKG_CONFIG_PATH="${SDKROOT}/usr/lib/pkgconfig:${BUILD_DIR}/lib/pkgconfig"
}

function do_openssl {
	export PACKAGE_NAME="openssl-${OPENSSL_VERSION}"
	pushd ${TEMP_DIR}
	if [ ! -e "${PACKAGE_NAME}.tar.gz" ]
	then
	  /usr/bin/curl -O -L "http://www.openssl.org/source/${PACKAGE_NAME}.tar.gz" || do_abort "$FUNCNAME: fetch failed "
	fi
	
	rm -rf "${PACKAGE_NAME}"
	tar zxvf "${PACKAGE_NAME}.tar.gz" || do_abort "$FUNCNAME: unpack failed "
	
	pushd ${PACKAGE_NAME}
	
	do_export
	
	./configure BSD-generic32 --openssldir=${BUILD_DIR} || do_abort "$FUNCNAME: configure failed "
	
	# Patch for iOS, taken from https://github.com/st3fan/ios-openssl/blame/master/build.sh
	perl -i -pe "s|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|" ./crypto/ui/ui_openssl.c
	perl -i -pe "s|^CC= gcc|CC= ${CC}|g" Makefile
	perl -i -pe "s|^CFLAG= (.*)|CFLAG= ${CFLAGS} $1|g" Makefile
	
	if [ ${PLATFORM} = "iPhoneSimulator" ]
		then
		pushd crypto/bn
		rm -f bn_prime.h
		perl bn_prime.pl >bn_prime.h
		popd
	fi
	
	make -j ${PARALLEL_NUM} || do_abort "$FUNCNAME: make failed "
	make install || do_abort "$FUNCNAME: install failed "
	
	rm -rf ${BUILD_DIR}/share/man
	
	popd
	popd
}

function do_curl {
	export PACKAGE_NAME="curl-${CURL_VERSION}"
	pushd ${TEMP_DIR}
	if [ ! -e "${PACKAGE_NAME}.tar.gz" ]
	then
	  /usr/bin/curl -O -L "http://www.execve.net/curl/${PACKAGE_NAME}.tar.gz" || do_abort "$FUNCNAME: fetch failed "
	fi
	
	rm -rf "${PACKAGE_NAME}"
	tar zxvf "${PACKAGE_NAME}.tar.gz" || do_abort "$FUNCNAME: unpack failed "
	
	pushd ${PACKAGE_NAME}
	
	do_export

	./configure --prefix="${BUILD_DIR}" ${COMMON_OPTIONS} --with-random=/dev/urandom --with-ssl --with-zlib LDFLAGS="${LDFLAGS}" || do_abort "$FUNCNAME: configure failed "
	
	make -j ${PARALLEL_NUM} || do_abort "$FUNCNAME: make failed "
	make install || do_abort "$FUNCNAME: install failed "
	
	popd
	popd
}

function do_libevent {
	export PACKAGE_NAME="libevent-${LIBEVENT_VERSION}"
	pushd ${TEMP_DIR}
	if [ ! -e "${PACKAGE_NAME}.tar.gz" ]
	then
	  /usr/bin/curl -O -L "https://github.com/downloads/libevent/libevent/${PACKAGE_NAME}.tar.gz" || do_abort "$FUNCNAME: fetch failed "
	fi
	
	rm -rf "${PACKAGE_NAME}"
	tar zxvf "${PACKAGE_NAME}.tar.gz" || do_abort "$FUNCNAME: unpack failed "
	
	pushd ${PACKAGE_NAME}
	
	do_export
	
	./configure --prefix="${BUILD_DIR}" ${COMMON_OPTIONS} || do_abort "$FUNCNAME: configure failed "
	
	make -j ${PARALLEL_NUM} || do_abort "$FUNCNAME: make failed "
	make install || do_abort "$FUNCNAME: install failed "
	
	popd
	popd
}

function do_transmission {	
	export PACKAGE_NAME="transmission-${TRANSMISSION_VERSION}"
	pushd ${TEMP_DIR}
	if [ ! -e "${PACKAGE_NAME}.tar.bz2" ]
	then
	  /usr/bin/curl -O -L "http://transmission.cachefly.net/${PACKAGE_NAME}.tar.bz2" || do_abort "$FUNCNAME: fetch failed "
	fi
	
	if [[ -z $DONT_OVERWRITE ]]; then
		rm -rf "${PACKAGE_NAME}"
		tar jxvf "${PACKAGE_NAME}.tar.bz2" || do_abort "$FUNCNAME: unpack failed "
	fi
	
	pushd ${PACKAGE_NAME}
	
	#apply whitelist patch (to allow LAN clients by default)
	pushd libtransmission
	patch -N < ${PATCH_DIR}/rpc_lan_whitelist.patch
	popd
	
	do_export
	
	if [[ ! -z $DONT_OVERWRITE ]]; then
		make clean
	fi
	
	./configure --prefix="${BUILD_DIR_TRANS}" ${COMMON_OPTIONS} --enable-largefile --enable-utp --disable-nls --enable-lightweight --enable-cli --enable-daemon --disable-mac --disable-gtk --with-kqueue --enable-debug || do_abort "$FUNCNAME: configure failed "
	
	if [ ! -e "${SDKROOT}/usr/include/net/route.h" ]
		then
		mkdir -p ${BUILD_DIR_TRANS}/include/net
		cp "/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator${SDK_VERSION}.sdk/usr/include/net/route.h" "${BUILD_DIR_TRANS}/include/net/route.h"
	fi
	
	make -j ${PARALLEL_NUM} || do_abort "$FUNCNAME: make failed "
	make install || do_abort "$FUNCNAME: install failed "
	
	# Default installation doesn't copy library and header files
	mkdir -p ${BUILD_DIR_TRANS}/include/libtransmission
	mkdir -p ${BUILD_DIR_TRANS}/lib
	find ./libtransmission -name "*.h" -exec cp "{}" ${BUILD_DIR_TRANS}/include/libtransmission \;
	find . -name "*.a" -exec cp "{}" ${BUILD_DIR_TRANS}/lib \;
	
	popd
	popd
}

do_loadenv

while getopts ":o:a:n" opt; do
  	case $opt in
		a)
		  export ARCH="$OPTARG"
		  do_loadenv
		  ;;
	    o)
	      export BUILD_FILTER="$OPTARG"
	      ;;
		n)
		  export DONT_OVERWRITE="YES"
		  ;;
	    \?)
	      do_abort "Invalid option: -$OPTARG"
	      ;;
	    :)
	      do_abort "Option -$OPTARG requires an argument."
	      ;;
	esac
done

mkdir -p ${TEMP_DIR}

if [[ $BUILD_FILTER == *ssl* ]]; then
	do_openssl
fi
if [[ $BUILD_FILTER == *curl* ]]; then
	do_curl
fi
if [[ $BUILD_FILTER == *libev* ]]; then
	do_libevent
fi
if [[ $BUILD_FILTER == *trans* ]]; then
	do_transmission
fi
