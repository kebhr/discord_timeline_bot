package Bot::Robo;

use strict;
use warnings;
use utf8;

use Discord::Client;
use Bot::Util;
use namespace::autoclean;

sub new {
    my ($class, $config) = @_;

    my $discord = Discord::Client->new($config->{token}, $config->{timeline_webhook_url});

    my $self = {
        config  => $config,
        discord => $discord,
        times   => {},
    };

    $discord->on("MESSAGE_CREATE",  sub { $self->_message_create(@_) });
    $discord->on("CHANNEL_CREATE",  sub { $self->_channel_create(@_) });
    $discord->on("CHANNEL_UPDATE",  sub { $self->_channel_update(@_) });
    $discord->on("GUILD_CREATE",    sub { $self->_guild_create(@_) });

    $discord->connect;

    return bless $self, $class;
}

sub _message_create {
    my ($self, $body) = @_;

    return if !exists $self->{times}{$body->{d}{channel_id}} || $body->{d}{author}{bot};

    my $msg_url     = sprintf("https://discord.com/channels/%s/%s/%s", $body->{d}{guild_id}, $body->{d}{channel_id}, $body->{d}{id});
    my $link_text   = $self->{times}->{$body->{d}{channel_id}}{topic} // $self->{times}->{$body->{d}{channel_id}}{name};
    my $display_msg = Bot::Util->is_emoji_only($link_text) ? sprintf("%s %s", $link_text, $body->{d}{content}) : sprintf("[%s](%s) %s", $link_text, $msg_url, $body->{d}{content});
    my $avatar_url  = sprintf("https://cdn.discordapp.com/avatars/%s/%s.png", $body->{d}{author}{id}, $body->{d}{member}{avatar} // $body->{d}{author}{avatar});

    my $content = {
        content     => $display_msg,
        username    => $body->{d}{member}{nick} // ($body->{d}{author}{global_name} // $body->{d}{author}{username}),
        avatar_url  => $avatar_url,
    };

    $self->{discord}->webhook_post($content, $body->{d}{attachments});
}

sub _channel_create {
    my ($self, $body) = @_;
    $self->_refresh_channel_info($body->{d}) if $body->{d}{name} =~ /^times_.*$/;
}

sub _channel_update {
    my ($self, $body) = @_;
    $self->_refresh_channel_info($body->{d}) if $body->{d}{name} =~ /^times_.*$/;
}

sub _guild_create {
    my ($self, $body) = @_;
    $self->{times}{$_->{id}} = {
        name    => $_->{name},
        topic   => $_->{topic},
    } for @{[grep { $_->{name} =~ /^times_.*$/ } @{$body->{d}{channels}}]};
}

sub _refresh_channel_info {
    my ($self, $channel) = @_;
    $self->{times}{$channel->{id}} = {
        name    => $channel->{name},
        topic   => $channel->{topic},
    };
}

1;