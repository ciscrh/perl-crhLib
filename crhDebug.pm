#!/usr/bin/perl
# crhDebug.pm
#
# debug , message and logging subroutines
# v1.01 crh 12-jan-09 -- initial release, extracted from crhPop3Mail.pm
# v1.14 crh 16-jan-09 -- extended with message and logging subs
# v1.20 crh 22-jun-13 -- incorporate output suppression or printing just newline

# setDbg($) -- set debug status
# isDbg() -- returns dbg status
# setDbgProgName($) -- sets the program name used in various subs [optional]

# dbgMsg($) -- prints debug labelled message to STDERR if debug active
# dbgTMsg($) -- prints debug labelled timestamp prepended message to STDERR if debug active

# statusDbgMsg($$$) -- prints formatted message to STDERR if debug active
# statusDbgTMsg($$$) -- prints formatted message, including timestamp, to STDERR if debug active

# setLogDyName($;$) -- set log file name with YYYMMDD prefix, incorporating directory if supplied
# setLogMnName($;$) -- set log file name with YYYMM prefix, incorporating directory if supplied
# setLogName($;$) -- set log file name, incorporating directory if supplied

# openLog() -- opens log file handle
# closeLog() -- closes log file handle

# logMsg($) -- prints message to STDERR and also writes datestamp prefixed message to the log file if open

# the following include backwards-compatible suppress & print just newline capability
# msg(;$$) -- prints message to STDOUT
# errMsg(;$$) -- prints message to STDERR
# tMsg(;$$) -- prints timestamp prepended message to STDOUT
# errTMsg(;$$) -- prints timestamp prepended message to STDERR
# dMsg(;$$) -- prints datestamp prepended message to STDOUT
# errDMsg(;$$) -- prints datestamp prepended message to STDERR
# the following include backwards-compatible suppresscapability
# statusMsg($$$;$) -- prints formatted message to STDOUT
# statusTMsg($$$;$) -- prints formatted message, including timestamp, to STDOUT
# statusErrMsg($$$;$) -- prints formatted message to STDERR
# statusErrTMsg($$$;$) -- prints formatted message, including timestamp, to STDERR

package crhDebug;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&setDbg &isDbg &setDbgProgName &dbgMsg &dbgTMsg &statusDbgMsg
	&statusDbgTMsg &statusMsg &statusTMsg &statusErrMsg &statusErrTMsg
	&setLogDyName &setLogMnName &setLogName &openLog &closeLog &logMsg &msg
	&errMsg &tMsg &errTMsg &dMsg &errDMsg);

use warnings;
use strict;
use File::Basename;
use POSIX;

