#!/bin/sh

hires=150x150

test -z "$1" && echo "Usage: $0 media/conference/presentation.pdf" && exit

dir=`dirname $1`

echo "generate slide images from $1 to $dir/hires"

mkdir -p $dir/hires
gs -sDEVICE=jpeg \
	-dNOPAUSE -dBATCH -dSAFER \
	-r$hires \
	-sOutputFile=$dir/hires/p%03d.jpg \
	$1

