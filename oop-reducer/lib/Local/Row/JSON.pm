package Local::Row::JSON;

use strict;
use warnings;
use base 'Local::Row';
use JSON::XS;
use Try::Tiny;

=encoding utf8

=head1 NAME

Local::Row - base abstract reducer

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

=cut


sub new {
    my ( $class, %args ) = @_;
    eval {
        my $self = decode_json( $args{str} );
        return undef if ( ref $self ne 'HASH' );
        return bless $self, $class;
    } or do { return undef; };
}

1;