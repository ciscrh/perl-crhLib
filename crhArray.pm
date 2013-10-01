#!/usr/bin/perl
# crhArray.pm
#
# Array subroutines
# v1.02 crh 17-feb-10 -- initial release
# this package is particularly concerned with arrays of array refs and bsv records

# bsvES (;$) -- set/retrieve bsv bar escape sequence
# bsv2Arr($) -- returns array from bsv record (to add to an array of array refs)
# arr2bsv(@)-- returns array formatted as bsv record
# arr2csv -- returns array formatted as csv record
# anonARef -- returns anonymous ref to a copy of an array
# arrTrunc -- truncates array
# arrARefSlice -- returns slice of array of array references
# arrARefFields -- returns filtered array of array references
# arrARefSortLex -- returns array of array refs sort by stated field lexicographically
# arrARefSortNum -- returns  array of array refs sort by stated field numerically
# arrPrintBSV -- prints array formatted as bsv record
# arrARefPrintBSV -- prints array of array refs formatted as bsv records
# arrPrintCSV -- prints array formatted as csv record
# arrCompElement -- compares element texts from two arrays ignoring differences do to case
# arrCompElements -- compares element texts from an array ignoring differences do to case
# arrARefSameElements -- returns array of array references filtered by comparison of the named elements

# when building arrays of refs to arrays programmatically you have to be careful
# not to get all refs pointing at the same array!
# anonARef() is your friend here, it points the ref at a copy of the supplied array

package crhArray;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&bsv2Arr &arr2bsv &arr2csv &anonARef &arrTruncate &arrARefSlice 
		&arrARefFields &arrARefSortLex &arrARefSortNum &arrARefSortRevNum 
		&arrPrintBSV &arrARefPrintBSV &arrPrintCSV &bsvES
		&arrCompElement &arrCompElements &arrARefSameElements);

use warnings;
use strict;

INIT {	#### persistent private variables for subroutines :-)
	my $bsvEscSeq = '{bar}';	# default bsv bar escape sequence

	sub bsvES (;$) {
	# set/retrieve bsv bar escape sequence

		if ($_[0]) {	# set escape sequence if argument supplied
			$bsvEscSeq = $_[0];
		}
		return $bsvEscSeq;	# always return current value
	}
}	# end INIT

sub bsv2Arr ($) {
# returns array generated from bsv record
# usage: bsv2Arr ($bsv)

	my $esc = bsvES();	# allow for bsv escape sequence
	my @a = ();
	my $bsv = $_[0];
	my $field;

	@a = split /\|/, $bsv;
	foreach $field (@a) {	# remove whitespace from ends * escape bar chars
		$field = trimStr($field);
		eval($field =~ s/$esc/\|/g);
	}
	return @a;
}

sub anonARef {
# returns  reference to an anonymous copy of an array
# used to build array of array refs
# usage anonARef(@array)

	return [@_];
}

sub arrARefSortLex  {
# returns array of array references sorted by up to 3 elements (default element 0 only)
# of the dereferenced array elements
# usage: arrARefSortLex (\@a[,$element[,$element[,$element]]])
# NOTE reference used

	my $unsorted = $_[0];
	my $ele1 = 0;	# default if no element specified
	my $ele2 = 0;	# default if no element specified (must not be 0)
	my $ele3 = 0;	# default if no element specified (must not be 0
	my @sorted = ();

	if ($_[1]) {	# element specified
		$ele1 = $_[1];
	}
	if ($_[2]) {	# element specified
		$ele2 = $_[2];
	}
	if ($_[3]) {	# element specified
		$ele3 = $_[3];
	}

	if ($ele3) {	# 3 elements specified
		@sorted = sort { ($a->[$ele1].$a->[$ele2].$a->[$ele3]) cmp ($b->[$ele1].$b->[$ele2].$b->[$ele3]) } @$unsorted;
	} elsif ($ele2) {	# 2 elements specified
		@sorted = sort { ($a->[$ele1].$a->[$ele2]) cmp ($b->[$ele1].$b->[$ele2]) } @$unsorted;
	} else {	# 0 or 1 element specified
		@sorted = sort { $a->[$ele1] cmp $b->[$ele1] } @$unsorted;
	}
	return @sorted;
}

sub arrARefSortNum ($$)  {
# returns array of array references sorted by element (default 0)
# of the dereferenced array elements
# does numeric sort
# usage: arrARefSortNum (\@a[,$element])
# NOTE reference used

	my $unsorted = $_[0];
	my $ele = 0;	# default of no element specified
	my @sorted = ();

	if ($_[1]) {	# element specified
		$ele = $_[1];
	}

	@sorted = sort { $a->[$ele] <=> $b->[$ele] } @$unsorted;
	return @sorted;
}

sub arrARefSortRevNum  {
# returns array of array references sorted by element (default 0)
# of the dereferenced array elements
# usage: arrARefSortNum (\@a[,$element])
# does reverse numeric sort
# NOTE reference used

	my $unsorted = $_[0];
	my $ele = 0;	# default of no element specified
	my @sorted = ();

	if ($_[1]) {	# element specified
		$ele = $_[1];
	}

	@sorted = sort { $b->[$ele] <=> $a->[$ele] } @$unsorted;
	return @sorted;
}

