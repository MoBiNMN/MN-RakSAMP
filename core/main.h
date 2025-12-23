
#include "platform_compat.h"
#include <iostream>
#include <vector>
#include <string>
#include <time.h>
#include <mutex>
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
	EXPORT const char *mn_get_logs(mn_handle h);
	EXPORT bool mn_isrunning(mn_handle h);
	EXPORT void mn_clear_logs(mn_handle h);
	EXPORT void mn_sendchat(mn_handle h, const char *chat);
	EXPORT mn_handle mn_find_handle(const char *username);
	EXPORT void mn_sendchat(mn_handle h, const char *chat);
	EXPORT int mn_start(mn_handle h, const char *username, const char *password);
	EXPORT void mn_stop(mn_handle h);

#ifdef __cplusplus
}
#endif

#define NETGAME_VERSION 4057

#define MAX_PLAYERS 1004
typedef uint16_t PLAYERID;

#pragma pack(1)
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
#pragma pack(1)
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
#pragma pack(1)
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
};

struct MNRakSampContext
{
	stRakClient client{};
	char userName[32];
	char userPassword[128];

	std::deque<std::string> logs;
	std::mutex logsMutex;
	std::atomic<bool> running{false};
	std::thread thread;
};

MNRakSampContext *mn_ctx_from_rpc(RPCParameters *p);

#include "SAMPRPC.h"

#include "netgame.h"
#include "netrpc.h"

#include "misc_funcs.h"

void Log(MNRakSampContext *ctx, const char *fmt, ...);
bool isSubstring(const char *input, const char *substr);
