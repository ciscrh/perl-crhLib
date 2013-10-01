#!/usr/bin/perl
# crhFile.pm
#
# file subroutines
# v1.13 crh 20-jan-09 -- initial release

# dos2UnixPath($) -- converts DOS path separators to Unix
# unix2DosPath($) -- converts Unix path separators to DOS
# absPath(;$) -- returns absolute pathname
# checkDir ($) -- check directory exists
# checkFile ($) -- check file, return short form of filename if exists
# checkInfile($) -- checks input file for existence, readability, etc
# createOutfile($$;$) -- checks and creates output file
# renFile($$;$) -- checks and renames file
# getFileLine ($;$) -- return next line (trimmed), skips blank & remark lines
# fileList ($$;$) -- returns filenames array, optionally searching recursively
# checkBinaryFile ($) -- check binary input file, return 1 if successful

package crhFile;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&dos2UnixPath &unix2DosPath &absPath &checkInfile &createOutfile 
    &renFile &getFileLine &fileList &checkBinaryFile &checkDir &checkFile);

use warnings;
use strict;
use lib '../crhLib';    # crh custom packages
use File::Basename;
use Cwd 'abs_path';
use File::Find;
use POSIX;
use crhDebug;

sub dos2UnixPath($) {
# converts DOS path separators (\) to Unix (/)
# allows code to be made portable across platforms
    
    $_[0] =~ s=\\=/=g;
    return $_[0];
}

sub unix2DosPath($) {
# converts Unix path separators (/) to DOS (\)
# complements dos2UnixPath()
    
    $_[0] =~ s=/=\\=g;
    return $_[0];
}

sub absPath(;$) {
# convenience renaming of core package subroutine abs_path()
# takes an optional single argument and returns the absolute pathname for it
# if no argument then returns current working directory

    if ($_[0]) {
        return abs_path($_[0]);
    } else {
        return abs_path();
    }
}

sub checkDir ($) {
# check directory
# args: directory
# return (status, error message);

	my $fileF = "";
	my $fileD = "";
	my $fileE = "";

	($fileF, $fileD, $fileE) = fileparse($_[0], qr/\..*/);
	return ("0", "directory not found") if !(-e $_[0]);
	return ("0", "not a directory") if !(-d $_[0]);
	return ($fileD, "directory OK");
}

sub checkFile ($) {
# check file, return short form of filename if exists
# otherwise returns "0"
# args: input filename
# return: (status, error message)

    my $fileF = "";
    my $fileD = "";
    my $fileE = "";
    my $okFile = "";
    
    ($fileF, $fileD, $fileE) = fileparse($_[0], qr/\..*/);
    $okFile = $fileF . $fileE;

    return ("0", "file not found") if !(-e $_[0]);
    return ($okFile, "file OK");
}
sub checkInfile ($) {
# check input file, return short form of filename if successful
# otherwise returns "0"
# args: input filename
# return: (status, error message)

    my $inFile = "";
    my $inFileF = "";
    my $inFileD = "";
    my $inFileE = "";
    my $okFile = "";
    
    ($inFileF, $inFileD, $inFileE) = fileparse($_[0], qr/\..*/);
    $inFile = $inFileD . $inFileF . $inFileE;
    $okFile = $inFileF . $inFileE;

    return ("0", "$inFile file not found") if !(-e $_[0]);
    return ("0", "$inFile is not a plain file") if !(-f $_[0]);
    return ("0", "$inFile is not a text file") if !(-T $_[0]);
    return ("0", "$inFile is not a readable file") if !(-r $_[0]);
    return ($okFile, "$okFile input file checks OK");
}

sub createOutfile ($$;$) {
#  output file based on input file, if checks OK
# args: input file, output file extension (incl .) [,output file name]

    my $inFile = $_[0];
    my $outFile = "";
    my $outFileF = "";  # generated output file name
    my $outFileD = "";
    my $outFileE = "";  # generated output file extension

    ($outFileF, $outFileD, $outFileE) = fileparse($inFile, qr/\..*/);
    $outFileE = $_[1];
    if ($_[2]) {    # use different file name if given as arg
        $outFileF = $_[2];
    }
    
    # generate output file name 
    $outFile = $outFileD . $outFileF . $outFileE;

    if (-e $outFile) {
        return ("0", "output file $outFile already exists");
    } elsif (open(OUTF, ">", $outFile)) {
        close(OUTF);
        return ($outFile, "$outFileF$outFileE output file checks OK");
    } else {
        return ("0", "output file $outFile cannot be created");
    }
}

sub renFile ($$;$) {
# rename input file
# args: input file, output file ext (incl .) [, output file name]

    my $inFile = $_[0];
    my $outFileF = "";  # generated output file name
    my $outFileD = "";
    my $outFileE = "";  # generated output file extension
    my $outFile = "";

    ($outFileF, $outFileD, $outFileE) = fileparse($inFile, qr/\..*/);
    $outFileE = $_[1];
    if ($_[2]) {    # use different file name if given as arg
        $outFileF = $_[2];
    }
    # generate output file name
    $outFile = $outFileD . $outFileF . $outFileE;

    if (-e $outFile) {
        return ("0", "rename failed,... $outFile already exists");
    } elsif (rename($inFile, $outFile)) {
        return ($outFile, "input file $inFile renamed to $outFileF$outFileE");
    } else {
        return ("0", "rename failed,... cannot rename $inFile to $outFileF$outFileE");
    }
}

sub getFileLine ($;$) {
# return next line (trimmed), skipping blank and remark lines
# return empty string if eof detected
# args: input file handle (open) [,remark character]

    my $fh = $_[0];
    my $remChar = '';
    if ($_[1]) {
        $remChar = $_[1];
    }
    my $line = '';

    while ($line = <$fh>) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;    # trim whitespace
        if ($line eq '') {  # blank line
            next;
        }
        if (($remChar ne '') && (substr($line, 0, 1) eq $remChar)) {    # ignore remark lines
            next;
        }
        return $line;   # success :-)
    }
    return '';  # signifies eof, the empty string is never returned otherwise
}

sub fileList ($$;$) {
# returns array of sorted filenames
# does recursive directory search if required
# does case insensitive filename sort within each directory 
# (should really use case folding [fc()] to work consistently with unicode)
# args: base directory, file glob, recursive

    my $fileDir = $_[0];
    my $fileListGlob = $_[1];
    my $recursive = 0;
    my @fileListFiles = ();

    if ($_[2]) { # set recursion flag, possibly
        $recursive = $_[2];
    }

    if ($recursive) {
        find sub {
            return unless -d;
            push(@fileListFiles, sort {lc($a) cmp lc($b)} glob("$File::Find::name/$fileListGlob"));
        }, $fileDir;
    } else {    # just process the specified directory
        @fileListFiles = sort {lc($a) cmp lc($b)} glob("$fileDir$fileListGlob");
    }
    return @fileListFiles;
}

sub checkBinaryFile ($) {
# check binary input file, return 1 if successful
# otherwise returns 0
# args: binary filename
# return (status, status message)

  my $binFile = $_[0];
  my $name = basename($binFile);
    
  return (0, $name, "$name file not found") if !(-e $binFile);
  return (0, $name, "$name is a directory") if !(-f $binFile);
  return (0, $name, "$name is not a readable file") if !(-r $binFile);
  return (0, $name, "$name is not a binary file") if !(-B $binFile);  # text files pass!
  return (0, $name, "$name is a text file") if (-T $binFile);
  return (1, $name, "$name file basic checks OK");
}

# helper subroutines, not exported

1;
