#!/bin/sh

hires=150x150

test -z "$1" && echo "Usage: $0 media/conference/presentation.pdf" && exit

dir=`dirname $1`
to="$dir/s/hires"

echo "generate slide images from $1 to $to"

mkdir -p $dir/s/hires
gs -sDEVICE=jpeg \
	-dNOPAUSE -dBATCH -dSAFER \
	-r$hires \
	-sOutputFile=$to/p%03d.jpg \
	$1

