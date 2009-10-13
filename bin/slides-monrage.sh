#!/bin/sh

dir=www/media/s

ls -d $dir/* | grep x | sed "s,$dir/*,," | sort -n -r | while read size ; do
	echo "# $size";

	if [ ! -e $dir/bars.png ] ; then
		convert media/SMPTE_Color_Bars.svg -geometry $size $dir/bars.png
	fi

	montage -geometry +1+1 -frame 3 -label %f $dir/$size/* $dir/$size.png
	qiv $dir/$size.png
done

