#!/usr/bin/perl

use warnings;
use strict;

use IPC::Open3 qw(open3);
use IO::Epoll;
use Data::Dump qw(dump);
use File::Slurp;
use YAML;
use JSON;
use HTML::TreeBuilder;
use Imager;


my $movie = shift @ARGV
	|| 'www/media/video.ogv';
#	|| die "usage: $0 media/conference-lecture_name/video.ogv\n";

my $base_dir = $1 if $movie =~ m{^(.+)/[^/]+$};

if ( -d $movie && $movie =~ m{media/} ) {
	$base_dir = $movie;
	$movie .= '/video.ogv';
} elsif ( -f $movie && $movie !~ m{video\.ogv} ) {
	my $movie_master = $movie;
	$movie = "$base_dir/video.ogv";
	symlink $movie_master, $movie unless -e $movie;
}

die "$movie $! - make symlink or specify path full path to video.ogv" unless -e $movie;

unlink 'www/media';

symlink $base_dir, 'www/media';
warn "# base_dir $base_dir\n";

my $edl = "/dev/shm/edl";
my $subtitles = $movie;
$subtitles =~ s{\.\w+$}{.srt};

my $preroll = 3;

my $slide_factor = 4; # 1/4 size of video

our $to_mplayer;
our $from_mplayer;
our $err_mplayer;
our $prop = {};

my $pid = open3( $to_mplayer, $from_mplayer, $err_mplayer,
	 'mplayer',
		'-slave', '-idle',
		'-quiet',
		'-edlout', $edl,
		'-osdlevel', 3,
		'-vf' => 'screenshot',
);

my $epfd = epoll_create(10);

epoll_ctl($epfd, EPOLL_CTL_ADD, fileno STDIN         , EPOLLIN  ) >= 0 || die $!;
epoll_ctl($epfd, EPOLL_CTL_ADD, fileno $from_mplayer , EPOLLIN  ) >= 0 || die $!;
#epoll_ctl($epfd, EPOLL_CTL_ADD, fileno $to_mplayer   , EPOLLOUT ) >= 0 || die $!;

sub load_movie {
	warn "$movie ", -s $movie, " bytes $edl\n";
	print $to_mplayer qq|loadfile "$movie"\n|;
	print $to_mplayer "get_property $_\n" foreach ( qw/metadata video_codec video_bitrate width height fps length/ );
}


my $term_id = `xdotool getwindowfocus`;
our $mplayer_id;


sub focus_mplayer {
	$mplayer_id ||= `xdotool search mplayer`;
	warn "focus_mplayer $mplayer_id\n";
	system "xdotool windowactivate $mplayer_id"
}

sub focus_term {
	warn "focus_term $term_id\n";
	system "xdotool windowactivate $term_id";
}

sub preroll {
	my ( $pos, $osd ) = @_;
	$osd =~ s{\W+}{ }gs;
	warn "PREROLL $pos $osd\n";
	print $to_mplayer "osd_show_text \"PREROLL $osd\" ", $preroll * 1000, "\n";
	my $to = $pos - $preroll;
	$to = 0 if $to < 0;
	print $to_mplayer "set_property time_pos $to\n";
	print $to_mplayer "get_property time_pos\n";
	print $to_mplayer "play\n";
}


$|=1;

my $line;
my $repl;

sub repl {
	print "> ";
	my $cmd = <STDIN>;
	warn ">>> $cmd\n";
	print $to_mplayer $cmd;
}


our @subtitles;

