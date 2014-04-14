/*============================================================================
 *
 * UTCFileTime.xs
 *
 * DESCRIPTION
 *   C and XS portions of Win32::UTCFileTime module.
 *
 * COPYRIGHT
 *   Copyright (C) 2003-2005 Steve Hay.  All rights reserved.
 *   Portions Copyright (C) 2001 Jonathan M Gilligan.  Used with permission.
 *   Portions Copyright (C) 2001 Tony M Hoyle.  Used with permission.
 *
 * LICENCE
 *   You may distribute under the terms of either the GNU General Public License
 *   or the Artistic License, as specified in the LICENCE file.
 *
 *============================================================================*/

/*============================================================================
 * C CODE SECTION
 *============================================================================*/

#include <direct.h>                     /* For _getdrive().                   */
#include <errno.h>                      /* For EACCES.                        */
#include <fcntl.h>                      /* For the O_* flags.                 */
#include <io.h>                         /* For _get_osfhandle().              */
#include <stdlib.h>                     /* For errno.                         */
#include <string.h>                     /* For the str*() functions.          */
#include <sys/types.h>                  /* For struct stat.                   */
#include <sys/stat.h>                   /* For struct stat.                   */

#define WIN32_LEAN_AND_MEAN             /* Don't pull in too much crap when   */
                                        /* including <windows.h> next.        */
#include <windows.h>                    /* For the Win32 API stuff.           */

#define PERL_NO_GET_CONTEXT             /* See the "perlguts" manpage.        */

#include "patchlevel.h"                 /* Get the version numbers first.     */

#if(PERL_REVISION == 5 && PERL_VERSION > 6)
#  define PERLIO_NOT_STDIO 0            /* See the "perlapio" manpage.        */
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "const-c.inc"

#define MY_CXT_KEY "Win32::UTCFileTime::_guts" XS_VERSION

typedef struct {
    int saved_errno;
    DWORD saved_error;
    char err_str[BUFSIZ];
} my_cxt_t;

START_MY_CXT

/* Macros to save and restore the value of the standard C library errno variable
 * and the Win32 API last-error code for use when cleaning up before returning
 * failure. */
#define WIN32_UTCFILETIME_SAVE_ERRS    STMT_START { \
    MY_CXT.saved_errno = errno;                     \
    MY_CXT.saved_error = GetLastError();            \
} STMT_END
#define WIN32_UTCFILETIME_RESTORE_ERRS STMT_START { \
    errno = MY_CXT.saved_errno;                     \
    SetLastError(MY_CXT.saved_error);               \
} STMT_END

#define WIN32_UTCFILETIME_SYS_ERR_STR (strerror(errno))
#define WIN32_UTCFILETIME_WIN_ERR_STR \
    (Win32UTCFileTime_StrWinError(aTHX_ aMY_CXT_ GetLastError()))

#define WIN32_UTCFILETIME_MAX_FS      32

#define WIN32_UTCFILETIME_ISSLASH(c)  ((c) == '\\' || (c) == '/')
#define WIN32_UTCFILETIME_ISUTCFS(fs) (!instr(fs, "FAT"))

static BOOL Win32UTCFileTime_IsWinNT(pTHX_ pMY_CXT);
static BOOL Win32UTCFileTime_IsUTCVolume(pTHX_ pMY_CXT_ const char *name);
static BOOL Win32UTCFileTime_IsLeapYear(WORD year);
static int Win32UTCFileTime_CompareTargetDate(const SYSTEMTIME *p_test_date,
    const SYSTEMTIME *p_target_date);
static LONG Win32UTCFileTime_GetTimeZoneBias(pTHX_ pMY_CXT_
    const SYSTEMTIME *st);
static BOOL Win32UTCFileTime_FileTimeToUnixTime(pTHX_ pMY_CXT_
    const FILETIME *ft, time_t *ut, const BOOL ft_is_local);
static BOOL Win32UTCFileTime_UnixTimeToFileTime(pTHX_ pMY_CXT_ const time_t ut,
    FILETIME *ft, const BOOL ft_is_local);
static BOOL Win32UTCFileTime_FileTimesToUnixTimes(pTHX_ pMY_CXT_
    const char *name, const FILETIME *atime_ft, const FILETIME *mtime_ft,
    const FILETIME *ctime_ft, time_t *u_atime_t, time_t *u_mtime_t,
    time_t *u_ctime_t);
static unsigned short Win32UTCFileTime_FileAttributesToUnixMode(pTHX_ pMY_CXT_
    const DWORD fa, const char *name);
static int Win32UTCFileTime_AltStat(pTHX_ pMY_CXT_ const char *name,
    struct stat *st_buf);
static BOOL Win32UTCFileTime_GetUTCFileTimes(pTHX_ pMY_CXT_ const char *name,
    time_t *u_atime_t, time_t *u_mtime_t, time_t *u_ctime_t);
static BOOL Win32UTCFileTime_SetUTCFileTimes(pTHX_ pMY_CXT_ const char *name,
    const time_t u_atime_t, const time_t u_mtime_t);
static char *Win32UTCFileTime_StrWinError(pTHX_ pMY_CXT_ DWORD err_num);
static void Win32UTCFileTime_SetErrStr(pTHX_ const char *value, ...);

/* Number of days in each month. */
static const WORD win32_utcfiletime_days_in_month[12] = {
    31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};

/* Number of "clunks" (100-nanosecond intervals) in one second. */
static const ULONGLONG win32_utcfiletime_clunks_per_second = 10000000L;

