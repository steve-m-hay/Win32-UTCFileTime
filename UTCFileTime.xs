/*------------------------------------------------------------------------------
 * Copyright (c) 2003, Steve Hay. All rights reserved.
 * Portions Copyright (c) 2001, Jonathan M Gilligan. Used with permission.
 * Portions Copyright (c) 2001, Tony M Hoyle. Used with permission.
 *
 * Module Name:	Win32::UTCFileTime
 * Source File:	UTCFileTime.xs
 * Description:	C and XS code for xsubpp
 *------------------------------------------------------------------------------
 */

/*------------------------------------------------------------------------------
 *
 * C code to be copied verbatim by xsubpp.
 */

#include <stdarg.h>
#include <stdio.h>
#include <tchar.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "const-c.inc"

#define _MAX_FS 32

static BOOL IsUTCVolume(LPCTSTR name);
static BOOL IsLeapYear(WORD year);
static int CompareTargetDate(const SYSTEMTIME *p_test_date,
		const SYSTEMTIME *p_target_date);
static int GetTimeZoneBias(const SYSTEMTIME *st);
static BOOL FileTimeToUnixTime(const FILETIME *ft, time_t *ut,
		const BOOL ft_is_local);
static BOOL UnixTimeToFileTime(const time_t ut, FILETIME *ft,
		const BOOL ft_is_local);
static BOOL GetUTCFileTimes(LPCTSTR name, time_t *u_atime_t, time_t *u_mtime_t,
		time_t *u_ctime_t);
static BOOL SetUTCFileTimes(LPCTSTR name, const time_t u_atime_t,
		const time_t u_mtime_t);
static void PrintfDebug(pTHX_ const char *fmt, ...);

/*
 * Function to determine whether or not file times are stored as UTC in the
 * filesystem that a given file is stored in.
 * If the information is successfully retrieved, it returns TRUE and sets *utc.
 * Otherwise, it returns FALSE and doesn't set *utc.
 *
 * This function was originally written by Tony M Hoyle.
 */

static BOOL IsUTCVolume(
	LPCTSTR	name)
{
	_TCHAR	szDrive[_MAX_DRIVE + 1] = _T("");
	_TCHAR	szFs[_MAX_FS]           = _T("");

	_tsplitpath(name, szDrive, NULL, NULL, NULL);
	_tcscat(szDrive, _T("\\"));

	if (GetVolumeInformation(szDrive, NULL, 0, NULL, NULL, NULL, szFs,
			sizeof(szFs)))
	{
		return !(_tcsicmp(szFs, _T("NTFS")) &&
				 _tcsicmp(szFs, _T("HPFS")) &&
				 _tcsicmp(szFs, _T("OWFS")));
	}
	else {
		warn("Could not determine name of filesystem. Assuming file times "
			"are stored as UTC-based values");
		return TRUE;
	}
}

/*
 * Function to determine whether or not a given year is a leap year, according
 * to the standard Gregorian rule (namely, every year divisible by 4 except
 * centuries indivisble by 400).
 *
 * This function was originally written by Jonathan M Gilligan.
 */

static BOOL IsLeapYear(
	WORD year)
{
	return ( ((year & 3u) == 0) &&
			 ((year % 100u == 0) || (year % 400u == 0)) );
}

static const WORD days_in_month[12] = {
	31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
};

/*
 * Function to compare a test date against a target date. The target date must
 * be specified in the day-in-month format, rather than the absolute format,
 * used by the StandardDate and DaylightDate members of a TIME_ZONE_INFORMATION
 * structure.
 * If the test date is earlier than the target date, it returns a negative
 * number. If the test date is later than the target date, it returns a positive
 * number. If the test date equals the target date, it returns zero.
 * Specifically, it returns:
 * -4/+4 if the test month is less than/greater than the target month;
 * -2/+2 if the test day   is less than/greater than the target day;
 * -1/+1 if the test time  is less than/greater than the target time;
 *   0   if the test date            equals          the target date.
 *
 * This function was originally written by Jonathan M Gilligan.
 */

