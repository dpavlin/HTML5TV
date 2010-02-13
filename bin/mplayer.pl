#!/usr/bin/perl

use warnings;
use strict;

use autodie;

use IPC::Open3 qw(open3);
use IO::Select;
use Data::Dump qw(dump);
use File::Slurp;
use YAML::Syck;
use JSON;
use Graphics::Magick;
use Time::HiRes qw(time);
use File::Path qw(rmtree);
use Getopt::Long;

use lib 'lib';
use HTML5TV::Slides;
use HTML5TV::hCalendar;

my $debug = $ENV{DEBUG} || 0;
my $generate = $ENV{GENERATE} || 0;

my $video_url; # override mplayer movie url

GetOptions(
	'video-url=s' => \$video_url,
) || die $!;

my $movie = shift @ARGV;

sub base_dir  { $1 if $_[0] =~ m{^(.+)/[^/]+$} }
sub base_name { $1 if $_[0] =~ m{^.+/([^/]+)$} }

if ( ! $movie && -e 'media/_editing' ) {
	$movie = 'media/' . readlink('media/_editing') . '/video.ogv';
	warn "using media/_editing -> $movie\n";
} elsif ( -d $movie && $movie =~ m{media/} ) {
	$movie .= '/video.ogv';
} elsif ( -f $movie && $movie =~ m{\.og[vg]\b}i ) {
	my $movie_master = $movie;
	$movie = base_dir($movie) . '/video.ogv';
	unlink $movie if -e $movie;
	symlink base_name($movie_master), $movie;
	warn "symlink video.ogv -> $movie_master";
} elsif ( $video_url ) {
	warn "video_url: $video_url\n";
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

my $min_slide_height = 480;

our $to_mplayer;
our $from_mplayer;
our $err_mplayer;
our $prop = {};

my @mplayer_command = (
	 'mplayer',
		'-slave', '-idle',
#		'-quiet',
#		'-msglevel', 'demux=9', '-msgmodule',
		'-edlout', $edl,
		'-osdlevel', 3,
		'-vf' => 'screenshot',
);

push @mplayer_command, qw/ -vo null -ao null / if $generate;

my $pid = open3( $to_mplayer, $from_mplayer, $err_mplayer, @mplayer_command );

my $select = IO::Select->new();
#$select->add( \*STDIN );
$select->add( $from_mplayer );
#$select->add( $err_mplayer );

sub load_subtitles;

sub load_movie {
	warn "$movie ", -s $movie, " bytes $edl\n";
	my $url = $video_url || $movie;
	warn "loadfile $url\n";
	print $to_mplayer qq|loadfile "$url"\n|;
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

our $pos;

sub preroll {
	my ( $to, $osd ) = @_;
	$osd =~ s{\W+}{ }gs;
	my $preroll_to = $to - $preroll;
	$preroll_to = 0 if $preroll_to < 0;
	print $to_mplayer "set_property time_pos $preroll_to\n";
	my $osd_ms = ( $to - time_pos() ) * 1000;
	print $to_mplayer "get_property time_pos\n";
	print $to_mplayer "osd_show_text \"PREROLL $osd\"\n"; # $osd_ms\n";
	warn "PREROLL $to -> $pos [$osd_ms] $osd\n";
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

sub fmt_mmss {
	my $t = shift;
	return sprintf('%02d:%02d', int($t/60), int($t%60));
}

my %escape = ('<'=>'&lt;', '>'=>'&gt;', '&'=>'&amp;', '"'=>'&quot;');
my $escape_re  = join '|' => keys %escape;
sub html_escape {
	my $what = join('',@_);
	$what =~ s/($escape_re)/$escape{$1}/gs;
	warn "XXX html_escape $what\n";
	return $what;
}

sub html5tv {

	if ( ! $prop->{width} || ! $prop->{height} ) {
		warn "SKIP no size yet\n" if $debug;
		return;
	}

	if ( ! @subtitles ) {
		warn "SKIP no subtitles yet\n";
		return;
	}

	warn "html5tv";

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
			push @frames, [ $2, $1 ] unless -e "$media_dir/s/hires/f$1.jpg";
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

	foreach ( 0 .. $#slide_t ) {
		my $slide_nr = $_ + 1;
		push @{ $sync->{htmlEvents}->{'#slide'} }, {
			startTime => $slide_t[$_],
			endTime   => $slide_t[$_ + 1] || $prop->{length},
			html      => '<img src=' . slide_jpg( 1 => $slide_nr ) . '>',
		};
	}


	my $max_slide_height = 480; # XXX

	my $path  = "$media_dir/s";
	my $hires = "$media_dir/s/hires";

	if ( ! -d $path ) {
		warn "create slides in $path";
		mkdir $path;
		mkdir $hires;

		my $nr = 1;

		foreach my $path ( glob "$media_dir/presentation*.pdf" ) {
			$path = $media_dir . '/' . readlink($path) if -l $path;

			warn "render pdf slides from $path\n";
			system "pdftoppm -png -r 100 '$path' $hires/p.$nr";

			$nr++;
		}

		my $slide = 1;

		foreach my $path ( sort glob "$hires/p.*" ) {
			rename $path, sprintf("$hires/p%03d.png", $slide++);
		}
	}


	if ( @frames ) {
		warn "create slides from video frames";
#		rmdir $_ foreach glob "$media_dir/s/[124]";

		oggThumb $movie, "$hires/.f%.jpg", map { $_->[0] } @frames;

		foreach my $i ( 0 .. $#frames ) {
			my $from = "$hires/.f$i.jpg";
 			my $to   = "$hires/f" . $frames[$i]->[1] . '.jpg';
			rename $from, $to || warn "can't rename $from -> $to: $!";
		}

	}


	my @slides_hires = glob "$hires/*";


	foreach my $hires ( @slides_hires ) {

		my ($slide_width, $slide_height) = Graphics::Magick->new->Ping( $hires );
		my $slide_aspect = $slide_width / $slide_height;

		my $nr = $1 if $hires =~ m{(\d+)\.\w+$} || warn "can't find number in $hires";
		next unless $nr;

		my $im;

		foreach my $factor ( 1, 2, 4 ) {

			mkdir "$path/$factor" unless -e "$path/$factor";

			my $file = slide_jpg( $factor => $nr );
			next if -e $file;

			my $w = int( $max_slide_height / $factor * $slide_aspect );
			my $h = int( $max_slide_height / $factor );

			warn "slide [$nr] $hires -> ${w}x${h} $file\n";

			if ( ! $im ) {
				warn "loading $hires ", -s $hires, " bytes\n";
				$im = Graphics::Magick->new;
				$im->ReadImage( $hires );
			}
			$im->Resize( width => $w, height => $h, filter => 13, blur => 0.9 );

			my $c = 1; # $h / 10;
			my %info = (
				font => 'Sans', pointsize => $h / 10,
				#text => "$factor = $w*$h",
				text => " $nr ",
				y => $c,
				x => $c,
			);

			if (0) {

			#warn "# info ", dump %info;
			#warn dump $im->QueryFontMetrics( %info );
			my ($x_ppem, $y_ppem, $ascender, $descender, $width, $height, $max_advance) = $im->QueryFontMetrics( %info );
			my $background = Graphics::Magick->new( size => $width . 'x' . $height );
			$background->ReadImage( 'xc:black' );
			$im->Composite( image => $background, compose => 'Over', x => $c, y => $c, opacity => 75 );
			$info{y} += $ascender;
			$im->Annotate( fill => 'yellow', %info );

			} # Annotate

			$im->Write( filename => $file );
		}

	}


	my $bars = "$path/bars.png";
	if ( 1 || ! -e $bars ) { # FIXME
		my $im = Graphics::Magick->new;
		$im->ReadImage( "$media_dir/../SMPTE_Color_Bars.svg" );
		my ($slide_width, $slide_height) = Graphics::Magick->new->Ping( slide_jpg( 1 => 1 ) );
		$im->Resize( width => $slide_width, height => $slide_height );
		$im->Write( filename => $bars );
		warn "created $bars ", -s $bars, " bytes\n";
	}


	my ($slide_width, $slide_height, $size, $format) = Graphics::Magick->new->Ping( slide_jpg( 1 => 1 ) );
	my ($c_slide_width, $c_slide_height) = Graphics::Magick->new->Ping( slide_jpg( $slide_factor => 1 ) );

	my $html5tv = {
		sync => $sync,
		video => $prop,
		slide => {
			width => $slide_width,
			height => $slide_height,
		},
		carousel => {
			width => $c_slide_width,
			height => $c_slide_height,
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
						src => "$media_dir/s/$s->[3]/00000001.jpg",
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

	my @customEvents_sorted;

	if ( ref $html5tv->{sync}->{customEvents} ne 'ARRAY' ) {
		my $max = 
		warn "ERROR: no slide markers [1] .. [", scalar @slides_hires, "] in subtitles\n";
		return;
	} else {
		@customEvents_sorted =
		sort { $a->{startTime} <=> $b->{startTime} }
		@{ $html5tv->{sync}->{customEvents} }
		;
	}

	my $index = 1;

	$_->{args}->{index} = $index++ foreach @customEvents_sorted;

	warn "last customEvent $index\n";

	$html5tv->{html}->{subtitles_table}
		= qq|
			<table id="subtitles">
			<tr><th>&#8676;</th><th>&#8677;</th><th>#</th><th>slide</th></tr>
		|
		. join("\n",
			map {
				my $s = $_->{startTime};
				my $e = $_->{endTime};
				my $i = $_->{index};
				my $t = html_escape( $_->{args}->{title} );
				my $slide = '';
				$slide = $1 if $t =~ s{\s*\[(\d+)\]\s*}{};

				my ( $s_f, $e_f ) = map { fmt_mmss $_ } ( $s, $e );

				qq|
				<tr id="sub_$i">
					<td class="seek_video"><a href="#$s">$s_f</a></td>
					<td class="seek_video"><a href="#$e">$e_f</a></td>
					<td class="slide">$slide</td>
					<td>$t</td>
				</tr>
				|
			}
			@customEvents_sorted
		)
		. qq|</table>|
		;

	my $hCalendar = '<div style="color: red">Create <tt>hCalendar.html</tt> to fill this space</div>';
	my $hcal_path = "$media_dir/hCalendar.html";
	if ( -e $hcal_path ) {
		$html5tv->{hCalendar} = read_file $hcal_path;
		my $hcal = HTML5TV::hCalendar->new( $hcal_path );
		$html5tv->{title} = $hcal->summary;
	}

	foreach my $file ( qw/video.ogv presentation.pdf video.srt video.srt.yaml/ ) {
		my $path = "$media_dir/$file";
		my $type = 'binary';
		$type = $1 if $file =~ m{\.([^\.]+)$};
		my $size = -s $path;
		$html5tv->{html}->{download} .= qq|<a href="$path" title="$file $size bytes">$type</a> |;
	}

	warn "# html5tv ", dump $html5tv if $debug;

	my $html = read_file 'www/tv.html';
	$html =~ s|{([^}]+)}|my $n = $1; $n =~ s(\.)(}->{)g; eval "\$html5tv->{$n}"|egs ||
		warn "no interpolation in template!";

	write_file "www/_editing.html", $html;
	$html =~ s{media/_editing}{media/$media_part}gs;
	write_file "www/$media_part.html", $html;

	my $sync_path = "$media_dir/video.js";
	delete $html5tv->{html};
	write_file $sync_path, "var html5tv = " . to_json($html5tv) . " ;\n";
	warn "sync $sync_path ", -s $sync_path, " bytes\n";

	# video + full-sized slide on right
	my $carousel_width = $prop->{width} + $slide_width;
	$carousel_width -= $carousel_width % ( $c_slide_width + 6 ); # round to full slide
	my $carousel_height = $c_slide_height + 2;


	write_file "$media_dir/video.css", qq|

.jcarousel-skin-ie7 .jcarousel-container-horizontal,
.jcarousel-skin-ie7 .jcarousel-clip-horizontal {
	width: ${carousel_width}px;
	height: ${carousel_height}px;
}

.jcarousel-skin-ie7 .jcarousel-item {
	width: ${c_slide_width}px;
	height: ${c_slide_height}px;
	margin: 0 2px 0 2px;
}

div#videoContainer {
//	width: $prop->{width}px;
//	height: $prop->{height}px;
	margin: 0 10px 0px 0;
}


div#slide_border, div#slide {
	width: ${slide_width}px;
	height: ${slide_height}px;
}


div#subtitle {
	width: $html5tv->{video}->{width}px;
}



.jcarousel-skin-ie7 .jcarousel-item div.thumbnailOverlay {
	width: ${c_slide_width}px;
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

my @to_mplayer;

sub save_subtitles {

	DumpFile "$subtitles.yaml", sort { $a->[0] <=> $b->[0] } @subtitles if @subtitles;

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

	push @to_mplayer
		, "sub_remove\n"
		, qq|sub_load "$subtitles"\n|
		, "sub_select 1\n"
		;
}

sub annotate_subtitles;

sub load_subtitles {
 	if ( ! -e "$subtitles.yaml" ) {
		warn "no subtitles $subtitles to load\n";
		return;
	}
	@subtitles = LoadFile "$subtitles.yaml";
	warn "subtitles ", dump @subtitles;
	annotate_subtitles;
	save_subtitles;
}

sub edit_subtitles {
	print $to_mplayer qq|pause\n|;
	focus_term;
	my $line = 1;
	my $jump_to = 1;
	open( my $fh, '<', "$subtitles.yaml" ) || die $1;
	while(<$fh>) {
		last if /^-\s([\d\.]+)/ && $1 > $pos;
		$jump_to = $line - 1 if /^---/;
		$line++;
	}
	close($fh);
	system( qq|vi +$jump_to "$subtitles.yaml"| ) == 0 and load_subtitles;
	focus_mplayer;
}


my @slide_titles;
foreach my $path ( sort glob "$media_dir/presentation*.pdf" ) {

	my $txt = $path;
	$txt =~ s/pdf$/txt/;

	system "pdftotext '$path'" unless -e $txt;

	my $slides = read_file $txt;
	my @s = ( map { [ split(/[\n\r]+/, $_) ] } split(/\f/, $slides) );

	my $slide_line = 0;
	$slide_line++ if $s[1]->[$slide_line] eq $s[2]->[$slide_line]; # skip header

	foreach my $s ( @s ) {
		push @slide_titles, $s->[$slide_line];
	}

	warn "# slides titles ", dump(@slide_titles);
}

sub annotate_subtitles {
	return unless @slide_titles;
	foreach my $s ( @subtitles ) {
		if ( $s->[2] =~ m{^\[(\d+)\]$} ) {
			if ( my $title = $slide_titles[ $1 - 1 ] ) {
				$s->[2] = "[$1] " . substr($title,0,40);
				warn "annotated [$1] $title\n";
			}
		}
	}
}


sub add_subtitle {

	my $last_slide;
	foreach ( 0 .. $#subtitles ) {
		my $i = $#subtitles - $_;
		$last_slide = $1 if $subtitles[$i]->[2] =~ m/\[(\d+)\]/;
		last if $last_slide;
	}

	if ( $last_slide && $subtitles[ $#subtitles ]->[2] ne '-' || ! @subtitles ) {

		# quick add next slide for Takahashi method presentations
		# with a lot of transitions
		my $nr = $last_slide + 1;
		my $text = "[$nr]";
		$text .= ' ' . $slide_titles[ $nr - 1 ] if defined $slide_titles[ $nr - 1 ];
		warn "add slide $text";
		push @subtitles, [ $pos, $pos + 1, $text ];
		save_subtitles;
		return;

	}

	print $to_mplayer qq|pause\n|;

	warn "subtitles ", dump( @subtitles ), "\nnext: [", $last_slide + 1, "]\n";

	focus_term;

	print "## ";
	my $line = <STDIN>;
	$subtitles[ $#subtitles ]->[2] = $line if defined $line;

	focus_mplayer;

	preroll $subtitles[ $#subtitles ]->[0], $line;
}

sub time_pos {
	print $to_mplayer qq|get_property time_pos\n|;
	my $line = <$from_mplayer>;
	if ( $line =~ m{^ANS_time_pos=(\d+\.\d+)} ) {
		warn "# time_pos $1\n";
		$pos = $1;
		return $1;
	}
}

sub sub_fmt {
	my $s = shift;
	sprintf "%1.5f - %1.5f %s %s\n", @$s, join(' | ',@_);
}

sub prev_subtitle {
	my $s = ( grep { $_->[0] < $pos } @subtitles )[-1] || return;
	warn "<<<< subtitle ", sub_fmt $s;
	preroll $s->[0], $s->[2];
#	print $to_mplayer "set_property time_pos $s->[0]\n";
}

sub next_subtitle {
	my $s = ( grep { $_->[0] > $pos } @subtitles )[0] || return;
	warn ">>>> subtitle ", sub_fmt $s;
	preroll $s->[0], $s->[2];
#	print $to_mplayer "set_property time_pos $s->[0]\n";
}

sub current_subtitle {
	my $callback = shift;
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

my $slides = HTML5TV::Slides->new(
	sub {
		my $t = shift || return;
		my $nr = 0;
		foreach my $s ( @subtitles ) {
			$nr = $1 if $s->[2] =~ m{\[(\d+)\]} && $s->[0] < $t;
		}
		return $nr;
	}
);


sub from_mplayer {
	my $line = shift;

	if ( $line =~ m{V:\s*(\d+\.\d+)\s+} ) {
		$pos = $1;
		print "$pos\r";
#		$pos = $1 if $1 > 0.2; # mplayer demuxer report fake position while seeking
	} elsif ( $line =~ m{Exiting} ) {
		exit;
	} elsif ( $line =~ m{ANS_(\w+)=(\S+)} ) {
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

		if ( $line =~ m{start}i ) {
			push @subtitles, [ $pos, $pos, '-' ];
		} else {
			$subtitles[ $#subtitles ]->[1] = $pos;
		}
	} elsif ( $line =~ m{(shot\d+.png)} ) {
		my $shot = $1;
		warn "shot $pos $shot\n";

		my @existing_slides = glob("$media_dir/s/hires/*");
		my $nr = $#existing_slides + 2;

		push @subtitles, [ $pos, $pos, "slide:$nr shot:$pos" ];

		warn "slide $nr from video $pos file $shot\n";
		save_subtitles;
	} elsif ( $line =~ m{File not found} ) {
		die $line;
	} else {
		warn "IGNORE $line\n"; # if $debug;
	}

}

my @mplayer_prop = ( qw/metadata video_codec video_bitrate width height fps/ );
warn "XXX $movie\n";
if ( my $l = `oggLength $movie` ) {
	$l = $l / 1000;
	$prop->{length} = $l;
	warn "$movie length ", fmt_mmss( $l );
}
push @mplayer_prop, 'length' unless $prop->{length};

push @to_mplayer, "get_property $_\n" foreach grep { ! $prop->{$_} } @mplayer_prop;

my $t = time;

push @to_mplayer, 'pause' if $generate;

while ( 1 ) {

	my $dt = time - $t;
	if ( abs($dt) > 0.2 ) {
#warn "dt $dt\n";
		$slides->show( $pos, $prop->{length}, @subtitles ) if $prop->{length} && ! $ENV{GENERATE};
		$t = time;
	}

	foreach my $fd ( $select->can_read(0.1) ) {
		if ( $fd == $from_mplayer ) {
			my $ch;
			sysread $from_mplayer, $ch, 1;
			if ( $ch =~ m{[\n\r]} ) {
				from_mplayer $line;
				$line = '';
			} else {
				$line .= $ch;
			}
		} else {
			warn "unknown fd $fd";
		}
	}

	if ( my $cmd = shift @to_mplayer ) {
		warn ">>>> $cmd\n";
		print $to_mplayer $cmd;
	}

	if ( $generate && html5tv() ) {
		warn "generated\n";
		exit;
	}
}

