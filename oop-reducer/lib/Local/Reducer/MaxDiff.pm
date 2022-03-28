package Local::Reducer::MaxDiff;

use warnings
use strict;
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

sub reduce_n($n) {
	my ($self,$n) = @_;
	my $max = 0;
	for (1..$n) {
		my $str = $self->{source}->Local::Source::next;
		if ($str) {
				my $struct = $self->{row_class}->new(str=>$str);
				if ($struct){
					my $value1 = $struct->Local::Row::get($self->{top});
					my $value2 = $struct->Local::Row::get($self->{bottom});
					if (($value1 =~ /^\d+$/) and ($value2 =~ /^\d+$/) and ($value1 - $value2 > $max)) {
						$max = $value1 - $value2;
					}
				}
		}
	}
	$self->{reduced} = $max if ($self->{reduced} < $max);
	return $self->{reduced};
}
sub reduce_all {
	my $self = shift;
	my $str = $self->{source}->Local::Source::next;
	while (my $max = reduce_n($self, 1)) {
		$self->{reduced} = $max if ($self->{reduced} < $max);
	}
	return $self->{reduced};
}

1;