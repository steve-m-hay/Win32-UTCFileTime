#!perl
#===============================================================================
#
# t/03_file_mode.t
#
# DESCRIPTION
#   Test program to check getting file mode.
#
# COPYRIGHT
#   Copyright (c) 2003-2004, Steve Hay.  All rights reserved.
#
# LICENCE
#   You may distribute under the terms of either the GNU General Public License
#   or the Artistic License, as specified in the LICENCE file.
#
#===============================================================================

use 5.006000;

use strict;
use warnings;

use Test;

#===============================================================================
# INITIALISATION
#===============================================================================

BEGIN {
    plan tests => 41;                   # Number of tests to be executed
}

use Win32::UTCFileTime;

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
                                        # Test 1: Did we make it this far OK?
    ok(1);

    my @files = map { "test.$_" } qw(txt exe bat com cmd);

    my(@cstats, @rstats, @astats);

    foreach my $file (@files) {
        open my $fh, ">$file" or die "Can't create file '$file': $!\n";
        close $fh;
    }

                                        # Tests 2-21: Check stat() functions
    foreach my $file (@files) {
        chmod 0777, $file;
        @cstats = CORE::stat $file;
        @rstats = Win32::UTCFileTime::stat $file;
        @astats = Win32::UTCFileTime::alt_stat($file);
        ok($rstats[2] == $cstats[2]);
        ok($astats[2] == $cstats[2]);

        chmod 0444, $file;
        @cstats = CORE::stat $file;
        @rstats = Win32::UTCFileTime::stat $file;
        @astats = Win32::UTCFileTime::alt_stat($file);
        ok($rstats[2] == $cstats[2]);
        ok($astats[2] == $cstats[2]);
    }

                                        # Tests 22-41: Check lstat() functions
    foreach my $file (@files) {
        chmod 0777, $file;
        @cstats = CORE::lstat $file;
        @rstats = Win32::UTCFileTime::lstat $file;
        @astats = Win32::UTCFileTime::alt_stat($file);
        ok($rstats[2] == $cstats[2]);
        ok($astats[2] == $cstats[2]);

        chmod 0444, $file;
        @cstats = CORE::lstat $file;
        @rstats = Win32::UTCFileTime::lstat $file;
        @astats = Win32::UTCFileTime::alt_stat($file);
        ok($rstats[2] == $cstats[2]);
        ok($astats[2] == $cstats[2]);
    }

    foreach my $file (@files) {
        chmod 0777, $file;
        unlink $file;
    }
}

#===============================================================================
