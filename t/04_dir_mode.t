#!perl
#-------------------------------------------------------------------------------
# Copyright (c) 2003, Steve Hay. All rights reserved.
#
# Module Name:  Win32::UTCFileTime
# Source File:  04_dir_mode.t
# Description:  Test program to check getting directory mode
#-------------------------------------------------------------------------------

use 5.006;

use strict;
use warnings;

use Test;

BEGIN {
    plan tests => 9;                    # Number of tests to be executed
};

use Win32::UTCFileTime;

#-------------------------------------------------------------------------------
#
# Main program.
#

MAIN: {
    my( $dir,                           # Test directory
        @cstats,                        # Return array from core stat()
        @rstats,                        # Return array from replacement stat()
        @astats                         # Return array from alternative stat()
        );

                                        # Test 1: Did we make it this far OK?
    ok(1);

    $dir = 'test';

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

#-------------------------------------------------------------------------------

