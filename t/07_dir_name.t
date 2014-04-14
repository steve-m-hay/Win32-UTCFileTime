#!perl
#===============================================================================
#
# t/07_dir_name.t
#
# DESCRIPTION
#   Test script to check getting info for various directory names.
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

use File::Spec;
use Test;

#===============================================================================
# INITIALISATION
#===============================================================================

BEGIN {
    plan tests => 22;                   # Number of tests to be executed
}

use Win32::UTCFileTime;

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
                                        # Test 1: Did we make it this far OK?
    ok(1);

    my $dir   =  File::Spec->rel2abs(File::Spec->curdir());
    my $drive = (File::Spec->splitpath($dir))[0];

    my @stats;

    # NOTE: We deliberately call each function in array context, rather than in
    # scalar context as in "ok(Win32::UTCFileTime::stat ...)", to exercise all
    # the features of each function.  (Some code is skipped when they are called
    # in scalar context.)

                                        # Tests 2-4: Check "drive:"
    $drive =~ s/[\\\/]$//;
    ok(@stats = Win32::UTCFileTime::stat $drive);
    ok(@stats = Win32::UTCFileTime::lstat $drive);
    ok(@stats = Win32::UTCFileTime::alt_stat($drive));

                                        # Tests 5-7: Check "drive:."
    ok(@stats = Win32::UTCFileTime::stat "$drive.");
    ok(@stats = Win32::UTCFileTime::lstat "$drive.");
    ok(@stats = Win32::UTCFileTime::alt_stat("$drive."));

                                        # Tests 8-10: Check "drive:\\"
    ok(@stats = Win32::UTCFileTime::stat "$drive\\");
    ok(@stats = Win32::UTCFileTime::lstat "$drive\\");
    ok(@stats = Win32::UTCFileTime::alt_stat("$drive\\"));

                                        # Tests 11-13: Check "drive:/"
    ok(@stats = Win32::UTCFileTime::stat "$drive/");
    ok(@stats = Win32::UTCFileTime::lstat "$drive/");
    ok(@stats = Win32::UTCFileTime::alt_stat("$drive/"));

                                        # Tests 14-16: Check "dir"
    $dir =~ s/[\\\/]$//;
    ok(@stats = Win32::UTCFileTime::stat $dir);
    ok(@stats = Win32::UTCFileTime::lstat $dir);
    ok(@stats = Win32::UTCFileTime::alt_stat($dir));

                                        # Tests 17-19: Check "dir\\"
    ok(@stats = Win32::UTCFileTime::stat "$dir\\");
    ok(@stats = Win32::UTCFileTime::lstat "$dir\\");
    ok(@stats = Win32::UTCFileTime::alt_stat("$dir\\"));

                                        # Tests 20-22: Check "dir/"
    ok(@stats = Win32::UTCFileTime::stat "$dir/");
    ok(@stats = Win32::UTCFileTime::lstat "$dir/");
    ok(@stats = Win32::UTCFileTime::alt_stat("$dir/"));
}

#===============================================================================
