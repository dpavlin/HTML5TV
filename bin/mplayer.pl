#!/usr/bin/perl

use warnings;
use strict;

use lib 'lib';
use Audio::Play::MPlayer;

my $movie = shift @ARGV || die "usage: $0 path/to/movie.ogv\n";

my $player = Audio::Play::MPlayer->new;
$player->load( $movie );
print "$movie ", -s $movie, " bytes ", $player->title, "\n";
$player->poll( 1 ) until $player->state == 0;

