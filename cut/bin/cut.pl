#!/usr/bin/env perl
use 5.016;
use warnings;
use Getopt::Long;
use Getopt::Long qw(:config no_ignore_case bundling);
my $f;
my $d = "\t";
my $s;
GetOptions (
	'f=s' => \$f,
	'd=s' => \$d,
	's' => \$s
) or die("Error in command line arguments\n");
my $str;
my @f_arr;
if ($f) { @f_arr = split (",", $f);}
while (<STDIN>) {
	if (!$f) { print $_; }
	chomp($_);
	$str = $_;
	my $flag = 1;
	my @arr = split ($d, $str);
	for (@arr){
		#say $_;
	}
	if ($s and !($str =~ $d)) {	$flag = 0; }
	if ($f and $flag) {
		my $res_str = "";
		if ($#arr){
			for (@f_arr){
				if (!(scalar(@arr) < $_)){
					if ($res_str eq ""){ $res_str = $arr[$_ - 1]; }
					else  { $res_str = join $d, $res_str, $arr[$_ - 1]; }
				}
			}
			say $res_str;
		}
		else{ say $arr[0]; }
	}
}
