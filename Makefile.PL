#!perl
#===============================================================================
#
# Makefile.PL
#
# DESCRIPTION
#   Makefile creation script.
#
# COPYRIGHT
#   Copyright (C) 2003-2006 Steve Hay.  All rights reserved.
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

use File::Copy qw(copy);
use File::Spec::Functions qw(catfile updir);

#===============================================================================
# INITIALIZATION
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
    name           ('Win32-UTCFileTime');
    all_from       ('lib/Win32/UTCFileTime.pm');
    build_requires ('Test::More');
    features       ('POD testing' => [
        -default   => 0,
        recommends ('Test::Pod' => '1.00')
    ]);
    clean_files    ('const-c.inc const-xs.inc');

    my $obj = get_shay_private_obj();
    $obj->check_compiler(0);

    auto_install();

    WriteMakefile(
        dist => {
            DIST_CP  => 'cp',
            PREOP    => 'chmod -R a+w $(DISTVNAME) && ' .
                        'C:\\cygwin\\bin\\find $(DISTVNAME) -type f ' .
                        '-exec unix2dos {} ; && ' .
                        'chmod -R a-x+rwX,go-w $(DISTVNAME)',
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
        foreach my $file ('const-c.inc', 'const-xs.inc') {
            my $fallback_file = catfile('fallback', $file);
            copy($fallback_file, $file) or
                die "Can't copy '$fallback_file' to '$file': $!.\n";
        }
    }
}

#===============================================================================
