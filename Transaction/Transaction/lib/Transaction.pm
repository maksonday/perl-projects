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

    for my $tr_id(keys %{$transactions}) {
        if (fork() == 0) {
            my $obj = $self->_process($tr_id, $transactions->{$tr_id});
            $self->commit($tr_id, $obj) unless $autocommit;
            print WRITER "Processed transaction $tr_id\n";
            exit;
        }
    }
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
            if(defined(my $line = <READER>)){
                $self->sync($line);
            }
        } else {
            #No input, do nothing
        }
        last if waitpid(-1,&WNOHANG) < 0;
    }
    close WRITER;

    return $OBJ;
}

sub sync
{
    my ($self, $changes) = @_;

    my ($tr_id, $time, $args) = split /\s*;\s*/, $changes;
    if ($args !~ /error/){
        $hdl_obj->lock();
        for (split /,/, $args){
            my ($key, $val) = split /\s*=>\s*/, $_;
            $OBJ->{$key} = $val;
        }
        $hdl_obj->unlock();
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
                $obj = $self->$action($obj, @args);

                if ($autocommit){
                    $self->commit($tr_id, $obj);
                }
            }
            else{
                if ($autocommit){
                    $self->rollback($tr_id, $obj);
                }
                my $time = time;
                print WRITER "$tr_id;$time;error: incorrect query: $query";
                print WRITER "\n";
            }
        }
        else{
            if ($autocommit){
                $self->rollback($tr_id, $obj);
            }
            print STDOUT "error: unsupported action: $action";
        }
    }
}

sub commit
{
    my ($self, $tr_id, $new_obj) = @_;
    my $time = time;
    my $changes = "$tr_id;$time;";
    my $is_changed = 0;
    for (keys %CHANGES){
        if ($CHANGES{$_} == $tr_id){
            my $new_val = $new_obj->{$_};
            my $old_val = $OBJ->{$_};
            if ( ($new_val || '') ne ($old_val || '')){
                $is_changed = 1;
                $changes .= "$_ => ";
                $changes .= $old_val if $old_val;
                $changes .= ":".$new_val if $new_val;
                $changes .= ',';
            }   
            if (exists $new_obj->{$_}){
                $OBJ->{$_} = $new_obj->{$_};
            }
            else{
                delete $OBJ->{$_};
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
