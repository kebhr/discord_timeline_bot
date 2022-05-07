package Bot::Robo;

use strict;
use warnings;

use Discord::Client;
use namespace::autoclean;

sub new {
    my ($class, $config) = @_;

    my $discord = Discord::Client->new($config->{token}, $config->{timeline_webhook_url});

    my $self = {
        config => $config,
        discord => $discord
    };

    $discord->connect;

    return bless $self, $class;
};

1;