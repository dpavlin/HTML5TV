#!/usr/bin/perl

use warnings;
use strict;

use lib 'lib';
use HTML5TV::hCalendar;
use File::Slurp;

my $html = qq|<!DOCTYPE html>
<html>

<head>
<meta charset="utf-8" />

<link rel="icon" type="image/png" href="media/favicon.png">

<script src="js/jqueryhcal/jqueryhcal.js" type="text/javascript"></script>
<link rel="stylesheet" type="text/css" href="js/jqueryhcal/jqueryhcal.css" />

<link rel="stylesheet" type="text/css" href="hcalendar.css" />

<title>HTML5TV all media available</title>

</head>

<body>

<div id="jhCalendar"></div> 

|;

my $vevents;

foreach my $path ( glob 'media/*/hCalendar.html' ) {
	next if $path =~ m{_editing};
	warn "+ $path\n";

	my $hcal = HTML5TV::hCalendar->new( $path );

	my $media = (split(/\//, $path))[1];

	if ( ! -e "www/$media.html" ) {
		warn "NO www/$media.html $!";
		next;
	}

	$vevents->{ $hcal->dtstart_iso } = $hcal->as_HTML(
		[ 'a', { href => "$media.html", title => 'watch video', class => 'watch' },
			[ 'img', { src => 'media/favicon.png' } ],
		]
	);
}

$html .= join("\n", map { $vevents->{$_} } sort keys %$vevents );

$html .= qq|

</body>
</html>

|;

write_file 'www/calendar.html', $html;