/* The epoch of time_t values (00:00:00 Jan 01 1970 UTC) as a SYSTEMTIME. */
static const SYSTEMTIME win32_utcfiletime_base_st = {
    1970,    /* wYear         */
    1,       /* wMonth        */
    0,       /* wDayOfWeek    */
    1,       /* wDay          */
    0,       /* wHour         */
    0,       /* wMinute       */
    0,       /* wSecond       */
    0        /* wMilliseconds */
};

/* The epoch of time_t values (00:00:00 Jan 01 1970 UTC) as a FILETIME.  This is
 * set at boot time from the SYSTEMTIME above and is not subsequently changed,
 * so is virtually a "const" and is therefore thread-safe. */
static FILETIME win32_utcfiletime_base_ft;

/*
 * Function to determine whether or not the operating system platform is Windows
 * NT (as opposed to Win32s, Windows [95/98/ME] or Windows CE).
 */

static BOOL Win32UTCFileTime_IsWinNT(pTHX_ pMY_CXT) {
    /* These statics are set "on demand" and are not subsequently changed, so
     * are virtually "consts"s and are therefore thread-safe. */
    static BOOL initialized = FALSE;
    static BOOL is_winnt;
    OSVERSIONINFO osver;

    if (!initialized) {
        Zero(&osver, 1, OSVERSIONINFO);
        osver.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
        if (GetVersionEx(&osver)) {
            is_winnt = (osver.dwPlatformId == VER_PLATFORM_WIN32_NT);
        }
        else {
            warn("Can't determine operating system platform: %s.  Assuming the "
                 "platform is Windows NT", WIN32_UTCFILETIME_WIN_ERR_STR);
            is_winnt = TRUE;
        }
        initialized = TRUE;
    }

    return is_winnt;
}

/*
 * Function to determine whether or not file times are stored as UTC in the
 * filesystem that a given file is stored in.
 *
 * This function is based on code written by Tony M Hoyle.
 */

static BOOL Win32UTCFileTime_IsUTCVolume(pTHX_ pMY_CXT_ const char *name) {
    size_t len = strlen(name);
    char szFs[WIN32_UTCFILETIME_MAX_FS];

    if (len >= 2 && isALPHA(name[0]) && name[1] == ':') {
        /* An absolute path with a drive letter is specified. */
        char root[4] = "?:\\";
        root[0] = name[0];

        if (GetVolumeInformation(root, NULL, 0, NULL, NULL, NULL, szFs,
                sizeof szFs))
        {
            return WIN32_UTCFILETIME_ISUTCFS(szFs);
        }
        else {
            warn("Can't determine name of filesystem: %s.  Assuming file times "
                 "are stored as UTC-based values",
                 WIN32_UTCFILETIME_WIN_ERR_STR);
            return TRUE;
        }
    }
    else if (len >= 5 && WIN32_UTCFILETIME_ISSLASH(name[0]) &&
            WIN32_UTCFILETIME_ISSLASH(name[1]))
    {
        /* An absolute path with a UNC share (the minimum length of which is 5,
         * as in \\x\y) is specified.  We assume that the filesystem is NTFS,
         * and hence stores UTC file times, in this case. */
        return TRUE;
    }
    else {
        /* A relative path, or something invalid, is specified.  We examine the
         * filesystem of the current directory in this case. */
        if (GetVolumeInformation(NULL, NULL, 0, NULL, NULL, NULL, szFs,
                sizeof szFs))
        {
            return WIN32_UTCFILETIME_ISUTCFS(szFs);
        }
        else {
            warn("Can't determine name of filesystem: %s.  Assuming file times "
                 "are stored as UTC-based values",
                 WIN32_UTCFILETIME_WIN_ERR_STR);
            return TRUE;
        }
    }
}

/*
 * Function to determine whether or not a given year is a leap year, according
 * to the standard Gregorian rule (namely, every year divisible by 4 except
 * centuries indivisble by 400).
 *
 * This function is based on code written by Jonathan M Gilligan.
 */

static BOOL Win32UTCFileTime_IsLeapYear(WORD year) {
    return ( ((year & 3u) == 0) &&
             ((year % 100u == 0) || (year % 400u == 0)) );
}

/*
 * Function to compare a test date against a target date.  The target date must
 * be specified in the day-in-month format, rather than the absolute format,
 * used by the StandardDate and DaylightDate members of a TIME_ZONE_INFORMATION
 * structure.
 * If the test date is earlier than the target date, it returns a negative
 * number.  If the test date is later than the target date, it returns a
 * positive number.  If the test date equals the target date, it returns zero.
 * Specifically, it returns:
 * -4/+4 if the test month is less than/greater than the target month;
 * -2/+2 if the test day   is less than/greater than the target day;
 * -1/+1 if the test time  is less than/greater than the target time;
 *   0   if the test date            equals          the target date.
 *
 * This function is based on code written by Jonathan M Gilligan.
 */

