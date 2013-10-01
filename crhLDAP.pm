#!/usr/bin/perl
# crhLDAP.pm
#
# ldap subroutines
# v1.07 crh 06-feb-09 -- initial release, ldapUserTidy.pl
# v1.11 crh 12-mar-10 -- quiet mode added
# v1.20 crh 01-may-10 -- paged ldap search supported (for AD)
# v1.31 crh 18-oct-11 -- error status reporting added
# v1.41 crh 16-sep-12 -- constants added
# the ldap* subs include basic error reporting to STDERR

# ldapSetQuiet($) -- set and return quiet mode status
# ldapIsQuiet() -- return quiet mode status
# ldapIsError() -- return current error status
# ldapError($$) -- prints ldap object error message
# ldapsNew($$) -- initiate secure ldap connection object
# ldapNew($$) -- initiate insecure ldap connection object
# ldapBind($$$) -- performs ldap bind
# ldapSearch($$$$;$$) -- performs ldap search
# ldapSearchPaged($$$$;$$$) -- performs paged ldap search
# ldapModify($$$$:$) -- performs simple ldap modify
# ldapModDN($$$$:$) -- performs simple ldap moddn
# ldapAddEntry($$) -- performs simple ldap add (using Net::LDAP::Entry)
# ldapAdd($$@) -- performs simple ldap add
# ldapDelete($$) -- performs ldap delete
# entryUpdate($$) -- performs ldap update using entry object
# hashInterect -- returns the intersection of 2 hashes
# hashUnion -- returns the union of 2 hashes
# hashSmplDiff -- returns the simple difference of two hashes
# hashPrintKey -- prints out a hash
# getRDN($) -- returns rdn extracted from dn

package crhLDAP;
require Exporter;
our @ISA = ("Exporter");
our @EXPORT = qw(&ldapError &ldapsNew &ldapNew &ldapBind &ldapSearch &ldapSearchPaged 
	&ldapModify &ldapModDN &ldapAddEntry &ldapAdd &ldapDelete &entryUpdate 
	&hashIntersect &hashUnion &hashSmplDiff &hashPrintKey &getRDN &ldapSetQuiet 
	&ldapIsQuiet &ldapIsError &ldapIsClass);
our @EXPORT_TAGS = ((consts => [qw(&LDAP_HOST_DEFAULT &LDAP_BASE_DEFAULT 
	&LDAP_PORT_SECURE &LDAP_PORT &LDAP_TRUE &LDAP_FALSE &LDAP_SCOPE_ONE 
	&LDAP_SCOPE_BASE &LDAP_SCOPE_SUB)]));
Exporter::export_tags('consts');

use warnings;
use strict;
use Net::LDAP;
use IO::Socket::SSL;
use Net::LDAPS;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_CONTROL_PAGED);
use crhDebug;

## some useful constants to give consistent look and feel to ldap scripts

# these should be customised to suit your ldap environment
use constant LDAP_HOST_DEFAULT => '127.0.0.1';	# works for me :-)
use constant LDAP_BASE_DEFAULT => 'o=hailey';	# works for me :-)
# these probably should not be changed under most circumstances
use constant LDAP_PORT_SECURE => 636;
use constant LDAP_PORT => 389;
# these should not be changed under any circumstances
use constant LDAP_TRUE => 1;
use constant LDAP_FALSE => 0;
use constant LDAP_SCOPE_ONE => 'one';
use constant LDAP_SCOPE_BASE => 'base';
use constant LDAP_SCOPE_SUB => 'sub';

