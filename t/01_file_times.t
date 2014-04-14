#!perl
#-------------------------------------------------------------------------------
# Copyright (c) 2003, Steve Hay. All rights reserved.
#
# Module Name:  Win32::UTCFileTime
# Source File:  01_file_times.t
# Description:  Test program to check getting/setting file times
#-------------------------------------------------------------------------------

use 5.006;

use strict;
use warnings;

use Test;

BEGIN {
    plan tests => 17;                   # Number of tests to be executed
};

use Win32::UTCFileTime;

#-------------------------------------------------------------------------------
#
# Main program.
#

MAIN: {
    my( $file,                          # Test file
        $fh,                            # Test filehandle
        $time,                          # Scratch time
        @stats,                         # Return array from stat()
        @lstats,                        # Return array from lstat()
        @alt_stats                      # Return array from alt_stat()
        );

                                        # Test 1: Did we make it this far OK?
    ok(1);

    $file = 'test.txt';

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

#-------------------------------------------------------------------------------
