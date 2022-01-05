package Meowse;
use 5.016;
use lib './Meta';
use Meowse::Meta::Class;
use Meowse::Meta::Attribute;
use Carp         qw(confess);
use Scalar::Util qw(blessed);

sub extends {
    Meowse::Meta::Class->initialize(scalar caller)->superclasses(@_);
    return;
}

sub has {
    my $meta = Meowse::Meta::Class->initialize(scalar caller);
    my $name = shift;

    Carp::croak(q{Usage: has 'name' => ( key => value, ... )})
        if @_ % 2; 

    if(ref $name){
        for (@{$name}){
            $meta->add_attribute($_ => @_);
        }
    }
    else{ 
        $meta->add_attribute($name => @_);
    }
    return;
}

sub before {
    my $meta = Meowse::Meta::Class->initialize(scalar caller);

    my $code = pop;

    for (@_) {
        $meta->add_before_method_modifier($_ => $code);
    }
    return;
}

sub after {
    my $meta = Meowse::Meta::Class->initialize(scalar caller);

    my $code = pop;

    for (@_) {
        $meta->add_after_method_modifier($_ => $code);
    }
    return;
}

sub around {
    my $meta = Meowse::Meta::Class->initialize(scalar caller);

    my $code = pop;

    for (@_) {
        $meta->add_around_method_modifier($_ => $code);
    }
    return;
}


__END__
