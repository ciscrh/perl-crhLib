#!/usr/bin/perl
# testArg.pl
#
# test crhArg package
# # v1.00 crh 04-sep-10 -- initial release

use warnings;
use strict;
use lib '../crhLib';	# crh custom packages
#use Getopt::Std;
use crhDebug;	# custom debug subroutines
use crhArg;	# custom argument subroutines
#use crhString;	# custom string subroutines
#use crhArray;	# custom array subroutines

#### sanity checks

my $progName = "testArg";
my $debug = 0;	# param default value -- 1 = debug on, 0 = debug off
my $quiet = 0;	# param default value -- 1 = quiet on, 0 = quiet off
my $flagA = 0;
my $paramB = "";
my $paramF = "";
my $paramP = "";

my $paramOK = 1;	# params check

#### subroutines


#### main

errTMsg("$progName invoked");
setDbg($debug);
setDbgProgName($progName);
statusDbgMsg("DEBUG", "main", "debug enabled");

## process input params

dbgMsg("process command line switches...");
argSetOpts ('AdqB:F:P:');

$quiet = argSetQuiet (argGetFlag('q', 'quiet mode = on', 'quiet mode = off'));
$debug = argGetFlag('d', 'debug mode = on', 'debug mode = off');

$flagA = argGetFlag('A', 'flag A is set', 'flag A is unset');

$paramB = argGetParam('B', 'param B = ', 'param B is not set');

$paramF = argGetInputFile ('F', "input file = ", "no input file provided");

$paramP = argGetPw('P', "password supplied", "no password supplied...", "enter password: ");
errMsg("password is...$paramP");

## tidy up

errMsg("");
errTMsg("...$progName exits successfully") if !$quiet;

#### end of main
