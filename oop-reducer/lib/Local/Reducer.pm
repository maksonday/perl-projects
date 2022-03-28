package Local::Reducer;

use strict;
use warnings;
=encoding utf8

=head1 NAME

Local::Reducer - base abstract reducer

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub new {
	my ($class, %args) = @_;
	$args{"reduced"} = 0;
	return bless \%args,$class;
}

sub reduced {
	my $self = shift;
	return $self->{reduced};
}


1;