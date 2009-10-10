#!/usr/bin/perl

use warnings;
use strict;

use IPC::Open3 qw(open3);
use IO::Epoll;
use Data::Dump qw(dump);


my $movie = shift @ARGV
	|| 'media/lpc-2009-network-namespaces/Pavel Emelyanov.ogg';
#	|| die "usage: $0 path/to/movie.ogv\n";

my $edl = "$$.edl";

our $to_mplayer;
our $from_mplayer;

my $pid = open3( $to_mplayer, $from_mplayer, $from_mplayer,
	 'mplayer',
		'-slave', '-idle',
		'-edlout', $edl
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


while ( my $events = epoll_wait($epfd, 10, 1000) ) { # Max 10 events returned, 1s timeout

	warn "no events" unless $events;

	foreach my $e ( @$events ) {
#		warn "# event: ", dump($e), $/;

		my $fileno = $e->[0];

		if ( $fileno == fileno STDIN ) {
			my $chr;
			read STDIN, $chr, 1;
			print "$chr";
		} elsif ( $fileno == fileno $from_mplayer ) {
			my $chr;
			read $from_mplayer, $chr, 1;
			print $chr;

			if ( $chr =~ m{[\n\r]} ) {

				exit if $line =~ m{Exiting};

				if ( $line =~ m{No bind found for key '(.)'} ) {
					warn "CUSTOM $1\n";
					repl if $1 eq 'c';
				} elsif ( $line =~ m{EDL}i ) {
					print $to_mplayer qq|osd_show_text "$line"\n|;
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

