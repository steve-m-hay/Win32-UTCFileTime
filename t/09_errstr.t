#!perl
#===============================================================================
#
# t/09_errstr.t
#
# DESCRIPTION
#   Test script to check $ErrStr variable.
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
    plan tests => 9;                    # Number of tests to be executed
}

use Win32::UTCFileTime qw(:DEFAULT $ErrStr);

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
                                        # Test 1: Did we make it this far OK?
    ok(1);

    my $file = 'test.txt';

    my $fh;

                                        # Tests 2-9: Check $ErrStr
    open $fh, ">$file";
    close $fh;

    stat $file;
    ok($ErrStr eq '');

    unlink $file;

    stat $file;
    ok($ErrStr =~ /^Can't stat file '\Q$file\E'/);

    open $fh, ">$file";
    close $fh;

    lstat $file;
    ok($ErrStr eq '');

    unlink $file;

    lstat $file;
    ok($ErrStr =~ /^Can't stat link '\Q$file\E'/);

    open $fh, ">$file";
    close $fh;

    Win32::UTCFileTime::alt_stat($file);
    ok($ErrStr eq '');

    unlink $file;

    Win32::UTCFileTime::alt_stat($file);
    ok($ErrStr =~ /^Can't open file '\Q$file\E' for reading/);

    open $fh, ">$file";
    close $fh;

    utime undef, undef, $file;
    ok($ErrStr eq '');

    unlink $file;

    utime undef, undef, $file;
    ok($ErrStr =~ /^Can't open file '\Q$file\E' for updating/);

    unlink $file;
}

#===============================================================================
