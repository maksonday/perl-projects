#!/usr/bin/env perl
use 5.016;

use warnings;
use strict;
use IO::Socket::INET;
use Getopt::Long;
my $port;
my $ip;
my $u;
my $do = 1;

sub working{
	return -t STDIN;
}

GetOptions(
	"p=i" => \$port,
	"u"   => \$u);
$ip = shift;

if (!defined $ip) { $ip = '127.0.0.0'; }
if (!defined $u) { $u = 'tcp'; }
else { $u = 'udp'; }

my $server = IO::Socket::INET->new(
	PeerPort  => $port,
	Type      => SOCK_STREAM,
	LocalAddr => 1,
	Listen    => 10,
	Proto     => $u,
	PeerHost  => $ip) or die "Can't open socket: $@/";

while (working() && $do){
	my $line = <STDIN>;
	print {$server} $line || die "Can't send: $!\n";
}

close($server);