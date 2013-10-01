#!/usr/bin/perl
# crhHash.pm
#
# Hash subroutines
# v1.01 crh 17-jul-09 -- initial release

# hashInterect -- returns the intersection of 2 hashes
# hashUnion -- returns the union of 2 hashes
# hashSmplDiff -- returns the simple difference of two hashes
# hashSmmtDiff -- returns the symmetric difference of two hashes

# hashPrintKey -- prints out hash keys
# hashPrintSortKey -- prints out hash keys in sorted order
# hashPrintValue -- prints out hash values
# hashPrintSortValue -- prints out hash values in sorted key order

package crhHash;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&hashIntersect &hashUnion &hashSmplDiff &hashSmmtDiff 
	&hashPrintKey &hashPrintSortKey &hashPrintValue &hashPrintSortValue);

use warnings;
use strict;

sub hashIntersect  {
# intersection of 2 hashes (values in both %a and %b)
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
# returns merged hash (%a duplicate key values overwritten by %b)
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
# simple difference of 2 hashes
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

sub hashSmmtDiff  {
# symmetric difference of 2 hashes
# usage: hashIntersect (\%a, \%b)
# returns hash of those values in either %a or %b but not in both

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

	while (($k,$v) = each(%b)) {
		next if exists $a{$k};
		$diff{$k} = $v;;
	}
	return %diff;
}

sub hashPrintKey {
# print out hash keys
# usage: hashPrintKey (\%a)

	my %hash = ();	
	my $aRef = $_[0];
	my %a = %$aRef;
	my $k;
	my $v;
	my $prefix = '';
	if (scalar(@_) == 2) {
		$prefix = $_[1];
	}

	while (($k, $v) = each %a) {
		pso("$prefix$k");
	}
}

sub hashPrintSortKey {
# print out a hash keys in sorted order
# usage: hashPrintSortKey (\%a)

	my %hash = ();	
	my $aRef = $_[0];
	my %a = %$aRef;
	my $k;
	my $prefix = '';
	if (scalar(@_) == 2) {
		$prefix = $_[1];
	}

	foreach $k (sort keys %a) {
		pso("$prefix$k");
	}
}

sub hashPrintValue {
# print out hash values
# usage: hashPrintValue (\%a)

	my %hash = ();	
	my $aRef = $_[0];
	my %a = %$aRef;
	my $k;
	my $v;
	my $prefix = '';
	if (scalar(@_) == 2) {
		$prefix = $_[1];
	}

	while (($k, $v) = each %a) {
		pso("$prefix$v");
	}
}

sub hashPrintSortValue {
# print out a hash values in sorted key order
# usage: hashPrintsortValue (\%a)

	my %hash = ();	
	my $aRef = $_[0];
	my %a = %$aRef;
	my $k;
	my $prefix = '';
	if (scalar(@_) == 2) {
		$prefix = $_[1];
	}

	foreach $k (sort keys %a) {
		pso("$prefix" . %a{$k});
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