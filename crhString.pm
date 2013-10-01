#!/usr/bin/perl
# crhString.pm
#
# string subroutines
# v1.02 crh 20-jan-09 -- initial release
# v1.17 crh 05-feb-10 -- trueFalse and various prompt subs added
# v1.20 crh 20-jun-13 -- bsv/array conversion functions added

# singural($$$) -- avoids ugly single/plural text constructs.
# trueFalse($;$$) -- generates required boolean string
# pretty($;$) -- allows binary data to be output as readable text
# trim -- trims whitespace from both ends of supplied text
# zeroPad($$) -- pads number with leading zeroes
# pad ($$$;$) -- pad text to give the specified width (general purpose)
# isSimilar($$) -- compares text ignoring differences due to case and white space
# isSimilarName($$) -- compares text ignoring differences to case and non-word characters
# errPrompt($) -- prompt to STDERR, get line from STDIN, do not echo input (eg, passwords)
# prompt($) -- prompt to STDOUT, get line from STDIN, do not echo input (eg, passwords)
# errPromptEcho($) -- prompt to STDERR, get line from STDIN and echo input
# promptEcho($) -- prompt to STDOUT, get line from STDIN and echo input
# bsvEsc (;$) -- set/retrieve bsv bar escape sequence
# arr2BSV(@) -- converts an array to a BSV text string
# bsv2Arr($) -- converts a BSV text string to an array.


package crhString;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&singural &trueFalse &pretty &trim &zeroPad &pad &isSimilar &isSimilarName
    &errPromptEcho &promptEcho &errPrompt &prompt);

use warnings;
use strict;
use Term::ReadKey;

sub singural ($$$) {
# generate return string with required singular/plural case)
# usage: singural(Nr, singular_string, plural_string)

    if ($_[0] == 1) {
        return $_[0] . $_[1];
    } else {
        return $_[0] . $_[2];
    }
}

sub trueFalse ($;$$) {
# generate return string with required true/false value)
# usage: trueFalse(Boolean [, true_string, false_string])
# defaults to "true" and "false"

    if ($_[0]) {
        if (scalar(@_) > 1) {
            return $_[1];
        } else {
            return 'true';
        }
    } else {
        if (scalar(@_) > 2) {
            return $_[2];
        } else {
            return 'false';
        }
    }
}

