#!perl
#-------------------------------------------------------------------------------
# Copyright (c) 2003, Steve Hay. All rights reserved.
#
# Module Name:  Win32::UTCFileTime
# Source File:  07_dir_name.t
# Description:  Test program to check getting info for various directory names
#-------------------------------------------------------------------------------

use 5.006;

use strict;
use warnings;

use File::Spec;
use Test;

BEGIN {
    plan tests => 15;                   # Number of tests to be executed
};

use Win32::UTCFileTime;

#-------------------------------------------------------------------------------
#
# Main program.
#

MAIN: {
    my( $dir,                           # Current directory
        $drive,                         # Current drive
        @stats                          # Return array from various stat()'s
        );

                                        # Test 1: Did we make it this far OK?
    ok(1);

    $dir   =  File::Spec->rel2abs(File::Spec->curdir());
    $drive = (File::Spec->splitpath($dir))[0];

    # NOTE: We deliberately call each function in array context, rather than in
    # scalar context as in "ok(Win32::UTCFileTime::stat ...)", to exercise all
    # the features of each function. (Some code is skipped when they are called
    # in scalar context.)

                                        # Tests 2-3: Check "drive:"
    $drive =~ s/[\\\/]$//;
    ok(@stats = Win32::UTCFileTime::stat $drive);
    ok(@stats = Win32::UTCFileTime::alt_stat($drive));

                                        # Tests 4-5: Check "drive:."
    ok(@stats = Win32::UTCFileTime::stat "$drive.");
    ok(@stats = Win32::UTCFileTime::alt_stat("$drive."));

                                        # Tests 6-7: Check "drive:\\"
    ok(@stats = Win32::UTCFileTime::stat "$drive\\");
    ok(@stats = Win32::UTCFileTime::alt_stat("$drive\\"));

                                        # Tests 8-9: Check "drive:/"
    ok(@stats = Win32::UTCFileTime::stat "$drive/");
    ok(@stats = Win32::UTCFileTime::alt_stat("$drive/"));

                                        # Tests 10-11: Check "dir"
    $dir =~ s/[\\\/]$//;
    ok(@stats = Win32::UTCFileTime::stat $dir);
    ok(@stats = Win32::UTCFileTime::alt_stat($dir));

                                        # Tests 12-13: Check "dir\\"
    ok(@stats = Win32::UTCFileTime::stat "$dir\\");
    ok(@stats = Win32::UTCFileTime::alt_stat("$dir\\"));

                                        # Tests 14-15: Check "dir/"
    ok(@stats = Win32::UTCFileTime::stat "$dir/");
    ok(@stats = Win32::UTCFileTime::alt_stat("$dir/"));
}

#-------------------------------------------------------------------------------


