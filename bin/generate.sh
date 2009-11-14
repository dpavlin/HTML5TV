#!/bin/sh -x

ls media/*/hCalendar.html | cut -d/ -f-2 | grep -v _editing | GENERATE=1 xargs -i ./bin/mplayer.pl {}