INIT {	#### persistent private variables for subroutines :-)
	our $crhLDAPquiet = 0;	# package quiet mode: off by default
	our $crhLDAPerror = 0;	# false by default
	
	sub ldapSetQuiet ($) {
	# set and return quiet status
		
		$crhLDAPquiet = $_[0];
		return $crhLDAPquiet;
	}

	sub ldapIsQuiet {
	# return quiet status
	
		return $crhLDAPquiet;
	}
	
	sub setErrorLDAP($) {
	## helper routine (not exported)
	# determine, set and return error status
	# usage: setErrorLDAP($message_object)
	# returns error status for given message
		
		my $message = $_[0];
		
		$crhLDAPerror = $message->is_error();
		return $crhLDAPerror;
	}

	sub resetErrorLDAP() {
	## helper routine (not exported)
	# reset (clear error status)
	# called to ensure error status cleared to default value
	# usage: resetErrorLDAP()
		
		$crhLDAPerror = LDAP_FALSE;
	}

	sub ldapIsError {
	# return error status
	
		return $crhLDAPerror;
	}

	sub ldapError ($$) {
	# print out error message to STDERR
	# usage: ldapError($context_string $message_object)
	# used by most following ldap* subs
	
		my ($from, $message) = @_;
		my $errTxt = $message->error_text;
	
		if (!setErrorLDAP($message)) {	 # not really an error :-)
			return;
		} elsif ($crhLDAPquiet) {	# quiet mode -- suppress error reporting
			return;
		}
		chomp $errTxt;
		pse("ldap error: " . $from);
		pse("  return code: " . $message->code);
		pse("  message: " . $message->error_name . "..." . $errTxt);
		if ($message->dn) {	# don't print if empty
			pse("  dn: " . $message->dn);
		}
		if ($message->server_error) {	# don't print if empty
			pse("  server error: " . $message->server_error);
		}
	}
	
	sub ldapIsClass ($$$) {
	# perform ldap search to determine if object belongs to specified class, assumes ldap object already bound
	# usage: ldapIsClass ($ldap,$dn,$class)
	# return 0 if not in class or error or not found, 1 if in class
		
		my $message;
		my $filter = $_[1];
		my $base = $_[1];
		my $class = $_[2];
		my @searchArgs;
		
		
		$filter =~ s/\\,/zZzZzZ/;	# allow for \, (escaped commas)
		$filter =~ s/^([^,]+)(.*)/$1/;	# match first element of csv
		$filter =~ s/zZzZzZ/\,/;	# reinstate escaped commas
		$filter = "(&($filter)(objectclass=$class))";
		$base =~ s/\\,/zZzZzZ/;	# allow for \, (escaped commas)
		$base =~ s/^[^,]+,//;	# remove first element of csv
		$base =~ s/zZzZzZ/\,/;	# reinstate escaped commas
		
	  @searchArgs = (base =>$base,scope =>'one',filter =>$filter,attrs => ['1.1'],sizelimit=>2);
		$message = $_[0]->search(@searchArgs);
	  
		if ($message->code) {	# error returned
			ldapError("ldapIsClass()", $message);
			return 0;
		} elsif ($message->count != 1) {	# zero or more than one hit returned
			return 0;
		} else {
			return 1;
		}
	}
}	# end of INIT block

sub ldapsNew ($$) {
# initialise ldaps object

	my $ldaps;
	my $host = $_[0];
	my $port = $_[1];
	my $verify = 'none';
	my $caPath = '';
	
	$ldaps = Net::LDAPS->new($host, port => $port, verify => $verify, capath => $caPath) or die "$@";
	return $ldaps;
}

sub ldapNew ($$) {
# initialise ldaps object

	my $ldap;
	my $host = $_[0];
	my $port = $_[1];
	
	$ldap = Net::LDAP->new($host, port => $port) or die "$@";
	return $ldap;
}

sub ldapBind ($$$) {
# perform ldap bind, assumes ldap object already initialised
# usage: ldapBind( $ldap, $userDN, $password)

	my $message;
	my $ldap = $_[0];
	my $userDN = $_[1];
	my $password = $_[2];

	resetErrorLDAP();
	$message = $ldap->bind($userDN, password=>$password) or die "$@";    # an authenticated bind
	if ($message->code) {
		ldapError("ldapBind()", $message);
	}
	return $message;
}

