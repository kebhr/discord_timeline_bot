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
        ua => undef,
        connection => undef,
        heartbeat_interval => 41.25,
        last_seq => 0,
        times => {},
    };
    return bless $self, $class;
}

sub connect {
    my $self = shift;
    my $token = shift;
    my $webhook_url = shift;

    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->agent("discord_timeline_bot/0.1");

    my $ws_url = $self->get_ws_url;

    my $heartbeat_timer = AnyEvent->timer (after => $self->{heartbeat_interval}, interval => $self->{heartbeat_interval}, cb => sub {
        my $heartbeat = encode_json({
            op => 1,
            d => $self->{last_seq} // 0
        });
        $self->{connection}->send($heartbeat);
    });

    my $ws = AnyEvent::WebSocket::Client->new;
    $ws->connect($ws_url . '/?v=9&encoding=json')->cb(sub {
        $self->{connection} = eval { shift->recv };
        if ($@) {
            warn $@;
            return;
        }

        $self->{connection}->on(each_message => sub {
            my ($connection, $message) = @_;
            my $body = decode_json($message->body);

            $self->{last_seq} = $body->{s};

            my $op_code = $body->{op};
            
            if ($op_code == 10) {
                # Hello
                $self->{heartbeat_interval} = $body->{d}{heartbeat_interval} / 1000;

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
            } elsif ($op_code == 11) {
                # Heartbeat ACK
                # Don't have to do anything.
            } else {
                # Dispatch
                my $message_type = $body->{t};
                if ($message_type eq "MESSAGE_CREATE" && exists $self->{times}{$body->{d}{channel_id}} && !$body->{d}{author}{bot}) {
                    my $req = HTTP::Request->new(POST => $webhook_url);
                    $req->header(
                        "Content-Type" => "application/json"
                    );

                    my $msg_url = sprintf("https://discord.com/channels/%s/%s/%s", $body->{d}{guild_id}, $body->{d}{channel_id}, $body->{d}{id});
                    my $link_text = $self->{times}->{$body->{d}{channel_id}}{topic} // $self->{times}->{$body->{d}{channel_id}}{name};
                    my $display_msg = sprintf("[%s](%s) %s", $link_text, $msg_url, $body->{d}{content});
                    my $avatar_url = sprintf("https://cdn.discordapp.com/avatars/%s/%s.png", $body->{d}{author}{id}, $body->{d}{author}{avatar});
                    
                    $req->content(encode_json({
                        content => $display_msg,
                        username => $body->{d}{author}{username},
                        avatar_url => $avatar_url,
                    }));

                    my $res = $self->{ua}->request($req);
                } elsif ($message_type eq "GUILD_CREATE") {
                    $self->{times}{$_->{id}} = {
                        name => $_->{name},
                        topic => $_->{topic},
                    } for @{[grep { $_->{name} =~ /^times_.*$/ } @{$body->{d}{channels}}]};
                }
            }
        });
    });

    AnyEvent->condvar->recv;
}

sub _get_ws_url {
    my $self = shift;
    my $req = HTTP::Request->new(GET => 'https://discordapp.com/api/gateway');
    my $res = $self->{ua}->request($req);
    return decode_json($res->content)->{url};
}

1;