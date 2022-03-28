package Local::Row;

use strict;
use warnings;

=encoding utf8

=head1 NAME

Local::Row - base abstract reducer

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub get {
	my ($self,$name) = @_;
	if (exists $self->{$name}) {
		return $self->{$name};
	}
	return undef;
}

1;