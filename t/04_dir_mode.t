#!perl
#===============================================================================
#
# 04_dir_mode.t
#
# DESCRIPTION
#   Test program to check getting directory mode.
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
    plan tests => 9;                    # Number of tests to be executed
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

                                        # Tests 2-5: Check stat() functions
    chmod 0777, $dir;
    @cstats = CORE::stat $dir;
    @rstats = Win32::UTCFileTime::stat $dir;
    @astats = Win32::UTCFileTime::alt_stat($dir);
    ok($rstats[2] == $cstats[2]);
    ok($astats[2] == $cstats[2]);

    chmod 0444, $dir;
    @cstats = CORE::stat $dir;
    @rstats = Win32::UTCFileTime::stat $dir;
    @astats = Win32::UTCFileTime::alt_stat($dir);
    ok($rstats[2] == $cstats[2]);
    ok($astats[2] == $cstats[2]);

                                        # Tests 6-9: Check lstat() functions
    chmod 0777, $dir;
    @cstats = CORE::lstat $dir;
    @rstats = Win32::UTCFileTime::lstat $dir;
    @astats = Win32::UTCFileTime::alt_stat($dir);
    ok($rstats[2] == $cstats[2]);
    ok($astats[2] == $cstats[2]);

    chmod 0444, $dir;
    @cstats = CORE::lstat $dir;
    @rstats = Win32::UTCFileTime::lstat $dir;
    @astats = Win32::UTCFileTime::alt_stat($dir);
    ok($rstats[2] == $cstats[2]);
    ok($astats[2] == $cstats[2]);

    chmod 0777, $dir;
    rmdir $dir;
}

#===============================================================================
