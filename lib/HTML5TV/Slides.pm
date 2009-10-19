package HTML5TV::Slides;

use warnings;
use strict;

use SDL::App;
use SDL::Surface;
use SDL::Rect;

use Data::Dump qw/dump/;

sub new {
	my $class = shift;
	my $self = {
		last_nr => -42,
	};
	bless $self, $class;
}

sub show {
	my ( $self, $nr ) = @_;

	if ( $self->{last_nr} == $nr ) {
		$self->{app}->sync if $self->{app};
		return;
	}

	$self->{last_nr} = $nr;

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

	my $background = SDL::Color->new( -r => 0x11, -g => 0x11, -b => 0x33 );

	foreach my $i ( 0 .. $#factors ) {

		my $factor = $factors[$i] || die "no factor $i in ",dump @factors;

		my $to = SDL::Rect->new(
			-width  => $w / $factor,
			-height => $h / $factor,
			-x      => $x,
			-y      => $y,
		);

		my $pos = $nr + $i - 5;

		if ( $pos < 0 ) {

			$slide->fill( $to, $background );

		} else {

			my $path = $subtitles[ $pos ];
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

	$self->{app}->sync;

}

1;
