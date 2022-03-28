package Local::Row::Simple;

use strict;
use warnings;
use base 'Local::Row';

=encoding utf8

=head1 NAME

Local::Row - base abstract reducer

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut


sub new {
	my ($class, %args) = @_;
	my %hash;
	my @arr = split ',' ,$args{"str"};
	for (@arr) {
		my @arr1 = split ':', $_;
		if (scalar(@arr1) == 2) {
			$hash{$arr1[0]} = $arr1[1];
		}
		else { return undef;}
	}
	return bless \%hash,$class;
}

1;