sub html5tv {

	if ( ! $prop->{width} || ! $prop->{height} ) {
		warn "SKIP no size yet\n";
		return;
	}

	if ( ! @subtitles ) {
		warn "SKIP no subtitles yet\n";
		return;
	}


	my $sync;

	my @slide_t;

	my @videos;

	foreach my $s ( @subtitles ) {
		push @{ $sync->{htmlEvents}->{'#subtitle'} }, {
			startTime => $s->[0],
			endTime   => $s->[1],
			html      => $s->[2],
		};

		if ( $s->[2] =~ m{video:(.+)} ) {
			my $video = $1;
			my $path = "www/media/$video";
			if ( ! -e $path ) {
				warn "MISSING $path: $!\n";
			} else {
				my $frame_dir = "www/media/s/$video";
				system "mplayer -vo jpeg:outdir=$frame_dir -frames 1 -ss 0 www/media/$video"
					if ! -e $frame_dir;
				push @videos, [ @$s, $video ];
			}
		}

		next unless $s->[2] =~ m{\[(\d+)\]};


		push @{ $sync->{customEvents} }, {
			startTime => $s->[0],
			endTime   => $s->[1],
			action    => 'chapterChange',
			args => {
				carousel => 'theCarousel',
				id => "chapter$1",
				title => $s->[2],
				description => $s->[2],
				src => sprintf('media/s/%dx%d/p%03d.jpg', $prop->{width} / $slide_factor, $prop->{height} / $slide_factor, $1),
				href => '',
			},
		};

		push @slide_t, $s->[0];
	}

	my $res = $prop->{width} . 'x' . $prop->{height};

	foreach ( 0 .. $#slide_t ) {
		push @{ $sync->{htmlEvents}->{'#slide'} }, {
			startTime => $slide_t[$_],
			endTime   => $slide_t[$_ + 1] || $prop->{length},
			html      => sprintf( '<img src=media/s/%s/p%03d.jpg>', $res, $_ + 1 ),
		};
	}

	my @slides_hires = glob 'www/media/s/hires/p*.jpg';
	@slides_hires    = glob 'shot*.png' unless @slides_hires;
	my $factor_s_path;

	foreach my $factor ( 4, 2, 1 ) {
		my $w = $prop->{width}  / $factor;
		my $h = $prop->{height} / $factor;

		my $path = "www/media/s/${w}x${h}";
		$factor_s_path->{$factor} = $path;

		if ( ! -d $path ) {
			mkdir $path;
			warn "created $path\n";

			foreach my $hires ( @slides_hires ) {

				my $file = $hires;
				$file =~ s{^.+/(p\d+\.\w)}{$path/$1};

				my $im = Imager->new( file => $hires );
				$im->scale( xpixels => $w, ypixels => $h, type => 'min' )->write( file => $file );
				warn "resized $file ", -s $file, " bytes\n";
			}
		}

	}

	my ( $slide_width, $slide_height );

	my $im = Imager->new( file => $factor_s_path->{ 1 } . '/p001.jpg"')
			|| Imager->new( file => "shot0001.png" ) # from mplayer [s]
			;

	if ( $im ) {
		$slide_width  = $im->getwidth  / $slide_factor;
		$slide_height = $im->getheight / $slide_factor;
	} else {
		warn "can't find first slide default to 1/$slide_factor of video size\n";
		$slide_width  = $prop->{width}  / $slide_factor;
		$slide_height = $prop->{height} / $slide_factor;
	}

	my $html5tv = {
		sync => $sync,
		video => $prop,
		slide => {
			width => $slide_width,
			height => $slide_height,
		},
	};

	$html5tv->{video_tags} =
		join("\n",
			map {
				my $s = $_;
				my $id = $s->[3];
				$id =~ s{\W+}{_}g;

				push @{ $html5tv->{sync}->{customEvents} }, {
					startTime => $s->[0],
					endTime   => $s->[1],
					action    => 'additional_video',
					args => {
						id => $id,
						title => $s->[2],
						description => $s->[2],
						src => "media/s/$s->[3]/00000001.jpg",
						href => '',
					},
				};

				qq|
					<video id="$id" style="display: none" controls="controls" width="$html5tv->{video}->{width}px" height="$html5tv->{video}->{height}px">
					<source src="media/$_->[3]" />
					</video>
				|
			} @videos
		)
	;

	sub customEvents_sorted {

		if ( ref $html5tv->{sync}->{customEvents} ne 'ARRAY' ) {
			my $max = 
			warn "ERROR: no slide markers [1] .. [", scalar @slides_hires, "] in subtitles\n";
			return;
		}

		sort { $a->{startTime} <=> $b->{startTime} }
		@{ $html5tv->{sync}->{customEvents} }
	}

	my $index = 1;

	$_->{args}->{index} = $index++ foreach customEvents_sorted;

	warn "last customEvent $index\n";

	$html5tv->{subtitles_table}
		= qq|<table id="subtitles">|
		. join("\n",
			map { qq|
				<tr id="sub_$_->{index}">
					<td class="seek_video">$_->{startTime}</td>
					<td class="seek_video">$_->{endTime}</td>
					<td>$_->{args}->{title}</td>
				</tr>
			| }
			customEvents_sorted
		)
		. qq|</table><a href="media/video.srt">download subtitles</a>|
		;

	my $hcalendar = '<div style="color: red">Create <tt>hcalendar.html</tt> to fill this space</div>';
	my $hcal_path = 'www/media/hcalendar.html';
	if ( -e $hcal_path ) {
		$html5tv->{hcalendar} = read_file $hcal_path;
		my $tree = HTML::TreeBuilder->new;
		$tree->parse_file($hcal_path);
		if ( my $vevent = $tree->look_down( class => 'vevent' ) ) {
			$html5tv->{title} = $vevent->look_down( class=> 'summary' )->as_trimmed_text;
		}
	}

	warn "# html5tv ", dump $html5tv;

	my $sync_path = 'www/media/video.js';
	write_file $sync_path, "var html5tv = " . to_json($html5tv) . " ;\n";
	warn "sync $sync_path ", -s $sync_path, " bytes\n";

	my $html = read_file 'www/tv.html';
	$html =~ s|{([^}]+)}|my $n = $1; $n =~ s(\.)(}->{)g; eval "\$html5tv->{$n}"|egs ||
		warn "no interpolation in template!";

	write_file 'www/media.html', $html;

	my $carousel_width = $prop->{width} + $slide_width - 80;
	$carousel_width -= $carousel_width % ( $slide_width + 6 ); # round to full slide
	my $carousel_height =   $slide_height + 2;

	write_file 'www/media/video.css', qq|

