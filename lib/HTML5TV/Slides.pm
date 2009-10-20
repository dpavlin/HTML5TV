package HTML5TV::Slides;

use warnings;
use strict;

use SDL::App;
use SDL::Surface;
use SDL::Rect;

use Data::Dump qw/dump/;

sub new {
	my $class = shift;
	my $current_slide = shift || die "need current slide coderef!";
	my $self = {
		last_nr => -42,
		current_slide => $current_slide,
	};
	bless $self, $class;
}

sub current_slide {
	my $self = shift;
	$self->{current_slide}->( shift );
}

sub show {
	my ( $self, $t ) = @_;

	my @subtitles =
		sort {
			my $n_a = $1 if $a =~ m{(\d+)};
			my $n_b = $1 if $b =~ m{(\d+)};
			$n_a <=> $n_b || $a cmp $b
		} glob("media/_editing/s/1/*")
	;

	my $slide = SDL::Surface->new( -name => $subtitles[0] );
	my $w = $slide->width;
	my $h = $slide->height;

	my @factors = ( qw/ 4 4 4 4 1 2 2 4 4 4 4 / );

	my ( $x, $y ) = ( 0, 0 );

	my $background = SDL::Color->new( -r => 0, -g => 0, -b => 0 );

	foreach my $i ( 0 .. $#factors ) {

		my $factor = $factors[$i] || die "no factor $i in ",dump @factors;

		my $to = SDL::Rect->new(
			-width  => $w / $factor,
			-height => $h / $factor,
			-x      => $x,
			-y      => $y,
		);

		my $pos = $self->current_slide($t) + $i - 5;
		my $path = $subtitles[ $pos ];

		if ( $pos < 0 || ! $path ) {

			$self->{app}->fill( $to, $background ) if $self->{app};

		} else {

			$path =~ s{/s/[124]/}{/s/$factor/};

			my $slide = SDL::Surface->new( -name => $path );

			my $rect = SDL::Rect->new(
				-width  => $slide->width(),
				-height => $slide->height(),
				-x      => 0,
				-y      => 0,
			);

#			warn "$x $y $path\n";

			if ( ! $self->{app} ) {

				$self->{app} = SDL::App->new(
					-width  => $w,
					-height => $h * 2,
					-depth  => 24,
					-title  => 'Slides',
				);

			}

			$slide->blit( $rect, $self->{app}, $to );
		
		}

		$self->{app}->update( $to ) if $self->{app};

		$x += $w / $factor;

		if ( $x >= $w ) {
			$x = 0;
			$y += $h / $factor;
		}

	}

	$self->{app}->sync if $self->{app};

}

1;
