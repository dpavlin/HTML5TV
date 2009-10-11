#!/bin/sh

hires=150x150

dir=www/media/s

if [ -e "$1" ] ; then
	dir=`dirname $1`
	dir="$dir/s"
fi

echo "output directory: $dir"

if [ `ls $dir/hires/p*.jpg | wc -l` == 0 ] ; then

	test -z "$1" && echo "Usage: $0 media/conference/presentation.pdf" && exit

	mkdir -p $dir/hires
	gs -sDEVICE=jpeg \
		-dNOPAUSE -dBATCH -dSAFER \
		-r$hires \
		-sOutputFile=$dir/hires/p%03d.jpg \
		$1 \
	|| exit
fi

ls -d $dir/* | grep x | sed "s,$dir/*,," | sort -n -r | while read size ; do
	echo "# $size";

	if [ ! -e $dir/bars.png ] ; then
		convert media/SMPTE_Color_Bars.svg -geometry $size $dir/bars.png
	fi

	ls $dir/hires/* | sed "s,$dir/hires/,," | xargs -i convert $dir/hires/{} -resize $size $dir/$size/{}
	montage -geometry +1+1 -frame 3 -label %f $dir/$size/* $dir/$size.png
	qiv $dir/$size.png
done

