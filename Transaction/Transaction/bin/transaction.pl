#!/usr/bin/perl
use strict;
use warnings;

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lib';

use Transaction;

my %transactions = (
    1 => 'set state => error; set id => 0; create_key old_state',
    2 => 'set id => 35; delete_key old_state; set id => 100; set id => 121',
    3 => 'set id => 41',
    4 => 'set sex => m; set age => 25; create_key new_state',
);

my $log_file = shift;
my $transaction = Transaction->new($log_file);

$Transaction::autocommit = 1; #set this option if you want to autocommit every change in transaction

my $result = $transaction->process(\%transactions);

use Data::Dumper;
print Dumper $result;