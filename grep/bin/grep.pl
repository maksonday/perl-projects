#!/usr/bin/env perl

use 5.016;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use Encode qw(decode_utf8);
#use Term::ANSIColor;
my $A = 0;
my $B = 0;
my $C = 0;
my $_c;
my $i;
my $v;
my $F;
my $n;
GetOptions (
	'A=i' => \$A,
	'B=i' => \$B,
	'C=i' => \$C,
	'c' => \$_c,
	'i' => \$i,
	'v' => \$v,
	'F' => \$F,
	'n' => \$n
);
my $reg = decode_utf8(shift @ARGV);
my @arr;
my $after = 0;
my $before = 0;

if ($F) { $reg = quotemeta($reg); }
if ($i) { $reg = qr/$reg/i; }

if ($C){
	$before = $C;
	$after = $C;
}
if ($B) { $before = $B; }
if ($A) { $after = $A; }

my $previous = undef;
my $flag = 0;
my $str_counter = 0;
my $c_ans = 0;
my @pr_arr = ();
my $d = ":";
while (<>) {
	if (!$_c){
		$str_counter++;
		if ($_ =~ $reg xor ($v)){
			if (defined $previous and (($previous !~ $reg) xor $v)){
				if ((scalar(@pr_arr) <= $after + $before) and ($before or ($after and $flag))){
					if ($after and $flag){
						for (0..$#pr_arr){
							if (($pr_arr[$_] =~ $reg) xor $v){ $d = ":"; }
							else{ $d = "-"; }
							if ($n){ print $str_counter - $#pr_arr - 1 + $_.$d.$pr_arr[$_]; }
							else{ print $pr_arr[$_]; }
						}
					}
					else{
						my $index = $#pr_arr - $before + 1;
						if ($index < 0) { $index = 0; }
						for ($index..$#pr_arr){
							if (($pr_arr[$_] =~ $reg) xor $v){ $d = ":"; }
							else{ $d = "-"; }
							if ($n){ print $str_counter - $#pr_arr + $index - 1 + $_.$d.$pr_arr[$_]; }
							else{ print $pr_arr[$_]; }
						}
					}
				}
				else{
					if ($after and $flag){
						my $index = $after - 1;
						if ($index > $#pr_arr){ $index = $#pr_arr; }
						for (0..$index){ 
							if (($pr_arr[$_] =~ $reg) xor $v){ $d = ":"; }
							else{ $d = "-"; }
							if ($n){ print $str_counter - $#pr_arr - 1 + $_.$d.$pr_arr[$_]; }
							else{ print $pr_arr[$_]; }
						}
					}
					if ($before){
						my $index = $#pr_arr - $before + 1;
						if ($index < 0) { $index = 0; }
						for ($index..$#pr_arr){
							if (($pr_arr[$_] =~ $reg) xor $v){ $d = ":"; }
							else{ $d = "-"; }
							if ($n){ print $str_counter - $#pr_arr - 1 + $_.$d.$pr_arr[$_]; }
							else{ print $pr_arr[$_]; }
						}
					}
				}
				@pr_arr = ();
			}
			if (($_ =~ $reg) xor $v){ $d = ":"; }
			else{ $d = "-"; }
			if ($n){
				print $str_counter.$d.$_;
			}
			else { print $_; }
			#print color('reset');
			$flag = 1;
		}
		elsif($before or ($after and $flag)){
			push(@pr_arr, $_);
		}
		$previous = $_;
	}
	else{
		if (($_ =~ $reg) xor $v){ $c_ans++; }
	} 
}
if($_c){ say $c_ans; }
elsif(scalar(@pr_arr) and $flag){
	my $index = $after - 1;
	if ($index > $#pr_arr){ $index = $#pr_arr; }
	for (0..$index){
		if (($pr_arr[$_] =~ $reg) xor $v){ $d = ":"; }
		else{ $d = "-"; }
		if ($n){ print $str_counter - $#pr_arr + $_.$d.$pr_arr[$_]; }
		else{ print $pr_arr[$_]; }
	}
}
