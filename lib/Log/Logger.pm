package Log::Logger;

use strict;
use warnings;

use Log::Minimal;

sub new {
    my $class = shift;
    my $self = {};
    return bless $self, $class;
}

sub enable_debug_mode {
    $ENV{LM_DEBUG} = 1;
}

sub debug {
    my $self = shift;
    my $message = shift;
    debugf($message);
}

sub info {
    my $self = shift;
    my $message = shift;
    infof($message);
}

sub warn {
    my $self = shift;
    my $message = shift;
    warnf($message);
}

sub crit {
    my $self = shift;
    my $message = shift;
    critf($message);
}

1;