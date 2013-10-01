#!/usr/bin/perl
# crhEntry.pm
#
# entry file subroutines to give consistent processing of entry file contents
# entry files are created and used by ldap scripts
# allows whitespace in lines
# avoids regex variables to minimise execution times
# v0.91 crh 25-sep-10 -- under development

# entryIsBlank ($) -- return true if blank or comment line
# entryIsValidLine ($) -- return true if potentially valid line
# entryIsDN ($) -- return true if dn line
# entryGetDN ($) -- return dn
# entryIsMode ($) -- return true if changemode line
# entryGetMode ($) -- return changemode
# entryIsMoveRename ($) -- return true if move/rename line
# entryIsMove ($) -- return true if move line
# entryGetMove ($;$) -- return location
# entryIsRename ($) -- return true if rename line
# entryGetRename ($) -- return new name
# entryParseAttrib ($) -- return attribute name and value pair array
# entrySetAction ($$$;$) -- populate action array

package crhEntry;

use Exporter;
@ISA = ("Exporter");

@EXPORT = qw(&entryIsBlank &entryIsValidLine &entryIsDN &entryGetDN	&entryIsMode
					&entryGetMode &entryIsMoveRename &entryIsMove &entryGetMove
					&entryIsRename &entryGetRename &entryParseAttrib &entrySetAction);

use warnings;
use strict;
use crhDebug;

#### main subroutines

sub entryIsBlank ($) {
# check if blank or line starts with # (comment)
# use to identify and ignore such lines
# arg: text line
# return 1 (true) if blank or comment line, otherwise return 0

	my $line = $_[0];

	return (($line =~ m/^#/)||(!length($line)));
}

sub entryIsValidLine ($) {
# check if at least one colon character present in valid location
# all entry lines (except blanks and comments) should have at least 1 colon
# this subroutine is not called by other subroutines in this module
# and should only be called after blank and comment lines have been discarded
# arg: text line
# return 1 (true) if potentially valid line, otherwise return 0

	my $line = $_[0];

	if ($line =~ m/^\s*[^ \t:]+\s*:/) {
		return 1;
	} else {
		statusErrMsg("error", "entryIsValidLine", "invalid format, line skipped");
		dbgMsg("line skipped>>$_[0]");
		return 0;
	}
}

sub entryIsDN($) {
# check if dn line
# arg: text line
# return 1 (true) if DN line, otherwise return 0

	my $line = $_[0];

	return ($line =~ m/^\s*dn\s*:\s*.+/i);
}

sub entryGetDN($) {
# identify and return distinguished name (dn: _dn)
# arg: text line
# return DN if possible, otherwise return ""

	my $line = $_[0];

	if (entryIsDN($line)) {
		$line =~ s/^\s*dn\s*:\s*//i; # remove prepended dn:
		return $line;
	} else {
		return "";
	}
}

sub entryIsMode($) {
# check if changemode line
# arg: text line
# return 1 (true) if changemode line, otherwise return 0

	my $line = $_[0];

	return ($line =~ m/^\s*changemode\s*::\s*.+/i);
}

sub entryGetMode($) {
# identify and return change mode (changemode:: _mode)
# arg: text line
# return changemode if possible, otherwise return ""

	my $line = $_[0];

	if (entryIsMode($line)) {
		$line =~ s/^\s*changemode\s*::\s*//i; # remove prepended changemode::
		if ($line =~ m/add|delete|replace/i) {
			return $line;
		} else {
			statusErrMsg("error", "entryGetMode", "invalid changemode skipped");
			dbgMsg("line skipped>>$_[0]");
		}
	}
	return "";
}

sub entryIsMoveRename($) {
# check if move or rename changemode line
# arg: text line
# return 1 (true) if move/rename line, otherwise return 0

	return (entryIsMove($_[0]) || entryIsRename($_[0]));
}

sub entryIsMove($) {
# check if move line (note does not always need a value)
# arg: text line
# return 1 (true) if move line, otherwise return 0

	my $line = $_[0];

	return ($line =~ m/^\s*move\s*::\s*/i);
}

sub entryGetMove($;$) {
# identify and return move destination (move:: [_destination])
# arg: text line[, _defaultDestination]
# return destination if possible, otherwise return ""
# note that "" is  a valid return value for move line as well
# as the value returned if not a move line, be careful!

	my $line = $_[0];

	if (entryIsMove($line)) {
		$line =~ s/^\s*move\s*::\s*//i; # remove prepended move::
		return $line if ($line);	# value to return
		if ((scalar(@_) == 2)) {	# default value provided
			return $_[1];
		} else {
			return "";
		}
	} else {
		statusErrMsg("error", "entryGetMove", "invalid move line");
	}
	dbgMsg("line>>$_[0]");
	return "";
}

sub entryIsRename($) {
# check if rename changemode line
# arg: text line
# return 1 (true) if rename line, otherwise return 0

	my $line = $_[0];

	return (($line =~ m/^\s*rename\s*::\s*.+/i));
}

sub entryGetRename($) {
# identify and return new name value (rename:: _newName)
# arg: text line (eg, rename: cn=ciscrh1)
# return new name if possible, otherwise return ""

	my $line = $_[0];

	if (entryIsRename($line)) {
		$line =~ s/^\s*rename\s*::\s*//i; # remove prepended rename:
		return $line;
	}
	return "";
}

sub entryParseAttrib($;$) {
# isolate and return attribute name and value (_attribName: _attribValue)
# arg: text line [, lcMode]
# return array of name and value pair (_attribName, _attribValue)
# this should only be called once all other line types have been processed
# entryHasColon() can be called first to carry out simple syntax check

	my $line = $_[0];
	my $lcMode = 1;	# default: true

	if (scalar(@_) == 2) {
		$lcMode = $_[1];
	}
	$line =~ /^\s*([^:]+):\s*(.*)/;
	if ($lcMode) {	# return lowercased name value
		return (lc("$1"), "$2");
	} else {
		return ("$1", "$2");
	}
}

sub entrySetAction ($$$;$) {	# populate action array
# arg: text line, mode, actionArrayRef [, lcMode]
# set action array (mode, attribute [,value])
## return 1 (true), if set, otherwise return 0 (false)

	my $line = $_[0];
	my $mode = $_[1];
	my $aRef = $_[2];
	my $lcMode = 1;	# default: true
	if (scalar(@_) == 4) {
		$lcMode = $_[3];
	}
	my @actions = @$aRef;
	my $attrib;
	my $value;
	my @action = ();

	if (!$mode) {
		statusErrMsg("warn", "entrySetAction", "set action skipped (no mode set)");
		dbgMsg("line skipped>>$line");
		return 0;
	}
	($attrib, $value) = entryParseAttrib($line, $lcMode);
	if (($mode =~ /add/) && (!$value)) {
		statusErrMsg("warn", "entrySetAction", "add $attrib skipped (no value given)");
		dbgMsg("line skipped>>$line");
		return 0;
	}
#	if ($value) {
#		@action = ($mode, $attrib, $value);
#	} else {
#		@action = ($mode, $attrib);
#	}
	if ($value) {
		@$aRef = ($mode, $attrib, $value);
	} else {
		@$aRef = ($mode, $attrib);
	}
	dbgMsg("entrySetAction()>>$mode|$attrib|$value");
	return 1;
}

#### helper subroutines -- not exported

1;
