package Log::Logger;

use strict;
use warnings;

use Log::Minimal;
use namespace::autoclean;

sub new {
    my $class = shift;
    my $self = {};

    $Log::Minimal::PRINT = sub {
        my ( $time, $type, $message, $trace, $raw_message ) = @_;
        print "$time [$type] $message\n";
    };

    return bless $self, $class;
}

sub enable_debug_mode {
    $ENV{LM_DEBUG} = 1;
}

sub debug {
    my $self = shift;
    my $message = shift;
    my $trace = $self->_trace;
    debugf("%s at %s", $message, $trace);
}

sub info {
    my $self = shift;
    my $message = shift;
    my $trace = $self->_trace;
    infof("%s at %s", $message, $trace);
}

sub warn {
    my $self = shift;
    my $message = shift;
    my $trace = $self->_trace;
    warnf("%s at %s", $message, $trace);
}

sub crit {
    my $self = shift;
    my $message = shift;
    my $trace = $self->_trace;
    critf("%s at %s", $message, $trace);
}

sub _trace {
    my ($package, $filename, $line) = caller(1);
    return sprintf("%s line %d", $filename, $line);
}

1;