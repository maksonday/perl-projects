package Meowse::Meta::Attribute;

use Carp        ();
use Scalar::Util();


sub meta {
    return Meowse::Meta::Class->initialize(ref($_[0]) || $_[0]);
}

sub _process_options{
    my($class, $name, $args) = @_;

    defined($name)
        or Carp::croak('You must provide a name for the attribute');

    if(!exists $args->{init_arg}){
        $args->{init_arg} = $name;
    }

    my $can_be_required = defined( $args->{init_arg} );

    if(exists $args->{builder}){
        Carp::croak('builder must be a defined scalar value which is a method name')
            if !defined $args->{builder};

        $can_be_required++;
    }
    elsif(exists $args->{default}){
        if(ref $args->{default} && ref($args->{default}) ne 'CODE'){
            Carp::croak("References are not allowed as default values, you must "
                              . "wrap the default of '$name' in a CODE reference (ex: sub { [] } and not [])");
        }
        $can_be_required++;
    }
    if( $args->{required} && !$can_be_required ) {
        Carp::croak("You cannot have a required attribute ($name) without a default, builder, or an init_arg");
    }

    if(exists $args->{is}){
        my $is = $args->{is};

        if($is eq 'ro'){
            $args->{reader} ||= $name;
        }
        elsif($is eq 'rw'){
            if(exists $args->{writer}){
                $args->{reader} ||= $name;
             }
             else{
                $args->{accessor} ||= $name;
             }
        }
        elsif($is eq 'bare'){
        }
        else{
            $is = 'undef' if !defined $is;
            Carp::croak("I do not understand this option (is => $is) on attribute ($name)");
        }
    }

    if ($args->{lazy_build}) {
        exists($args->{default})
            && Carp::croak("You can not use lazy_build and default for the same attribute ($name)");

        $args->{lazy}      = 1;
        $args->{builder} ||= "_build_${name}";
        if ($name =~ /^_/) {
            $args->{clearer}   ||= "_clear${name}";
            $args->{predicate} ||= "_has${name}";
        }
        else {
            $args->{clearer}   ||= "clear_${name}";
            $args->{predicate} ||= "has_${name}";
        }
    }

    return;
}

sub new {
    my $class = shift;
    my $name  = shift;

    my %args  = (@_ == 1) ? %{ $_[0] } : @_;

    $class->_process_options($name, \%args);

    $args{name} = $name;

    my $self = bless \%args, $class;

    return $self;
}   

1;
__END__