static int Win32UTCFileTime_CompareTargetDate(const SYSTEMTIME *test_st,
    const SYSTEMTIME *target_st)
{
    /* Check that the given dates are in the correct format. */
    if (test_st->wYear == 0)
        croak("The test date used in a date comparison is not in the "
              "required \"absolute\" format");
    if (target_st->wYear != 0)
        croak("The target date used in a date comparison is not in the "
              "required \"day-in-month\" format");

    if (test_st->wMonth != target_st->wMonth) {
        /* The months are different. */

        return (test_st->wMonth > target_st->wMonth) ? 4 : -4;
    }
    else {
        /* The months are the same. */

        WORD first_dow;
        WORD temp_dom;
        WORD last_dom;
        int test_ms;
        int target_ms;

        /* If w is the day-of-the-week of some arbitrary day-of-the-month x then
         * the day-of-the-week of the first day-of-the-month is given by
         * ((1 + w - x) mod 7). */
        first_dow = (WORD)((1u + test_st->wDayOfWeek - test_st->wDay) % 7u);

        /* If y is the day-of-the-week of the first day-of-the-month then
         * the day-of-the-month of the first day-of-the-week z is given by
         * ((1 + z - y) mod 7). */
        temp_dom = (WORD)((1u + target_st->wDayOfWeek - first_dow) % 7u);

        /* If t is the day-of-the-month of the first day-of-the-week z then
         * the day-of-the-month of the (n)th day-of-the-week z is given by
         * (t + (n - 1) * 7). */
        temp_dom = (WORD)(temp_dom + target_st->wDay * 7u);

        /* We need to handle the special case of the day-of-the-month of the
         * last day-of-the-week z.  For example, if we tried to calculate the
         * day-of-the-month of the fifth Tuesday of the month then we may have
         * overshot, and need to correct for that case.
         * Get the last day-of-the-month (with a suitable correction if it is
         * February of a leap year) and move the temp_dom that we have
         * calculated back one week at a time until it doesn't exceed that. */
        last_dom = win32_utcfiletime_days_in_month[target_st->wMonth - 1];
        if (test_st->wMonth == 2 &&
                Win32UTCFileTime_IsLeapYear(test_st->wYear))
            ++last_dom;
        while (temp_dom > last_dom)
            temp_dom -= 7;

        if (test_st->wDay != temp_dom) {
            /* The days are different. */

            return (test_st->wDay > temp_dom) ? 2 : -2;
        }
        else {
            /* The days are the same. */

            test_ms = ((test_st->wHour     * 60   +
                        test_st->wMinute)  * 60   +
                       test_st->wSecond  ) * 1000 +
                      test_st->wMilliseconds;
            target_ms = ((target_st->wHour     * 60   +
                          target_st->wMinute)  * 60   +
                         target_st->wSecond  ) * 1000 +
                        target_st->wMilliseconds;
            test_ms -= target_ms;
            return (test_ms > 0) ? 1 : (test_ms < 0) ? -1 : 0;
        }
    }
}

/*
 * Function to return the time zone bias for a given local time.  The bias is
 * the difference, in minutes, between UTC and local time: UTC = local time +
 * bias.
 *
 * This function is based on code written by Jonathan M Gilligan.
 */

static LONG Win32UTCFileTime_GetTimeZoneBias(pTHX_ pMY_CXT_
    const SYSTEMTIME *st)
{
    TIME_ZONE_INFORMATION tz;
    LONG bias;

    if (GetTimeZoneInformation(&tz) == TIME_ZONE_ID_INVALID)
        croak("Can't get time zone information: %s",
              WIN32_UTCFILETIME_WIN_ERR_STR);

    /* We only deal with cases where the transition dates between standard time
     * and daylight time are given in "day-in-month" format rather than
     * "absolute" format. */
    if (tz.DaylightDate.wYear != 0 || tz.StandardDate.wYear != 0)
        croak("Can't handle year-specific DST clues in time zone information");

    /* Get the difference between UTC and local time. */
    bias = tz.Bias;

    /* Add on the standard bias (usually 0) or the daylight bias (usually -60)
     * as appropriate for the given time. */
    if (Win32UTCFileTime_CompareTargetDate(st, &tz.DaylightDate) < 0) {
        bias += tz.StandardBias;
    }
    else if (Win32UTCFileTime_CompareTargetDate(st, &tz.StandardDate) < 0) {
        bias += tz.DaylightBias;
    }
    else {
        bias += tz.StandardBias;
    }

    return bias;
}

/*
 * Function to convert a FILETIME to a time_t.
 * The time_t will be UTC-based, so if the FILETIME is local time-based then
 * set the ft_is_local flag so that a local time adjustment can be made.
 *
 * This function is based on code written by Jonathan M Gilligan.
 */

static BOOL Win32UTCFileTime_FileTimeToUnixTime(pTHX_ pMY_CXT_
    const FILETIME *ft, time_t *ut, const BOOL ft_is_local)
{
    LONG bias = 0;
    ULARGE_INTEGER it;

    if (ft_is_local) {
        SYSTEMTIME st;

        /* Convert the FILETIME to a SYSTEMTIME, and get the bias from that. */
        if (FileTimeToSystemTime(ft, &st)) {
            bias = Win32UTCFileTime_GetTimeZoneBias(aTHX_ aMY_CXT_ &st);
        }
        else {
            Win32UTCFileTime_SetErrStr(aTHX_
                "Can't convert FILETIME to SYSTEMTIME: %s",
                WIN32_UTCFILETIME_WIN_ERR_STR
            );

            /* Do the same as mktime() in the event of failure. */
            *ut = -1;
            return FALSE;
        }
    }

    /* Convert the FILETIME (which is expressed as the number of clunks
     * since 00:00:00 Jan 01 1601 UTC) to a time_t value by subtracting the
     * FILETIME representation of the epoch of time_t values and then
     * converting clunks to seconds. */
    it.QuadPart  = ((ULARGE_INTEGER *)ft)->QuadPart;
    it.QuadPart -= ((ULARGE_INTEGER *)&win32_utcfiletime_base_ft)->QuadPart;
    it.QuadPart /= win32_utcfiletime_clunks_per_second;

    /* Add the bias (which is in minutes) to get UTC. */
    it.QuadPart += bias * 60;

    *ut = it.LowPart;
    return TRUE;
}

