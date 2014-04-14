#!perl
#===============================================================================
#
# t/01_file_times.t
#
# DESCRIPTION
#   Test script to check getting/setting file times.
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
    plan tests => 17;                   # Number of tests to be executed
}

use Win32::UTCFileTime;

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
                                        # Test 1: Did we make it this far OK?
    ok(1);

    my $file = 'test.txt';

    my($fh, $time, @stats, @lstats, @alt_stats);

                                        # Tests 2-3: Check stat()
    unlink $file or die "Can't delete file '$file': $!\n" if -e $file;
    open $fh, ">$file" or die "Can't create file '$file': $!\n";
    close $fh;
    $time  = time;
    @stats = stat $file;
    ok(@stats);
    # Don't check $stats[8] (last access time): not stored on FAT.
    # Allow for 2 second granularity on FAT.
    ok(abs($time - $stats[9]) < 3);
    # Don't check $stats[10] (creation time): often gets cached value.

                                        # Tests 4-5: Check lstat()
    unlink $file or die "Can't delete file '$file': $!\n" if -e $file;
    open $fh, ">$file" or die "Can't create file '$file': $!\n";
    close $fh;
    $time   = time;
    @lstats = lstat $file;
    ok(@lstats);
    # Don't check $lstats[8] (last access time): not stored on FAT.
    # Allow for 2 second granularity on FAT.
    ok(abs($time - $lstats[9]) < 3);
    # Don't check $lstats[10] (creation time): often gets cached value.

                                        # Tests 6-7: Check alt_stat()
    unlink $file or die "Can't delete file '$file': $!\n" if -e $file;
    open $fh, ">$file" or die "Can't create file '$file': $!\n";
    close $fh;
    $time   = time;
    @alt_stats = Win32::UTCFileTime::alt_stat($file);
    ok(@alt_stats);
    # Don't check $alt_stats[8] (last access time): not stored on FAT.
    # Allow for 2 second granularity on FAT.
    ok(abs($time - $alt_stats[9]) < 3);
    # Don't check $alt_stats[10] (creation time): often gets cached value.

                                        # Tests 8-17: Check utime()
    unlink $file or die "Can't delete file '$file': $!\n" if -e $file;
    open $fh, ">$file" or die "Can't create file '$file': $!\n";
    close $fh;
    $time = time;
    foreach my $age (5000000, 10000000, 15000000, 20000000, 25000000) {
        my $utime = $time - $age;
        ok(utime $utime, $utime, $file);
        @stats = stat $file;
        # Don't check $stats[8] (last access time): not stored on FAT.
        # Allow for 2 second granularity on FAT.
        ok(abs($utime - $stats[9]) < 3);
        # Don't check $stats[10] (creation time): not set by utime().
    }

    unlink $file;
}

#===============================================================================
