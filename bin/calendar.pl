#!/usr/bin/perl

use warnings;
use strict;

use lib 'lib';
use HTML5TV::hCalendar;
use File::Slurp;
use XML::FeedPP;
use HTML::ResolveLink;

my $url = 'http://html5tv.rot13.org';

my $style = qq|
<style type="text/css">

|
. read_file('www/css/hCalendar.css')
. qq|

.watch {
	margin-right: 0.1em;
}

</style>
|;

my $html = qq|<!DOCTYPE html>
<html>

<head>
<meta charset="utf-8" />

<link rel="alternate" type="application/rss+xml" title="RSS" href="calendar.xml">

<link rel="icon" type="image/png" href="media/favicon.png">

<script src="js/jquery-1.3.2.min.js" type="text/javascript"></script>

<script src="js/jqueryhcal/jqueryhcal.js" type="text/javascript"></script>
<link rel="stylesheet" type="text/css" href="js/jqueryhcal/jqueryhcal.css" />

<link rel="stylesheet" type="text/css" href="css/hCalendar.css" />

$style

<title>HTML5TV all media available</title>

</head>

<body>

<div id="jhCalendar"></div>

|;

my $vevents;
my $feed = XML::FeedPP::RSS->new;
$feed->title( 'HTML5TV' );
$feed->link( $url );

my $resolver = HTML::ResolveLink->new( base => $url );

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
		[ 'span', { class => 'watch' },
			[ 'a', { href => "$media.html", title => $media, },
				[ 'img', { src => 'media/favicon.png', border => 0 } ],
			]
		]
	);

	$vevents->{ $hcal->dtstart_iso . $media } = $html;

	my $pubDate = $hcal->dtstart_iso;
	$pubDate =~ s{^(\d\d\d\d)(\d\d)(\d\d).*$}{$1-$2-$3};

	my $item = $feed->add_item( "$url/$media.html" );
	$item->title( $hcal->summary );
	$item->pubDate( $pubDate );
	$item->description( $style . $resolver->resolve( $html ) );
}

$feed->to_file( 'www/calendar.xml' );

$html .= join("\n", map { $vevents->{$_} } sort keys %$vevents );

$html .= qq|

<a href="calendar.xml">rss</a>

</body>
</html>

|;

write_file 'www/calendar.html', $html;