/*
 * Function to convert a time_t to a FILETIME.
 * The time_t is UTC-based, so if a local time-based FILETIME is required then
 * set the make_ft_local flag so that a local time adjustment can be made.
 *
 * This function is based on code written by Tony M Hoyle.
 */

static BOOL Win32UTCFileTime_UnixTimeToFileTime(pTHX_ pMY_CXT_ const time_t ut,
    FILETIME *ft, const BOOL make_ft_local)
{
    ULARGE_INTEGER it;
    LONG bias = 0;

    /* Convert the time_t value to a FILETIME (which is expressed as the
     * number of clunks since 00:00:00 Jan 01 1601 UTC) by converting
     * seconds to clunks and then adding the FILETIME representation of the
     * epoch of time_t values. */
    it.LowPart   = ut;
    it.HighPart  = 0;
    it.QuadPart *= win32_utcfiletime_clunks_per_second;
    it.QuadPart += ((ULARGE_INTEGER *)&win32_utcfiletime_base_ft)->QuadPart;

    if (make_ft_local) {
        SYSTEMTIME st;

        /* Convert the FILETIME to a SYSTEMTIME, and get the bias from that. */
        if (FileTimeToSystemTime((FILETIME *)&it, &st)) {
            bias = Win32UTCFileTime_GetTimeZoneBias(aTHX_ aMY_CXT_ &st);
        }
        else {
            Win32UTCFileTime_SetErrStr(aTHX_
                "Can't convert FILETIME to SYSTEMTIME: %s",
                WIN32_UTCFILETIME_WIN_ERR_STR
            );

            /* Set a zero FILETIME in the event of failure. */
            (*ft).dwLowDateTime  = 0;
            (*ft).dwHighDateTime = 0;
            return FALSE;
        }
    }

    /* Add the bias (which is in minutes) to get UTC. */
    it.QuadPart += bias * 60;

    *(ULARGE_INTEGER *)ft = it;
    return TRUE;
}

/*
 * Function to convert three FILETIME values (the last access time, last
 * modification time and creation time of a given file from calls to either
 * FindFirstFile() or GetFileInformationByHandle()) to time_t values.
 * The time_t values will be UTC-based, whatever filesystem the file is stored
 * in.
 *
 * This function is based on code written by Jonathan M Gilligan.
 */

static BOOL Win32UTCFileTime_FileTimesToUnixTimes(pTHX_ pMY_CXT_
    const char *name, const FILETIME *atime_ft, const FILETIME *mtime_ft,
    const FILETIME *ctime_ft, time_t *u_atime_t, time_t *u_mtime_t,
    time_t *u_ctime_t)
{
    BOOL ret;

    if (Win32UTCFileTime_IsUTCVolume(aTHX_ aMY_CXT_ name)) {
        /* The filesystem stores UTC file times.  FindFirstFile() and
         * GetFileInformationByHandle() return them to us as unadulterated UTC
         * FILETIMEs, so just convert them to time_t values to be returned. */
        ret = Win32UTCFileTime_FileTimeToUnixTime(aTHX_ aMY_CXT_
                atime_ft, u_atime_t, FALSE)              &&
              Win32UTCFileTime_FileTimeToUnixTime(aTHX_ aMY_CXT_
                      mtime_ft, u_mtime_t, FALSE)        &&
              Win32UTCFileTime_FileTimeToUnixTime(aTHX_ aMY_CXT_
                      ctime_ft, u_ctime_t, FALSE);
    }
    else {
        FILETIME l_atime_ft;
        FILETIME l_mtime_ft;
        FILETIME l_ctime_ft;

        /* The filesystem stores local file times.  FindFirstFile() and
         * GetFileInformationByHandle() return them to us as incorrectly
         * converted UTC FILETIMEs, so undo the faulty time zone conversion and
         * then redo it properly, converting to time_t values to be returned in
         * the process. */
        ret = FileTimeToLocalFileTime(atime_ft, &l_atime_ft)          &&
              FileTimeToLocalFileTime(mtime_ft, &l_mtime_ft)          &&
              FileTimeToLocalFileTime(ctime_ft, &l_ctime_ft)          &&
              Win32UTCFileTime_FileTimeToUnixTime(aTHX_ aMY_CXT_
                      &l_atime_ft, u_atime_t, TRUE)                   &&
              Win32UTCFileTime_FileTimeToUnixTime(aTHX_ aMY_CXT_
                      &l_mtime_ft, u_mtime_t, TRUE)                   && 
              Win32UTCFileTime_FileTimeToUnixTime(aTHX_ aMY_CXT_
                      &l_ctime_ft, u_ctime_t, TRUE);
    }

    return ret;
}

/*
 * Function to convert file attributes as returned by the Win32 API function
 * GetFileAttributes() into a Unix mode as stored in the st_mode field of a
 * struct stat.
 *
 * This function is based on code taken from the wnt_stat() function in CVSNT
 * (version 2.0.4) the win32_stat() function in Perl (version 5.8.0).
 */

