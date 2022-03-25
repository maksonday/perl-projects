#!/usr/bin/env perl
# vim: noet:

use 5.016;  # for say, given/when
use warnings;

# This code required for use of given/when
BEGIN {
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';

our $VERSION = 1.0;

use FindBin;
use lib "$FindBin::Bin/../lib";

use DeepClone;
use Data::Dumper;

local $Data::Dumper::Indent = 0;

# В качестве значения $orig следует использовать какую либо сложую структуру.
my $orig = {
	sv => "string",
	av => [ qw(some elements) ],
	hv => {
		nested => "value",
		key => [ 1,2,{} ],
	},
};
my $cloned = DeepClone::clone($orig);

say "ORIGINAL ", Dumper($orig);
say "CLONED   ", Dumper($cloned);
