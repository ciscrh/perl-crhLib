package File::Tail;
# crh 14-dec-10 -- using this local source code version because activestate cpan does not have package for latest release of perl

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
$VERSION = '0.99.3';


# Preloaded methods go here.

use FileHandle;
#use IO::Seekable; # does not define SEEK_SET in 5005.02
use File::stat;
use Carp;
use Time::HiRes qw ( time sleep ); #import hires microsecond timers

sub SEEK_SET   () {0;}
sub SEEK_CUR () {1;}
sub SEEK_END   () {2;}


sub interval {
    my $object=shift @_;
    if (@_) {
	$object->{interval}=shift;
	$object->{interval}=$object->{maxinterval} if 
	    $object->{interval}>$object->{maxinterval};
    }
    $object->{interval};
}

sub logit {
    my $object=shift;
    my @call=caller(1);
    print # STDERR 
#	time()." ".
	"\033[7m".
	    $call[3]." ".$object->{"input"}." ".join("",@_).
		"\033[0m".
		    "\n"
	if $object->debug;
}

sub adjustafter {
    my $self=shift;
    $self->{adjustafter}=shift if @_;
    return $self->{adjustafter};
}

sub debug {
    my $self=shift;
    $self->{"debug"}=shift if @_;
    return $self->{"debug"};
}

sub errmode {
    my($self, $mode) = @_;
    my($prev) = $self->{errormode};
 
    if (@_ >= 2) {
        ## Set the error mode.
	defined $mode or $mode = '';
	if (ref($mode) eq 'CODE') {
	    $self->{errormode} = $mode;
	} elsif (ref($mode) eq 'ARRAY') {
	    unless (ref($mode->[0]) eq 'CODE') {
		croak 'bad errmode: first item in list must be a code ref';
		$mode = 'die';
	    }
	    $self->{errormode} = $mode;
	} else {
	    $self->{errormode} = lc $mode;
	}
    }
     $prev;
} 

sub errmsg {
    my($self, @errmsgs) = @_;
    my($prev) = $self->{errormsg};
 
    if (@_ > 0) {
        $self->{errormsg} = join '', @errmsgs;
    }
 
    $prev;
} # end sub errmsg
 
 
sub error {
    my($self, @errmsg) = @_;
    my(
       $errmsg,
       $func,
       $mode,
       @args,
       );
 
    if (@_ >= 1) {
        ## Put error message in the object.
        $errmsg = join '', @errmsg;
        $self->{"errormsg"} = $errmsg;
 
        ## Do the error action as described by error mode.
        $mode = $self->{"errormode"};
        if (ref($mode) eq 'CODE') {
            &$mode($errmsg);
            return;
        } elsif (ref($mode) eq 'ARRAY') {
            ($func, @args) = @$mode;
            &$func(@args);
            return;
        } elsif ($mode eq "return") {
            return;
	} elsif ($mode eq "warn") {
	    carp $errmsg;
        } else {  # die
	    croak $errmsg;
	}
    } else {
        return $self->{"errormsg"} ne '';
    }
} # end sub error


sub copy {
    my $self=shift;
    $self->{copy}=shift if @_;
    return $self->{copy};
}

sub tail {
    my $self=shift;
    $self->{"tail"}=shift if @_;
    return $self->{"tail"};
}

sub reset_tail {
    my $self=shift;
    $self->{reset_tail}=shift if @_;
    return $self->{reset_tail};
}

sub nowait {
    my $self=shift;
    $self->{nowait}=shift if @_;
    return $self->{nowait};
}

sub method {
    my $self=shift;
    $self->{method}=shift if @_;
    return $self->{method};
}

sub input {
    my $self=shift;
    $self->{input}=shift if @_;
    return $self->{input};
}

sub maxinterval {
    my $self=shift;
    $self->{maxinterval}=shift if @_;
    return $self->{maxinterval};
}

sub resetafter {
    my $self=shift;
    $self->{resetafter}=shift if @_;
    return $self->{resetafter};
}

sub ignore_nonexistant {
    my $self=shift;
    $self->{ignore_nonexistant}=shift if @_;
    return $self->{ignore_nonexistant};
}

sub name_changes {
    my $self=shift;
    $self->{name_changes_callback}=shift if @_;
    return $self->{name_changes_callback};
}

sub TIEHANDLE {
    my $ref=new(@_);
}

sub READLINE {
    $_[0]->read();
}

sub PRINT {
  $_[0]->error("PRINT makes no sense in File::Tail");
}

