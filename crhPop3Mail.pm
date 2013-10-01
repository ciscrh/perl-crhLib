#!/usr/bin/perl
# crhPop3Mail.pm
#
# mail subroutines
# v1.02 crh 30-oct-08 -- initial release
# v1.10 crh 12-jan-09 -- debug subroutines removed

package crhPop3Mail;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&arrayStr &ref2Array &datestamp &timestamp &rTrim &trim 
	&sqlStatement &validDate &validSize &parseComm &parseHeader &pop3Conn 
	&mailDBHandle &maildropStats &maildropArray &maildropRst &byteStuff 
	&msgStatus);

use warnings;
#use POSIX;
use DBI;
use Mail::POP3Client;
use Digest::MD5;

#### general subroutines

sub arrayStr {
# return string consisting of csv of arguments

	my $string = "";
	my $size = scalar(@_);
	my $index = 0;
	
	if ($size == 1) {	#trivial case
		$string .= $_[0];
	} else {
		for ($index = 0; $index < $size - 1; $index++) {
			$string .= $_[$index] . ", ";
		}
		$string .= $_[$size - 1];
	}
	return $string;
}

sub ref2Array ($) {
# return array from array reference
# arg: array ref
# more efficient version required for large arrays?

	my $item;
	my $aRef = $_[0];
	my @array = ();
	
	foreach $item (@$aRef) {
		push(@array, $item);
	}
	return @array;
}

sub datestamp {
# return current date as timestamp

	return strftime("%Y%m%d-%H%M%S", localtime);
}

sub timestamp {
# return current timestamp
# append string if supplied as parameter

	if (scalar(@_) > 0) {
		return strftime("%H:%M:%S", localtime) . " " . $_[0];
	} else {
		return strftime("%H:%M:%S", localtime);
	}
}

sub rTrim ($) {
# remove white space (incl newline chars) from end of string

	if ($_[0] eq "")	{	# avoid using empty string in substitution
		return "";
	}
	my $trim = $_[0];
	$trim =~ s/\s*$//g;	# remove whitespace from end of string
	return $trim;
}

sub trim ($) {
# remove white space (incl newline chars) from ends of string

	if ($_[0] eq "")	{	# avoid using empty string in substitution
		return "";
	}
	my $trim = $_[0];
	$trim =~ s/\s*$//g;	# remove whitespace from  end of string
	$trim =~ s/^\s+//;	# remove whitespace from beginning of string
	return $trim;
}

sub sqlStatement ($$) {
# param dbHandle statement
# return sql statement handle

	my $dbh = $_[0];
	my $sqlSt = $_[1];
	my $sqlH =$dbh->prepare($sqlSt);
	
	return $sqlH;
}

sub validDate ($$$) {
# return 1 if given date in range
# args: date, before, after
# dates on YYYYMMDD format

	my $ok = 1;
	
	if (!trim($_[0]) && (($_[1]) || ($_[2]))) {	# message has no date value -- fail
		return 0;
	}
	
	if ($_[1]) {	# before string has value
		$ok = ($_[0] lt $_[1]);
	}
	if ($ok && $_[2]) {	# after string has value
		$ok = ($_[0] gt $_[2]);
	}
	if ($ok) {
		return 1;
	} else {
		return 0;
	}
}

sub validSize ($$$) {
# return 1 if given size in range
# args: size, min, max

	my $ok = 1;
	
	if ($_[1]) {	# min size has value
		$ok = ($_[0] > $_[1]);
	}
	if ($ok && $_[2]) {	# max size has value
		$ok = ($_[0] < $_[2]);
	}
	if ($ok) {
		return 1;
	} else {
		return 0;
	}
}
#### mail specific subroutines

sub parseComm($) {
# parse the command line submitted by pop3 client
# return (command nr, command, command data) array
# command determined using case insensitive match
	
	my $comm = "BAD";	# default values for bad command
	my $commNr = 0;
	my $commData = $_[0];
#	print STDERR "parseComm($_[0])\n";
	
	if ($_[0] =~ /^\s*DELE\s*(.*)/i) {
		$comm = "DELE";
		$commNr = 1;
	} elsif ($_[0] =~ /^\s*LIST\s*(.*)/i) {
		$comm= "LIST";
		$commNr = 2;
	} elsif ($_[0] =~ /^\s*NOOP\s*(.*)/i) {
		$comm= "NOOP";
		$commNr = 3;
	} elsif ($_[0] =~ /^\s*PASS\s*(.*)/i) {
		$comm= "PASS";
		$commNr = 4;
	} elsif ($_[0] =~ /^\s*QUIT\s*(.*)/i) {
		$comm= "QUIT";
		$commNr = 5;
	} elsif ($_[0] =~ /^\s*RETR\s*(.*)/i) {
		$comm= "RETR";
		$commNr = 6;
	} elsif ($_[0] =~ /^\s*RSET\s*(.*)/i) {
		$comm= "RSET";
		$commNr = 7;
	} elsif ($_[0] =~ /^\s*STAT\s*(.*)/i) {
		$comm= "STAT";
		$commNr = 8;
	} elsif ($_[0] =~ /^\s*USER\s*(.*)/i) {
		$comm= "USER";
		$commNr = 9;
	} elsif ($_[0] =~ /^\s*BYE\s*(.*)/i) {
		# an extra non-pop3 command for convenience
		$comm= "BYE";
		$commNr = 10;
	}
	if ($commNr > 0) {	# input string less command
		$commData = $1;
	}
	return ($commNr, $comm, $commData);
}

