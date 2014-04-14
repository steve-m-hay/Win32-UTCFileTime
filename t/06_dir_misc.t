#!perl
#===============================================================================
#
# t/06_dir_misc.t
#
# DESCRIPTION
#   Test script to check getting miscellaneous directory info.
#
# COPYRIGHT
#   Copyright (C) 2003-2004 Steve Hay.  All rights reserved.
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
    plan tests => 37;                   # Number of tests to be executed
}

use Win32::UTCFileTime;

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
                                        # Test 1: Did we make it this far OK?
    ok(1);

    my $dir = 'test';

    my(@cstats, @rstats, @astats);

    mkdir $dir or die "Can't create directory '$dir': $!\n";

    @cstats = CORE::stat $dir;
    @rstats = Win32::UTCFileTime::stat $dir;
    @astats = Win32::UTCFileTime::alt_stat($dir);

                                        # Tests 2-3: Check "dev"
    ok($rstats[0] == $cstats[0]);
    ok($astats[0] == $cstats[0]);

                                        # Tests 4-5: Check "ino"
    ok($rstats[1] == $cstats[1]);
    ok($astats[1] == $cstats[1]);

                                        # Tests 6-7: Check "nlink"
    ok($rstats[3] == $cstats[3]);
    ok($astats[3] == $cstats[3]);

                                        # Tests 8-9: Check "uid"
    ok($rstats[4] == $cstats[4]);
    ok($astats[4] == $cstats[4]);

                                        # Tests 10-11: Check "gid"
    ok($rstats[5] == $cstats[5]);
    ok($astats[5] == $cstats[5]);

                                        # Tests 12-13: Check "rdev"
    ok($rstats[6] == $cstats[6]);
    ok($astats[6] == $cstats[6]);

                                        # Tests 14-15: Check "size"
    ok($rstats[7] == $cstats[7]);
    ok($astats[7] == $cstats[7]);

                                        # Tests 16-17: Check "blksize"
    ok($rstats[11] eq $cstats[11]);
    ok($astats[11] eq $cstats[11]);

                                        # Tests 18-19: Check "blocks"
    ok($rstats[12] eq $cstats[12]);
    ok($astats[12] eq $cstats[12]);

    @cstats = CORE::lstat $dir;
    @rstats = Win32::UTCFileTime::lstat $dir;
    @astats = Win32::UTCFileTime::alt_stat($dir);

                                        # Tests 20-21: Check "dev"
    ok($rstats[0] == $cstats[0]);
    ok($astats[0] == $cstats[0]);

                                        # Tests 22-23: Check "ino"
    ok($rstats[1] == $cstats[1]);
    ok($astats[1] == $cstats[1]);

                                        # Tests 24-25: Check "nlink"
    ok($rstats[3] == $cstats[3]);
    ok($astats[3] == $cstats[3]);

                                        # Tests 26-27: Check "uid"
    ok($rstats[4] == $cstats[4]);
    ok($astats[4] == $cstats[4]);

                                        # Tests 28-29: Check "gid"
    ok($rstats[5] == $cstats[5]);
    ok($astats[5] == $cstats[5]);

                                        # Tests 30-31: Check "rdev"
    ok($rstats[6] == $cstats[6]);
    ok($astats[6] == $cstats[6]);

                                        # Tests 32-33: Check "size"
    ok($rstats[7] == $cstats[7]);
    ok($astats[7] == $cstats[7]);

                                        # Tests 34-35: Check "blksize"
    ok($rstats[11] eq $cstats[11]);
    ok($astats[11] eq $cstats[11]);

                                        # Tests 36-37: Check "blocks"
    ok($rstats[12] eq $cstats[12]);
    ok($astats[12] eq $cstats[12]);

    rmdir $dir;
}

#===============================================================================
