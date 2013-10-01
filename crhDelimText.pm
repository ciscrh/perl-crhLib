#!/usr/bin/perl
# crhDelimText.pm
#
# IDM delim text driver text file subroutines
# v1.00 crh 20-jan-09 -- initial release

package crhDelimText;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&checkInFile &checkOutFile renInFile);

use warnings;
use strict;
use File::Basename;
use POSIX;

sub checkInFile (*) {
# check input file, return short form of filename if successful

	my $inFile = "";
	my $inFileF = "";
	my $inFileD = "";
	my $inFileE = "";
	my $ok = "1";
	
	($inFileF, $inFileD, $inFileE) = fileparse($_[0], qr/\..*/);
	$inFile = $inFileD . $inFileF . $inFileE;
	$ok = $inFileF . $inFileE;

	if (!(-e $_[0])) {
		return ("0", "$inFile skipped, file not found");
	} elsif (!(-f $_[0])) {
		return ("0", "$inFile skipped, not a plain file");
	} elsif (!(-T $_[0])) {
		return ("0", "$inFile skipped, , not a text file");
	} elsif (!(-r $_[0])) {
		return ("0", "$inFile skipped, not a readable file");
	} else {
		return ($ok, "$ok input file checks OK");
	}
}

sub checkOutFile (*) {
# check output file

	my $outFile = "";
	my $outFileF = "";
	my $outFileD = "";
	my $outFileE = "";
	my $outExt = ".pwd";	##### generated output file extension: modify to suit

	($outFileF, $outFileD, $outFileE) = fileparse($_[0], qr/\..*/);
	
	#generate an output file name based on the current timestamp
	$outFileF = strftime("%Y%m%d-%H%M%S", localtime);
	$outFile = $outFileD . $outFileF . $outExt;

	if (-e $outFile) {
		return ("0", "skipped,... output file $outFile already exists");
	} elsif (open(OUTF, ">", $outFile)) {
		close(OUTF);
		return ($outFile, "$outFileF$outExt output file checks OK");
	} else {
		return ("0", "skipped,... output file $outFile cannot be created");
	}
}

sub renInFile (*) {
# rename input file

	my $inFile = "";
	my $inFileF = "";
	my $inFileD = "";
	my $inFileE = "";
	my $newExt = ".bkp";	#### processed input file extension: modify to suit
	my $argFile = $_[0];


	($inFileF, $inFileD, $inFileE) = fileparse($argFile, qr/\..*/);
	$inFile = $inFileD . $inFileF . $newExt;

	if (-e $inFile) {
		return ("0", "rename skipped,... $inFile already exists");
	} elsif (rename($argFile, $inFile)) {
		return ($inFile, "input file $inFileF$inFileE renamed to $inFileF$newExt");
	} else {
		reurn ("0", "rename skipped,... cannot rename $argFile to $inFile");
	}
}

# helper subroutines

1;