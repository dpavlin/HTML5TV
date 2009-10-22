#!/usr/bin/perl

use warnings;
use strict;

use Graphics::Magick;
use File::Path qw(rmtree);

my $length = 100;
my $fps = 5;

rmtree "/tmp/blank";
mkdir "/tmp/blank";

my $frame_fmt = '/tmp/blank/f%08d.jpg';

foreach my $pos ( 0 .. $length * $fps ) {

	my $im = Graphics::Magick->new( size => '320x200' );
	$im->ReadImage( 'xc:black' );
	my $t = $pos / $fps;
	my $hh = int( $t / 60 / 60 );
	my $mm = int( $t / 60 );
	my $ss = $t - $mm * 60 - $hh * 60 * 60;
	$im->Annotate(
		x => 10, y => 175,
		font => 'Sans', pointsize => 24,
		text => sprintf("%02d:%02d:%06.3f", $hh, $mm, $ss ),
		fill => 'yellow',
	);
	my $path = sprintf $frame_fmt, $pos;
	$im->Write( filename => $path );
#	warn "# $hh $mm $ss $path ", -s $path, $/ if $t % $fps == 0;
	print STDERR '.' if $pos % $fps == 0;
}

print STDERR "\n";

#system "oggSlideshow -f $fps -o /tmp/blank.ogv -d 20000 -e -l $fps -t p /tmp/blank/f*";
system "ffmpeg2theora --framerate $fps --keyint $fps -o /tmp/blank.ogv $frame_fmt";

rmtree "/tmp/blank";

