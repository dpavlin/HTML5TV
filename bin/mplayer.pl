#!/usr/bin/perl

use warnings;
use strict;

use IPC::Open3 qw(open3);
use IO::Epoll;
use Data::Dump qw(dump);
use File::Slurp;
use YAML;


my $movie = shift @ARGV
	|| 'media/lpc-2009-network-namespaces/Pavel Emelyanov.ogg';
#	|| die "usage: $0 path/to/movie.ogv\n";

my $edl = "/dev/shm/edl";
my $subtitles = $movie;
$subtitles =~ s{\.\w+$}{.srt};

our $to_mplayer;
our $from_mplayer;

my $pid = open3( $to_mplayer, $from_mplayer, $from_mplayer,
	 'mplayer',
		'-slave', '-idle',
		'-quiet',
		'-edlout', $edl,
		'-osdlevel', 3,
);

my $epfd = epoll_create(10);

epoll_ctl($epfd, EPOLL_CTL_ADD, fileno STDIN         , EPOLLIN  ) >= 0 || die $!;
epoll_ctl($epfd, EPOLL_CTL_ADD, fileno $from_mplayer , EPOLLIN  ) >= 0 || die $!;
epoll_ctl($epfd, EPOLL_CTL_ADD, fileno $to_mplayer   , EPOLLOUT ) >= 0 || die $!;

warn "$movie ", -s $movie, " bytes $edl\n";
print $to_mplayer qq|loadfile "$movie"\n|;

$|=1;

my $line;
my $repl;

sub repl {
	print "> ";
	my $cmd = <STDIN>;
	warn ">>> $cmd\n";
	print $to_mplayer $cmd;
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

our @subtitles;
sub save_subtitles {
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
	YAML::DumpFile "$subtitles.yaml", @subtitles;
}

if ( -e $subtitles ) {
	print $to_mplayer "sub_visibility 1\n";
	print $to_mplayer qq|sub_load "$subtitles"\n|;
	@subtitles = YAML::LoadFile "$subtitles.yaml";
	warn "subtitles ", dump @subtitles;
}

sub add_subtitle {
	print $to_mplayer qq|pause\n|;

	warn "subtitles ", dump( @subtitles );
	print "## ";
	my $line = <STDIN>;
	$subtitles[ $#subtitles ]->[2] = $line if defined $line;

	my $preroll_pos = $subtitles[ $#subtitles ]->[0] - 1;
	$preroll_pos = 0 if $preroll_pos < 0;
	warn "PREROLL $preroll_pos\n";
	print $to_mplayer "set_property time_pos $preroll_pos\n";

	save_subtitles;

	print $to_mplayer "sub_remove\n";
	print $to_mplayer qq|sub_load "$subtitles"\n|;
	print $to_mplayer "sub_visibility 1\n";

	print $to_mplayer "play\n";
}

while ( my $events = epoll_wait($epfd, 10, 1000) ) { # Max 10 events returned, 1s timeout

	warn "no events" unless $events;

	foreach my $e ( @$events ) {
#		warn "# event: ", dump($e), $/;

		my $fileno = $e->[0];

		if ( $fileno == fileno STDIN ) {
			my $chr;
			sysread STDIN, $chr, 1;
			print "$chr";
		} elsif ( $fileno == fileno $from_mplayer ) {
			my $chr;
			sysread $from_mplayer, $chr, 1;
			print $chr;

			if ( $chr =~ m{[\n\r]} ) {

				exit if $line =~ m{Exiting};

				if ( $line =~ m{No bind found for key '(.)'} ) {

					warn "CUSTOM $1\n";
					repl if $1 eq 'c';
					add_subtitle if $1 eq ',';

				} elsif ( $line =~ m{EDL}i ) {

					print $to_mplayer qq|osd_show_text "$line"\n|;

					print $to_mplayer qq|get_property time_pos\n|;
					my $pos = <$from_mplayer>;
					if ( $pos =~ m{^ANS_time_pos=(\d+\.\d+)} ) {
						$pos = $1;
						warn "POS: $pos\n";
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

