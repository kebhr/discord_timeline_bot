#!/usr/bin/env perl
use strict;
use warnings;

use Bot::Robo;
use DDP;

my $config = do "./app.conf";

my $bot = Bot::Robo->new($config);
