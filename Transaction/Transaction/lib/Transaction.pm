package Transaction;

our $VERSION = 1.0;

use AnyEvent;
use AnyEvent::Handle;
use Storable qw(dclone);
use Data::Dumper;
use IPC::Shareable qw(:lock);
use Data::Dumper;

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
    open(DATA,"+>>", $self->{log_file});
    $hdl = new AnyEvent::Handle
        fh => \*DATA,
        on_error => sub {
            $hdl->destroy;
        };
    $self->{hdl} = $hdl;
    bless $self, $class;
    return $self;
}

sub process
{
    my ($self, $transactions) = @_;
    my %process;
    $hdl_obj = tie $OBJ, 'IPC::Shareable', undef, { destroy => 1 };
    $hdl_chg = tie %CHANGES, 'IPC::Shareable', undef, { destroy => 1 };
    for my $tr_id(keys %{$transactions}){
        my $pid = fork();
        die 'Failed to fork' if !defined $pid;

        if ($pid == 0) {
            my $obj = $self->_process($tr_id, $transactions->{$tr_id});

            $self->commit($tr_id, $obj) unless $autocommit;

            for (keys %CHANGES){
                $hdl_chg->lock();
                delete $CHANGES{$_} if $CHANGES{$_} == $tr_id;
                $hdl_chg->unlock();
            }

            print "Processed transaction $tr_id\n";

            use Data::Dumper;
            warn Dumper $OBJ;

            exit;
        }
        $process{$pid} = $tr_id;
        next;
    }

    while (1) {
        my $pid = waitpid(-1, WNOHANG);
        if ($pid > 0) {
            my $exit_code = $?/256;
            my $tr_id = delete $process{$pid};
            next;
        }
        last if !%process;
    }
        
    
    return $OBJ;
}

sub _process
{
    my ($self, $tr_id, $transaction) = @_;

    my $obj = dclone($OBJ);

    my @queries = split /\s*;\s*/, $transaction;
    for my $query(@queries){
        $query =~ /^(\w+)\s+(.+)$/;
        my ($action, $object) = ($1, $2);
        if (exists $ACTIONS{$action}){
            my @args = split /\s*=>\s*/, $object;
            if ($ACTIONS{$action} == scalar @args){      
                while ($CHANGES{$args[0]} && $CHANGES{$args[0]} != $tr_id){
                    #wait while field is blocked due to changes from other transaction
                }
                if ($action =~ /^(set|create_key|delete_key)$/){
                    $hdl_chg->lock();
                    $CHANGES{$args[0]} = $tr_id;
                    $hdl_chg->unlock();
                }
                $new_obj = $self->$action($obj, @args);
                if ($autocommit){
                    $self->commit($tr_id, $obj);
                }
            }
            else{
                if ($autocommit){
                    $self->rollback($tr_id, $obj);
                }
                return "error: incorrect query: $query";
            }
        }
        else{
            if ($autocommit){
                $self->rollback($tr_id, $time, $obj);
            }
            return "error: unsupported action: $action";
        }
    }
}

sub commit
{
    my ($self, $tr_id, $new_obj) = @_;
    for (keys %CHANGES){
        if ($CHANGES{$_} == $tr_id){
            #my $new_val = $new_obj->{$_};
            #my $old_val = $old_obj->{$_};
            #$changes .= "$_ => $old_val:$new_val,";
            if (exists $new_obj->{$_}){
                $hdl_obj->lock();
                $OBJ->{$_} = $new_obj->{$_};
                $hdl_obj->unlock();
            }
            else{
                $hdl_obj->lock();
                delete $OBJ->{$_};
                $hdl_obj->unlock();
            }
        }
    }
}

sub rollback
{
    my ($self, $tr_id, $time, $obj) = @_;
    for (keys %CHANGES){
        if ($CHANGES{$_} == $tr_id){
            $hdl_obj->lock();
            $OBJ->{$_} = $obj->{$_};
            $hdl_obj->unlock();
            $hdl_chg->lock();
            delete $CHANGES{$_};
            $hdl_chg->unlock();
        }
    }
}

sub select
{
    my ($self, $obj, $key) = @_;
    my @keys = split /\s*,\s*/, $key;
    for (@keys){
        if ($obj->{$_}){
            print $_.' => '.$obj->{$_}."\n"
        }
        else{
            print $_.' => undef'."\n"
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
