#!/bin/sh -x

hires=150x150

if [ `ls www/s/hires/p*.jpg | wc -l` == 0 ] ; then
	mkdir -p www/s/hires
	gs -sDEVICE=jpeg \
		-dNOPAUSE -dBATCH -dSAFER \
		-r$hires \
		-sOutputFile=www/s/hires/p%08d.jpg \
		$1 \
	|| exit
fi

ls -d www/s/* | grep x | cut -d/ -f3 | while read size ; do
	echo "# $size";
	ls www/s/hires/* | cut -d/ -f4- | xargs -i convert www/s/hires/{} -resize $size www/s/$size/{}
	montage -geometry +1+1 -frame 3 -label %f www/s/$size/* www/s/$size.png
	qiv s/$size.png
done

