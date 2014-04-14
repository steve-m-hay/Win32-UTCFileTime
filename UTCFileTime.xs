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
#include <time.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include "const-c.inc"

#define _MAX_FS 32

static BOOL IsUTCVolume(LPCTSTR name);
static BOOL FileTimeToUnixTime(const FILETIME ft, time_t *ut,
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
 * Function to convert a FILETIME to a time_t.
 * The time_t will be UTC-based, so if the FILETIME is local time-based then
 * set the ft_is_local flag so that a local time adjustment can be made.
 *
 * This function was originally written by Jonathan M Gilligan.
 */

static BOOL FileTimeToUnixTime(
	const FILETIME	ft,
	time_t			*ut,
	const BOOL		ft_is_local)
{
	BOOL			ret;

	if (ft_is_local) {
		struct tm	atm;
		SYSTEMTIME	st;

		/* Convert the FILETIME to a SYSTEMTIME, and build a struct tm from
		 * that. */
		if (FileTimeToSystemTime(&ft, &st)) {
			atm.tm_sec   = st.wSecond;
			atm.tm_min   = st.wMinute;
			atm.tm_hour  = st.wHour;
			atm.tm_mday  = st.wDay;
			atm.tm_mon   = st.wMonth - 1;
			atm.tm_year  = st.wYear > 1900 ? st.wYear - 1900 : st.wYear;     
			atm.tm_isdst = -1;

			/* Convert the struct tm to a (UTC-based) time_t value, interpreting
			 * the struct tm as local time. Note that the tm_isdst member is set
			 * to -1, meaning use the United States' rule for deciding whether
			 * or not to apply a DST correction. */
			if (*ut = mktime(&atm)) {
				ret = TRUE;
			}
			else {
				PrintfDebug(aTHX_ "mktime() failed\n");
				ret = FALSE;
			}
		}
		else {
			PrintfDebug(aTHX_ "FileTimeToSystemTime() failed\n");
			ret = FALSE;
		}
	}
	else {
		/* Number of "clunks" (100-nanosecond intervals) in one second. */
		const ULONGLONG	second = 10000000L;
		/* The epoch of time_t values (00:00:00 Jan 01 1970 UTC) as a
		 * SYSTEMTIME. */
		SYSTEMTIME		base_st = {
			1970,	/* wYear			*/
			1,		/* wMonth			*/
			0,		/* wDayOfWeek		*/
			1,		/* wDay				*/
			0,		/* wHour			*/
			0,		/* wMinute			*/
			0,		/* wSecond			*/
			0		/* wMilliseconds	*/
		};
		ULARGE_INTEGER	it;
		FILETIME		base_ft;

		/* Get the epoch of time_t values as a FILETIME. */
		if (SystemTimeToFileTime(&base_st, &base_ft)) {
			it.QuadPart  = ((ULARGE_INTEGER *)&ft)->QuadPart;

			/* Convert the FILETIME (which is expressed as the number of clunks
			 * since 00:00:00 Jan 01 1601 UTC) to a time_t value by subtracting
			 * the FILETIME representation of the epoch of time_t values and
			 * then converting clunks to seconds. */
			it.QuadPart -= ((ULARGE_INTEGER *)&base_ft)->QuadPart;
			it.QuadPart /= second;

			*ut = it.LowPart;
			ret = TRUE;
		}
		else {
			PrintfDebug(aTHX_ "SystemTimeToFileTime() failed\n");
			ret = FALSE;
		}
	}

	/* Do the same as mktime() in the event of failure. */
	if (!ret)
		*ut = -1;

	return ret;
}

/*
 * Function to convert a time_t to a FILETIME.
 * The time_t is UTC-based, so if a local time-based FILETIME is required then
 * set the make_ft_local flag so that a local time adjustment can be made.
 */

static BOOL UnixTimeToFileTime(
	const time_t	ut,
	FILETIME		*ft,
	const BOOL		make_ft_local)
{
	BOOL			ret;
	struct tm		*tmb;
	SYSTEMTIME		st;

	/* Convert the (UTC-based) time_t value to a struct tm, either in local time
	 * or in UTC time, depending on what is required for the FILETIME. */
	if (make_ft_local)
		if ((tmb = localtime(&ut)) != NULL) {
			ret = TRUE;
		}
		else {
			PrintfDebug(aTHX_ "localtime() failed\n");
			ret = FALSE;
		}
	else
		if ((tmb = gmtime(&ut)) != NULL) {
			ret = TRUE;
		}
		else {
			PrintfDebug(aTHX_ "gmtime() failed\n");
			ret = FALSE;
		}

	/* Build a SYSTEMTIME from the struct tm, and convert that to a FILETIME. */
	if (ret) {
		st.wYear			= (WORD)(tmb->tm_year + 1900);
		st.wMonth			= (WORD)(tmb->tm_mon + 1);
		st.wDay				= (WORD)(tmb->tm_mday);
		st.wHour			= (WORD)(tmb->tm_hour);
		st.wMinute			= (WORD)(tmb->tm_min);
		st.wSecond			= (WORD)(tmb->tm_sec);
		st.wMilliseconds	= 0;

		if (SystemTimeToFileTime(&st, ft)) {
			ret = TRUE;
		}
		else {
			PrintfDebug(aTHX_ "SystemTimeToFileTime() failed\n");
			ret = FALSE;
		}
	}

	/* Set a zero FILETIME in the event of failure. */
	if (!ret) {
		(*ft).dwLowDateTime  = 0;
		(*ft).dwHighDateTime = 0;
	}

	return ret;
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
		ret =	FileTimeToUnixTime(fb.ftLastAccessTime, u_atime_t, FALSE)	&&
				FileTimeToUnixTime(fb.ftLastWriteTime,  u_mtime_t, FALSE)	&&
				FileTimeToUnixTime(fb.ftCreationTime,   u_ctime_t, FALSE);
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
				FileTimeToUnixTime(l_atime_ft, u_atime_t, TRUE)				&&
				FileTimeToUnixTime(l_mtime_ft, u_mtime_t, TRUE)				&& 
				FileTimeToUnixTime(l_ctime_ft, u_ctime_t, TRUE);
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
