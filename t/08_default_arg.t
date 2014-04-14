#!perl
#===============================================================================
#
# t/08_default_arg.t
#
# DESCRIPTION
#   Test script to check default arguments.
#
# COPYRIGHT
#   Copyright (C) 2004 Steve Hay.  All rights reserved.
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
    plan tests => 7;                    # Number of tests to be executed
}

use Win32::UTCFileTime;

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
                                        # Test 1: Did we make it this far OK?
    ok(1);

    my $file = 'test.txt';

    my($fh, @stats1, @stats2, $ok);

    open $fh, ">$file" or die "Can't create file '$file': $!\n";
    close $fh;

    @stats1 = Win32::UTCFileTime::stat $file;
    $_ = $file;
    @stats2 = Win32::UTCFileTime::stat;

                                        # Test 2: Check $_ is not changed
    ok($_ eq $file);

                                        # Test 3: Check results are the same
    if ($ok = (@stats1 == @stats2)) {
        for my $i (0 .. $#stats1) {
            if ($stats1[$i] ne $stats2[$i]) {
                $ok = 0;
                last;
            }
        }
    }
    ok($ok);

    @stats1 = Win32::UTCFileTime::lstat $file;
    $_ = $file;
    @stats2 = Win32::UTCFileTime::lstat;

                                        # Test 4: Check $_ is not changed
    ok($_ eq $file);

                                        # Test 5: Check results are the same
    if ($ok = (@stats1 == @stats2)) {
        for my $i (0 .. $#stats1) {
            if ($stats1[$i] ne $stats2[$i]) {
                $ok = 0;
                last;
            }
        }
    }
    ok($ok);

    @stats1 = Win32::UTCFileTime::alt_stat($file);
    $_ = $file;
    @stats2 = Win32::UTCFileTime::alt_stat;

                                        # Test 5: Check $_ is not changed
    ok($_ eq $file);

                                        # Test 7: Check results are the same
    if ($ok = (@stats1 == @stats2)) {
        for my $i (0 .. $#stats1) {
            if ($stats1[$i] ne $stats2[$i]) {
                $ok = 0;
                last;
            }
        }
    }
    ok($ok);

    unlink $file;
}

#===============================================================================
