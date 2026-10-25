
#include "platform_compat.h"
#include <iostream>
#include <vector>
#include <string>
#include <time.h>
#include <mutex>
#include <random>
#include <thread>
#include <deque>
#include <stdlib.h>
#include <cstdlib>
#include <unordered_map>
#include <iomanip>
#include <sstream>
#include <regex>

// raknet stuff
#include "PacketEnumerations.h"
#include "RakNetworkFactory.h"
#include "RakClientInterface.h"
#include "NetworkTypes.h"
#include "BitStream.h"
#include "StringCompressor.h"
#include "SAMPAuth.h"

#pragma warning(disable : 4996)
#define SAMP_VERSION "0.3.7"

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C"
{
#endif

	typedef void *mn_handle;
	EXPORT mn_handle mn_create(void);
	EXPORT void mn_destroy(mn_handle h);
	EXPORT int mn_get_logs(mn_handle h, char *out, int outSize);
	EXPORT bool mn_isrunning(mn_handle h);
	EXPORT void mn_clear_logs(mn_handle h);
	EXPORT void mn_sendchat(mn_handle h, const char *chat);
	EXPORT mn_handle mn_find_handle(const char *username);
	EXPORT int mn_start(mn_handle h, const char *username, const char *password);
	EXPORT void mn_stop(mn_handle h);

#ifdef __cplusplus
}
#endif

#define NETGAME_VERSION 4057

#define MAX_PLAYERS 1004
typedef uint16_t PLAYERID;

// ---------------------------------------------------------------------------
// Wire-format structs.
//
// EVERY struct in this region is sent to / received from the SA-MP server via
// RakNet, so each one MUST stay 1-byte packed.  The server has hardcoded
// offsets (e.g. ONFOOT_SYNC_DATA is 68 bytes packed), so inserting padding
// anywhere here silently desynchronises every packet and gets the client
// kicked as a teleport hacker.
//
// push/pop is used so the packing applies to exactly these structs and nothing
// else: do NOT convert this to a bare #pragma pack(1) with no pop, and do NOT
// let the packing leak past the pop below.  See the note after the pop.
// ---------------------------------------------------------------------------
#pragma pack(push, 1)

typedef struct _ONFOOT_SYNC_DATA
{
	WORD lrAnalog;
	WORD udAnalog;
	WORD wKeys;
	float vecPos[3];
	float fQuaternion[4];
	BYTE byteHealth;
	BYTE byteArmour;
	BYTE byteCurrentWeapon;
	BYTE byteSpecialAction;
	float vecMoveSpeed[3];
	float vecSurfOffsets[3];
	WORD wSurfInfo;
	int iCurrentAnimationID;
} ONFOOT_SYNC_DATA;

#pragma pack(1)
typedef struct _SPECTATOR_SYNC_DATA
{
	WORD lrAnalog;
	WORD udAnalog;
	WORD wKeys;
	float vecPos[3];
} SPECTATOR_SYNC_DATA;
typedef struct _PLAYER_SPAWN_INFO
{
	BYTE byteTeam;
	int iSkin;
	BYTE unk;
	float vecPos[3];
	float fRotation;
	int iSpawnWeapons[3];
	int iSpawnWeaponsAmmo[3];
} PLAYER_SPAWN_INFO;

// TEXT_DRAW_TRANSMIT is the last wire-format struct.  It is written out only
// field-by-field by sendDialogResponse(), but it is kept packed with the others
// so the whole wire block stays 1-byte aligned end to end.
typedef struct _TEXT_DRAW_TRANSMIT
{
	union
	{
		BYTE byteFlags;
		struct
		{
			BYTE byteBox : 1;
			BYTE byteLeft : 1;
			BYTE byteRight : 1;
			BYTE byteCenter : 1;
			BYTE byteProportional : 1;
			BYTE bytePadding : 3;
		};
	};
	float fLetterWidth;
	float fLetterHeight;
	DWORD dwLetterColor;
	float fLineWidth;
	float fLineHeight;
	DWORD dwBoxColor;
	BYTE byteShadow;
	BYTE byteOutline;
	DWORD dwBackgroundColor;
	BYTE byteStyle;
	BYTE byteSelectable;
	float fX;
	float fY;
	WORD wModelID;
	float fRotX;
	float fRotY;
	float fRotZ;
	float fZoom;
	WORD wColor1;
	WORD wColor2;
} TEXT_DRAW_TRANSMIT;

