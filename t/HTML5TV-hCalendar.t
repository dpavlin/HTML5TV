#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 7;

use lib 'lib';

BEGIN {
	use_ok( 'HTML5TV::hCalendar' );
}

my $path = shift @ARGV || 'media/hCalendar.html';

ok( my $hcal = HTML5TV::hCalendar->new( $path ), "new $path" );

foreach my $class ( qw/organiser summary url dtstart description/ ) {
	ok( defined( my $text = $hcal->$class ), $class );
	diag "$class: $text";
}

