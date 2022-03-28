#!/usr/bin/perl
use strict;
use warnings;

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lib';

use Transaction;

my %transactions = (
    1 => 'set state => error; set id => 0; set old_state => undef',
    2 => 'set id => 35; delete_key old_state; set id => 100; set id => 121',
    3 => 'set id => 41',
    4 => 'set sex => m; set age => 25; set new_state => undef',
);

my $log_file = shift;
my $transaction = Transaction->new($log_file);

$Transaction::autocommit = 1; #set this option if you want to autocommit every change in transaction
use Data::Dumper;

my $result = $transaction->process(\%transactions);

print Dumper $result;