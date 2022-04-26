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

    $discord->connect($config->{token}, $config->{timeline_webhook_url});

    return bless $self, $class;
};

1;