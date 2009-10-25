#!/usr/bin/perl

# ./bin/sync2yaml.pl media/_editing/sync.txt > media/_editing/video.srt.yaml

use warnings;
use strict;

use YAML;

my @subtitles;

my $nr = 0;

while(<>) {
	chomp;
	if ( m{(\d+):(\d+)\s+(.+)} ) {
		my $t = $1 * 60 + $2;
		$nr++;
		push @subtitles, [ $t, $t+3, "[$nr] $3" ];
	} else {
		die "unknown format: $_";
	}

}

print Dump @subtitles;
