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
use Graphics::Magick;

my $debug = $ENV{DEBUG} || 0;

my $movie = shift @ARGV;

sub base_dir  { $1 if $_[0] =~ m{^(.+)/[^/]+$} }
sub base_name { $1 if $_[0] =~ m{^.+/([^/]+)$} }

if ( ! $movie && -e 'media/_editing' ) {
	$movie = 'media/' . readlink('media/_editing') . '/video.ogv';
	warn "using media/_editing -> $movie\n";
} elsif ( -d $movie && $movie =~ m{media/} ) {
	$movie .= '/video.ogv';
} elsif ( -f $movie && $movie !~ m{video\.ogv} ) {
	my $movie_master = $movie;
	$movie = base_dir($movie) . '/video.ogv';
	if ( ! -e $movie ) {
		symlink base_name($movie_master), $movie;
		warn "symlink video.ogv -> $movie_master";
	} else {
		warn "using symlink video.ogv -> ", readlink $movie;
	}
} elsif ( -f $movie ) {
	warn "using video $movie";
} else {
	die "Usage: $0 media/conference-Title_of_talk[/video.ogv'\n";
}

my $media_part = my $media_dir = base_dir($movie);
$media_part =~ s{media/}{};
$media_part =~ s{/$}{};

unlink 'media/_editing';
symlink $media_part, 'media/_editing';

warn "# media_part $media_part\n";

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

sub load_subtitles;

