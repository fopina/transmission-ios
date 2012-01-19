transmission-os
==========
This is a set of scripts to make it easier to cross-compile transmission for iOS and package it (mainly to use in Apple TV 2nd gen).

Usage
-----

Using the terminal (assuming you have a working installation of XCode and git):
clone this repository
	git clone git@github.com:fopina/transmission-ios.git
compile transmission and dependencies
	cd transmission-ios
	./build.sh
create the deb file
	./create_deb.sh
copy it to jailbroken AppleTV 2G (any other iOS device)
	scp transmission*.deb mobile@apple-tv:
install it in the device
	ssh root@apple-tv
	cd ~mobile
	dpkg -i transmission*.deb
	
It's done.
Personally, regarding Apple TV usage, I like to install the XBMC Transmission plugin as well.

Links
-------
http://www.transmissionbt.com/
