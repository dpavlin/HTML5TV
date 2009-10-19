use warnings;
use strict;

package HTML5TV::Slides;

use SDL::App;
use SDL::Surface;
use SDL::Rect;

sub new {
	my $class = shift;
	my $self = {
		border_color => SDL::Color->new( -r => 0xFF, -g => 0xCC, -b => 0x00 ),
	};
	bless $self, $class;
}

our $app;

my ( $x, $y ) = ( 0, 0 );
my ( $w, $h );

my @factors = ( qw/ 4 4 4 4 1 2 2 4 4 4 4 / );

foreach my $path (
	sort {
		my $n_a = $1 if $a =~ m{(\d+)};
		my $n_b = $1 if $b =~ m{(\d+)};
		$n_a <=> $n_b || $a cmp $b
	} glob("media/_editing/s/2/*")
) {

	my $factor = shift @factors || '4';
	$path =~ s{/s/[124]/}{/s/$factor/};

	my $slide = SDL::Surface->new( -name => $path );

	my $rect = SDL::Rect->new(
		-width  => $slide->width(),
		-height => $slide->height(),
		-x      => 0,
		-y      => 0,
	);

	my $to = SDL::Rect->new(
		-width  => $slide->width(),
		-height => $slide->height(),
		-x      => $x,
		-y      => $y,
	);

	warn "$x $y $path\n";

	if ( ! $app ) {
		$w = $slide->width()  * $factor;
		$h = $slide->height() * $factor * 2;

		warn "window $w $h\n";

		$app = SDL::App->new(
			-width  => $w,
			-height => $h,
			-depth  => 24,
			-title  => 'Slides',
		);

	}

		
	$slide->blit( $rect, $app, $to );
	$app->update( $to );

	$x += $slide->width();

	if ( $x >= $w ) {
		$x = 0;
		$y += $slide->height();
	}

}

warn "window $w $h\n";


<STDIN>;

