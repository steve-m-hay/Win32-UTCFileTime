#!perl
#-------------------------------------------------------------------------------
# Copyright (c) 2003, Steve Hay. All rights reserved.
#
# Module Name:  Win32::UTCFileTime
# Source File:  03_file_mode.t
# Description:  Test program to check getting file mode
#-------------------------------------------------------------------------------

use 5.006;

use strict;
use warnings;

use Test;

BEGIN {
    plan tests => 41;                   # Number of tests to be executed
};

use Win32::UTCFileTime;

#-------------------------------------------------------------------------------
#
# Main program.
#

MAIN: {
    my( @files,                         # Array of test files
        @cstats,                        # Return array from core stat()
        @rstats,                        # Return array from replacement stat()
        @astats                         # Return array from alternative stat()
        );

                                        # Test 1: Did we make it this far OK?
    ok(1);

    @files = map { "test.$_" } qw(txt exe bat com cmd);

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

#-------------------------------------------------------------------------------
