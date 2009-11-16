#!/usr/bin/perl

use warnings;
use strict;

use lib 'lib';
use HTML5TV::hCalendar;
use File::Slurp;
use XML::FeedPP;

my $url = 'http://html5tv.rot13.org';

my $html = qq|<!DOCTYPE html>
<html>

<head>
<meta charset="utf-8" />

<link rel="alternate" type="application/rss+xml" title="RSS" href="calendar.xml">

<link rel="icon" type="image/png" href="media/favicon.png">

<script src="js/jquery-1.3.2.min.js" type="text/javascript"></script>

<script src="js/jqueryhcal/jqueryhcal.js" type="text/javascript"></script>
<link rel="stylesheet" type="text/css" href="js/jqueryhcal/jqueryhcal.css" />

<link rel="stylesheet" type="text/css" href="hcalendar.css" />

<title>HTML5TV all media available</title>

</head>

<body>

<div id="jhCalendar"></div> 

|;

my $vevents;
my $feed = XML::FeedPP::RSS->new;
$feed->title( 'HTML5TV' );
$feed->link( $url );

foreach my $path ( glob 'media/*/hCalendar.html' ) {
	next if $path =~ m{_editing};
	warn "+ $path\n";

	my $hcal = HTML5TV::hCalendar->new( $path );

	my $media = (split(/\//, $path))[1];

	if ( ! -e "www/$media.html" ) {
		warn "NO www/$media.html $!";
		next;
	}

	my $html = $hcal->as_HTML(
		[ 'div',
			[ 'a', { href => "$media.html", title => 'watch video', class => 'watch' },
				[ 'img', { src => 'media/favicon.png', border => 0 } ],
			]
		]
	);

	$vevents->{ $hcal->dtstart_iso } = $html;

	my $pubDate = $hcal->dtstart_iso;
	$pubDate =~ s{^(\d\d\d\d)(\d\d)(\d\d).*$}{$1-$2-$3};

	my $item = $feed->add_item( "$url/$media.html" );
	$item->title( $hcal->summary );
	$item->pubDate( $pubDate );
	$item->description( $html );
}

$feed->to_file( 'www/calendar.xml' );

$html .= join("\n", map { $vevents->{$_} } sort keys %$vevents );

$html .= qq|

</body>
</html>

|;

write_file 'www/calendar.html', $html;
