/// \file
///
/// This file is part of RakNet Copyright 2003 Kevin Jenkins.
///
/// Usage of RakNet is subject to the appropriate license agreement.
///
/// Creative Commons Licensees are subject to the license found at
/// http://creativecommons.org/licenses/by-nc/2.5/
///
/// Single application licensees are subject to the license found at
/// http://www.rakkarsoft.com/SingleApplicationLicense.html
///
/// Custom license users are subject to the license terms specified in the
/// license agreement.

#include "GetTime.h"
#include <mutex>

#ifdef _COMPATIBILITY_1
#include "Compatibility1Includes.h" // Developers of a certain platform will know what to do here.
#elif defined(_WIN32)
#include <windows.h>
#elif defined(_COMPATIBILITY_2)
#include "Compatibility2Includes.h"
#include <sys/time.h>
#include <unistd.h>
#include <time.h>
#else
#include <sys/time.h>
#include <unistd.h>
#include <time.h>
#endif

// ---------------------------------------------------------------------------
// TIME BASE -- READ THIS BEFORE CHANGING ANYTHING HERE
// ---------------------------------------------------------------------------
//
// This tree pins two time contracts.  Both must hold, and neither may change
// without also changing every consumer and the on-wire packet layout.
//
// 1. RakNetTime is MILLISECONDS and 32 bits wide.
//    __GET_TIME_64BIT is deliberately left off (see RakNetDefines.h): a 64 bit
//    RakNetTime changes the timestamp field width inside every timestamped
//    packet, and therefore the expected NETGAME_VERSION and every packet
//    offset.  Server protocol compatibility depends on this staying 32 bit.
//
// 2. RakNetTimeNS is MICROSECONDS.
//    This is the contract the whole reliability layer is built on.  Every
//    consumer divides by 1000 to recover milliseconds:
//
//      RakPeer.cpp         : timeMS = (RakNetTime)(timeNS / (RakNetTimeNS)1000);
//                            and timeMS is then compared against
//                            remoteSystem->connectionTime and
//                            remoteSystem->lastReliableSend, both of which are
//                            stored from RakNet::GetTime() (i.e. in real
//                            milliseconds).
//      ReliabilityLayer.cpp: (RakNetTime)(time / (RakNetTimeNS)1000)
//      ReliabilityLayer.cpp: time + (RakNetTimeNS)timeoutTime * 1000
//      ReliabilityLayer.cpp: time - lastAckTime > (RakNetTimeNS)timeoutTime * 1000
//      ReliabilityLayer.cpp: time > splitPacketChannel->lastUpdateTime + 10000000
//
//    If GetTimeNS() returns nanoseconds instead, timeMS becomes 1000x too large
//    while connectionTime/lastReliableSend stay in real milliseconds.  The
//    connection timeout check
//
//        timeMS > connectionTime && timeMS - connectionTime > 10000
//
//    then succeeds on the next RunUpdateCycle iteration, the peer is torn down
//    mid-handshake, and the caller sees ID_CONNECTION_ATTEMPT_FAILED - which is
//    precisely the regression introduced by the multi-account concurrency
//    commit.  Every reliability layer timeout collapses by the same factor
//    (10 s -> 10 ms), so retransmissions and resend bursts also fire at once.
//
//    Both the original gettimeofday() path and the original QPC path happened
//    to return microseconds, so the unit change was invisible until the clock
//    source was swapped.
//
// GetTime() and GetTimeNS() below are both derived from the single helper
// QueryMonotonicMicroseconds(), so "GetTime() == GetTimeNS()/1000" holds by
// construction and cannot silently drift again.
// ---------------------------------------------------------------------------

#ifdef _WIN32
// Performance-counter frequency.  Written once inside the call_once lambda
// below and read only after that call_once has returned, which publishes the
// write with a release-acquire pair, so no extra locking is needed at call time.
static long long g_frequency = 0;
#else
// Nothing: the POSIX branch has no shared mutable state at all.  The origin is
// the clock's own epoch, so there is no per-call state like the old `timeval tp`.
#endif

static void EnsureTimeBaseReady( void )
{
#ifdef _WIN32
	// call_once, not "if (initialized == false) { ... initialized = true; }".
	// One RakPeer exists per account, and the first GetTime() call can arrive
	// concurrently from several account threads.  With a plain bool one of them
	// could read g_frequency while it is still zero and divide by it.
	static std::once_flag initOnce;
	std::call_once( initOnce, []() {
		LARGE_INTEGER frequency;
		QueryPerformanceFrequency( &frequency );
		g_frequency = ( frequency.QuadPart > 0 ) ? (long long) frequency.QuadPart : 1;
	} );
#endif
	// POSIX needs no one-time setup: clock_gettime(CLOCK_MONOTONIC) is
	// self-initialising and monotonic.
}

// ---------------------------------------------------------------------------
// Monotonic MICROSECONDS (see the unit contract above).
//
// The clock is monotonic, so unlike the pre-commit code this is immune to wall
// clock adjustments (NTP steps, manual date changes) which used to make
// timeouts expire early or never.
// ---------------------------------------------------------------------------
static long long QueryMonotonicMicroseconds( void )
{
	EnsureTimeBaseReady();

#ifdef _WIN32
	LARGE_INTEGER now;
	QueryPerformanceCounter( &now );

	const long long frequency = g_frequency;
	const long long ticks = (long long) now.QuadPart;

	// Split whole seconds from the fractional tick count.
	//
	// The pre-commit code computed (PerfVal * 1000), which overflows a signed 64
	// bit integer once the counter passes ~9.2e15 ticks - around 29 years of
	// uptime at 10 MHz.  The buggy commit multiplied by 1000000 instead, which
	// dropped that to about 10 days at 10 MHz and to minutes on a TSC-based high
	// frequency counter.  Splitting the computation keeps every intermediate
	// small for any realistic lifetime: (ticks % frequency) is always below the
	// counter frequency, and only whole seconds are scaled by 1e6.
	const long long whole = ticks / frequency;
	const long long frac = ticks % frequency;

	return whole * 1000000LL + ( frac * 1000000LL ) / frequency;
#else
#if defined(CLOCK_MONOTONIC)
	struct timespec ts;
	clock_gettime( CLOCK_MONOTONIC, &ts );
	const long long nowSeconds = (long long) ts.tv_sec;
	const long long nowNanos = (long long) ts.tv_nsec;
#else
	// Fallback for platforms without a monotonic clock.
	struct timeval tv;
	gettimeofday( &tv, 0 );
	const long long nowSeconds = (long long) tv.tv_sec;
	const long long nowNanos = (long long) tv.tv_usec * 1000;
#endif

	return nowSeconds * 1000000LL + nowNanos / 1000;
#endif
}

RakNetTime RakNet::GetTime( void )
{
	// MICROSECONDS -> MILLISECONDS.  Routed through the same helper as
	// GetTimeNS() on purpose, so the two cannot disagree on scale.
	return (RakNetTime)( QueryMonotonicMicroseconds() / (RakNetTimeNS) 1000 );
}

RakNetTimeNS RakNet::GetTimeNS( void )
{
	// MICROSECONDS.  Not nanoseconds.  See the unit contract at the top of this
	// file for the full list of consumers that divide by 1000.
	return (RakNetTimeNS) QueryMonotonicMicroseconds();
}
