package Meowse::Meta::Class;
use 5.016;
use Scalar::Util qw/blessed weaken/;

my %METAS;

sub initialize {
    my($class, $package_name, @args) = @_;

    ($package_name && !ref($package_name))
        || Carp::croak("You must pass a package name and it cannot be blessed");

    return $METAS{$package_name}
        ||= $class->_construct_meta(package => $package_name, @args);
}

sub _construct_meta {
    my($class, %args) = @_;

    $args{attributes} = {};
    $args{methods}    = {};
    $args{roles}      = [];

    $args{superclasses} = do {
        no strict 'refs';
        \@{ $args{package} . '::ISA' };
    };

    my $self = bless \%args, ref($class) || $class;
    return $self;
}

sub superclasses {
    my $self = shift;

    if (@_) {
        foreach my $super(@_){
        @{ $self->{superclasses} } = @_;
    }

    return @{ $self->{superclasses} };
}

sub add_attribute {
    my $self = shift;

    my($attr, $name);

    if(blessed $_[0]){
        $attr = $_[0];
        $name = $attr->name;
    }
    else{
        $name = shift;

        my %args = (@_ == 1) ? %{$_[0]} : @_;

        defined($name)
            or Carp::croak('You must provide a name for the attribute');

        my $attribute_class = \%args;
        $attr = $attribute_class->new($name, %args);
    }

    weaken( $attr->{associated_class} = $self );

    $self->{attributes}{$attr->name} = $attr;
    return $attr;
}

sub _install_modifier {
    my ( $self, $type, $name, $code ) = @_;
    require Class::Method::Modifiers::Fast;
    my $install_modifier = Class::Method::Modifiers::Fast->can('_install_modifier');
    my $impl = sub {
        my ( $self, $type, $name, $code ) = @_;
        my $into = $self->name;
        $install_modifier->($into, $type, $name, $code);
        $self->add_method($name => do{
            no strict 'refs';
            \&{ $into . '::' . $name };
        });
        return;
    };

    {
        no warnings 'redefine';
        *_install_modifier = $impl;
    }

    $self->$impl( $type, $name, $code );
}

sub add_before_method_modifier {
    my ( $self, $name, $code ) = @_;
    $self->_install_modifier( 'before', $name, $code );
}

sub add_around_method_modifier {
    my ( $self, $name, $code ) = @_;
    $self->_install_modifier( 'around', $name, $code );
}

sub add_after_method_modifier {
    my ( $self, $name, $code ) = @_;
    $self->_install_modifier( 'after', $name, $code );
}

__END__
