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

my $overview = SDL::Surface->new( -name => 'media/_editing/s/overview.jpg' );

my $app = SDL::App->new(
	-width  => $overview->width(),
	-height => $overview->height(),
	-depth  => 24,
	-title  => 'Slides',
);

my $rect = SDL::Rect->new(
	-height => $overview->height(),
	-width  => $overview->width(),
	-x      => 0,
	-y      => 0,
);

$overview->blit( $rect, $app, $rect );
$app->update( $rect );

<STDIN>;

