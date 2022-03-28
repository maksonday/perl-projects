package Transaction;

our $VERSION = 1.0;

use Storable qw(dclone);
use Data::Dumper;
use IPC::Shareable qw(:all);
use Data::Dumper;

use IO::Handle;
use POSIX ':sys_wait_h';

use strict;
use warnings 'all';

#Our modifying object
my $OBJ = {
    id => undef,
    name => undef,
    age => undef,
    sex => undef,
    state => undef,
};


#Hashref of blocking fields during transactions

my %CHANGES = ();

our $autocommit = 0;

my %ACTIONS = (
    select => 1,
    set => 2,
    create_key => 1,
    delete_key => 1,
    rollback => 0,
    commit => 0,
);

my $LOG_FILE_DEFAULT = 'changes.log';

my $hdl_obj = tie $OBJ, 'IPC::Shareable', undef, { destroy => 1 };

my $hdl_sync = tie my $sync = 0, 'IPC::Shareable', undef, { destroy => 1 };

sub new
{
    my $class = shift;
    my $self->{log_file} = shift // $LOG_FILE_DEFAULT;
    bless $self, $class;
    return $self;
}

my @queue = ();

sub process
{
    my ($self, $transactions) = @_;

    open(LOGGER, '+>>', $self->{log_file});
    
    my $parent=$$;
    my $num;
    for my $tr_id(0..2) {
=a
        if (fork() == 0) {
            my $obj = $self->_process($tr_id, $transactions->{$tr_id});
            $self->commit($tr_id, $obj) unless $autocommit;
            my $time = time;
            print WRITER "$tr_id;$time;Processed transaction $tr_id\n";
            exit;
        }
=cut    
        defined fork or die "Cant fork: $!";
        pipe(READER,WRITER);
        WRITER->autoflush(1);
         if($$ == $parent) # Master process
        {
            close WRITER;        
            print "parent $$\n";
            while (defined(my $line = <READER>)){
                print "<<<<< $line";

                #sleep rand 5;
            } 
            
        }
            else # Fork process
            {
            close READER;

            print WRITER $tr_id, "\n";
        
            exit 0;
        }
    }
=a
    my ($rin,$rout) = ('');
    vec($rin,fileno(READER),1) = 1;
    while (1) {
        my $read_avail = select($rout=$rin, undef, undef, 0.0);
        if ($read_avail < 0) {
            if (!$!{EINTR}) {
                warn "READ ERROR: $read_avail $!\n";
                last;
            }
        } elsif ($read_avail > 0) {
            if (defined(my $line = <READER>)){
                print LOGGER $line;
            }
        } else {
            if (fork() == 0 and $^T<10){
                sync(' ', \@queue);
            }
        }
        
        last if waitpid(-1,&WNOHANG) < 0;
    }
    #print Dumper \@queue;
    #process_queue();
   
    close WRITER;
=cut

   
    return $OBJ;
}

sub sync
{
    my ($changes, $queue) = @_;
    #close READER;
    #print LOGGER $changes;
    return;
    my ($tr_id, $time, $args);
    my @queue = $queue ? @{$queue} : ();

    if ($changes){
        chomp($changes);
        ($tr_id, $time, $args) = split /\s*;\s*/, $changes;
        if (($args || '')!~ /(Error)|(Processed)|(BLOCK)/){
            push @queue, {tr_id => $tr_id, time => $time, args => $args};
        }
        elsif (($args || '') =~ /BLOCK/){
            my @keys = split /,/, (split /:/, $args)[1];
            for (@keys){
                if ($CHANGES{$_}){
                    push @{$CHANGES{$_}}, $tr_id;
                } 
                else{
                    $CHANGES{$_} = [$tr_id];
                }
            }
        }
        elsif (($args || '') =~ /Processed/){
            for (keys %CHANGES){
                for (@{$CHANGES{$_}}){

                }
            }
        }
        elsif(($args || '') =~ /Error/){
            for (keys %CHANGES){
                if ( ($CHANGES{$_}->[0] || -1) == $tr_id ){
                    
                }
            }
        }
    }
    my $current = $queue[0];
    if ($current->{args}){
        for (split /,/, $current->{args}){
            my ($key, $val) = split /\s*=>\s*/, $_;
            if ( ($CHANGES{$key}->[0] || -1) == $tr_id ){
                $OBJ->{$key} = (split /\s*:\s*/, $val)[1];
                #print LOGGER "$current->{tr_id};$current->{time};$current->{args}\n";
                shift @{$CHANGES{$key}};
                shift @queue;
            }
        }
    }
    #return @queue;

    exit;
}