.jcarousel-skin-ie7 .jcarousel-container-horizontal,
.jcarousel-skin-ie7 .jcarousel-clip-horizontal {
	width: ${carousel_width}px;
	height: ${carousel_height}px;
}

.jcarousel-skin-ie7 .jcarousel-item {
	width: ${slide_width}px;
	height: ${slide_height}px;
	margin: 0 2px 0 2px;
}

.active {
	background-color: #ffc;
}

div#videoContainer {
	width: $prop->{width}px;
	height: $prop->{height}px;
	font-family: Arial, Helvetica, sans-serif;
	margin: 0 10px 0px 0;
	position: relative;
	display: inline;
}


div#subtitle {
	bottom: 24px;
	color: white;
	font-size: 100%;
	font-weight: bold;
	height: 22px;
	line-height: 1em;
	margin: 0  0 0 0;
	padding: 1px 10px 5px 10px ;
	position: absolute;
	text-align: center;
	width: $html5tv->{video}->{width}px;
}



.jcarousel-skin-ie7 .jcarousel-item img:hover {
//	border-color: #555 !important;
}

.jcarousel-skin-ie7 .jcarousel-item:hover div.thumbnailOverlay {
	visibility: visible !important;
}

.jcarousel-skin-ie7 .jcarousel-item div.thumbnailOverlay {
	background: black;
	bottom: 1px;
	color: #00EEFF;
	visibility: hidden;
	font-size: 10px;
	font-family: Arial, Verdana;
	font-weight: bold;
	line-height: 0.9em;
	opacity: 0.5;
	position: absolute;
	text-align: center;
	z-index: 10;
	padding: 2px 0 2px 0;
	width: ${slide_width}px;
}

.seek_video {
	text-align: right;
	font-family: monospace;
}

	|;

	return 1;
}


sub t_srt {
	my $t = shift;
	my $hh = int( $t / 3600 );
	$t -= $hh * 3600;
	my $mm = int( $t / 60 );
	$t -= $mm * 60;
	my $srt = sprintf "%02d:%02d:%04.1f", $hh, $mm, $t;
	$srt =~ s{\.}{,};
	return $srt;
}

sub save_subtitles {

	html5tv || return;

	my $nr = 0;
	my $srt = "\n";
	foreach my $s ( @subtitles ) {
		$srt .= $nr++ . "\n"
			. t_srt( $s->[0] ) . " --> " . t_srt( $s->[1] ) . "\n"
			. $s->[2] . "\n\n"
			;
	}
	warn $srt;

	write_file $subtitles, $srt;
	YAML::DumpFile "$subtitles.yaml", sort { $a->[0] <=> $b->[0] } @subtitles;

	print $to_mplayer "sub_remove\n";
	print $to_mplayer qq|sub_load "$subtitles"\n|;
	print $to_mplayer "sub_select 1\n";
}

sub load_subtitles {
	@subtitles = YAML::LoadFile "$subtitles.yaml";
	warn "subtitles ", dump @subtitles;
	save_subtitles;
}

load_subtitles if -e "$subtitles.yaml";

sub edit_subtitles {
	print $to_mplayer qq|pause\n|;
	focus_term;
	system( qq|vi "$subtitles.yaml"| ) == 0 and load_subtitles;
	focus_mplayer;
}

