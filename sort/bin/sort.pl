#!/usr/bin/env perl

use 5.016;
use warnings;
use Scalar::Util qw(dualvar);

my $param_r = '';
my $param_u = '';
my $param_n = '';
my @arr = ();
my @sorted = ();
my %uniq;

use Getopt::Long;
Getopt::Long::GetOptions("-n" => \$param_n, "-r" => \$param_r, "-u" => \$param_u) or die("Error in command line arguments\n");

while(<>){
	chomp($_);
	my $var;
	if ($_ =~ m/(^\s*\-?\d+(\.?\d+)?)/){ $var = dualvar($1, $_); }
	else{ $var = dualvar(0, $_); }
	push(@arr, $var);
}
if ($param_n){
	@sorted = sort{
		if(!$param_r){ $a <=> $b || $a cmp $b; }
		else{ $b <=> $a || $b cmp $a; }
	} @arr;
}
else{
	@sorted = sort{
		if(!$param_r){ $a cmp $b; }
		else{ $b cmp $a; }
	} @arr;
}

if ($param_u) { @sorted = grep{ !$uniq{$_}++ } @sorted; } #удаляем повторяющиеся строки
for (@sorted) { say $_; }
print <>;
