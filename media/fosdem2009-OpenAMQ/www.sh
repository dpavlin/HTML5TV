#!/bin/sh -x

#wget -nc http://ftp.belnet.be/mirror/FOSDEM/2009/maintracks/openamq.ogv
wget -nc http://video.fosdem.org/2009/maintracks/openamq.xvid.avi && \
	ffmpeg2theora-0.25.linux32.bin --width 640 --height 360 --aspect 4:3 openamq.xvid.avi
# http://www.slideshare.net/pieterh/restms-introduction