sub pretty ($;$) {
# returns string with printable '^' character representation of abnormal
# characters found in the text string.
# multiple sequences of abnormal characters reduced to a single '^'.
# some whitespace characters treated separately
# args: string, [barff count] (0 = no limit)

    my $str = $_[0];
    my $lenStr;
    my $prettyStr = "";
    my $barff = 15; # default max count of unprintable char sequences
    my $hatCount = 0;
    my $seqCount = 0;
    my $char;
    my @chars;
    my $lower = ord(" ");
    my $upper = ord("~");
    
    if (scalar(@_) == 2) {
        $barff = $_[1];
    }
    
    # deal with trivial or simple white space cases quickly
    if (!($str =~ m/[^ £[:word:][:punct:]]/)) { # no action required
        return $str;
    } elsif (!($str =~ m/[^ £\t\r\n[:word:][:punct:]]/)) {  # white space action
        # substitute tab, carriage return and line feed control chars
        $str =~ s/\t/\\t/g;
        $str =~ s/\r/\\r/g;
        $str =~ s/\n/\\n/g;
        return $str;
    }
    
    # deal with binary data non-printable chars, one by one
    @chars = split(//, $str);
    foreach $char (@chars) {
        if ((ord($char) > $upper)||(ord($char) < $lower)) {
            if (!$seqCount++) { # first in sequence
                $prettyStr .= "^";
                if (++$hatCount == $barff) {    # enough!
                    last;
                }
            }
        } else {
            $prettyStr .= $char;
            $seqCount = 0;
        }
    }
    if ($hatCount) {    # this should always be triggered
        # give an indication of the length of the original binary data value
        $lenStr = length($_[0]);
        return $prettyStr . "[$lenStr]";
    } else {
        return $prettyStr;
    }
}

sub trim($;$) {
# trim whitespace from beginning and end of text
# args: text, remove all flag
# return: trimmed text
    
    my $text = $_[0];
    my $all  = 0;
    if (scalar(@_) == 2) {
        $all = $_[1];
    }
    
    if ($all) { # remove all whitespace chars
        $text =~ s/\s//g;
    } else {    # remove end whitespace (default case)
        $text =~ s/^\s+|\s+$//g;
    }
    return $text;
}

sub zeroPad ($$) {
## zero pad a number to give the specified width
# arg: number, width
# return padded text

    my $test = $_[0];
    my $padLen = $_[1] - length($_[0]);
    
    if ($test =~ /\D/) { # non-digits present
        return $_[0];
    } elsif ($padLen > 0) { # ok
        return ('0' x ($padLen) . $_[0]);
    } else {    # nothing to do
        return $_[0];
    }
}

sub pad ($$$;$) {
# pad text to give the specified width
# args: text, width, pad_char[, left]
# assumes left pad required unless 4th arg is FALSE
# return padded text

    my $text = $_[0];
    my $padLen = $_[1] - length($_[0]);
    my $char = $_[2];   # assumed single char
    my $left = (scalar(@_) == 3) ? 1 : $_[3];
    
    if ($padLen > 0) { # ok, work to do
        $left ? return ($char x ($padLen) . $_[0]) : ($_[0] . $char x ($padLen));
    } else {    # nothing to do
        return $_[0];
    }
}

sub isSimilar($$) {
# compares text ignoring differences due to case, beginning or ending white space
# and different number and types of embedded white space
# args: text1, text2
# return: 1 if same by the above criteria, 0 if different

    my $txt1 = $_[0];
    my $txt2 = $_[1];
    
    $txt1 =~ s/^\s+|\s+$//g;    # trim whitespace 
    $txt1 =~ s/\s+/ /g; # reduce embedded whitespace to single space
    $txt2 =~ s/^\s+|\s+$//g;    # trim whitespace
    $txt2 =~ s/\s+/ /g; # reduce embedded whitespace to single space
    return (lc($txt1) eq lc($txt2));
}

sub isSimilarName($$) {
# compares text ignoring differences due to case, white space
# and non-alphanumeric characters
# useful for comparing surnames with hyphens and apostrophes
# args: text1, text2
# return: 1 if same by the above criteria, 0 if different

    my $txt1 = $_[0];
    my $txt2 = $_[1];
    
    $txt1 =~ s/[^a-zA-Z]+//g;   # remove whitespace and non-word chars
    $txt2 =~ s/[^a-zA-Z]+//g;   # remove whitespace and non-word chars
    return (lc($txt1) eq lc($txt2));
}
sub errPrompt($) {
# prompt to STDERR
# get line from STDIN, do not echo input

    my $response = '';

    print STDERR "$_[0]";
    ReadMode('noecho');
    $response = ReadLine(0);
    ReadMode('restore');
    print STDERR "\n";
    chomp($response);
    return $response;
}

sub prompt($) {
# prompt to STDOUT
# get line from STDIN, do not echo input

    my $response = '';

    print STDOUT "$_[0]";
    ReadMode('noecho');
    $response = ReadLine(0);
    ReadMode('restore');
    print STDOUT "\n";
    chomp($response);
    return $response;
}

sub errPromptEcho($) {
# prompt to STDERR
# get line from STDIN, echo input

    my $response = '';

    print STDERR "$_[0]";
    ReadMode('normal');
    $response = ReadLine(0);
    ReadMode('restore');
    print STDERR "\n";
    chomp($response);
    return $response;
}

sub promptEcho($) {
# prompt to STDOUT
# get line from STDIN, echo input

    my $response = '';

    print STDOUT "$_[0]";
    ReadMode('normal');
    $response = ReadLine(0);
    ReadMode('restore');
    print STDOUT "\n";
    chomp($response);
    return $response;
}

# helper subroutines

1;