sub ldapSearch ($$$$;$$) {
# perform ldap search, assumes ldap object already bound
# usage: ldapSearch ($ldap,$base,$scope,$filter[,$attribs[,$limit]])
	
	my $message;
	my $attribs = "*";
	my $limit = 0;
	my @searchArgs;
	
	resetErrorLDAP();
	if (scalar(@_) > 4) {	# attributes given
		$attribs = $_[4];
	}
	if (scalar(@_) > 5) {	# limit given
		$limit = $_[5];
	}

	@searchArgs = (base => $_[1],scope => $_[2],filter => $_[3],attrs=>$attribs,sizelimit=>$limit);
	$message = $_[0]->search(@searchArgs);
  
	if ($message->code) {
		ldapError("ldapSearch()", $message);
	}
	return $message;
}
sub ldapSearchPaged ($$$$;$$$) {
# perform paged ldap search, assumes ldap object already bound
# usage: ldapSearchPaged ($ldap,$base,$scope,$filter[$pageSize[,$attribs[,$limit]]])
# returns array of all ldap entries returned by search
# doesn't optimise memory usage, just works around (AD) ldap restrictions
# note that page size of 0 used to flag message variable returned (better memory use?)
	
	my $message;
	my $attribs = "*";
	my $limit = 0;
	my @searchArgs;
	my $pageSize = 200;	# playing safe here, probably capped by ldap server limit anyway
	my $page;
	my $pageCount = 1;
	my $entry;
	my @entries;
	my $cookie;
	my $mode = 0;	# return ldap message variable for external processing if set true
	
	if (scalar(@_) > 4) {	# page size given
		if ($pageSize) {	# set page size if non-zero
			$pageSize = $_[4];
		} else {	# flag return message variable, not entries array
			$mode = 1;
		}
	}
	if (scalar(@_) > 5) {	# attributes given
		$attribs = $_[5];
	}
	if (scalar(@_) > 6) {	# limit given
		$limit = $_[6];
	}

	$page = Net::LDAP::Control::Paged->new(size=>$pageSize);
  @searchArgs = (base => $_[1],scope => $_[2],filter => $_[3],attrs=>$attribs,sizelimit=>$limit, control=>[$page]);
  
	while (1) {
		dbgMsg("page>>>" . $pageCount++);
		resetErrorLDAP();
		$message = $_[0]->search(@searchArgs);
		if ($message->code) {
			ldapError("ldapSearchPaged()", $message);
		}
		$message->code and last;	# be extra safe, exit on error
		if ($mode) {	# external processing flagged
			return $message;
		}
		# generate and return entries array
		foreach $entry ($message->entries) {
			push (@entries, $entry);
		}	
		# get cookie from paged control
		my ($response) = $message->control(LDAP_CONTROL_PAGED) or last;
		$cookie = $response->cookie or last;
		$page->cookie($cookie)	# set cookie in paged control
	}
	
	if ($cookie) {	# abnormal exit, tidy up server end and return undef
		$page->cookie($cookie);
		$page->size(0);
		$message = $_[0]->search(@searchArgs);
		return;
	}
	return @entries;
}

sub ldapModify ($$$$;$) {
# perform simple ldap modify, assumes ldap object already bound
# usage: ldapModify ($ldap, $dn, $action, $attrib [$values])
# where action: add|delete|replace (add must act on specific values)
	
	my $message;

#	dbgMsg("ldapModify($_[1], $_[2], $_[3], $_[4]");

	resetErrorLDAP();
  if (scalar(@_) == 5) {	# action specific values
		$message = $_[0]->modify($_[1], $_[2] => {$_[3]=>$_[4]});
	} else {	# action all values
		if ($_[2] eq "replace") {	# delete all values only
			$message = $_[0]->modify($_[1], $_[2] => {$_[3] => []});
		} else {
			$message = $_[0]->modify($_[1], $_[2] => [$_[3]]);
		}
	}
  
	if ($message->code) {
		ldapError("ldapModify()", $message);
	}
	return $message;
}

