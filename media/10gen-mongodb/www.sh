#!/bin/sh -x

wget -nc http://assets.leadit.us/mysql/MongoDB-10gen-CEO-Dwight-Merriman-presenting-at-NYC-MySQL-Group-at-Sun-Microsystems.pdf
wget -nc http://blip.tv/file/get/Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.flv -O Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.flv
ffmpeg2theora --sync -p videobin Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.flv
#ffmpeg -i Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.flv -s 512x288 -vcodec libtheora -acodec libvorbis Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.ogv