static int CompareTargetDate(
	const SYSTEMTIME *test_st,
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

		WORD	first_dow;
		WORD	temp_dom;
		WORD	last_dom;
		int		test_ms;
		int		target_ms;

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
		 * last day-of-the-week z. For example, if we tried to calculate the
		 * day-of-the-month of the fifth Tuesday of the month then we may have
		 * overshot, and need to correct for that case.
		 * Get the last day-of-the-month (with a suitable correction if it is
		 * February of a leap year) and move the temp_dom that we have
		 * calculated back one week at a time until if doesn't exceed that. */
		last_dom = days_in_month[target_st->wMonth - 1];
		if (test_st->wMonth == 2 && IsLeapYear(test_st->wYear))
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
 * Function to return the time zone bias for a given local time. The bias is the
 * difference, in minutes, between UTC and local time: UTC = local time + bias.
 *
 * This function was originally written by Jonathan M Gilligan.
 */

static int GetTimeZoneBias(
	const SYSTEMTIME *st)
{
	TIME_ZONE_INFORMATION	tz;
	int						bias;

	if (GetTimeZoneInformation(&tz) == TIME_ZONE_ID_INVALID)
		croak("Could not get time zone information");

	/* We only deal with cases where the transition dates between standard time
	 * and daylight time are given in "day-in-month" format rather than
	 * "absolute" format. */
	if (tz.DaylightDate.wYear != 0 || tz.StandardDate.wYear != 0)
		croak("Cannot handle year-specific DST clues in time zone information");

	/* Get the difference between UTC and local time. */
	bias = tz.Bias;

	/* Add on the standard bias (usually 0) or the daylight bias (usually -60)
	 * as appropriate for the given time. */
	if (CompareTargetDate(st, &tz.DaylightDate) < 0) {
		bias += tz.StandardBias;
	}
	else if (CompareTargetDate(st, &tz.StandardDate) < 0) {
		bias += tz.DaylightBias;
	}
	else {
		bias += tz.StandardBias;
	}

	return bias;
}

/* Number of "clunks" (100-nanosecond intervals) in one second. */
static const ULONGLONG	clunks_per_second = 10000000L;

/* The epoch of time_t values (00:00:00 Jan 01 1970 UTC) as a SYSTEMTIME. */
static const SYSTEMTIME	base_st = {
	1970,	/* wYear			*/
	1,		/* wMonth			*/
	0,		/* wDayOfWeek		*/
	1,		/* wDay				*/
	0,		/* wHour			*/
	0,		/* wMinute			*/
	0,		/* wSecond			*/
	0		/* wMilliseconds	*/
};

/*
 * Function to convert a FILETIME to a time_t.
 * The time_t will be UTC-based, so if the FILETIME is local time-based then
 * set the ft_is_local flag so that a local time adjustment can be made.
 *
 * This function was originally written by Jonathan M Gilligan.
 */

static BOOL FileTimeToUnixTime(
	const FILETIME	*ft,
	time_t			*ut,
	const BOOL		ft_is_local)
{
	int				bias = 0;
	FILETIME		base_ft;
	ULARGE_INTEGER	it;

	if (ft_is_local) {
		SYSTEMTIME	st;

		/* Convert the FILETIME to a SYSTEMTIME, and get the bias from that. */
		if (FileTimeToSystemTime(ft, &st)) {
			bias = GetTimeZoneBias(&st);
		}
		else {
			PrintfDebug(aTHX_ "FileTimeToSystemTime() failed\n");

			/* Do the same as mktime() in the event of failure. */
			*ut = -1;
			return FALSE;
		}
	}

	/* Get the epoch of time_t values as a FILETIME. */
	if (!SystemTimeToFileTime(&base_st, &base_ft))
		croak("Could not convert base SYSTEMTIME to FILETIME");

	/* Convert the FILETIME (which is expressed as the number of clunks
	 * since 00:00:00 Jan 01 1601 UTC) to a time_t value by subtracting the
	 * FILETIME representation of the epoch of time_t values and then
	 * converting clunks to seconds. */
	it.QuadPart  = ((ULARGE_INTEGER *)ft)->QuadPart;
	it.QuadPart -= ((ULARGE_INTEGER *)&base_ft)->QuadPart;
	it.QuadPart /= clunks_per_second;

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
 * This function was originally written by Tony M Hoyle.
 */

static BOOL UnixTimeToFileTime(
	const time_t	ut,
	FILETIME		*ft,
	const BOOL		make_ft_local)
{
	ULARGE_INTEGER	it;
	FILETIME		base_ft;
	int				bias = 0;

	/* Get the epoch of time_t values as a FILETIME. */
	if (!SystemTimeToFileTime(&base_st, &base_ft))
		croak("Could not convert base SYSTEMTIME to FILETIME");

	/* Convert the time_t value to a FILETIME (which is expressed as the
	 * number of clunks since 00:00:00 Jan 01 1601 UTC) by converting
	 * seconds to clunks and then adding the FILETIME representation of the
	 * epoch of time_t values. */
	it.LowPart   = ut;
	it.HighPart  = 0;
	it.QuadPart *= clunks_per_second;
	it.QuadPart += ((ULARGE_INTEGER *)&base_ft)->QuadPart;

	if (make_ft_local) {
		SYSTEMTIME	st;

		/* Convert the FILETIME to a SYSTEMTIME, and get the bias from that. */
		if (FileTimeToSystemTime((FILETIME *)&it, &st)) {
			bias = GetTimeZoneBias(&st);
		}
		else {
			PrintfDebug(aTHX_ "FileTimeToSystemTime() failed\n");

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
 * Function to get the last access time, last modification time and creation
 * time of a given file.
 * The values are returned expressed as UTC-based time_t values, whatever
 * filesystem the file is stored in.
 *
 * This function was originally written by Jonathan M Gilligan.
 */

static BOOL GetUTCFileTimes(
	LPCTSTR			name,
	time_t			*u_atime_t,
	time_t			*u_mtime_t,
	time_t			*u_ctime_t)
{
	BOOL			ret;
	HANDLE			fh;
	WIN32_FIND_DATA	fb;

	/* Use FindFirstFile() like Microsoft's stat() does, rather than the more
	 * obvious GetFileTime(), to avoid a problem with the latter caching UTC
	 * time values on FAT volumes. */
	if ((fh = FindFirstFile(name, &fb)) == INVALID_HANDLE_VALUE) {
		PrintfDebug(aTHX_ "FindFirstFile() failed for '%s'\n", name);
		return FALSE;
	}

	if (IsUTCVolume(name)) {
		/* The filesystem stores UTC file times. FindFirstFile() returns them to
		 * us as unadulterated UTC FILETIMEs, so just convert them to time_t
		 * values to be returned. */
		ret =	FileTimeToUnixTime(&fb.ftLastAccessTime, u_atime_t, FALSE)	&&
				FileTimeToUnixTime(&fb.ftLastWriteTime,  u_mtime_t, FALSE)	&&
				FileTimeToUnixTime(&fb.ftCreationTime,   u_ctime_t, FALSE);
	}
	else { 
		FILETIME	l_atime_ft;
		FILETIME	l_mtime_ft;
		FILETIME	l_ctime_ft;

		/* The filesystem stores local file times. FindFirstFile() returns them
		 * to us as incorrectly converted UTC FILETIMEs, so undo the faulty
		 * time zone conversion and then redo it properly, converting to time_t
		 * values to be returned in the process. */
		ret =	FileTimeToLocalFileTime(&fb.ftLastAccessTime, &l_atime_ft)	&&
				FileTimeToLocalFileTime(&fb.ftLastWriteTime,  &l_mtime_ft)	&&
				FileTimeToLocalFileTime(&fb.ftCreationTime,   &l_ctime_ft)	&&
				FileTimeToUnixTime(&l_atime_ft, u_atime_t, TRUE)			&&
				FileTimeToUnixTime(&l_mtime_ft, u_mtime_t, TRUE)			&& 
				FileTimeToUnixTime(&l_ctime_ft, u_ctime_t, TRUE);
	}        

	if (!FindClose(fh))
		warn("Could not close file search handle");

    return ret;
}

/*
 * Function to set the last access time and last modification time of a given
 * file.
 * The values should be supplied expressed as UTC-based time_t values, whatever
 * filesystem the file is stored in.
 */

static BOOL SetUTCFileTimes(
	LPCTSTR			name,
	const time_t	u_atime_t,
	const time_t	u_mtime_t)
{
	BOOL			ret = FALSE;
	HANDLE			handle;

	/* Use CreateFile() like Perl's win32_utime() does, rather than open() and
	 * _get_osfhandle() like Microsoft's utime() does, so that this works on
	 * directories too. */
	if ((handle = CreateFile(name,
					GENERIC_READ | GENERIC_WRITE,
					FILE_SHARE_READ | FILE_SHARE_DELETE,
					NULL,
					OPEN_EXISTING,
					FILE_FLAG_BACKUP_SEMANTICS,
					NULL)) == INVALID_HANDLE_VALUE)
	{
		PrintfDebug(aTHX_ "CreateFile() failed for '%s'\n", name);
		return FALSE;
	}

	/* Use NULL for the creation time passed to SetFileTime() like Microsoft's
	 * utime() does. This simply means that the information is not changed.
	 * There is no need to retrieve the existing value first in order to reset
	 * it like Perl's win32_utime() does. */
	if (IsUTCVolume(name)) {
		FILETIME	u_atime_ft;
		FILETIME	u_mtime_ft;

		/* The filesystem stores UTC file times. SetFileTime() will set its UTC
		 * FILETIME arguments without change, so just convert the time_t values
		 * to UTC FILETIMEs to be set. */
		if (UnixTimeToFileTime(u_atime_t, &u_atime_ft, FALSE) &&
			UnixTimeToFileTime(u_mtime_t, &u_mtime_ft, FALSE))
		{
			if (!SetFileTime(handle, NULL, &u_atime_ft, &u_mtime_ft)) {
				PrintfDebug(aTHX_ "SetFileTime() failed for '%s'\n", name);
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
		FILETIME	l_atime_ft;
		FILETIME	l_mtime_ft;
		FILETIME	u_atime_ft;
		FILETIME	u_mtime_ft;

		/* The filesystem stores local file times. SetFileTime() will set its
		 * UTC FILETIME arguments after an incorrect local time conversion, so
		 * do the conversion properly first, converting the time_t values to
		 * local FILETIMEs in the process, and then do an extra incorrect UTC
		 * conversion ready to be undone by SetFileTime() when it sets them. */
		if (UnixTimeToFileTime(u_atime_t, &l_atime_ft, TRUE)	&&
			UnixTimeToFileTime(u_mtime_t, &l_mtime_ft, TRUE)	&&
			LocalFileTimeToFileTime(&l_atime_ft, &u_atime_ft)	&&
			LocalFileTimeToFileTime(&l_mtime_ft, &u_mtime_ft))
		{
			if (!SetFileTime(handle, NULL, &u_atime_ft, &u_mtime_ft)) {
				PrintfDebug(aTHX_ "SetFileTime() failed for '%s'\n", name);
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

	if (!CloseHandle(handle))
		warn("Could not close file object handle");

	return ret;
}

/*
 * Function to retrieve the Perl module's $Debug variable and output a formatted
 * debug message on the stderr stream if $Debug is true.
 */

static void PrintfDebug(pTHX_ const char *fmt, ...) {
	va_list	args;

	/* Get the Perl module's global $Debug variable and see if it is "true". */
	if (SvTRUE(get_sv("Win32::UTCFileTime::Debug", FALSE))) {
		va_start(args, fmt);
		vfprintf(stderr, fmt, args);
		va_end(args);
	}
}

/*------------------------------------------------------------------------------
 */

MODULE = Win32::UTCFileTime		PACKAGE = Win32::UTCFileTime		

PROTOTYPES: ENABLE

INCLUDE: const-xs.inc

#-------------------------------------------------------------------------------
#
# XS code to be converted to C code by xsubpp.
#

# Function to expose the GetUTCFileTimes() function above.
# This is only intended to be used by stat() and lstat() in the Perl module.

void
_get_utc_file_times(file)
	INPUT:
		const char	*file;

	PREINIT:
		time_t		atime;
		time_t		mtime;
		time_t		ctime;

	PROTOTYPE: $

	PPCODE:
		if (GetUTCFileTimes(file, &atime, &mtime, &ctime)) {
			XPUSHs(sv_2mortal(newSViv(atime)));
			XPUSHs(sv_2mortal(newSViv(mtime)));
			XPUSHs(sv_2mortal(newSViv(ctime)));
		}
		else {
			XSRETURN_EMPTY;
		}

# Function to expose the SetUTCFileTimes() function above.
# This is only intended to be used by utime() in the Perl module.

BOOL
_set_utc_file_times(file, atime, mtime)
	INPUT:
		const char		*file;
		const time_t	atime;
		const time_t	mtime;

	PROTOTYPE: $$$

	CODE:
		RETVAL = SetUTCFileTimes(file, atime, mtime);

	OUTPUT:
		RETVAL

# Function to expose the Win32 API function SetErrorMode().
# This is only intended to be used by stat() and lstat() in the Perl module.

UINT
_set_error_mode(umode)
	INPUT:
		const UINT	umode;

	PROTOTYPE: $

	CODE:
		RETVAL = SetErrorMode(umode);

	OUTPUT:
		RETVAL

#-------------------------------------------------------------------------------
