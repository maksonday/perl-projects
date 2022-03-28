#!/usr/bin/env perl
use 5.016;

use warnings;
use Data::Dumper;
use Cwd;
use strict;
use POSIX qw(:sys_wait_h);
use IO::Handle;

$|=1;
our $do = 1;
our $pipe_check = 0;

sub PN{
    print "SHELL:", getcwd(),  " ";
}

sub working{
    return -t STDIN && -t STDOUT;
}

sub PipeCheck{
    my $line = shift;
    my @arr = split /\|/, $line;
    if (@arr eq 1) { $pipe_check = 0; }
    else { $pipe_check = 1; }

}

sub IsBashCommand{
    my $cmd = shift;
    my $flag;
    my @arrPath = split /:/, $ENV{PATH};
        for my $dir (@arrPath) {
        if (-e "$dir/$cmd" and -x "$dir/$cmd") {
            $flag = "$dir";
            last;
        }
    }
    return 1 if (defined $flag);
    return undef;   
}

sub Cd{
    my $folder = shift;
    if ($folder) {
        $folder =~ s/~/$ENV{HOME}/;
        unless (chdir $folder) {
            say "$folder doesn't exist\n"
        }
    }
    else {
        chdir $ENV{HOME};
    }
}

sub run{
    my $line = shift;
    my @line = split /\|/, $line;
    if ($pipe_check) {
        if (my $pid = open(RFC, '-|')) {
            print $_ while(<RFC>);
            close(RFC);
            waitpid($pid, 0);
        }
        else {
            die "Can't fork: $!" unless defined $pid;
            local $SIG{INT} = 'DEFAULT';    
            my @childout;
            for my $i(0..$#line) {
                my $cmd = $line[$i];
                $cmd =~ m/\s*(\w+)\s+(.*)/;
                next unless $1;
                pipe(IFP, OFC);    
                pipe(IFC, OFP);    
                if (my $pidP = fork()) {
                    if ($i) {    
                        close (IFP);
                        print OFC @childout;    
                        close (OFC);
                        @childout = ();
                    }
                    close (OFP);
                    while (<IFC>) {
                        push @childout, $_;
                    }
                    close (IFC);
                    waitpid ($pidP, 0);
                } 
                else {  
                    open (STDERR, '>&', 'STDOUT');
                    if ($i) {
                        close (OFC);
                        open (STDIN, '<&', 'IFP'); 
                        close (IFP);
                    }
                    close (IFC);
                    open (STDOUT, '>&', 'OFP') or die $!;
                    close (OFP);

                    if ($1 eq "echo"){
                        say $2;
                    }
                    elsif ($1 eq "cd"){
                        my @arr = split /\s+/, $2;
                        Cd($arr[0]);
                    }
                    elsif ($1 eq "pwd"){
                        say getcwd();
                    }
                    elsif ($1 eq "kill"){
                        kill 'TERM', $2;
                    }
                    else { 
                        exec "$line";
                    } 
                }
            }
            print @childout;
            exit;
        }
    }
    else {
        $line =~ m/(\w+)\s+(.*)/;
        if ($1 eq "echo"){
            say $2;
        }
        elsif ($1 eq "cd"){
            my @arr = split /\s+/, $2;
            Cd($arr[0]);
        }
        elsif ($1 eq "pwd"){
            say getcwd();
        }
        elsif ($1 eq "kill"){
            kill 'TERM', $2;
        }
        elsif(IsBashCommand($1)){
            local $SIG{INT} = 'DEFAULT';
            open (PW, "<&STDIN");

            pipe(PR, CW);
            pipe(CR, PW);
            
            if (my $pid = fork()){
                local *STDOUT;
                local *STDIN;
                close CR;
                close CW;
                open (STDOUT, "<&PR");
                open (STDIN, ">&PW");
                say $_ while <PR>;
                close PR;
                close PW;
                waitpid ($pid, 0);
            }
            else{
                close PR;
                close PW;
                exec "$line";
            }
        }
        else {
            say "Unknown command: $1";
        }
    }
}


while (working() && $do){
    local $SIG{INT} = 'IGNORE';
    PN;
    my $line = <>;
    if (defined $line) {
        PipeCheck($line);
        run($line);
    }
}
return 1;
