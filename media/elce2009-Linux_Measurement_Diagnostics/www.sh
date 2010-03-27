wget -nc -O survey_of_linux_measurement_and_diagnostic_tools.pdf \
	'http://tree.celinuxforum.org/CelfPubWiki/ELCEurope2009Presentations?action=AttachFile&do=get&target=survey_of_linux_measurement_and_diagnostic_tools.pdf'
wget -nc http://free-electrons.com/pub/video/2009/elce/elce2009-rowand-measurement-diagnostic-tools.ogv && \
	ffmpeg2theora -p preview -o elce2009-rowand-measurement-diagnostic-tools-preview.ogv elce2009-rowand-measurement-diagnostic-tools.ogv