sub load_movie {
	warn "$movie ", -s $movie, " bytes $edl\n";
	print $to_mplayer qq|loadfile "$movie"\n|;
	print $to_mplayer "get_property $_\n" foreach ( qw/metadata video_codec video_bitrate width height fps length/ );
	load_subtitles;
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

sub slide_jpg {
	sprintf "%s/s/%d/%03d.jpg", $media_dir, @_;
}

sub oggThumb {
	my $video = shift;
	my $file  = shift;
	my $t = join(',', @_);
	system "oggThumb -t $t -o jpg -n $file $video";
}

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
	my @frames;

	foreach my $s ( @subtitles ) {
		push @{ $sync->{htmlEvents}->{'#subtitle'} }, {
			startTime => $s->[0],
			endTime   => $s->[1],
			html      => $s->[2],
		};

		if ( $s->[2] =~ m{video:(.+)} ) {
			my $video = $1;
			my $path = "$media_dir/$video";
			if ( ! -e $path ) {
				warn "MISSING $path: $!\n";
			} else {
				my $frame_dir = "$media_dir/s/$video";
				system "mplayer -vo jpeg:outdir=$frame_dir,quality=95 -frames 1 -ss 0 -ao null -really-quiet $media_dir/$video"
					if ! -e $frame_dir;
				push @videos, [ @$s, $video ];
			}
		} elsif ( $s->[2] =~ m{slide:(\d+)\s+shot:(\d+\.\d+)} ) {
			push @frames, [ $2, $1 ];
			next;
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
				src => slide_jpg( 4 => $1 ),
				href => '',
			},
		};

		push @slide_t, $s->[0];
	}

	if ( @frames ) {
		my $hires = "$media_dir/s/hires";
		mkdir $hires unless -e $hires;
		oggThumb $movie, "$hires/.f%.jpg", map { $_->[0] } @frames;

		foreach my $i ( 0 .. $#frames ) {
			my $from = "$hires/.f$i.jpg";
 			my $to   = "$hires/f" . $frames[$i]->[1] . '.jpg';
			rename $from, $to || warn "can't rename $from -> $to: $!";
		}
	}

	foreach ( 0 .. $#slide_t ) {
		my $slide_nr = $_ + 1;
		push @{ $sync->{htmlEvents}->{'#slide'} }, {
			startTime => $slide_t[$_],
			endTime   => $slide_t[$_ + 1] || $prop->{length},
			html      => '<img src=' . slide_jpg( 1 => $slide_nr ) . '>',
		};
	}

	my @slides_hires = glob "$media_dir/s/hires/*";

	my ($slide_width, $slide_height, $size, $format) = Graphics::Magick->new->Ping( $slides_hires[0] );
	my $slide_aspect = $slide_width / $slide_height;

	foreach my $factor ( 4, 2, 1 ) {
		my $w = $prop->{height} / $factor * $slide_aspect;
		my $h = $prop->{height} / $factor;

		my $path = "$media_dir/s";
		if ( ! -d $path ) {
			warn "create slides imaes in $path";
			mkdir $path;
		}

		$path .= '/' . $factor;

		if ( ! -d $path ) {
			mkdir $path;
			warn "created $path\n";

		}

		foreach my $hires ( @slides_hires ) {

			my $nr = $1 if $hires =~ m{(\d+)\.\w+$} || warn "can't find number in $hires";
			next unless $nr;
			my $file = slide_jpg( $factor => $nr );
			warn "slide $hires -> $file\n";
#			next if -e $file;

			my $im = Graphics::Magick->new;
			$im->ReadImage( $hires );
			$im->Resize( width => $w, height => $h, filter => 13, blur => 0.9 );
			my $c = $h / 10;
			my %info = (
				font => 'Sans', pointsize => $h / 10,
				#text => "$factor = $w*$h",
				text => " $nr ",
				y => $c,
				x => $c,
			);
			warn "# info ", dump %info;
			warn dump $im->QueryFontMetrics( %info );
			my ($x_ppem, $y_ppem, $ascender, $descender, $width, $height, $max_advance) = $im->QueryFontMetrics( %info );
			my $background = Graphics::Magick->new( size => $width . 'x' . $height );
			$background->ReadImage( 'xc:black' );
			$im->Composite( image => $background, compose => 'Over', x => $c, y => $c, opacity => 75 );
			$info{y} += $ascender;
			$im->Annotate( fill => 'yellow', %info );
			$im->Write( filename => $file );
		}

	}

	my ($slide_width, $slide_height, $size, $format) = Graphics::Magick->new->Ping( slide_jpg( $slide_factor => 1 ) );

	$slide_width  ||= $prop->{width}  / $slide_factor;
	$slide_height ||= $prop->{height} / $slide_factor;

	my $html5tv = {
		sync => $sync,
		video => $prop,
		slide => {
			width => $slide_width,
			height => $slide_height,
		},
	};

	$html5tv->{html}->{video_tags} =
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
						src => "$media_dir/s/1/00000001.jpg",
						href => '',
					},
				};

				qq|
					<video id="$id" style="display: none" controls="controls" width="$html5tv->{video}->{width}px" height="$html5tv->{video}->{height}px">
					<source src="$media_dir/$_->[3]" />
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

	$html5tv->{html}->{subtitles_table}
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
		. qq|</table><a href="$media_dir/video.srt">download subtitles</a>|
		;

	my $hCalendar = '<div style="color: red">Create <tt>hCalendar.html</tt> to fill this space</div>';
	my $hcal_path = '$media_dir/hCalendar.html';
	if ( -e $hcal_path ) {
		$html5tv->{hCalendar} = read_file $hcal_path;
		my $tree = HTML::TreeBuilder->new;
		$tree->parse_file($hcal_path);
		if ( my $vevent = $tree->look_down( class => 'vevent' ) ) {
			$html5tv->{title} = $vevent->look_down( class=> 'summary' )->as_trimmed_text;
		}
	}

	warn "# html5tv ", dump $html5tv if $debug;

	my $sync_path = "$media_dir/video.js";
	write_file $sync_path, "var html5tv = " . to_json($html5tv) . " ;\n";
	warn "sync $sync_path ", -s $sync_path, " bytes\n";

	my $html = read_file 'www/tv.html';
	$html =~ s|{([^}]+)}|my $n = $1; $n =~ s(\.)(}->{)g; eval "\$html5tv->{$n}"|egs ||
		warn "no interpolation in template!";

	write_file "www/_editing.html", $html;
	$html =~ s{media/_editing}{media/$media_part}gs;
	write_file "www/$media_part.html", $html;

	my $carousel_width = $prop->{width} + $slide_width - 80;
	$carousel_width -= $carousel_width % ( $slide_width + 6 ); # round to full slide
	my $carousel_height =   $slide_height + 2;

	write_file "$media_dir/video.css", qq|

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
 	if ( ! -e "$subtitles.yaml" ) {
		warn "no subtitles $subtitles to load\n";
		return;
	}
	@subtitles = YAML::LoadFile "$subtitles.yaml";
	warn "subtitles ", dump @subtitles;
	save_subtitles;
}

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
	my $s = ( grep { $_->[0] < $pos } @subtitles )[-1] || return;
	warn "<<<< subtitle ", sub_fmt $s;
	preroll $s->[0], $s->[2];
#	print $to_mplayer "set_property time_pos $s->[0]\n";
}

sub next_subtitle {
	my $pos = time_pos;
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
				} elsif ( $line =~ m{(shot\d+.png)} ) {
					my $shot = $1;
					my $t = time_pos;
					warn "shot $t $shot\n";

					my @existing_slides = glob("$media_dir/s/hires/*");
					my $nr = $#existing_slides + 2;

					push @subtitles, [ $t, $t, "slide:$nr shot:$t" ];

					warn "slide $nr from video $t file $shot\n";
					save_subtitles;
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

