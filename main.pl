#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Bot::Robo;

my $config = do "./app.conf";

my $bot = Bot::Robo->new($config);
