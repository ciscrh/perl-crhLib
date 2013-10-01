#!/usr/bin/perl
# crhDBI.pm
#
# DBI subroutines
# v0.90 crh 08-apr-10 -- under development
# the dbi* subs include basic error reporting to STDERR

# dbiError() -- prints DBI object error message
# dbiNew($$$) -- initiate database handle connection

package crhDBI;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&dbiError &dbiConnect &dbiDisconnect
	&dbiError &setQuietDBI &isQuietDBI &setTraceDBI &isTraceDBI); 

use warnings;
use strict;
use DBI;;

INIT {	#### persistent private variables for subroutines :-)
	my $quietDBI = 0;	# off by default (ie, issues warnings)
	my $traceDBI = 0;	# off by default
	
	sub setQuietDBI ($) {
	# set quiet status, 1 = on, 0 = off
		
		$quietDBI = $_[0];
		return $quietDBI;
	}

	sub isQuietDBI {
	# return quiet status
	
		return $quietDBI;
	}

	sub setTraceDBI ($) {
	# set trace level, 0 = off, 1, 2 or 3 with increasing debug info
		
		$traceDBI = $_[0];
		DBI->trace($traceDBI);
		return $traceDBI;
	}

	sub isTraceDBI {
	# return trace level
	
		return $traceDBI;
	}

	sub dbiError ($) {
	# print out error message to STDERR
	# usage: dbiError()
	# return 0 if not error, 1 otherwise
	# used by some  dbi* subs
	
		my $dbh = $_[0];
		my $errCode = DBI->err();
		my $errState;
	
		if ($errCode eq "") {	 # not really an error :-)
			return 0;
		} elsif ($quietDBI) {	# quiet mode -- suppress error reporting
			return 1;
		}
		pse("native error code: " . $errCode);
		pse("dbi error        : " . DBI->errstr());
#		$errState = DBI->state();
#		if ($errState ne 'S1000') {	# useful value provided
#			pse("sqlstate error   : " . $errState);
#		}
		return 1;
	}
}

sub dbiConnect ($$$) {
# initialise DBI database handle object
# usage: dbiConnect($dsn, $username, $password)
# returns true if successful, false otherwise

	my $dbh;
	my $dsn = $_[0];
	my $user = $_[1];
	my $pw = $_[2];
	
	$dbh = DBI->connect($dsn, $user, $pw, {PrintError=>0, RaiseError=>0, AutoCommit=>1});
	if (!$dbh) {
		dbiError($dbh);
	}
	return $dbh;
}

sub dbiDisconnect ($) {
# disconnect from database associated with supplied database handle object
# usage: dbiDisconnect($dbh)
# returns the handle or unset if the connection fails

	my $dbh = $_[0];
	
	if ($dbh->disconnect) {	# ok
		return 1;
	} else {	# problem encountered
		dbiError($dbh);
		return 0;
	}
}

## helper subroutines (not exported)

sub pse  ($) {
# print string to STDERR, appending newline char

	print STDERR $_[0] . "\n";
}

sub pso  ($) {
# print string to STDOUT, appending newline char

	print STDOUT $_[0] . "\n";
}

1;