sub add_subtitle {
	print $to_mplayer qq|pause\n|;

	focus_term;

	warn "subtitles ", dump( @subtitles );
	print "## ";
	my $line = <STDIN>;
	$subtitles[ $#subtitles ]->[2] = $line if defined $line;

	save_subtitles;

	focus_mplayer;

	preroll $subtitles[ $#subtitles ]->[0], $line;
}

sub time_pos {
	print $to_mplayer qq|get_property time_pos\n|;
	my $pos = <$from_mplayer>;
	if ( $pos =~ m{^ANS_time_pos=(\d+\.\d+)} ) {
		warn "# time_pos $1\n";
		return $1;
	}
}

sub sub_fmt {
	my $s = shift;
	sprintf "%1.5f - %1.5f %s %s\n", @$s, join(' | ',@_);
}

sub prev_subtitle {
	my $pos = time_pos;
	my $s = ( grep { $_->[0] < $pos } @subtitles )[0] || return;
	warn "<<<< subtitle ", sub_fmt $s;
	preroll $s->[0], $s->[2];
#	print $to_mplayer "set_property time_pos $s->[0]\n";
}

sub next_subtitle {
	my $pos = time_pos + $preroll;
	my $s = ( grep { $_->[0] > $pos } @subtitles )[0] || return;
	warn ">>>> subtitle ", sub_fmt $s;
	preroll $s->[0], $s->[2];
#	print $to_mplayer "set_property time_pos $s->[0]\n";
}

sub current_subtitle {
	my $callback = shift;
	my $pos = time_pos;
	my $visible;
	foreach my $nr ( 0 .. $#subtitles ) {
		my $s = $subtitles[$nr];
		if ( $s->[0] <= $pos && $s->[1] >= $pos ) {
			warn sub_fmt $s, $pos;
			$visible = $nr;
			$callback->( $visible, $pos ) if $callback;
			return ( $visible, $pos );
		}
	}
	warn "# $pos no visible subtitle\n";
}

sub move_subtitle {
	my $offset = shift;
	current_subtitle( sub {
		my ( $nr, $pos ) = @_;
		my $new_start = $subtitles[$nr]->[0] += $offset;
		warn "subtitle $nr $pos $offset $new_start\n";
		save_subtitles;
		preroll $new_start, "$pos $offset $new_start";
	} );
}



# XXX main epool loop

load_movie;

while ( my $events = epoll_wait($epfd, 10, 1000) ) { # Max 10 events returned, 1s timeout

	warn "no events" unless $events;

	foreach my $e ( @$events ) {
#		warn "# event: ", dump($e), $/;

		my $fileno = $e->[0];

		if ( $fileno == fileno STDIN ) {
			my $chr;
			sysread STDIN, $chr, 1;
			print $chr;
		} elsif ( $fileno == fileno $from_mplayer ) {
			my $chr;
			sysread $from_mplayer, $chr, 1;
			print $chr;

			if ( $chr =~ m{[\n\r]} ) {

				exit if $line =~ m{Exiting};

				if ( $line =~ m{ANS_(\w+)=(\S+)} ) {
					$prop->{$1} = $2;
					warn "prop $1 = $2\n";
				} elsif ( $line =~ m{No bind found for key '(.+)'} ) {

					# XXX keyboard shortcuts

					  $1 eq 'c'  ? repl
					: $1 eq ','  ? add_subtitle
					: $1 eq 'F1' ? prev_subtitle
					: $1 eq 'F2' ? move_subtitle( -0.3 )
					: $1 eq 'F3' ? move_subtitle( +0.3 )
					: $1 eq 'F4' ? next_subtitle
					: $1 eq 'F5' ? save_subtitles
					: $1 eq 'F9' ? add_subtitle
					: $1 eq 'F12' ? edit_subtitles
					: warn "CUSTOM $1\n"
					;

				} elsif ( $line =~ m{EDL}i ) {

					print $to_mplayer qq|osd_show_text "$line"\n|;

					if ( my $pos = time_pos ) {
						if ( $line =~ m{start}i ) {
							push @subtitles, [ $pos, $pos, '-' ];
						} else {
							$subtitles[ $#subtitles ]->[1] = $pos;
						}
					}
				}

				$line = '';
			} else {
				$line .= $chr;
			}


		} elsif ( $fileno == fileno $to_mplayer ) {
#			warn "command";
		} else {
			die "invalid fileno $fileno";
		}
	}

}

