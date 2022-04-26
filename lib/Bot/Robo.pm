package Bot::Robo;

use strict;
use warnings;

use Discord::Client;

sub new {
    my ($class, $config) = @_;

    my $discord = Discord::Client->new;

    my $self = {
        config => $config,
        discord => $discord
    };

    $discord->connect($config->{token});

    return bless $self, $class;
};

1;