sub parseHeader ($$) {
# param pop3 messageNr
# return array (header msgNr, msgUID, msgID, from, to, date, subject, size)
# possibly the line terminator added should be CRLF
	
	my $msgNr = $_[1];
	my @header = $_[0]->Head($msgNr);
	my $header = "";
	my $msgUID = trim($_[0]->Uidl($msgNr));
	my $msgID = "";
	my $from = "";
	my $to = "";
	my $date = "";
	my $subject = "";
	my $size = "";
	my $xx = "";
	
	($xx, $size) = split('\s+', $_[0]->List($msgNr));
	
	foreach (@header) {
		$header .= $_ . "\n";
		if (/^Message-ID:\s+/i) {
			($msgID = $_) =~s/Message-ID://i;
			$msgID = trim($msgID);
			next;
		}
		if (/^From:\s+/i) {
			($from = $_) =~s/From://i;
			$from = trim($from);
			next;
		}
		if (/^To:\s+/i) {
			($to = $_) =~s/To://i;
			$to = trim($to);
			next;
		}
		if (/^Date:\s+/i) {
			($date = $_) =~s/Date://i;
			$date = trim($date);
			next;
		}
		if (/^Subject:\s+/i) {
			($subject = $_) =~s/Subject://i;
			$subject = trim($subject);
		}
	}
	return ($header, $msgNr, $msgUID, $msgID, $from, $to, $date, $subject, $size);
}

sub pop3Conn ($$$$$$) {
# create pop3 server client connection

	my $pop;

	$pop = new Mail::POP3Client( 
						USER		=>$_[0],
						PASSWORD	=> $_[1],
						HOST		=> $_[2],
						PORT		=> $_[3],
						DEBUG		=> $_[4],
						AUTH_MODE	=> $_[5],);
	return $pop;
}

sub mailDBHandle ($$$$) {
# param dbHandle dbConn dbUser dbPw
# connect to mail database
# return dbHandle
	
	my $dbh = $_[0];
	my $dbc = $_[1];
	my $user = $_[2];
	my $pw = $_[3];
	
	if ($dbh = DBI->connect ($dbc, $user, $pw)) {
		return $dbh;
	} else {
		print STDERR "problem connecting to database $dbc, " . DBI->errstr . "\n";
		return 0;
	}
}

sub maildropStats (\@) {
# return array of number and total size of non-deleted messages
# assumes argument is a ref to a maildrop array of array refs with array 
# values of (number, size, deleted)

	my $aRef = $_[0];
	my @array = @$aRef;
	my $ttlNr = 0;
	my $ttlSize = 0;
	my $listRef;
	my @subArray = ();
	
	foreach $listRef (@array) {
		@subArray = ref2Array($listRef);
		if ($subArray[2] eq "false") {	# not deleted
			$ttlNr++;
			$ttlSize += $subArray[1];
		}
	}
	return ($ttlNr, $ttlSize);
}

sub maildropArray (\@$) {
# return nth maildrop item as array of (number, size, deleted)
# assumes argument is a ref to a maildrop array of array refs witharray 
# values of (number, size, deleted)
# args: arrayRef, n
# return (0, 0, "bad") if n larger than array size

	my $aRef = $_[0];
	my $n = $_[1];
	my @array = @$aRef;
	
	if ($n > scalar(@array)) {	# n too large
		return (0, 0, "bad");
	} else {
		return ref2Array($array[$n-1]);
	}
}

sub maildropRst (\@) {
# reset all marked deleted messages as not deleted
# assumes argument is a ref to a maildrop array of array refs with array 
# values of (number, size, deleted)

	my $aRef = $_[0];
	my @array = @$aRef;
	my $listRef;
	my @subArray = ();
	my $index = 0;
	my $reset = 0;

	foreach $listRef (@array) {
		@subArray = ref2Array($listRef);
		if ($subArray[2] eq "true") {	# deleted
			$subArray[2] = "false";
			$array[$index] = [@subArray];
			$reset++;
		}
		$index++;
	}
	return @array;
}

sub byteStuff ($) {
# byte-stuff a string, as defined on rfc 1939
# that is, prepend any line starting with . (period) with another . (period)
# string size exceeding database allocation can lead to truncation and that
# results in bad termiation, which can cause the mail client to hang

	my $str = $_[0];
	
	$str =~ s/\x0D\x0A\x2E/\x0D\x0A\x2E\x2E/g;
	if (substr($str, -2) eq "\x0D\x0A") {	# ends with crlf, as expected
		return $str;
	} else {	# something odd happening here, add crlf
		$str .= "\x0D\x0A";
		return $str;
	}
}

sub msgStatus ($) {
# returns status of message as text

	if ($_[0] eq "false") {
		return "enabled";
	} elsif ($_[0] eq "true") {
		return "disabled";
	} else {
		return "unknown";
	}
}

1;