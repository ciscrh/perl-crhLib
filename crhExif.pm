#!/usr/bin/perl
# crhExif.pm
#
# Image EXIF subroutines
# v1.00 crh 18-jun-13 -- initial release

# sub exifPrintMetadata ($$$;$$$$$) -- get and print image metadata
# sub exifGetTag ($$;$$) -- get value for single tag
# exifGetTagNames ($) -- return array of tag names
# exifBSVArray(@) -- return string consisting of bsv of array

package crhExif;
use Exporter;
@ISA = ("Exporter");
@EXPORT = qw(&exifPrintMetadata &exifGetTag &exifGetTagNames &exifBSVArray);

use warnings;
use strict;
use File::Basename;
use lib '../crhLib';    # crh custom packages
use crhDebug;
use crhString;

sub exifPrintMetadata ($$;$$$$$$) {
# get and print image metadata
# args: imageFile, groupTag [, metaTags, srchTag, recursive, pretty, missing, verbose]
# only prints filename for successful matches if tag search string defined
    
  my $fullFilename = $_[0];
  my $grpTag = $_[1];
	my $metaTags = '';
	if ($_[2]) {
		$metaTags = $_[2];
	}
	my $recursive = my $pretty = my $srchTag = my $missing = my $verbose = 0;
  if ($_[3]) {
    $srchTag = $_[3];
	}
  $recursive = 1 if ($_[4]);
	$pretty = 1 if ($_[5]);
  $missing = 1 if ($_[6]);
  $verbose = 1 if ($_[7]);
	my @metaTags;
	if ($metaTags) {
		@metaTags = exifGetTagNames($metaTags);
	}
	my $filename = basename($fullFilename);	
	my $exifTool = new Image::ExifTool;
  my $group = my $tag = '';
  my $tagDesc;
  my $grpHdg;
  my $grpOK;
  my $info;
  my $printFile = my $printOut = my $srchCount = my $msngCount = 0;
	
  if (!$srchTag && !$missing) { # always print filename if search string not specified
    if ($recursive) {
      msg("\nfile: $fullFilename");
    } else {
      msg("\nfile: $filename");
    }
    $printFile = 1;
  }

  if ($verbose) { # extreme debugging mode!
    $exifTool->Options(Unknown => 1, Verbose => 2);
  } else {
    $exifTool->Options(Unknown => 1);
  }
	$info = $exifTool->ImageInfo($fullFilename);

  foreach $tag ($exifTool->GetFoundTags('Group0')) {
    if ($group ne $exifTool->GetGroup($tag)) {
      $group = $exifTool->GetGroup($tag);
      next if (lc($grpTag) ne 'all' && lc($group) ne $grpTag);
      $grpHdg = "---- $group ----";
      $grpOK = 0;
    }
    next if (lc($grpTag) ne 'all' && lc($group) ne $grpTag);
    my $val = $info->{$tag};
    if (ref $val eq 'SCALAR') {
      if ($$val =~ /^Binary data/) {
        $val = "($$val)";
      } else {
        my $len = length($$val);
        $val = "(Binary data $len bytes)";
      }
    }
    if ($srchTag) {
      if ($val =~ m/($srchTag)/i) {
        $srchCount++;
      } else {
        next;
      }
    }
    if ($pretty) {
      $tagDesc = $exifTool->GetDescription($tag);
      if ($metaTags eq '' || (grep {$_ eq lc($tagDesc)} @metaTags)) {
        $srchCount++ if ($srchTag && ($val =~ m/($srchTag)/i));
        if (!$printFile && !$missing) {  # print filename on first match
          if ($recursive) {
            msg("\nfile: $fullFilename");
          } else {
            msg("\nfile: $filename");
          }
          $printFile = 1;
        }
        $printOut = 1;
        if (!$missing) {
          msg($grpHdg) if (!$grpOK++);
          msg(pad($tagDesc, 32, ' ', 0) . ': ' . $val);
        }
      }
    } else {
      if ($metaTags eq '' || (grep {$_ eq lc($tag)} @metaTags)) {
        if (!$printFile && !$missing) {  # print filename on first match
          if ($recursive) {
            msg("\nfile: $fullFilename");
          } else {
            msg("\nfile: $filename");
          }
          $printFile = 1;
        }
        $printOut = 1;
        if (!$missing) {
          msg($grpHdg) if (!$grpOK++);
          msg(pad($tag, 32, ' ', 0) . ': ' . $val);
        }
      }
    }
  }
	if (!$printOut) {
    $msngCount = 1;
    if ($recursive) {
      msg("\nfile: $fullFilename");
    } else {
      msg("\nfile: $filename");
    }
  }
	return ($srchCount, $msngCount);
}

sub exifGetTag ($$;$$) {
# get value for single tag
# args: imageFile, tag [, groupTag, exifToolInfo]
# returns value, or '' if no match (ie: tag doesn't exist)
# allows existing exifTool object to be used
    
  my $fullFilename = $_[0];
	my $metaTag = lc($_[1]);
	my $grpTag = 'all';	# default value
  $grpTag = lc($_[2]) if ($_[2]);
#	my $exifTool = new Image::ExifTool;
	my $exifTool = new Image::ExifTool if (!$_[3]);
  my $info;	
	if ($_[3]) {
		$info = $_[3];
	} else {
		$exifTool->Options(Unknown => 1);
		$info = $exifTool->ImageInfo($fullFilename);
	}
	my $value = my $tag = my $group = '';

	foreach $tag ($exifTool->GetFoundTags('Group0')) {
		next if (lc($tag) ne $metaTag);
		if ($grpTag ne 'all') {	# check group if tag name matches
      $group = lc($exifTool->GetGroup($tag));
     last if ($group ne $grpTag);
    }
    $value = $info->{$tag};
		$metaTag = $tag;
		last;
  }
	return ($metaTag, $value);
}

sub exifGetTagNames ($) {
# return array of tag names
# comma is used as the value delimiter char
# converts ## into comma and __ into space
# args: string list (tagName[,tagName...])
# return tagName array

    my $tag;
    my $idx = 0;
    my @tags = split(/,/, $_[0]);   # comma separated

    foreach $tag (@tags) {
        $tag =~ s/##/,/g;   # substitute comma for ##
        $tag =~ s/__/ /g;   # substitute space for __
        $tags[$idx++] = $tag;
    }
    return @tags;
}

# helper subroutines, not exported

1;
