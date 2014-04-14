#!perl
#===============================================================================
#
# Makefile.PL
#
# DESCRIPTION
#   Makefile creation program.
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

use Config;
use ExtUtils::MakeMaker;

#===============================================================================
# INITIALISATION
#===============================================================================

BEGIN {
    unless ($Config{osname} =~ /MSWin32/i and $Config{cc} =~ /cl/i) {
        die "This module requires Microsoft Visual C to build.\n";
    }
}

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
    WriteMakefile(
        NAME          => 'Win32::UTCFileTime',

        ABSTRACT_FROM => 'lib/Win32/UTCFileTime.pm',

        VERSION_FROM  => 'lib/Win32/UTCFileTime.pm',

        AUTHOR        => 'Steve Hay <shay@cpan.org>',

        PREREQ_PM => {
            Carp         => 0,
            Exporter     => 0,
            'File::Spec' => 0,          # Only used by test suite
            Test         => 0,          # Only used by test suite
            XSLoader     => 0
        },

        clean => {
            FILES   => 'const-c.inc const-xs.inc'
        },

        dist => {
            DIST_CP  => 'cp',
            PREOP    => 'chmod -R a-x+rwX,go-w $(DISTVNAME)',
            COMPRESS => 'gzip -9fv',
            SUFFIX   => '.gz',
            ZIPFLAGS => '-9r'
        }
    );

    if  (eval { require ExtUtils::Constant; 1 }) {
        ExtUtils::Constant::WriteConstants(
            NAME => 'Win32::UTCFileTime',

            NAMES => [ qw(
                SEM_FAILCRITICALERRORS
                SEM_NOGPFAULTERRORBOX
                SEM_NOALIGNMENTFAULTEXCEPT
                SEM_NOOPENFILEERRORBOX
            ) ],

            DEFAULT_TYPE => 'IV',

            C_FILE => 'const-c.inc',

            XS_FILE => 'const-xs.inc'
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

#===============================================================================
