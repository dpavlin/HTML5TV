#!/usr/bin/perl

# ./bin/srt2yaml.pl media/_editing/captions.srt > media/_editing/video.srt.yaml

use warnings;
use strict;

use YAML;
use Data::Dump qw(dump);

my @subtitles;

my $nr = 0;
our @s;

sub to_t {
	my $txt = shift;
	$txt =~ s/,/./; # fix decimal
	my @t = split(/:/,$txt);
	my $t = ( $t[0] * 60 * 60 ) + ( $t[1] * 60 ) + $t[2];
	warn "# $txt -> $t\n";
	return $t;
}

while(<>) {
	s/^\xEF\xBB\xBF//; # strip utf-8 marker
	s/[\n\r]+$//;
	warn "# ",dump $_;
	if ( length($_) == 0 ) {

		warn "s = ",dump(@s);

		my ( $f,$t ) = split(/\s*-->\s*/, $s[1], 2);

		$subtitles[ $s[0] ] = [ to_t($f), to_t($t), join(" ", @s[ 2 .. $#s ]) ];

		@s = ();
		next;
	}
	push @s, $_;

}

$subtitles[0] ||= [ 0, 0.001, "[1]" ]; # fake first slide

print Dump @subtitles;
