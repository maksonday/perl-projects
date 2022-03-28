package Local::Sum;

use strict;
use warnings;
use base 'Local::Reducer';
use Local::Row;
use Local::Source;

=encoding utf8

=head1 NAME

Local::Reducer - base abstract reducer

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut

sub reduce_n {
	my ($self,$n) = @_;
	my $str;
	my $sum = 0;
	for (1..$n) {
		$str = Local::Source::next($self->{source});
		if ($str) {
			my $struct = $self->{row_class}->new(str=>$str);
			if ($struct){
				my $value = $struct->Local::Row::get($self->{field});
				if ($value =~ /^\d+$/) {
					$sum += $value;
				}
			}
		}
	}
	$self->{reduced} += $sum;
	return $sum;
}
sub reduce_all {
	my $self = shift;
	while (my $sum = reduce_n($self, 1)) {
		$self->{reduced} = $self->{reduced} + $sum;
	}
	return $self->{reduced};
}

1;