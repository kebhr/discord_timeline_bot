package Discord::Client;

use strict;
use warnings;

use utf8;
use JSON;
use LWP;
use LWP::UserAgent;
use AnyEvent;
use AnyEvent::WebSocket::Client;
use DDP;

sub new {
    my $class = shift;
    my $self = {

    };
    return bless $self, $class;
}

sub connect {
    p @_;
    
    my $self = shift;
    my $token = shift;

    my $ua = LWP::UserAgent->new;
    $ua->agent("discord_timeline_bot/0.1");

    my $ws_url = _get_ws_url($ua);

    my $ws = AnyEvent::WebSocket::Client->new;
    $ws->connect($ws_url . '/?v=9&encoding=json')->cb(sub {
        our $connection = eval { shift->recv };
        if ($@) {
            warn $@;
            return;
        }

        $connection->on(each_message => sub {
            my ($connection, $message) = @_;
            my $body = decode_json($message->body);
            # p $body;

            my $op_code = $body->{op};

            if ($op_code == 10) {
                my $w = AnyEvent->timer (after => 0, interval => $body->{d}{heartbeat_interval} / 1000, cb => sub {
                    # TODO: send heartbeat
                    p @_;
                });

                my $json = encode_json({
                    op => 2,
                    d => {
                        token => $token,
                        intents => 513,
                        properties => {
                            '$os' => "linux",
                            '$browser' => 'discord_timeline_bot',
                            '$device' => 'discord_timeline_bot'
                        }
                    }
                });

                $connection->send($json);
            }

            if ($body->{t} eq "MESSAGE_CREATE") {
                print $body->{d}{author}{username} . " says " . $body->{d}{content} . "\n";
            }
        });
    });

    AnyEvent->condvar->recv;
}

sub _get_ws_url {
    my $ua = shift;
    my $req = HTTP::Request->new(GET => 'https://discordapp.com/api/gateway');
    my $res = $ua->request($req);
    return decode_json($res->content)->{url};
}

1;