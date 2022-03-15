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
);

my $log_file = shift;
my $transaction = Transaction->new($log_file);

sub delay{
    my $cb = pop;

    my $w; $w = AnyEvent->timer (after => 0, interval => 0, cb => sub{
        undef $w;
        
        $cb->();
    });

    return;
}

$Transaction::autocommit = 1; #set this option if you want to autocommit every change in transaction

my $cv = AnyEvent->condvar;
$cv->begin;
use Data::Dumper;
for my $cur (keys %transactions){
    print "Process $cur\n";
    $cv->begin;
    delay sub{
        #do transaction
        $transactions{$cur} =~ s/^\s+|\s+$//g;
        my $result = $transaction->process($transactions{$cur});
        unless (ref $result) {
            print "Transaction $cur $result\n"
        }
        else{
            print "Processed $cur\n";
            print Dumper $result;
        } 
        $cv->end;
    }
}

$cv->end;
$cv->recv;