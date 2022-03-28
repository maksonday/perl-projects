package Local::Source::Text;

use strict;
use warnings;
use base 'Local::Source';

=encoding utf8

=head1 NAME

Local::Source - base abstract reducer

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub new {
	my ($class, %args) = @_;
	my $del;
	if (exists $args{"delimiter"}) {
		$del = quotemeta ($args{"delimiter"});
	}
	else { $del = '\n';  }
	my @array = split $del, $args{"text"};
	$args{"array"} = \@array;
	delete ($args{"text"});
	return bless \%args,$class;
}

1;