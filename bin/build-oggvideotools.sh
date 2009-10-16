#!/bin/sh

test -d oggvideotools || svn co https://oggvideotools.svn.sourceforge.net/svnroot/oggvideotools/trunk oggvideotools
cd oggvideotools
svn update
./autogen.sh
./configure
make