static unsigned short Win32UTCFileTime_FileAttributesToUnixMode(pTHX_ pMY_CXT_
    const DWORD fa, const char *name)
{
    unsigned short st_mode = 0;
    size_t len;
    const char *p;

    if (fa & FILE_ATTRIBUTE_DIRECTORY)
        st_mode |= _S_IFDIR;
    else
        st_mode |= _S_IFREG;

    if (fa & FILE_ATTRIBUTE_READONLY)
        st_mode |= (  _S_IREAD       +
                     (_S_IREAD >> 3) +
                     (_S_IREAD >> 6));
    else
        st_mode |= ( (_S_IREAD | _S_IWRITE)       +
                    ((_S_IREAD | _S_IWRITE) >> 3) +
                    ((_S_IREAD | _S_IWRITE) >> 6));

    if (fa & FILE_ATTRIBUTE_DIRECTORY)
        st_mode |= (  _S_IEXEC       +
                     (_S_IEXEC >> 3) +
                     (_S_IEXEC >> 6));

    len = strlen(name);
    if (len >= 4 && (*(p = name + len - 4) == '.') &&
            (!stricmp(p, ".exe") ||  !stricmp(p, ".bat") ||
             !stricmp(p, ".com") || (!stricmp(p, ".cmd") &&
                                     Win32UTCFileTime_IsWinNT(aTHX_ aMY_CXT))))
        st_mode |= (  _S_IEXEC       +
                     (_S_IEXEC >> 3) +
                     (_S_IEXEC >> 6));

    return st_mode;
}

/*
 * Function to emulate the standard C library function stat(), setting the
 * last access time, last modification time and creation time members of the
 * given "stat" structure to UTC-based time_t values, whatever filesystem the
 * file is stored in.
 *
 * This function is based on code taken from the wnt_stat() function in CVSNT
 * (version 2.0.4) and the win32_stat() function in Perl (version 5.8.0).
 */

static int Win32UTCFileTime_AltStat(pTHX_ pMY_CXT_ const char *name,
    struct stat *st_buf)
{
    int drive;
    HANDLE hndl;
    BY_HANDLE_FILE_INFORMATION bhfi;

    /* Return an error if a wildcard has been specified. */
    if (strpbrk(name, "?*")) {
        Win32UTCFileTime_SetErrStr(aTHX_ "Wildcard in filename '%s'", name);
        errno = ENOENT;
        return -1;
    }

    Zero(&bhfi, 1, BY_HANDLE_FILE_INFORMATION);

    /* Use CreateFile(), rather than FindFirstFile() like Microsoft's stat()
     * does, for three reasons:
     * (1) It doesn't require "List Folder Contents" permission on the parent
     *     directory like FindFirstFile() does;
     * (2) It works for directories specified with a trailing slash or backslash
     *     and it works for root (drive or UNC) directories like C: and
     *     \\SERVER\SHARE, with or without a trailing slash or backslash
     *     (provided that this is a Windows NT platform and the
     *     FILE_FLAG_BACKUP_SEMANTICS flag is passed to allow directory handles
     *     to be obtained), whereas FindFirstFile() requires non-root
     *     directories to not have a trailing slash or backslash and requires
     *     root directories to have a trailing \*; and
     * (3) The BY_HANDLE_FILE_INFORMATION stucture returned by a subsequent call
     *     to GetFileInformationByHandle() contains the number of links to the
     *     file, which the WIN32_FIND_DATA structure returned by FindFirstFile()
     *     does not. */
    if ((hndl = CreateFile(name, GENERIC_READ, FILE_SHARE_READ, NULL,
            OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL)) ==
            INVALID_HANDLE_VALUE)
    {
        /* If this is a valid directory (presumably under a Windows 95 platform
         * on which the FILE_FLAG_BACKUP_SEMANTICS flag doesn't do the trick)
         * then set all the fields except st_mode to zero and return TRUE, like
         * Perl's built-in functions do in this case.  Save the Win32 API last-
         * error code from the failed CreateFile() call first in case this is
         * not a directory. */
        DWORD le = GetLastError();
        DWORD fa = GetFileAttributes(name);
        if (fa != 0xFFFFFFFF && (fa & FILE_ATTRIBUTE_DIRECTORY)) {
            Zero(st_buf, 1, struct stat);
            st_buf->st_mode =
                Win32UTCFileTime_FileAttributesToUnixMode(aTHX_ aMY_CXT_
                                                          fa, name);
            return 0;
        }
        else {
            Win32UTCFileTime_SetErrStr(aTHX_
                "Can't open file '%s' for reading: %s",
                name, Win32UTCFileTime_StrWinError(aTHX_ aMY_CXT_ le)
            );
            return -1;
        }
    }
    else {
        if (!GetFileInformationByHandle(hndl, &bhfi)) {
            Win32UTCFileTime_SetErrStr(aTHX_
                "Can't get file information for file '%s': %s",
                name, WIN32_UTCFILETIME_WIN_ERR_STR
            );
            WIN32_UTCFILETIME_SAVE_ERRS;
            CloseHandle(hndl);
            WIN32_UTCFILETIME_RESTORE_ERRS;
            return -1;
        }
        if (!CloseHandle(hndl))
            warn("Can't close file object handle '%lu' for file '%s' after "
                 "reading: %s", hndl, name, WIN32_UTCFILETIME_WIN_ERR_STR);
    }

