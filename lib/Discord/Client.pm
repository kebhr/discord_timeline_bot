package Discord::Client;

use strict;
use warnings;

use Log::Logger;

use utf8;
use JSON;
use LWP;
use LWP::UserAgent;
use AnyEvent;
use AnyEvent::WebSocket::Client;
use DDP;
use namespace::autoclean;

sub new {
    my $class = shift;
    my $token = shift;
    my $webhook_url = shift;

    my $logger = Log::Logger->new;
    $logger->enable_debug_mode;

    my $self = {
        logger => $logger,
        ua => undef,
        connection => undef,
        token => $token,
        webhook_url => $webhook_url,
        session_id => undef,
        heartbeat_interval => 41.25,
        heartbeat_timer => undef,
        initiated => 0,
        last_seq => 0,
        times => {},
        count => 0,
    };
    return bless $self, $class;
}

sub connect {
    my $self = shift;

    $self->{ua} = LWP::UserAgent->new;
    $self->{ua}->agent("discord_timeline_bot/0.1");

    my $ws_url = $self->_get_ws_url;

    $self->{heartbeat_timer} = AnyEvent->timer (after => $self->{heartbeat_interval}, interval => $self->{heartbeat_interval}, cb => sub {
        $self->_send_heartbeat;
    });

    my $ws = AnyEvent::WebSocket::Client->new;
    $ws->connect($ws_url . '/?v=9&encoding=json')->cb(sub {
        $self->{connection} = eval { shift->recv };
        if ($@) {
            warn $@;
            return;
        }

        $self->{logger}->info("connected");

        $self->_send_resume if $self->{initiated} == !!1;

        $self->{connection}->on(each_message => sub {
            my ($connection, $message) = @_;
            my $body = decode_json($message->body);

            $self->{last_seq}++ if defined $body->{s};

            my $op_code = $body->{op};
            
            if ($op_code == 10) {
                $self->_hello($body);
            } elsif ($op_code == 11) {
                $self->_heartbeat_ack($body);
            } elsif ($op_code == 0) {
                $self->_dispatch($body);
            } elsif ($op_code == 9) {
                $self->_invalid_session;
            }
        });

        $self->{connection}->on(finish => sub {
            $self->{logger}->warn("connection closed");
            $self->{logger}->info("attempt to reconnect in 10 seconds");

            my $reconnect;
            $reconnect = AnyEvent->timer(after => 10, cb => sub {
                $self->{logger}->info("attempt to reconnect");
                $self->connect;
                $reconnect = undef;
            });
        });
    });
}

# op code = 0
sub _dispatch {
    my $self = shift;
    my $body = shift;

    $self->{logger}->debug("received dispatch(0) type=@{[$body->{t}]}");
    my $message_type = $body->{t};
    if ($message_type eq "MESSAGE_CREATE" && exists $self->{times}{$body->{d}{channel_id}} && !$body->{d}{author}{bot}) {
        my $req = HTTP::Request->new(POST => $self->{webhook_url});
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
    } elsif ($message_type eq "CHANNEL_UPDATE" || $message_type eq "CHANNEL_CREATE") {
        $self->{times}{$body->{d}{id}} = {
            name => $body->{d}{name},
            topic => $body->{d}{topic},
        };
    } elsif ($message_type eq "GUILD_CREATE") {
        $self->{times}{$_->{id}} = {
            name => $_->{name},
            topic => $_->{topic},
        } for @{[grep { $_->{name} =~ /^times_.*$/ } @{$body->{d}{channels}}]};
    } elsif ($message_type eq "READY") {
        $self->{session_id} = $body->{d}{session_id};
    }
}

# op code = 9
sub _invalid_session {
    my $self = shift;

    $self->_send_identity;
}

# op code = 10
sub _hello {
    my $self = shift;
    my $body = shift;

    $self->{logger}->debug("received hello(10)");

    $self->{heartbeat_interval} = $body->{d}{heartbeat_interval} / 1000;

    if ($self->{initiated} == 0) {
        $self->_send_identity;
        $self->{initiated} = !!1;
    }
}

# op code = 11
sub _heartbeat_ack {
    # Don't have to do anything.
    my $self = shift;

    $self->{logger}->debug("received heartbeat ack(11)");
}

sub _get_ws_url {
    my $self = shift;
    my $req = HTTP::Request->new(GET => 'https://discordapp.com/api/gateway');
    my $res = $self->{ua}->request($req);
    return decode_json($res->content)->{url};
}

sub _send_heartbeat {
    my $self = shift;
    $self->{logger}->debug("send heartbeat");
    my $heartbeat = encode_json({
        op => 1,
        d => $self->{last_seq} // 0
    });
    $self->{connection}->send($heartbeat);
}

sub _send_identity {
    my $self = shift;
    $self->{logger}->debug("send identify");
    my $json = encode_json({
        op => 2,
        d => {
            token => $self->{token},
            intents => 513,
            properties => {
                '$os' => "linux",
                '$browser' => 'discord_timeline_bot',
                '$device' => 'discord_timeline_bot'
            }
        }
    });
    $self->{connection}->send($json);
}

sub _send_resume {
    my $self = shift;
    $self->{logger}->debug("send resume");
    my $json = encode_json({
        op => 6,
        d => {
            token => $self->{token},
            session_id => $self->{session_id},
            seq => $self->{last_seq},
        }
    });
    $self->{connection}->send($json);
}

1;