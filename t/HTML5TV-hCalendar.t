#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 10;

use lib 'lib';

BEGIN {
	use_ok( 'HTML5TV::hCalendar' );
}

my $path = shift @ARGV || 'media/hCalendar.html';

ok( my $hcal = HTML5TV::hCalendar->new( $path ), "new $path" );

ok( my $html = $hcal->as_HTML, 'as_HTML' );
diag $html;

ok( my $date = $hcal->dtstart_iso, 'dtstart_iso' );
diag $date;

foreach my $class ( qw/organiser summary url location dtstart description/ ) {
	ok( defined( my $text = $hcal->$class ), $class );
	diag "$class: $text";
}

