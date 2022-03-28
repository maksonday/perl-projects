package Local::Source::Array;

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
	my @arr;
	$arr[@arr] = $_ for (@{$args{"array"}});
	$args{"array"} = \@arr;
	return bless \%args,$class;
}

1;