#!perl
#===============================================================================
#
# 09_debug.t
#
# DESCRIPTION
#   Test program to check debug variable.
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

sub _stderr(;$);

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

    my $file = 'test.txt';

    my $output;

    unlink $file or die "Can't delete file '$file': $!\n" if -e $file;

    $SIG{__WARN__} = \&_stderr;

                                        # Tests 2-9: Check $Debug
    $Win32::UTCFileTime::Debug = 0;

    _stderr(undef);
    stat $file;
    $output = _stderr();
    ok(not defined $output);

    $Win32::UTCFileTime::Debug = 1;

    _stderr(undef);
    stat $file;
    $output = _stderr();
    ok(defined $output and $output =~ /CORE::stat\(\) failed for '$file'/);

    $Win32::UTCFileTime::Debug = 0;

    _stderr(undef);
    lstat $file;
    $output = _stderr();
    ok(not defined $output);

    $Win32::UTCFileTime::Debug = 1;

    _stderr(undef);
    lstat $file;
    $output = _stderr();
    ok(defined $output and $output =~ /CORE::lstat\(\) failed for '$file'/);

    $Win32::UTCFileTime::Debug = 0;

    _stderr(undef);
    Win32::UTCFileTime::alt_stat($file);
    $output = _stderr();
    ok(not defined $output);

    $Win32::UTCFileTime::Debug = 1;

    _stderr(undef);
    Win32::UTCFileTime::alt_stat($file);
    $output = _stderr();
    ok(defined $output and $output =~ /_alt_stat\(\) failed for '$file'/);

    $Win32::UTCFileTime::Debug = 0;

    _stderr(undef);
    utime undef, undef, $file;
    $output = _stderr();
    ok(not defined $output);

    $Win32::UTCFileTime::Debug = 1;

    _stderr(undef);
    utime undef, undef, $file;
    $output = _stderr();
    ok(defined $output and $output =~ /open\(\) failed for '$file'/);
}

#===============================================================================
# SUBROUTINES
#===============================================================================

{
    my $_stderr;

    sub _stderr(;$) {
        if (@_) {
            my $msg = shift;
            if (defined $msg and defined $_stderr) {
                $_stderr .= $msg;
            }
            else {
                $_stderr  = $msg;
            }
        }

        return $_stderr;
    }
}

#===============================================================================
