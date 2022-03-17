#!/usr/bin/perl
use strict;
use warnings;

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lib';

use Transaction;

my %transactions = (
    1 => 'set state => error; set id => 0',
    2 => 'set id => 35; select id',
    3 => 'set id => 41; select id; delete_key id; create_key name',
    4 => 'set sex => m; set age => 25',
);

my $log_file = shift;
my $transaction = Transaction->new($log_file);

$Transaction::autocommit = 1; #set this option if you want to autocommit every change in transaction

$transaction->process(\%transactions);