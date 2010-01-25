#!/bin/sh -x

wget -nc http://assets.leadit.us/mysql/MongoDB-10gen-CEO-Dwight-Merriman-presenting-at-NYC-MySQL-Group-at-Sun-Microsystems.pdf
wget http://blip.tv/file/get/Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.flv -O Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.flv
ffmpeg2theora -p preview Emagazine-10genCEODoubleClickCoFounderPresentingMongoDBHighPerforma244.flv
