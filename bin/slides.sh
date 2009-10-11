#!/bin/sh

hires=150x150

dir=www/s

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
		-sOutputFile=$dir/hires/p%08d.jpg \
		$1 \
	|| exit
fi

ls -d $dir/* | grep x | sed "s,$dir/*,," | while read size ; do
	echo "# $size";
	ls $dir/hires/* | cut -d/ -f4- | xargs -i convert $dir/hires/{} -resize $size $dir/$size/{}
	montage -geometry +1+1 -frame 3 -label %f $dir/$size/* $dir/$size.png
	qiv $dir/$size.png
done