sub PRINTF {
  $_[0]->error("PRINTF makes no sense in File::Tail");
}

sub READ {
  $_[0]->error("READ not implemented in File::Tail -- use READLINE (<HANDLE>) instead");
}

sub GETC {
  $_[0]->error("GETC not (yet) implemented in File::Tail -- use READLINE (<HANDLE>) instead");
}

sub DESTROY {
  my($this) = $_[0];
  close($this->{"handle"}) if (defined($this) && defined($this->{'handle'}));
#  undef $_[0];
  return;
}

sub CLOSE {
    &DESTROY(@_);
}

sub new {
    my ($pkg)=shift @_;
    $pkg=ref($pkg) || $pkg;
    unless ($pkg) {
	$pkg="File::Tail";
    } 
    my %params;
    if ($#_ == 0)  {
	$params{"name"}=$_[0];
    } else {
	if (($#_ % 2) != 1) {
	    croak "Odd number of parameters for new";
	    return;
	}
	%params=@_;
    }
    my $object = {};
    bless $object,$pkg;
    unless (defined($params{'name'})) {
	croak "No file name given. Pass filename as \"name\" parameter";
	return;
    }
    $object->input($params{'name'});
    $object->copy($params{'cname'});
    $object->method($params{'method'} || "tail");
    $object->{buffer}="";
    $object->maxinterval($params{'maxinterval'} || 60);
    $object->interval($params{'interval'} || 10);
    $object->adjustafter($params{'adjustafter'} || 10);
    $object->errmode($params{'errmode'} || "die");
    $object->resetafter($params{'resetafter'} || 
			 ($object->maxinterval*$object->adjustafter));
    $object->{"debug"}=($params{'debug'} || 0);
    $object->{"tail"}=($params{'tail'} || 0);
    $object->{"nowait"}=($params{'nowait'} || 0);
    $object->{"maxbuf"}=($params{'maxbuf'} || 16384);
    $object->{"name_changes_callback"}=($params{'name_changes'} || undef);
    if (defined $params{'reset_tail'}) {
        $object->{"reset_tail"} = $params{'reset_tail'};
    } else {
        $object->{"reset_tail"} =  -1;
    }
    $object->{'ignore_nonexistant'}=($params{'ignore_nonexistant'} || 0);
    $object->{"lastread"}=0;
    $object->{"sleepcount"}=0;
    $object->{"lastcheck"}=0;
    $object->{"lastreset"}=0;
    $object->{"nextcheck"}=time();
    if ($object->{"method"} eq "tail") {
	$object->reset_pointers;
    }
#    $object->{curpos}=0;        # ADDED 25May01: undef warnings when
#    $object->{endpos}=0;        #   starting up on a nonexistant file
    return $object;
}

# Sets position in file when first opened or after that when reset:
# Sets {endpos} and {curpos} for current {handle} based on {tail}.
# Sets {tail} to value of {reset_tail}; effect is that first call 
# uses {tail} and subsequent calls use {reset_tail}.
sub position {
    my $object=shift;
    $object->{"endpos"}=sysseek($object->{handle},0,SEEK_END);
    unless ($object->{"tail"}) {
	$object->{endpos}=$object->{curpos}=
	    sysseek($object->{handle},0,SEEK_END);
    } elsif ($object->{"tail"}<0) {
	$object->{endpos}=sysseek($object->{handle},0,SEEK_END);
	$object->{curpos}=sysseek($object->{handle},0,SEEK_SET);
    } else {
	my $crs=0;
	my $maxlen=sysseek($object->{handle},0,SEEK_END);
	while ($crs<$object->{"tail"}+1) {
	    my $avlen=length($object->{"buffer"})/($crs+1);
	    $avlen=80 unless $avlen;
	    my $calclen=$avlen*$object->{"tail"};
	    $calclen+=1024 if $calclen<=length($object->{"buffer"});
	    $calclen=$maxlen if $calclen>$maxlen;
	    $object->{curpos}=sysseek($object->{handle},-$calclen,SEEK_END);
	    sysread($object->{handle},$object->{"buffer"},
		    $calclen);
	    $object->{curpos}=sysseek($object->{handle},0,SEEK_CUR);
	    $crs=$object->{"buffer"}=~tr/\n//;
	    last if ($calclen>=$maxlen);
	}
	$object->{curpos}=sysseek($object->{handle},0,SEEK_CUR);
	$object->{endpos}=sysseek($object->{handle},0,SEEK_END);
	if ($crs>$object->{"tail"}) {
	    my $toskip=$crs-$object->{"tail"};
	    my $pos;
	    $pos=index($object->{"buffer"},"\n");
	    while (--$toskip) {
		$pos=index($object->{"buffer"},"\n",$pos+1);
	    }
	    $object->{"buffer"}=substr($object->{"buffer"},$pos+1);
	}
    }
    $object->{"tail"}=$object->{"reset_tail"};
}

# Tries to open or reopen the file; failure is an error unless 
# {ignore_nonexistant} is set. 
# 
# For a new file (ie, first time opened) just does some book-keeping 
# and calls position for initial position setup.  Otherwise does some 
# checks whether file has been replaced, and if so changes to the new 
# file.  (Calls position for reset setup).
#
# Always updates {lastreset} to current time.
#
sub reset_pointers {
    my $object=shift @_;
    $object->{lastreset} = time();

    my $st;

    my $oldhandle=$object->{handle};
    my $newhandle=FileHandle->new;

    my $newname;
    if ($oldhandle && $$object{'name_changes_callback'}) {
	$newname=$$object{'name_changes_callback'}();
    } else {
	$newname=$object->input;
    }

    unless (open($newhandle,"<$newname")) {
	if ($object->{'ignore_nonexistant'}) {
         # If we have an oldhandle, leave endpos and curpos to what they 
         # were, since oldhandle will still be the "current" handle elsewhere, 
         # eg, checkpending.  This also allows tailing a file which is removed 
         # but still being written to.
            if (!$oldhandle) {
                $object->{'endpos'}=0;
                $object->{'curpos'}=0;
            }
	    return;
	}
	$object->error("Error opening ".$object->input.": $!");
	$object->{'endpos'}=0 unless defined($object->{'endpos'});
	$object->{'curpos'}=0 unless defined($object->{'curpos'});
	return;
    }
    binmode($newhandle);
    
    if (defined($oldhandle)) {
	# If file has not been changed since last OK read do not do anything
	$st=stat($newhandle);
	# lastread uses fractional time, stat doesn't. This can cause false
        # negatives. 
        # If the file was changed the same second as it was last read,
        # we only reopen it if it's length has changed. The alternative is that
        # sometimes, files would be reopened needlessly, and with reset_tail
	# set to -1, we would see the whole file again.
	# Of course, if the file was removed the same second as when it was
        # last read, and replaced (within that second) with a file of equal
        # length, we're out of luck. I don't see how to fix this.
	if ($st->mtime<=int($object->{'lastread'})) {
	    if ($st->size==$object->{"curpos"}) {
		$object->{lastread} = $st->mtime; 
		return;
	    } else { 
		# will continue further to reset
	    }
	} else {
	}
	$object->{handle}=$newhandle;
	$object->position;
	$object->{lastread} = $st->mtime;
	close($oldhandle);
    } else {                  # This is the first time we are opening this file
	$st=stat($newhandle);
	$object->{handle}=$newhandle;
	$object->position;
	$object->{lastread}=$st->mtime; # for better estimate on initial read
    }
    
}


sub checkpending {
   my $object=shift @_;

   my $old_lastcheck = $object->{lastcheck};
   $object->{"lastcheck"}=time;
   unless ($object->{handle}) {
       $object->reset_pointers;
       unless ($object->{handle}) { # This try did not open the file either
	   return 0;
       }
   }
   
   $object->{"endpos"}=sysseek($object->{handle},0,SEEK_END);
   if ($object->{"endpos"}<$object->{curpos}) {  # file was truncated
       $object->position;
   } elsif (($object->{curpos}==$object->{"endpos"}) 
	       && (time()-$object->{lastread})>$object->{'resetafter'}) {
       $object->reset_pointers;
       $object->{"endpos"}=sysseek($object->{handle},0,SEEK_END);
   }

   if ($object->{"endpos"}-$object->{curpos}) {
       sysseek($object->{handle},$object->{curpos},SEEK_SET);
       readin($object,$object->{"endpos"}-$object->{curpos});
   }
   return ($object->{"endpos"}-$object->{curpos});
}

sub predict {
    my $object=shift;
    my $crs=$object->{"buffer"}=~tr/\n//; # Count newlines in buffer 
    my @call=caller(1);
    return 0 if $crs;
    my $ttw=$object->{"nextcheck"}-time();
    return $ttw if $ttw>0;
    if (my $len=$object->checkpending) {
	readin($object,$len);
	return 0;
    }
    if ($object->{"sleepcount"}>$object->adjustafter) {
	$object->{"sleepcount"}=0;
	$object->interval($object->interval*10);
    }
    $object->{"sleepcount"}++;
    $object->{"nextcheck"}=time()+$object->interval;
    return ($object->interval);
}

sub bitprint {
    return "undef" unless defined($_[0]);
    return unpack("b*",$_[0]);
}

sub select {
    my $object=shift @_  if ref($_[0]);
    my ($timeout,@fds)=splice(@_,3);
    $object=$fds[0] unless defined($object);
    my ($savein,$saveout,$saveerr)=@_;
    my ($minpred,$mustreturn);
    if (defined($timeout)) {
	$minpred=$timeout;
	$mustreturn=time()+$timeout;
    } else {
	$minpred=$fds[0]->predict;
    }
    foreach (@fds) {
	my $val=$_->predict;
	$minpred=$val if $minpred>$val;
    }
    my ($nfound,$timeleft);
    my @retarr;
    while (defined($timeout)?(!$nfound && (time()<$mustreturn)):!$nfound) {
# Restore bitmaps in case we called select before
	splice(@_,0,3,$savein,$saveout,$saveerr);


	($nfound,$timeleft)=select($_[0],$_[1],$_[2],$minpred);


	if (defined($timeout)) {
	    $minpred=$timeout;
	} else {
	    $minpred=$fds[0]->predict;
	}
	undef @retarr;
	foreach (@fds) {
	    my $val=$_->predict;
	    $nfound++ unless $val;
	    $minpred=$val if $minpred>$val;
	    push(@retarr,$_) unless $val;
	}
    }
    if (wantarray) {
	return ($nfound,$timeleft,@retarr);
    } else {
	return $nfound;
    }
}

sub readin {
    my $crs;
    my ($object,$len)=@_;
    if (length($object->{"buffer"})) {
	# this means the file was reset AND a tail -n was active
	$crs=$object->{"buffer"}=~tr/\n//; # Count newlines in buffer 
	return $crs if $crs;
    }
    $len=$object->{"maxbuf"} if ($len>$object->{"maxbuf"});
    my $nlen=$len;
    while ($nlen>0) {
	$len=sysread($object->{handle},$object->{"buffer"},
		     $nlen,length($object->{"buffer"}));
	return 0 if $len==0; # Some busy filesystems return 0 sometimes, 
                             # and never give anything more from then on if 
                             # you don't give them time to rest. This return 
                             # allows File::Tail to use the usual exponential 
                             # backoff.
	$nlen=$nlen-$len;
    }
    $object->{curpos}=sysseek($object->{handle},0,SEEK_CUR);
    
    $crs=$object->{"buffer"}=~tr/\n//;
    
    if ($crs) {
	my $tmp=time;
	$object->{lastread}=$tmp if $object->{lastread}>$tmp; #???
	$object->interval(($tmp-($object->{lastread}))/$crs);
	$object->{lastread}=$tmp;
    }
    return ($crs);
}

sub read {
    my $object=shift @_;
    my $len;
    my $pending=$object->{"endpos"}-$object->{"curpos"};
    my $crs=$object->{"buffer"}=~m/\n/;
    while (!$pending && !$crs) {
	$object->{"sleepcount"}=0;
	while ($object->predict) {
	    if ($object->nowait) {
		if (wantarray) {
		    return ();
		} else {
		    return "";
		}
	    }
	    sleep($object->interval) if ($object->interval>0);
	}
	$pending=$object->{"endpos"}-$object->{"curpos"};
	$crs=$object->{"buffer"}=~m/\n/;
    }
    
    if (!length($object->{"buffer"}) || index($object->{"buffer"},"\n")<0) {
	readin($object,$pending);
    }
    unless (wantarray) {
	my $str=substr($object->{"buffer"},0,
		       1+index($object->{"buffer"},"\n"));
	$object->{"buffer"}=substr($object->{"buffer"},
				   1+index($object->{"buffer"},"\n"));
	return $str;
    } else {
	my @str;
	while (index($object->{"buffer"},"\n")>-1) {
	    push(@str,substr($object->{"buffer"},0,
			     1+index($object->{"buffer"},"\n")));
	    $object->{"buffer"}=substr($object->{"buffer"},
				       1+index($object->{"buffer"},"\n"));

	}
	return @str;
    }
}

1;
