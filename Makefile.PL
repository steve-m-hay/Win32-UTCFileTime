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

use inc::Module::Install;

#===============================================================================
# INITIALISATION
#===============================================================================

BEGIN {
    unless ($^O =~ /MSWin32/i) {
        die qq{This module requires a "native" (i.e. non-Cygwin) Microsoft } .
            qq{Windows platform.\n};
    }
}

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
    name          ('Win32-UTCFileTime');
    abstract_from ('lib/Win32/UTCFileTime.pm');
    version_from  ('lib/Win32/UTCFileTime.pm');
    author        ('Steve Hay <shay@cpan.org>');
    license       ('perl');
    perl_version  (5.006000);
    clean_files   ('const-c.inc const-xs.inc');

    WriteMakefile(
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