sub arr2bsv(@)  {
# returns array formated as bsv record
# usage: array2bsv (@a)

	my $bsv = my $field = '';
	my $esc = bsvES();	# allow for bsv escape sequence

	foreach (@_) {	# escape bar chars
		$field = $_;
		$field =~ s/\|/$esc/ge;
		$bsv .= $field . '|';
	}
	chop($bsv);	# remove terminating bar
	return $bsv;
}

sub arrTruncate {
# truncate array elements to given number
# usage arrTruncate(\@a, truncNr)

	my $a = $_[0];
	my @b = ();
	my $trunc = $_[1];
	my $popCount = (@$a - $trunc);
	
	if ($popCount > 0) {	# truncate array
		while ($popCount--) {	# remove last element
			pop(@$a);
		}
	}
}
		
sub arrPrintBSV  {
# prints array formatted as bsv record to STDOUT
# includes newline char
# usage: arrPrintBSV (@row)

	pso(arr2bsv(@_));
	return;
}

sub arrARefPrintBSV  {
# prints array of array references formatted as bsv records
# assumes each element of the array is a reference to an array
# usage: arrayPrintBSV (\@a)
# NOTE reference used

	my $a = $_[0];
	my $row;

	foreach $row (@$a) {	# row is reference to array
		arrPrintBSV(@$row);	# deference row array here
	}
	return;
}

sub arrARefSlice ($$$)  {
# takes slice of each array reference array in an array of array references
# assumes each element of the input array is a reference to an array
# usage: arrARefSlice (\@a, lower subscript, upper subscript)
# returns new sliced array of arrays (input array not modified)
# NOTE reference used and field = subscript+1

	my $a = $_[0];
	my $lower = $_[1];
	my $upper = $_[2];
	my @slice = ();
	my $row;

	foreach $row (@$a) {	# row is reference to array
		push(@slice, [@$row[$lower .. $upper]]);
	}
	return @slice;
}

sub arrARefFields ($$)  {
#### NOT CHECKED
# takes requested fields of each array reference array in an array of array references
# assumes each element of the input array is a reference to an array
# usage: arrARefSlice (\@a, \@fields)
# where @fields is an ordered list of subscripts [eg, (0,5,4)]
# returns new filtered array of arrays (input array not modified)
# NOTE reference used and field = subscript+1

	my $a = $_[0];
	my $fields = $_[1];
	my @filtered = ();
	my $row;
	my $fieldNr;

	foreach $row (@$a) {	# row is reference to array
		my @b;
		foreach $fieldNr (@$fields) {
			push(@b, @$row[$fieldNr -1]);
		}
		push(@filtered, anonARef(@b));
	}
	return @filtered;
}

sub arr2csv  {
# returns array formated as csv record
# usage: array2CSV (@a)

	my @a = @_;
	my $csv = '';
	my $element = '';

	foreach $element (@a) {
		$csv .= $element . ',';
	}
	chop($csv);	# remove terminating bar
	return $csv;
}

sub arrPrintCSV  {
# prints array formatted as csv record to STDOUT
# includes newline char
# usage: arrayPrintCSV (@row)

	pso(arr2csv(@_));
	return;
}

sub arrCompElement($$$) {
# compares element texts from two arrays ignoring differences do to case
# args: \@arr1, \@arr2, subscript
# return: 1 if same by the above criteria, 0 if different

	my $aRef1 = $_[0];
	my $aRef2 = $_[1];
	my @arr1 = @$aRef1;
	my @arr2 = @$aRef2;
	my $txt1 = $arr1[$_[2]];
	my $txt2 = $arr2[$_[2]];
	
	return (lc($txt1) eq lc($txt2));
}

sub arrCompElements($$$) {
# compares element texts from an array ignoring differences do to case
# args: \@arr, subscript1, subscript2
# return: 1 if same by the above criteria, 0 if different

	my $aRef = $_[0];
	my @arr = @$aRef;
	my $txt1 = $arr[$_[1]];
	my $txt2 = $arr[$_[2]];
	
	return (lc($txt1) eq lc($txt2));
}

sub arrARefSameElements ($$$;$)  {
# returns array of array references filtered by the named elements
# of the dereferenced array elements
# includes array reference if elements the same ignoring differences do to case
# includes array references if elements different if 4th argument present
# usage: arrARefSameElements  (\@a, $subscript1, $subscript2 [, $diffFlag])
# NOTE reference used

	my $aRef = $_[0];
	my $subscript1 =$_[1];
	my $subscript2 =$_[2];
	my $diff = 0;	# default: keep if same
	my @filtered = ();
	my $row;
	
	if ($_[3]) {	# keep if different
		$diff = 1;
	}

	foreach $row (@$aRef) {	# row is reference to array
		if (arrCompElements($row, $subscript1, $subscript2)) {
			if (!$diff) {
				push(@filtered, [@$row]);
			}
		} elsif ($diff) {
				push(@filtered, [@$row]);
		}
	}
	return @filtered;
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

sub trimStr($) {
# trim whitespace from both ends of text
# args: text
# return: trimmed text
	
	my $text = $_[0];
	$text =~ s/^\s+|\s+$//g;	# trim whitespace
	return $text;
}

sub compTextLC($$) {
# compares texts ignoring differences do to case
# args: text1, text2
# return: 1 if same by the above criteria, 0 if different

	return (lc($_[0]) eq lc($_[1]));
}

1;
