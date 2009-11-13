package HTML5TV::Slides;

use warnings;
use strict;

use SDL::App;
use SDL::Surface;
use SDL::Rect;
use SDL::Tool::Font;

use Data::Dump qw/dump/;

sub new {
	my $class = shift;
	my $current_slide = shift || die "need current slide coderef!";
	my $self = {
		last_slide => 0,
		last_t => 0,
		current_slide => $current_slide,
		width  => 0,
		height => 0,
	};
	bless $self, $class;
}

sub current_slide {
	my $self = shift;
	$self->{current_slide}->( shift );
}

sub progress_bar;

sub show {
	my $self = shift;
	my $t = shift;
	my $length = shift;
	my @subtitles = @_;

	my $current_slide = $self->current_slide($t);

	my $dt = $t - $self->{last_t};

	if ( $self->{last_slide} == $current_slide ) {
		if ( $dt > 1 ) {
			$self->{last_t} = $t;
			$self->progress_bar( $t, $length, @subtitles );
			return;
		}
		return;
	}

	$self->{last_slide} = $current_slide;
	warn "slide change $current_slide\n";

	my @slide_paths =
		sort {
			my $n_a = $1 if $a =~ m{(\d+)};
			my $n_b = $1 if $b =~ m{(\d+)};
			$n_a <=> $n_b || $a cmp $b
		} glob("media/_editing/s/1/*")
	;

	if ( ! $self->{width} || ! $self->{height} ) {
		my $slide = SDL::Surface->new( -name => $slide_paths[0] );
		$self->{width}  = $slide->width;
		$self->{height} = $slide->height;
	}

	my @factors = ( qw/ 4 4 4 4 1 2 2 4 4 4 4 / );

	my ( $x, $y ) = ( 0, 0 );

	my $background = SDL::Color->new( -r => 0, -g => 0, -b => 0 );
	my $overlay_color = SDL::Color->new( -r => 0xff, -g => 0xff, -b => 0x88 );

	foreach my $i ( 0 .. $#factors ) {

		my $factor = $factors[$i] || die "no factor $i in ",dump @factors;

		my $to = SDL::Rect->new(
			-width  => $self->{width}  / $factor,
			-height => $self->{height} / $factor,
			-x      => $x,
			-y      => $y,
		);

		my $pos = $self->current_slide($t) + $i - 5;
		my $path = $slide_paths[ $pos ];

		if ( $pos < 0 || ! $path ) {

			$self->{app}->fill( $to, $background ) if $self->{app};

		} else {

			$path =~ s{/s/[124]/(\D*(\d+))}{/s/$factor/$1};
			my $nr = $2;

			my $slide = SDL::Surface->new( -name => $path );

			my $subtitle_text = $nr;
			foreach my $s ( @subtitles ) {
				if ( $s->[2] =~ m/\[(\d+)\]/ && $1 == $nr ) {
					$subtitle_text = $s->[2];
					last;
				}
			}

			my $font = SDL::Tool::Font->new(
				-normal => 1,
				-ttfont => 'media/slides.ttf', # FIXME
				-size => 40 / $factor,
				-fg => $background,
				-bg => $background,
			);
			$font->print( $slide, 4, 4, $subtitle_text );
			$font->print( $slide, 4, 6, $subtitle_text );
			$font->print( $slide, 6, 4, $subtitle_text );
			$font->print( $slide, 6, 6, $subtitle_text );
			$font->print( $slide, 5, 5, $subtitle_text );

			SDL::Tool::Font->new(
				-normal => 1,
				-ttfont => 'media/slides.ttf', # FIXME
				-size => 40 / $factor,
				-fg => $overlay_color,
				-bg => $background,
			)->print( $slide, 5, 5, $subtitle_text );

			my $rect = SDL::Rect->new(
				-width  => $slide->width(),
				-height => $slide->height(),
				-x      => 0,
				-y      => 0,
			);

#			warn "$x $y $path\n";

			if ( ! $self->{app} ) {

				$self->{app} = SDL::App->new(
					-width  => $self->{width},
					-height => ( $self->{height} * 2 ) + 20,
					-depth  => 24,
					-title  => 'Slides',
				);

			}

			$slide->blit( $rect, $self->{app}, $to );

		}

		$self->{app}->update( $to ) if $self->{app};

		$x += $self->{width} / $factor;

		if ( $x >= $self->{width} ) {
			$x = 0;
			$y += $self->{height} / $factor;
			$y += 5;
		}

	}

	$self->progress_bar( $t, $length, @subtitles );
}

sub progress_bar {
	my $self = shift;

	my $t = shift;
	my $length = shift;
	my @subtitles = @_;

	return unless $self->{app};


		my $w_1s = $self->{width} / $length;

		my $bar_h = 3;
		my $y_bar = int( $self->{height} / 4 ) + 1;

		my $bar_back = SDL::Color->new( -r => 0, -g => 0, -b => 0 );
		my $rect = SDL::Rect->new(
			-width  => $self->{width},
			-height => $bar_h,
			-x      => 0,
			-y      => $y_bar,
		);

		$self->{app}->fill( $rect, $bar_back );
#		$self->{app}->update( $rect );

		my $col_slide    = SDL::Color->new( -r => 0xcc, -g => 0xcc, -b => 0x00 );
		my $col_subtitle = SDL::Color->new( -r => 0xcc, -g => 0x00, -b => 0x00 );
		my $col_pos      = SDL::Color->new( -r => 0xff, -g => 0xff, -b => 0xff );


		foreach my $s ( @subtitles ) {

			next unless defined $s->[0];

			my $s_x = int( $s->[0] * $w_1s + 0.9 );
			my $s_w = int( abs( $s->[1] - $s->[0] ) * $w_1s );
			$s_w = 1 if $s_w < 1;

#			warn "$s_x $s_w ", $s->[2];

			my $rect = SDL::Rect->new(
				-width => $s_w,
				-height => $bar_h,
				-x => $s_x,
				-y => $y_bar,
			);
			$self->{app}->fill( $rect, $s->[2] =~ m/\[\d+\]/ ? $col_slide : $col_subtitle );
#			$self->{app}->update( $rect );
		}

		my $rect_pos = SDL::Rect->new(
			-width => $bar_h,
			-height => $bar_h,
			-x => int( $t * $w_1s - $bar_h / 2 ),
			-y => $y_bar,
		);
		$self->{app}->fill( $rect_pos, $col_pos );
#		$self->{app}->update( $rect );

		$self->{app}->sync;

}

1;
