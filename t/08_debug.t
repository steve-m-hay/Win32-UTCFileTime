#!perl
#-------------------------------------------------------------------------------
# Copyright (c) 2003, Steve Hay. All rights reserved.
#
# Module Name:  Win32::UTCFileTime
# Source File:  07_debug.t
# Description:  Test program to check debug variable
#-------------------------------------------------------------------------------

use 5.006;

use strict;
use warnings;

use Test;

sub _stderr(;$);

BEGIN { plan tests => 9 };              # Number of tests to be executed

use Win32::UTCFileTime;

#-------------------------------------------------------------------------------
#
# Main program.
#

MAIN: {
    my( $file,                          # Test file
        $output                         # Captured warn() output
        );

                                        # Test 1: Did we make it this far OK?
    ok(1);

    $file = 'test.txt';

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

#-------------------------------------------------------------------------------
#
# Subroutines.
#

lexicalscope: {
    my $_stderr;

    sub _stderr(;$) {
        my( $msg,                       # Optional message to store
            ) = @_;

        if (@_) {
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

1;

#-------------------------------------------------------------------------------
