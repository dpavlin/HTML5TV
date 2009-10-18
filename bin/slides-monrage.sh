#!/bin/sh

dir=media/_editing/s

function resize() {
	size=$1
	gm montage -geometry +1+1 -frame 3 -label %f $dir/$size/* $dir/$size.png
	qiv $dir/$size.png
}

#resize hires
resize 1
resize 2
resize 4

