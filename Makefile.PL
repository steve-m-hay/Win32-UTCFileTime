#!perl
#-------------------------------------------------------------------------------
# Copyright (c) 2003, Steve Hay. All rights reserved.
#
# Module Name:  Win32::UTCFileTime
# Source File:  Makefile.PL
# Description:  Makefile creation program
#-------------------------------------------------------------------------------

use 5.006;

use strict;
use warnings;

use Config;
use ExtUtils::MakeMaker;

BEGIN {
    unless ($Config{osname} =~ /MSWin32/i and $Config{cc} =~ /cl/i) {
        die "This module requires Microsoft Visual C to build.\n";
    }
}

#-------------------------------------------------------------------------------
#
# Main program.
#

MAIN: {
    WriteMakefile(
        NAME            => 'Win32::UTCFileTime',

        ABSTRACT_FROM   => 'UTCFileTime.pm',

        AUTHOR          => 'Steve Hay <shay@cpan.org>',

        VERSION_FROM    => 'UTCFileTime.pm',

        PREREQ_PM       => {
            Carp            => 0,
            Exporter        => 0,
            'File::Spec'    => 0,       # Only used by test suite
            Test            => 0,       # Only used by test suite
            XSLoader        => 0
        },

        dist            => {
            DIST_CP     => 'cp'
        }
    );

    if  (eval { require ExtUtils::Constant; 1 }) {
        ExtUtils::Constant::WriteConstants(
            NAME            => 'Win32::UTCFileTime',

            NAMES           => [ qw(
                SEM_FAILCRITICALERRORS
                SEM_NOGPFAULTERRORBOX
                SEM_NOALIGNMENTFAULTEXCEPT
                SEM_NOOPENFILEERRORBOX
            ) ],

            DEFAULT_TYPE    => 'IV',

            C_FILE          => 'const-c.inc',

            XS_FILE         => 'const-xs.inc'
        );
    }
    else {
        require File::Copy;
        require File::Spec;

        foreach my $file ('const-c.inc', 'const-xs.inc') {
            my $fallback_file = File::Spec->catfile('fallback', $file);
            File::Copy::copy($fallback_file, $file) or
                die "Can't copy '$fallback_file' to '$file': $!.\n";
        }
    }
}

#-------------------------------------------------------------------------------