    if (!Win32UTCFileTime_FileTimesToUnixTimes(aTHX_ aMY_CXT_ name,
            &bhfi.ftLastAccessTime, &bhfi.ftLastWriteTime, &bhfi.ftCreationTime,
            &st_buf->st_atime, &st_buf->st_mtime, &st_buf->st_ctime))
        return -1;

    st_buf->st_mode =
        Win32UTCFileTime_FileAttributesToUnixMode(aTHX_ aMY_CXT_
                                                  bhfi.dwFileAttributes, name);

    if (bhfi.nNumberOfLinks > SHRT_MAX) {
        warn("Overflow: Too many links (%lu) to file '%s'",
             bhfi.nNumberOfLinks, name);
        st_buf->st_nlink = SHRT_MAX;
    }
    else {
        st_buf->st_nlink = (short)bhfi.nNumberOfLinks;
    }

    st_buf->st_size = bhfi.nFileSizeLow;

    /* Get the drive from the name, or use the current drive. */
    if (strlen(name) >= 2 && isALPHA(name[0]) && name[1] == ':')
        drive = toLOWER(name[0]) - 'a' + 1;
    else
        drive = _getdrive();

    st_buf->st_dev = st_buf->st_rdev = (_dev_t)(drive - 1);

    st_buf->st_ino = st_buf->st_uid = st_buf->st_gid = 0;

    return 0;
}

/*
 * Function to get the last access time, last modification time and creation
 * time of a given file.
 * The values are returned expressed as UTC-based time_t values, whatever
 * filesystem the file is stored in.
 *
 * This function is based on code written by Jonathan M Gilligan.
 */

static BOOL Win32UTCFileTime_GetUTCFileTimes(pTHX_ pMY_CXT_ const char *name,
    time_t *u_atime_t, time_t *u_mtime_t, time_t *u_ctime_t)
{
    HANDLE hndl;
    WIN32_FIND_DATA wfd;
    BY_HANDLE_FILE_INFORMATION bhfi;

    /* Use FindFirstFile() like Microsoft's stat() does, rather than the more
     * obvious GetFileTime(), to avoid a problem with the latter caching UTC
     * time values on FAT volumes. */
    if ((hndl = FindFirstFile(name, &wfd)) == INVALID_HANDLE_VALUE) {
        /* FindFirstFile() will fail if the given name specifies a directory
         * with a trailing slash or backslash, or if it is a root (drive or UNC)
         * directory like C: or \\SERVER\SHARE.  CreateFile() does not have
         * these restrictions (provided that this is a Windows NT platform and
         * the FILE_FLAG_BACKUP_SEMANTICS flag is passed to allow directory
         * handles to be obtained), so try that instead if FindFirstFile()
         * failed. */
        if ((hndl = CreateFile(name, GENERIC_READ, FILE_SHARE_READ, NULL,
                OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL)) ==
                INVALID_HANDLE_VALUE)
        {
            /* This function is only ever called after a call to Perl's built-in
             * stat() or lstat() function has already succeeded on the same
             * name, so this must just be a directory under a Windows 95
             * platform on which the FILE_FLAG_BACKUP_SEMANTICS flag doesn't do
             * the trick.  Set all the file times to zero and return TRUE, like
             * Perl's built-in functions do in this case. */
            *u_atime_t = 0;
            *u_mtime_t = 0;
            *u_ctime_t = 0;
            return TRUE;
        }
        else {
            if (!GetFileInformationByHandle(hndl, &bhfi)) {
                Win32UTCFileTime_SetErrStr(aTHX_
                    "Can't get file information for file '%s': %s",
                    name, WIN32_UTCFILETIME_WIN_ERR_STR
                );
                WIN32_UTCFILETIME_SAVE_ERRS;
                CloseHandle(hndl);
                WIN32_UTCFILETIME_RESTORE_ERRS;
                return FALSE;
            }
            if (!CloseHandle(hndl))
                warn("Can't close file object handle '%lu' for file '%s' after "
                     "reading: %s", hndl, name, WIN32_UTCFILETIME_WIN_ERR_STR);
            wfd.ftLastAccessTime = bhfi.ftLastAccessTime;
            wfd.ftLastWriteTime  = bhfi.ftLastWriteTime;
            wfd.ftCreationTime   = bhfi.ftCreationTime;
        }
    }
    else {
        if (!FindClose(hndl))
            warn("Can't close file search handle '%lu' for file '%s' after "
                 "reading: %s", hndl, name, WIN32_UTCFILETIME_WIN_ERR_STR);
    }

    return Win32UTCFileTime_FileTimesToUnixTimes(aTHX_ aMY_CXT_ name,
            &wfd.ftLastAccessTime, &wfd.ftLastWriteTime, &wfd.ftCreationTime,
            u_atime_t, u_mtime_t, u_ctime_t);
}

/*
 * Function to set the last access time and last modification time of a given
 * file.
 * The values should be supplied expressed as UTC-based time_t values, whatever
 * filesystem the file is stored in.
 */

