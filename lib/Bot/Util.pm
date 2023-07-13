package Bot::Util;

use strict;
use warnings;
use utf8;

sub is_emoji_only {
    my ($class, $text) = @_;
    return $text =~ m/^[^\p{BasicLatin}|\p{Katakana}|\p{Hiragana}|\p{Han}|\p{CJKSymbolsAndPunctuation}|\p{HalfwidthAndFullwidthForms}]*$/;
}

1;