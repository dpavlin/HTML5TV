#!/bin/sh -x

ls -al wsdm09_dean_cblirs_01.flv && exit

../../contrib/rtmpdump/rtmpdump_x86 --host oxy.videolectures.net --port 1935 --app video --playpath 2009/other/wsdm09_barcelona/dean_cblirs/wsdm09_dean_cblirs_01 --flv wsdm09_dean_cblirs_01.flv

