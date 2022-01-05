#!/usr/bin/env perl

package Local::Client;

use strict;
use warnings;
use Socket;
use IO::Select;
use IO::Socket::INET;
use Local::Proto;
use Data::Dumper;

our $timeout = 0.1;
our $N = 5;

my %FDS;
my $s = IO::Select->new();
my $listen_socket;
my $proto = Local::Proto->new();
my $host_to_sock = {};
my $req_sock = {};
my ($NOW, @TIMERS);

#my %ip_info = ();

sub start_server {
	my ($ip,$port,$cb) = @_;
	$listen_socket = IO::Socket::INET->new(
	    LocalAddr=>$ip,
	    LocalPort=>$port,
	    ReusePort=>1,
	    Listen =>10)
	or die "Can't create server";
	$FDS{$listen_socket} = {
        cb => sub {
            my ($socket) = @_;
            $s->add($socket);
            $FDS{$socket} = {cb => $cb};
        },
    };
	$s->add($listen_socket);
}

sub add_fd {
    my ($fd,$cb)=@_;
	my %hash;
	$s->add($fd);
	$hash{"cb"} = $cb;
	$FDS{$fd}=\%hash;
}

sub start_connect {

    my %hash;
    my ($ip,$port,$cmd,$data,$cb) = @_;
    my $header = $proto->make_header($cmd);
    my $bytes = $proto->enc_req($header,$data);
    if (!defined $bytes) {
	warn "неправильный формат данных";
        $cb->(undef, "can't pack req");
        return;
    }
    my $socket_c;
    if (exists $host_to_sock->{"$ip:$port"}) {
        if ($host_to_sock->{"$ip:$port"}->connected()) {
            $socket_c = $host_to_sock->{"$ip:$port"};
        }
        else {
            delete $host_to_sock->{"$ip:$port"};
        }
    }
    unless ($socket_c) {
	    $socket_c = $host_to_sock->{"$ip:$port"} = IO::Socket::INET->new(
            PeerAddr=>$ip,
            PeerPort=>$port,
            Proto =>"tcp",
            Type =>SOCK_STREAM,
            Timeout => 5,
            Autoflush => 1,
        );
        #$ip_info{$socket_c} = $ip if defined $socket_c;
    }
    unless($socket_c) {
        delete $host_to_sock->{"$ip:$port"};
        $cb->(undef, "can't make connect to $ip:$port");
    } else {
        warn "REQ=".$bytes;
        syswrite($socket_c, $bytes, 1024);
        $s->add($socket_c);
        $hash{"cb"} = $cb;
        $hash{"cmd"} = $cmd;
        $hash{"timer"}= NOW() + $N;
        $hash{socket} = $socket_c;
        $FDS{$socket_c} = \%hash;
    }
}

sub process_ready_socket {
    my $fh = shift;
    my $cb = $FDS{$fh}->{cb};
    if ($listen_socket and $fh eq $listen_socket) {
        warn "Connect";
        my $socket = $fh->accept();
	    $cb->($socket);
        $s->add($socket);
        $req_sock->{$socket} = 1;
    }
    else {
        my $bytes;
        if(sysread($fh, $bytes, 1024)){
            warn "READ DATA=".$bytes;
            my $req = $proto->dec_req($bytes);

            unless ($req) {
                warn "Неправильный формат данных из сети";
                warn "Disconnected";
            	$s->remove($fh);
            	delete $FDS{$fh};
            	$cb->($fh, undef);
	        }
           	if(exists $FDS{$fh}) {
                my $resp = $cb->($fh, $req);
                print "REQUEST:";
                print Dumper($resp);
                print "-------------";
                if ($resp) {
                    my $bytes = $proto->enc_resp($req->{head}, $resp);

                    if ($bytes) {
                         syswrite($fh, $bytes, length($bytes));
                    }
                    else {
                        warn "Client answer" . Dumper($resp);
                        $cb->(undef, "proto error");
                    }
                }
                else {
                    if ($req_sock->{$fh}) {
                        $cb->(undef, "empty resp not allowed");
                    }
                    else {
                        $s->remove($FDS{$fh}->{socket});
                        delete $FDS{$fh};
                    }
                }
            }
            else {
                warn "Прочитали из сокета и незнаем кому отдать";
                $cb->(undef, "fatal!!!");
            }
        }
        else {
            warn "Disconnected";
            $s->remove($fh);
            delete $FDS{$fh};
            $cb->($fh, undef);
        }
    }
    return;
}

my $looped = 1;
sub stop_loop {
	$looped = 0;
}

sub start_loop {
	my $cb_idle = shift;
	die "Error" unless $s;
	$looped = 1;
	while ($looped) {
		$NOW = time();

		my @invalid_handlers = $s -> has_exception($timeout);
		foreach my $bad_h(@invalid_handlers) {
			process_ready_socket($bad_h);
		}

		my @fhs = $s->can_read($timeout);
		for my $fh (@fhs) {
			process_ready_socket($fh);
		}
		my @ready_timers;
		while(@TIMERS) {
		    last if $TIMERS[0]->{dl} > time;
		    push @ready_timers, shift @TIMERS;
		}
		for(@ready_timers) {
		    $_->{cb}->();
		    timer($_->{interval}, $_->{interval}, $_->{cb}) if $_->{interval};
		}
		for (keys %FDS) {
			if (exists $FDS{$_}->{timer} and $FDS{$_}->{timer} < NOW()) {
				#warn "Disconnected ip = $ip_info{$FDS{$_}->{socket}}";
				#delete $ip_info{$FDS{$_}->{socket}};
				close($FDS{$_}->{socket});
				$s->remove($FDS{$_}->{socket});
				my $del_fd = delete $FDS{$_};
				$del_fd->{cb}->(undef, "timeout");
			}
		}
		$cb_idle->() if $cb_idle;
	}
}

sub timer {
    my ($timeout, $interval, $cb) = @_;
    push @TIMERS, { dl => NOW() + $timeout, cb => $cb, interval => $interval };
    @TIMERS = sort { $a->{dl} <=> $b->{dl} } @TIMERS;
}

sub NOW { $NOW || time }


1;