#pragma pack(pop)


static_assert( alignof( ONFOOT_SYNC_DATA ) == 1, "ONFOOT_SYNC_DATA must stay 1-byte packed (wire format)" );
static_assert( alignof( SPECTATOR_SYNC_DATA ) == 1, "SPECTATOR_SYNC_DATA must stay 1-byte packed (wire format)" );
static_assert( alignof( PLAYER_SPAWN_INFO ) == 1, "PLAYER_SPAWN_INFO must stay 1-byte packed (wire format)" );
static_assert( alignof( TEXT_DRAW_TRANSMIT ) == 1, "TEXT_DRAW_TRANSMIT must stay 1-byte packed (wire format)" );
static_assert( sizeof( ONFOOT_SYNC_DATA ) == 68, "ONFOOT_SYNC_DATA wire size changed" );
static_assert( sizeof( SPECTATOR_SYNC_DATA ) == 18, "SPECTATOR_SYNC_DATA wire size changed" );
static_assert( sizeof( PLAYER_SPAWN_INFO ) == 46, "PLAYER_SPAWN_INFO wire size changed" );
static_assert( sizeof( TEXT_DRAW_TRANSMIT ) == 63, "TEXT_DRAW_TRANSMIT wire size changed" );

struct stSAMPDialog
{
	int iIsActive;
	BYTE bDialogStyle;
	WORD wDialogID;
	BYTE bTitleLength;
	char szTitle[257];
	BYTE bButton1Len;
	char szButton1[257];
	BYTE bButton2Len;
	char szButton2[257];
	char szInfo[257];
};

struct stRakClient
{
	RakClientInterface *rakClient;
	char nickName[32];
	PLAYERID playerid;
	int drunkLevel;
	int lastDrunkLevel;
	int money;
	int lastMoney;
	uint64_t lastStatsUpdate;
	uint64_t dwLastUpdateTick;
	float playerHealth;
	float playerArmour;
	float normalModePos[3];
	float currentPosition[3];
	float normalModeRot;
	PLAYER_SPAWN_INFO SpawnInfo;
	stSAMPDialog sampDialog;
	unsigned short dialogid;
	bool connectionRequested;
	bool callSampRequestClass;
	bool gameInited;
	bool areWeConnected;
	bool isConnected;
	bool isSpectating;
	bool spawned;
	bool logined;
	uint64_t sleepTime;
	int netModeNormalOnfootSendRate;
	int netModeNormalIncarSendRate;
	int netModeSendMultiplier;
	bool hasSendRate;
};

struct MNRakSampContext
{
	stRakClient client{};
	char userName[32];
	char userPassword[128];

	std::deque<std::string> logs;
	std::mutex logsMutex;
	std::atomic<bool> running{false};
	std::atomic<bool> destroyed{false};
	std::thread thread;
	std::mt19937 rng{ std::random_device{}() };
};


static_assert( alignof( stSAMPDialog ) > 1, "stSAMPDialog must not be packed" );
static_assert( alignof( stRakClient ) > 1, "stRakClient must not be packed" );
static_assert( alignof( MNRakSampContext ) > 1, "MNRakSampContext must not be packed" );
static_assert( alignof( MNRakSampContext ) >= alignof( std::mutex ),
               "MNRakSampContext must not be packed below std::mutex alignment" );
static_assert( offsetof( MNRakSampContext, logsMutex ) % alignof( std::mutex ) == 0,
               "MNRakSampContext::logsMutex must be naturally aligned" );
static_assert( offsetof( MNRakSampContext, running ) % alignof( std::atomic<bool> ) == 0,
               "MNRakSampContext::running must be naturally aligned" );
static_assert( offsetof( MNRakSampContext, destroyed ) % alignof( std::atomic<bool> ) == 0,
               "MNRakSampContext::destroyed must be naturally aligned" );
static_assert( offsetof( MNRakSampContext, thread ) % alignof( std::thread ) == 0,
               "MNRakSampContext::thread must be naturally aligned" );

MNRakSampContext *mn_ctx_from_rpc(RPCParameters *p);

#include "SAMPRPC.h"

#include "netgame.h"
#include "netrpc.h"

#include "misc_funcs.h"

void Log(MNRakSampContext *ctx, const char *fmt, ...);
bool isSubstring(const char *input, const char *substr);
