package Transaction;

our $VERSION = 1.0;

my $OBJ = {};

our $CHANGES = {};

my $tr_id = 0;

our $autocommit = 0;

use AnyEvent;
use AnyEvent::Handle;
use Storable qw(dclone);
use Data::Dumper;

my %ACTIONS = (
    select => 1,
    set => 2,
    create_key => 1,
    delete_key => 1,
    rollback => 0,
    commit => 0,
);

my $LOG_FILE_DEFAULT = 'changes.log';

my $hdl;

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
    my ($self, $transaction) = @_;
    $tr_id++;
    my $time = time;
    my $obj = dclone($OBJ);
    my $new_obj = dclone($obj);
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
                    $CHANGES{$args[0]} = $tr_id;
                }
                $new_obj = $self->$action($new_obj, @args);
                if ($autocommit){
                    $self->commit($tr_id, $new_obj, $obj, $time);
                }
            }
            else{
                if ($autocommit){
                    $self->rollback($tr_id, $time, $obj);
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
    $self->commit($tr_id, $new_obj, $obj, $time) unless $autocommit;
    for (keys %CHANGES){
        delete $CHANGES{$_} if $CHANGES{$_} == $tr_id;
    }
    return $OBJ;
}

sub commit
{
    my ($self, $tr_id, $new_obj, $old_obj, $time) = @_;
    my $changes = "$tr_id:$time: ";
    for (keys %CHANGES){
        if ($CHANGES{$_} == $tr_id){
            my $new_val = $new_obj->{$_};
            my $old_val = $old_obj->{$_};
            $changes .= "$_ => $old_val:$new_val,";
            if (exists $new_obj->{$_}){
                $OBJ->{$_} = $new_obj->{$_};
            }
            else{
                delete $OBJ->{$_};
            }
        }
    }
    chop($changes);
    $hdl->push_write($changes);
    $hdl->push_write("\n");
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