sub ldapModDN ($$$$;$) {
# perform simple ldap rename, assumes ldap object already bound
# usage: ldapModDN ($ldap, $dn, $newrdn, $newsuperior [$deleteoldrdn])
# provide empty string for $newsuperior if not required
	
	my $message;
	
	resetErrorLDAP();
  if ((scalar(@_) == 5) && $_[4]) {	# delete oldrdn
  	if ($_[2] && $_[3]) {	# both newrdn and newsuperior
			$message = $_[0]->moddn($_[1], newrdn => $_[2], newsuperior => $_[3], deleteoldrdn => 1);
		} elsif ($_[2]) {	# newrdn
			$message = $_[0]->moddn($_[1], newrdn => $_[2], deleteoldrdn => 1);
		} else {	# no newrdn -- error
			pse("ldapModdn error: newrdn not specified");
		}
	} else {	# leave oldrdn as value in naming attribute
  	if ($_[2] && $_[3]) {	# both newrdn and newsuperior
			$message = $_[0]->moddn($_[1], newrdn => $_[2], newsuperior => $_[3]);
		} elsif ($_[2]) {	# newrdn
			$message = $_[0]->moddn($_[1], newrdn => $_[2]);
		} else {	# no newrdn -- error
			pse("ldapModdn error: newrdn not specified");
		}
	}
  
	if ($message->code) {
		ldapError("ldapModify()", $message);
	}
	return $message;
}

sub ldapAddEntry ($$) {
# perform simple ldap add using entry object, assumes ldap object already bound
# usage: ldapModify ($ldap, $entry)
	
	my $message;
	
	resetErrorLDAP();
	$message = $_[0]->add($_[1]);
  
	if ($message->code) {
		ldapError("ldapAddEntry()", $message);
	}
	return $message
}

sub ldapAdd ($$@) {
# perform simple ldap add using array, assumes ldap object already bound
# usage: ldapModify ($ldap, $DN, @attribs)
	
	my $message;
	
	resetErrorLDAP();
	$message = $_[0]->add($_[1], attrs => $_[2]);
  
	if ($message->code) {
		ldapError("ldapAdd()", $message);
	}
	return $message
}

sub ldapDelete ($$) {
# perform ldap delete, assumes ldap object already bound
# usage: ldapDelete ($ldap, $dn)
	
	my $message;
	
	resetErrorLDAP();
	$message = $_[0]->delete($_[1]);
  
	if ($message->code) {
		ldapError("ldapDelete()", $message);
	}
	return $message;
}

sub entryUpdate ($$) {
# perform entry object update, assumes ldap object already bound
# usage: entryUpdate ($ldap, $entry)
	
	my $message;
	
	resetErrorLDAP();
	$message = $_[1]->update($_[0]);
  
	if ($message->code) {
		ldapError("entryUpdate()", $message);
	}
	return $message;
}

sub hashIntersect  {
# intersection of 2 hashes
# usage: hashIntersect (\%a, \%b)

	my %inter = ();
  my $aRef = $_[0];
  my $bRef = $_[1];
	my %a = %$aRef;
	my %b = %$bRef;
	my $k;
	my $v;

	while (($k,$v) = each(%a)) {
		$inter{$k} = $v if exists $b{$k};
	}
	return %inter;
}

sub hashUnion {
# merge 2 hashes
# returns merged hash
# usage: hashUnion (\%a, \%b)

	my %union = ();
  my $aRef = $_[0];
  my $bRef = $_[1];
	my %a = %$aRef;
	my %b = %$bRef;
	my $k;
	my $v;
	
	while (($k,$v) = each(%a)) {
		$union{$k} = $v;
	}
	while (($k,$v) = each(%b)) {
		$union{$k} = $v;
	}
	
	return %union;
}

sub hashSmplDiff  {
# imple difference of 2 hashes
# usage: hashIntersect (\%a, \%b)
# returns hash of those values in %a but not %b

	my %diff = ();
  my $aRef = $_[0];
  my $bRef = $_[1];
	my %a = %$aRef;
	my %b = %$bRef;
	my $k;
	my $v;

	while (($k,$v) = each(%a)) {
		next if exists $b{$k};
		$diff{$k} = $v;;
	}
	return %diff;
}

sub hashPrintKey {
# print out a hash
# usage: hashPrintKey (\%a)

	my %hash = ();	
	my $aRef = $_[0];
	my %a = %$aRef;
	my $k;
	my $v;

	while (($k, $v) = each %a) {
		pso("        $k");
	}
}

sub getRDN ($) {
# returns rdn from dn
# args: dn

	my $rdn = $_[0];

	$rdn =~ s/,.+//;	
	return $rdn;
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