INIT {	#### persistent private variables for subroutines :-)
	my $debug = 0;	# off by default
	# set default value for $dbgProgName -- use setProgName() to be safe
	my ($dbgProgName, $dbgDir, $dbgExt) = fileparse($0, ".pl");
	# set default value for log file name -- use setLogName() to be safe
	my $logFile = strftime("%Y%m", localtime) . "$dbgProgName.log";
	my $logF;	# file handle for log file

	sub setDbg ($) {
	# set debug status

		$debug = $_[0];
		return $debug;
	}

	sub isDbg {
	# return debug status

		return $debug;
	}

	sub setDbgProgName (;$) {
	# set program name
	# use to set to a sensible value before calling following subroutines
	# resets deafult value if no argument supplied
	# returns the set value after calling this subroutine
	# arg: required program name value

		if ($_[0]) {
			$dbgProgName = $_[0];
		} else {
			($dbgProgName, $dbgDir, $dbgExt) = fileparse($0, ".pl");
		}
		return $dbgProgName;
	}

	sub dbgMsg ($) {
	# print simple debug message to STDERR, possibly

		if ($debug) {
			print STDERR "DEBUG-$_[0]\n";
		}
		return $debug;
	}

	sub dbgTMsg ($) {
	# print debug message with prepended timestamp to STDERR, possibly

		if ($debug) {
			print STDERR "DEBUG -- [" . dbgTimestamp() . "] $_[0]\n";
		}
		return $debug;
	}

	sub statusDbgMsg ($$$) {
	# print message in standard format to STDERR, possibly
	# args: status, function, message

		if ($debug) {
			print STDERR "$_[0]-$dbgProgName-$_[1] -- $_[2]\n";
		}
		return $debug;
	}

	sub statusDbgTMsg ($$$) {
	# print message in standard format prepended with timestamp to STDERR, possibly
	# args: status, function, message

		if ($debug) {
			print STDERR "$_[0]-$dbgProgName-$_[1] -- [" . dbgTimestamp() . "] $_[2]\n";
		}
		return $debug;
	}

	sub statusMsg ($$$;$) {
	# print message in standard format to STDOUT
	# args: status, function, message

		return if $_[3];
		print STDOUT "$_[0]-$dbgProgName-$_[1] -- $_[2]\n";
	}

	sub statusTMsg ($$$;$) {
	# print message in standard format, prepended with timestamp to STDOUT
	# args: status, function, message [, suppress]

		return if $_[3];
		print STDOUT "$_[0]-$dbgProgName-$_[1] -- [" . dbgTimestamp() . "] $_[2]\n";
	}

	sub statusErrMsg ($$$;$) {
	# print message in standard format to STDERR
	# args: status, function, message [, suppress]

		return if $_[3];
		print STDERR "$_[0]-$dbgProgName-$_[1] -- $_[2]\n";
	}

	sub statusErrTMsg ($$$;$) {
	# print message in standard format, prepended with timestamp to STDERR
	# args: status, function, message [, suppress]

		return if $_[3];
		print STDERR "$_[0]-$dbgProgName-$_[1] -- [" . dbgTimestamp() . "] $_[2]\n";
	}

	sub setLogDyName ($;$) {
	# set log file name withYYMMDD prefix, using optional directory if supplied
	# args: file name stem [, directory]

		if ($_[1]) {
			$logFile = $_[1] . strftime("%Y%m%d", localtime) . $_[0] . ".log";
		} else {
			$logFile = strftime("%Y%m%d", localtime) . $_[0] . ".log";
		}
		return $logFile;
	}

	sub setLogMnName ($;$) {
	# set log file name with YYYYMM prefix, using optional directory if supplied
	# args: file name stem [, directory]

		if ($_[1]) {
			$logFile = $_[1] . strftime("%Y%m", localtime) . $_[0] . ".log";
		} else {
			$logFile = strftime("%Y%m", localtime) . $_[0] . ".log";
		}
		return $logFile;
	}

	sub setLogName ($;$) {
	# set log file name, using optional directory if supplied
	# args: file name stem [, directory]

		if ($_[1]) {
			$logFile = $_[1] . $_[0] . ".log";
		} else {
			$logFile = $_[0] . ".log";
		}
		return $logFile;
	}

	sub openLog {
	# open log file

		open($logF, ">>", $logFile) or die "abort program... problem accessing log file $logFile\n";
	}

	sub closeLog {
	# close log file

		close($logF);
		undef $logF;
	}

	sub logMsg ($) {
	# print argument message to STDERR
	# also print datestamp prefixed message to log file if currently open

		print STDERR "$_[0]\n";
		if ($logF) {
			print $logF dbgDatestamp() . ": $_[0]\n" or die "abort program... problem writing to log file $logFile\n";
		}
	}
}

sub msg (;$$) {
# print argument message to STDOUT
# args: [text [suppress]]

	return if $_[1];
	if ($_[0]) {	# text & newline
		print STDOUT "$_[0]\n";
	} else {	# newline
		print STDOUT "\n";
	}
}

sub errMsg (;$$) {
# print argument message to STDERR
# args: [text [suppress]]

	return if $_[1];
	if ($_[0]) {	# text & newline
		print STDERR "$_[0]\n";
	} else {	# newline
		print STDERR "\n";
	}
}

sub tMsg (;$$) {
# print timestamp prepended argument message to STDOUT
# args: [text [suppress]]

	return if $_[1];
	if ($_[0]) {
		print STDOUT "[" . dbgTimestamp() . "] $_[0]\n";
	} else {
		print STDOUT "[" . dbgTimestamp() . "]\n";
	}
}

sub errTMsg (;$$) {
# print timestamp prepended argument message to STDERR
# args: [text [suppress]]

	return if $_[1];
	if ($_[0]) {
		print STDERR "[" . dbgTimestamp() . "] $_[0]\n";
	} else {
		print STDERR "[" . dbgTimestamp() . "]\n";
	}
}

sub dMsg (;$$) {
# print datestamp prepended argument message to STDOUT
# args: [text [suppress]]

	return if $_[1];
	if ($_[0]) {
		print STDOUT "[" . dbgDatestamp() . "] $_[0]\n";
	} else {
		print STDOUT "[" . dbgDatestamp() . "]\n";
	}
}

sub errDMsg (;$$) {
# print datestamp prepended argument message to STDERR
# args: [text [suppress]]

	return if $_[1];
	if ($_[0]) {
		print STDERR "[" . dbgDatestamp() . "] $_[0]\n";
	} else {
		print STDERR "[" . dbgDatestamp() . "]\n";
	}
}

# helper subroutines (not exported)

sub dbgTimestamp {
# return current timestamp
# append string if supplied as parameter

	if (scalar(@_) > 0) {
		return strftime("%H:%M:%S", localtime) . ": " . $_[0];
	} else {
		return strftime("%H:%M:%S", localtime);
	}
}

sub dbgDatestamp {
# return current date and timestamp
# append string if supplied as parameter

	if (scalar(@_) > 0) {
		return strftime("%Y%m%d-%H%M%S", localtime) . ": " . $_[0];
	} else {
		return strftime("%Y%m%d-%H%M%S", localtime);
	}
}

1;