sub process_queue
{
    @queue = sort {$a->{time} <=> $b->{time} || $a->{tr_id} <=> $b->{tr_id}} @queue;  
    while(scalar @queue){
        my $continue = 0;
        for my $current(@queue){
            if ($current->{args} && !($current->{done} || 0)){
                for (split /,/, $current->{args}){
                    my ($key, $val) = split /\s*=>\s*/, $_;
                    if ( ($CHANGES{$key}->[0] || -1) == $current->{tr_id} ){
                        $continue = 1;
                        $current->{done} = 1;
                        $OBJ->{$key} = (split /\s*:\s*/, $val)[1];
                        #print LOGGER "$current->{tr_id};$current->{time};$current->{args}\n";
                        shift @{$CHANGES{$key}};
                    }
                }
            }
        }
        last unless $continue;
    }
    my @new_queue = ();
    for (@queue){
        push @new_queue, $_ unless ($_->{done} || 0);
    }
    return @new_queue;
}

sub _process
{
    my ($self, $tr_id, $transaction) = @_;
    close READER;

    my ($obj, $new_obj);
    my $time = time;

    $obj = dclone($OBJ) if $OBJ;
    $new_obj = dclone($obj) if $obj;

    my $blocking_keys = "$tr_id;$time;BLOCK:";
    my @keys = $self->parse_args($transaction);
    $blocking_keys .= join ',', @keys if @keys;
    print WRITER $blocking_keys."\n" if @keys;

    my @queries = split /\s*;\s*/, $transaction;

    for my $query(@queries){
        $query =~ /^(\w+)\s+(.+)$/;
        my ($action, $object) = ($1, $2);

        if (exists $ACTIONS{$action}){
            my @args = split /\s*=>\s*/, $object;

            if ($ACTIONS{$action} == scalar @args){      
                if ($action =~ /^(set|create_key|delete_key)$/){
                    $CHANGES{$args[0]} = $tr_id;
                }
                $new_obj = $self->$action($new_obj, @args);

                if ($autocommit){
                    $self->commit($tr_id, $obj, $new_obj);
                }
            }
            else{
                if ($autocommit){
                    $self->rollback($tr_id, $obj);
                }
                my $time = time;
                print WRITER "$tr_id;$time;Error: incorrect query: $query\n";
            }
        }
        else{
            if ($autocommit){
                $self->rollback($tr_id, $obj);
            }
            print STDOUT "Error: unsupported action: $action";
        }
    }
}

sub commit
{
    my ($self, $tr_id, $obj, $new_obj) = @_;
    my $time = time;
    my $changes = "$tr_id;$time;";
    my $is_changed = 0;
    for (keys %CHANGES){
        if ($CHANGES{$_}){
            my $new_val = $new_obj->{$_};
            my $old_val = $obj->{$_};
            if ( ($new_val || '') ne ($old_val || '')){
                $is_changed = 1;
                $changes .= "$_=>";
                $changes .= $old_val if $old_val;
                $changes .= ":";
                $changes .= $new_val if $new_val;
                $changes .= ',';
            } 
        }
    }
    %CHANGES = ();
    if ($is_changed){
        chop($changes);
        $changes .= "\n";
        print WRITER $changes;
    }
}

sub rollback
{
    my ($self, $tr_id, $time, $obj) = @_;
    for (keys %CHANGES){
        if ($CHANGES{$_} == $tr_id){
            $OBJ->{$_} = $obj->{$_};
            delete $CHANGES{$_};
        }
    }
}

sub select
{
    my ($self, $obj, $key) = @_;
    my @keys = split /\s*,\s*/, $key;
    for (@keys){
        if ($obj->{$_}){
            print STDOUT $_.' => '.$obj->{$_}."\n";
        }
        else{
            print STDOUT $_.' => undef'."\n";
        }
    }
    return $obj;
}

sub set
{
    my ($self, $obj, $key, $val) = @_;
    $obj->{$key} = $val;
    return $obj;
}

sub delete_key
{
    my ($self, $obj, $key) = @_;
    delete $obj->{$key} if exists $obj->{$key};
    return $obj;
}

sub create_key
{
    my ($self, $obj, $key) = @_;
    $obj->{$key} = undef unless exists $obj->{$key};
    return $obj;
}

sub parse_args
{
    my ($self, $string) = @_;
    $string =~ s/^\s+|\s+$//g;
    my @keys = map { (split /\s+/, $_)[1] } (split /\s*;\s*/, $string);
    return @keys;
}

sub string_to_struct
{
    my $string = shift;
    $string =~ s/^\s+|\s+$//g;
    my $obj = { map { my ( $key, $val ) = split /\s*:\s*/, $_; $key => $val } split /\s*;\s*/, $string };
    #TODO
    return $obj;
}

1;