static BOOL Win32UTCFileTime_SetUTCFileTimes(pTHX_ pMY_CXT_ const char *name,
    const time_t u_atime_t, const time_t u_mtime_t)
{
    int fd;
    BOOL ret = FALSE;
    HANDLE hndl;

    /* Try opening the file normally first, like Microsoft's utime(), and hence
     * Perl's win32_utime(), does.  Note that this will fail with errno EACCES
     * if name specifies a directory or a read-only file. */
    if ((fd = PerlLIO_open(name, O_RDWR | O_BINARY)) < 0) {
        /* If name is a directory then PerlLIO_open() will fail.  However,
         * CreateFile() can open directory handles (provided that this is a
         * Windows NT platform and the FILE_FLAG_BACKUP_SEMANTICS flag is passed
         * to allow directory handles to be obtained), so try that instead like
         * Perl's win32_utime() does in case that was the cause of the failure.
         * This will (and should) still fail on read-only files. */
        if ((hndl = CreateFile(name, GENERIC_READ | GENERIC_WRITE,
                FILE_SHARE_READ | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
                FILE_FLAG_BACKUP_SEMANTICS, NULL)) == INVALID_HANDLE_VALUE)
        {
            Win32UTCFileTime_SetErrStr(aTHX_
                "Can't open file '%s' for updating: %s",
                name, WIN32_UTCFILETIME_WIN_ERR_STR
            );
            return FALSE;
        }
    }
    else if ((hndl = (HANDLE)_get_osfhandle(fd)) == INVALID_HANDLE_VALUE) {
        /* If Perl is linked against the OS's msvcrt.dll and this module is
         * linked against a recent Visual C compiler's msvcrXX.dll then the file
         * descriptor obtained by the former via PerlLIO_open() cannot be used
         * by the latter, so _get_osfhandle() will fail.  In case that is the
         * cause of the failure, we close the file descriptor and try the Win32
         * API function CreateFile() directly instead. */
        if (PerlLIO_close(fd) < 0)
            warn("Can't close file descriptor '%d' for file '%s': %s",
                 fd, name, WIN32_UTCFILETIME_SYS_ERR_STR);

        if ((hndl = CreateFile(name, GENERIC_READ | GENERIC_WRITE,
                FILE_SHARE_READ | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0,
                NULL)) == INVALID_HANDLE_VALUE)
        {
            Win32UTCFileTime_SetErrStr(aTHX_
                "Can't open file '%s' for updating: %s",
                name, WIN32_UTCFILETIME_WIN_ERR_STR
            );
            return FALSE;
        }
    }

    /* Use NULL for the creation time passed to SetFileTime() like Microsoft's
     * utime() does.  This simply means that the information is not changed.
     * There is no need to retrieve the existing value first in order to reset
     * it like Perl's win32_utime() does. */
    if (Win32UTCFileTime_IsUTCVolume(aTHX_ aMY_CXT_ name)) {
        FILETIME u_atime_ft;
        FILETIME u_mtime_ft;

        /* The filesystem stores UTC file times.  SetFileTime() will set its UTC
         * FILETIME arguments without change, so just convert the time_t values
         * to UTC FILETIMEs to be set. */
        if (Win32UTCFileTime_UnixTimeToFileTime(aTHX_ aMY_CXT_
                u_atime_t, &u_atime_ft, FALSE) &&
            Win32UTCFileTime_UnixTimeToFileTime(aTHX_ aMY_CXT_
                u_mtime_t, &u_mtime_ft, FALSE))
        {
            if (!SetFileTime(hndl, NULL, &u_atime_ft, &u_mtime_ft)) {
                Win32UTCFileTime_SetErrStr(aTHX_
                    "Can't set file times for file '%s': %s",
                    name, WIN32_UTCFILETIME_WIN_ERR_STR
                );
                ret = FALSE;
            }
            else {
                ret = TRUE;
            }
        }
        else {
            ret = FALSE;
        }
    }
    else {
        FILETIME l_atime_ft;
        FILETIME l_mtime_ft;
        FILETIME u_atime_ft;
        FILETIME u_mtime_ft;

        /* The filesystem stores local file times.  SetFileTime() will set its
         * UTC FILETIME arguments after an incorrect local time conversion, so
         * do the conversion properly first, converting the time_t values to
         * local FILETIMEs in the process, and then do an extra incorrect UTC
         * conversion ready to be undone by SetFileTime() when it sets them. */
        if (Win32UTCFileTime_UnixTimeToFileTime(aTHX_ aMY_CXT_
                u_atime_t, &l_atime_ft, TRUE)                 &&
            Win32UTCFileTime_UnixTimeToFileTime(aTHX_ aMY_CXT_
                u_mtime_t, &l_mtime_ft, TRUE)                 &&
            LocalFileTimeToFileTime(&l_atime_ft, &u_atime_ft) &&
            LocalFileTimeToFileTime(&l_mtime_ft, &u_mtime_ft))
        {
            if (!SetFileTime(hndl, NULL, &u_atime_ft, &u_mtime_ft)) {
                Win32UTCFileTime_SetErrStr(aTHX_
                    "Can't set file times for file '%s': %s",
                    name, WIN32_UTCFILETIME_WIN_ERR_STR
                );
                ret = FALSE;
            }
            else {
                ret = TRUE;
            }
        }
        else {
            ret = FALSE;
        }
    }

    if (!CloseHandle(hndl))
        warn("Can't close file object handle '%lu' for file '%s' after "
             "updating: %s", hndl, name, WIN32_UTCFILETIME_WIN_ERR_STR);

    return ret;
}

/*
 * Function to get a message string for the given Win32 API last-error code.
 * Returns a pointer to a buffer containing the string.
 * Note that the buffer is a (thread-safe) static, so subsequent calls to this
 * function from a given thread will overwrite the string.
 *
 * This function is based on the win32_str_os_error() function in Perl (version
 * 5.8.5).
 */

