#!/bin/sh -x

echo "deb http://www.debian-multimedia.org sid main" > /etc/apt/sources.list.d/debian-multimedia.list
apt-get update
apt-get install libio-epoll-perl libdata-dump-perl libfile-slurp-perl libyaml-perl libjson-perl libhtml-tree-perl xdotool mplayer
