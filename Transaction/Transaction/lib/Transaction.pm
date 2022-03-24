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
my $ipc = tie 
            $OBJ, 
            'IPC::Shareable', 
            undef, 
            { destroy => 1 };

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

my $hdl_obj;
my $hdl_chg;
sub new
{
    my $class = shift;
    my $self->{log_file} = shift // $LOG_FILE_DEFAULT;
    bless $self, $class;
    return $self;
}

sub process
{
    my ($self, $transactions) = @_;
    pipe(READER,WRITER);
    WRITER->autoflush(1);
    my $pid;
    for my $tr_id(keys %{$transactions}) {
        $pid = fork();
        unless ($pid) {
            my $obj = $self->_process($tr_id, $transactions->{$tr_id});
            $self->commit($tr_id, $obj) unless $autocommit;
            my $time = time;
            print WRITER "$tr_id;$time;Processed transaction $tr_id\n";
            exit;
        }
    }

    while(1){
        my $res = waitpid($pid, WNOHANG);
        if ($res){
            last;
        }
        elsif (defined(my $line = <READER>)){
            print $line;
            $self->sync($line);      
        }
        close WRITER;
    }
    return $OBJ;
}

sub sync
{
    my ($self, $changes) = @_;
    chomp $changes;
    my ($tr_id, $time, $args) = split /\s*;\s*/, $changes;
    if ($args !~ /(error)|(Processed)/){
        $ipc->lock(LOCK_EX|LOCK_NB);
        for (split /,/, $args){
            my ($key, $val) = split /\s*=>\s*/, $_;
            $OBJ->{$key} = (split /:/, $val)[1];
        }
        $ipc->unlock();
    }
    else{
        $self->rollback();
    }
}

sub _process
{
    my ($self, $tr_id, $transaction) = @_;
    close READER;
    my $obj = dclone($OBJ);
    my $new_obj = dclone($obj);
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
                    $self->rollback($tr_id, $obj, $new_obj);
                }
                my $time = time;
                print WRITER "$tr_id;$time;error: incorrect query: $query";
                print WRITER "\n";
            }
        }
        else{
            if ($autocommit){
                $self->rollback($tr_id, $obj, $new_obj);
            }
            print STDOUT "error: unsupported action: $action";
        }
    }
    use Data::Dumper;
    #warn Dumper $obj;

}

sub commit
{
    my ($self, $tr_id, $obj, $new_obj) = @_;
    my $time = time;
    my $changes = "$tr_id;$time;";
    my $is_changed = 0;
    for (keys %CHANGES){
        if ($CHANGES{$_} == $tr_id){
            my $new_val = $new_obj->{$_};
            my $old_val = $obj->{$_};
            if ( ($new_val || '') ne ($old_val || '')){
                $is_changed = 1;
                $changes .= "$_ => ";
                $changes .= $old_val if $old_val;
                $changes .= ":".$new_val if $new_val;
                $changes .= ',';
            }   
            if (exists $new_obj->{$_}){
                $obj->{$_} = $new_obj->{$_};
            }
            else{
                delete $obj->{$_};
            }
        }
    }
    if ($is_changed){
        chop($changes);
        print WRITER $changes."\n";
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
    my $string = shift;
    $string =~ s/^\s+|\s+$//g;
    #TODO
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
