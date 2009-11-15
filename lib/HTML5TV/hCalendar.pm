package HTML5TV::hCalendar;

use warnings;
use strict;

use File::Slurp;
use HTML::TreeBuilder;
use Data::Dump qw/dump/;

sub new {
	my $class = shift;
	my $path = shift || die "need path to hCalendar";

	my $tree = HTML::TreeBuilder->new;
	$tree->parse_file($path);

	my $self = {
		path => $path,
		tree => $tree,
	};
	bless $self, $class;
	return $self;
}

# we don't want DESTROY to fallback into AUTOLOAD
sub DESTROY {}

our $AUTOLOAD;
sub AUTOLOAD {
	my $self = shift;

    my $class = $AUTOLOAD;
    $class =~ s/.*://;

#warn "XX $class\n";

	if ( my $vevent = $self->{tree}->look_down( class => 'vevent' ) ) {
		if ( my $text = $vevent->look_down( class => $class )->as_trimmed_text ) {
			return $text;
		} else {
			die "can't find vevent.$class in ", $self->{path};
		}
	} else {
		die "can't find vevent in ", $self->{path};
	}

}

sub as_HTML {
	my $self = shift;
	my $el = shift;
	my $vevent = $self->{tree}->look_down( class => 'vevent' )
		->push_content( $el )
		->as_HTML('<>&')
	;
}

sub dtstart_iso {
	my $self = shift;
	$self->{tree}->look_down( class => 'vevent' )->look_down( class => 'dtstart' )->attr('title');
}

1;