static char *Win32UTCFileTime_StrWinError(pTHX_ pMY_CXT_ DWORD err_num) {
    DWORD len;

    len = FormatMessage(
        FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_FROM_SYSTEM, NULL,
        err_num, 0, MY_CXT.err_str, sizeof MY_CXT.err_str, NULL
    );

    if (len > 0) {
        /* Remove the trailing newline (and any other whitespace).  Note that
         * the len returned by FormatMessage() does not include the NUL
         * terminator, so decrement len by one immediately. */
        do {
            --len;
        } while (len > 0 && isSPACE(MY_CXT.err_str[len]));

        /* Increment len by one unless the last character is a period, and then
         * add a NUL terminator, so that any trailing period is also removed. */
        if (MY_CXT.err_str[len] != '.')
            ++len;

        MY_CXT.err_str[len] = '\0';
    }
    else {
        sprintf(MY_CXT.err_str, "Unknown error #0x%lX", err_num);
    }

    return MY_CXT.err_str;
}

/*
 * Function to set the Perl module's $ErrStr variable to the given value.
 */

static void Win32UTCFileTime_SetErrStr(pTHX_ const char *value, ...) {
    va_list args;

    /* Get the Perl module's $ErrStr variable and set an appropriate value in
     * it. */
    va_start(args, value);
    sv_vsetpvf(get_sv("Win32::UTCFileTime::ErrStr", TRUE), value, &args);
    va_end(args);
}

/*============================================================================*/

MODULE = Win32::UTCFileTime PACKAGE = Win32::UTCFileTime        

#===============================================================================
# XS CODE SECTION
#===============================================================================

PROTOTYPES:   ENABLE
VERSIONCHECK: ENABLE

INCLUDE: const-xs.inc

BOOT:
{
    MY_CXT_INIT;

    /* Get the epoch of time_t values as a FILETIME.  This calculation only
     * needs to be done once, and is required by all four functions (stat(),
     * lstat(), alt_stat() and utime()), so we might as well do it here. */
    if (!SystemTimeToFileTime(&win32_utcfiletime_base_st,
            &win32_utcfiletime_base_ft))
        croak("Can't convert base SYSTEMTIME to FILETIME: %s",
              WIN32_UTCFILETIME_WIN_ERR_STR);
}

void
CLONE(...)
    PPCODE:
    {
        MY_CXT_CLONE;
    }

# Private function to expose the Win32UTCFileTime_AltStat() function above.
# This function is based on code taken from the pp_stat() function in Perl
# (version 5.8.0).

void
_alt_stat(file)
    PROTOTYPE: $

    INPUT:
        const char *file

    PPCODE:
    {
        dMY_CXT;
        U32 gimme = GIMME_V;
        struct stat st_buf;

        if (Win32UTCFileTime_AltStat(aTHX_ aMY_CXT_ file, &st_buf) == 0) {
            if (gimme == G_SCALAR) {
                XSRETURN_YES;
            }
            else if (gimme == G_ARRAY) {
                EXTEND(SP, 13);
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_dev)));
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_ino)));
                PUSHs(sv_2mortal(newSVuv((UV)st_buf.st_mode)));
                PUSHs(sv_2mortal(newSVuv((UV)st_buf.st_nlink)));
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_uid)));
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_gid)));
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_rdev)));
                PUSHs(sv_2mortal(newSVnv((NV)st_buf.st_size)));
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_atime)));
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_mtime)));
                PUSHs(sv_2mortal(newSViv((IV)st_buf.st_ctime)));
                PUSHs(sv_2mortal(newSVpvn("", 0)));
                PUSHs(sv_2mortal(newSVpvn("", 0)));
                XSRETURN(13);
            }
            else {
                XSRETURN_EMPTY;
            }
        }
        else {
            XSRETURN_EMPTY;
        }
    }

# Private function to expose the Win32UTCFileTime_GetUTCFileTimes() function
# above.

void
_get_utc_file_times(file)
    PROTOTYPE: $

    INPUT:
        const char *file;

    PPCODE:
    {
        dMY_CXT;
        time_t atime;
        time_t mtime;
        time_t ctime;

        if (Win32UTCFileTime_GetUTCFileTimes(aTHX_ aMY_CXT_
                file, &atime, &mtime, &ctime))
        {
            EXTEND(SP, 3);
            PUSHs(sv_2mortal(newSViv((IV)atime)));
            PUSHs(sv_2mortal(newSViv((IV)mtime)));
            PUSHs(sv_2mortal(newSViv((IV)ctime)));
            XSRETURN(3);
        }
        else {
            XSRETURN_EMPTY;
        }
    }

# Private function to expose the Win32UTCFileTime_SetUTCFileTimes() function
# above.

void
_set_utc_file_times(file, atime, mtime)
    PROTOTYPE: $$$

    INPUT:
        const char *file;
        const time_t atime;
        const time_t mtime;

    PPCODE:
    {
        dMY_CXT;

        if (Win32UTCFileTime_SetUTCFileTimes(aTHX_ aMY_CXT_
                file, atime, mtime)) {
            XSRETURN_YES;
        }
        else {
            XSRETURN_EMPTY;
        }
    }

# Private function to expose the Win32 API function SetErrorMode().

UINT
_set_error_mode(umode)
    PROTOTYPE: $

    INPUT:
        const UINT umode;

    CODE:
        RETVAL = SetErrorMode(umode);

    OUTPUT:
        RETVAL

#===============================================================================
