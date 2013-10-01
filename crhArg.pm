#!/usr/bin/perl
# crhArg.pm
#
# program argument subroutines
# v1.02 crh 04-sep-10 -- initial release

# argSetOpts ($) -- set internal args
#	argSetQuiet($) -- set/reset module quiet mode
# argIsQuiet() -- return module quiet mode status
# argGetFlag ($;$$) -- return 1 (true) if switch present, 0 (false) otherwise
# argGetParam ($;$$) -- return parameter if argument present, "" otherwise
# argGetInputFile ($;$$) -- return filename if OK, "" otherwise
# argGetPw ($;$$$) -- return password if argument present, otherwise prompt for and return password

package crhArg;

use Exporter;
@ISA = ("Exporter");

@EXPORT = qw(&argSetOpts &argSetQuiet &argIsQuiet
	&argGetFlag &argGetParam &argGetInputFile &argGetPw);

use warnings;
use strict;
use Getopt::Std;
use Term::ReadKey;
use crhDebug;
use crhFile;

my $argQuiet = 0;	# off by default
my %args = ();

#### main subroutines

sub argSetOpts ($) {
# set the opts hash
# arg: opts string
		getopts("$_[0]", \%args);
}

sub argSetQuiet($) {
# set quiet mode
# arg: true|false
# return quiet mode

	$argQuiet = $_[0];
	return $argQuiet;
}

sub argIsQuiet() {
# returns quiet status

	return $argQuiet;
}

sub argGetFlag ($;$$) {
# return true if flag switch present
# args: switch, set message, unset message
# return: flag status

#	if ($args{"$_[0]"}) {	# switch present
	if (exists($args{"$_[0]"})) {	# switch present
		errMsg($_[1]) if ($_[1] && !argIsQuiet());
		return 1;
	} else {	# switch not present
		errMsg($_[2]) if ($_[2] && !argIsQuiet());
		return 0;
	}
}

sub argGetParam ($;$$) {
# return value of argument parameter
# args: parameter argument, set message, unset message
# return: parameter value

	my $value = "";

#	if ($args{"$_[0]"}) {	# argument present
	if (exists($args{"$_[0]"})) {	# argument present
		$value = $args{"$_[0]"};
		errMsg($_[1] . $value) if ($_[1] && !argIsQuiet());
	} else {	# argument not present
		errMsg($_[2]) if ($_[2] && !argIsQuiet());
	}
	return $value;
}

sub argGetInputFile ($;$$) {
# check and return input file
# args: parameter argument, file OK message, file not OK message
# return filename if checks OK, otherwise return ""

	my $file = "";
	my $fMsg = "";


#	if ($args{"$_[0]"}) {	# argument present
	if (exists($args{"$_[0]"})) {	# argument present
		$file = $args{"$_[0]"};
		errMsg($_[1] . $file) if ($_[1] && !argIsQuiet());
		($file, $fMsg) = checkInfile($file);
		if (!$file) {	# file checks fail
			errMsg("input file error: $fMsg");
		} else {	# file checks OK
			return $args{"$_[0]"};
		}
	} else {
		errMsg($_[2]) if ($_[2] && !argIsQuiet());
	}
	return "";
}

sub argGetPw ($;$$$) {
# return value of password parameter if present
# prompt and return password if not present and password prompt message provided
# args: parameter argument, password ok message, no password message, password prompt message
# return password if obtained, otherwise ""

	my $pw = "";

#	if ($args{"$_[0]"}) {	# argument present
	if (exists($args{"$_[0]"})) {	# argument present
		$pw = $args{"$_[0]"};
		errMsg($_[1]) if ($_[1] && !argIsQuiet());
	} else {	# argument not present
			errMsg($_[2]) if ($_[2] && !argIsQuiet());
		if ($_[3]) {	# prompt for password
			$pw = argErrPrompt($_[3]);
		}
	}
	return $pw;
}

#### helper subroutines -- not exported

sub argErrPrompt($) {	# from crhString
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

1;
