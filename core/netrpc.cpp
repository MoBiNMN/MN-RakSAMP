#include "main.h"

#define RPC_CTX                             \
	auto *ctx = mn_ctx_from_rpc(rpcParams); \
	if (!ctx)                               \
		return;
void InitGame(RPCParameters *rpcParams)
{

	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsInitGame((unsigned char *)Data, (iBitLength / 8) + 1, false);

	PLAYERID MyPlayerID;
	bool bLanMode, bStuntBonus;
	BYTE byteVehicleModels[212];

	bool m_bZoneNames, m_bUseCJWalk, m_bAllowWeapons, m_bLimitGlobalChatRadius;
	float m_fGlobalChatRadius, m_fNameTagDrawDistance;
	bool m_bDisableEnterExits, m_bNameTagLOS, m_bManualVehicleEngineAndLight;
	bool m_bShowPlayerTags;
	int m_iShowPlayerMarkers;
	BYTE m_byteWorldTime, m_byteWeather;
	float m_fGravity;
	int m_iDeathDropMoney;
	bool m_bInstagib;
	int iSpawnsAvailable;
	int iNetModeNormalOnfootSendRate, iNetModeNormalIncarSendRate, iNetModeFiringSendRate, iNetModeSendMultiplier;
	BYTE m_bLagCompensation;

	bsInitGame.ReadCompressed(m_bZoneNames);
	bsInitGame.ReadCompressed(m_bUseCJWalk);
	bsInitGame.ReadCompressed(m_bAllowWeapons);
	bsInitGame.ReadCompressed(m_bLimitGlobalChatRadius);
	bsInitGame.Read(m_fGlobalChatRadius);
	bsInitGame.ReadCompressed(bStuntBonus);
	bsInitGame.Read(m_fNameTagDrawDistance);
	bsInitGame.ReadCompressed(m_bDisableEnterExits);
	bsInitGame.ReadCompressed(m_bNameTagLOS);
	bsInitGame.ReadCompressed(m_bManualVehicleEngineAndLight); //
	bsInitGame.Read(iSpawnsAvailable);
	bsInitGame.Read(MyPlayerID);
	bsInitGame.ReadCompressed(m_bShowPlayerTags);
	bsInitGame.Read(m_iShowPlayerMarkers);
	bsInitGame.Read(m_byteWorldTime);
	bsInitGame.Read(m_byteWeather);
	bsInitGame.Read(m_fGravity);
	bsInitGame.ReadCompressed(bLanMode);
	bsInitGame.Read(m_iDeathDropMoney);
	bsInitGame.ReadCompressed(m_bInstagib);

	// Server's send rate restrictions
	bsInitGame.Read(iNetModeNormalOnfootSendRate);
	bsInitGame.Read(iNetModeNormalIncarSendRate);
	bsInitGame.Read(iNetModeFiringSendRate);
	bsInitGame.Read(iNetModeSendMultiplier);

	bsInitGame.Read(m_bLagCompensation);

	BYTE unk;
	bsInitGame.Read(unk);
	bsInitGame.Read(unk);
	bsInitGame.Read(unk);

	BYTE byteStrLen;
	bsInitGame.Read(byteStrLen);
	char g_szHostName[256];
	if (byteStrLen)
	{
		memset(g_szHostName, 0, sizeof(g_szHostName));
		bsInitGame.Read(g_szHostName, byteStrLen);
	}
	g_szHostName[byteStrLen] = '\0';

	bsInitGame.Read((char *)&byteVehicleModels[0], 212);

	Log(ctx, "{FFFFFF}Connected to {FF0000}%.64s", g_szHostName);

	bsInitGame.Read((char *)&byteVehicleModels[0], 212);

	ctx->client.playerid = MyPlayerID;
	ctx->client.gameInited = true;
}

void ConnectionRejected(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);
	BYTE byteRejectReason;

	bsData.Read(byteRejectReason);

	if (byteRejectReason == REJECT_REASON_BAD_VERSION)
	{
		Log(ctx, "{FF0000}Bad SA-MP version.");
	}
	else if (byteRejectReason == REJECT_REASON_BAD_NICKNAME)
	{
		Log(ctx, "{FF0000}Bad nickname.");
	}
	else if (byteRejectReason == REJECT_REASON_BAD_MOD)
	{
		Log(ctx, "{FF0000}Bad mod version.");
	}
	else if (byteRejectReason == REJECT_REASON_BAD_PLAYERID)
	{
		Log(ctx, "{FF0000}Bad player ID.");
	}
	else
		Log(ctx, "{FF0000}ConnectionRejected: unknown");

	sampDisconnect(ctx);
	ctx->running.store(false);
}

static std::string colorToString(uint32_t color)
{
	uint8_t r = (color & 0xFF000000) >> 24;
	uint8_t g = (color & 0x00FF0000) >> 16;
	uint8_t b = (color & 0x0000FF00) >> 8;

	std::stringstream ss;
	ss << "{"
	   << std::uppercase
	   << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(r)
	   << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(g)
	   << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(b)
	   << "}";

	return ss.str();
}

static int32_t secondsFromMessage(const std::string &msg)
{

	std::regex re(R"((\d+))");
	std::smatch m;
	if (std::regex_search(msg, m, re))
	{
		try
		{
			int32_t minutes = std::stoi(m.str(1));
			return minutes * 60;
		}
		catch (...)
		{
			return -1;
		}
	}
	return -1;
}

void ClientMessage(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);
	uint32_t dwStrLen, dwColor;
	char szMsg[257];
	memset(szMsg, 0, 257);

	bsData.Read(dwColor);
	bsData.Read(dwStrLen);
	if (dwStrLen > 256)
		return;

	bsData.Read(szMsg, dwStrLen);
	szMsg[dwStrLen] = 0;

	char szNonColorEmbeddedMsg[257];
	int iNonColorEmbeddedMsgLen = 0;
	Log(ctx, "%s%s", colorToString(dwColor).c_str(), szMsg);
	// Log(ctx, "[CMSG] [%s] %s", ctx->client.nickName, szMsg);
	for (size_t pos = 0; pos < strlen(szMsg) && szMsg[pos] != '\0'; pos++)
	{
		if (!((*(unsigned char *)(&szMsg[pos]) - 32) >= 0 && (*(unsigned char *)(&szMsg[pos]) - 32) < 224))
			continue;

		if (pos + 7 < strlen(szMsg))
		{
			if (szMsg[pos] == '{' && szMsg[pos + 7] == '}')
			{
				pos += 7;
				continue;
			}
		}

		szNonColorEmbeddedMsg[iNonColorEmbeddedMsgLen] = szMsg[pos];
		iNonColorEmbeddedMsgLen++;
	}

	szNonColorEmbeddedMsg[iNonColorEmbeddedMsgLen] = 0;

	if (isSubstring(szNonColorEmbeddedMsg, "Due to high server population, you cannot connect using RakSAMP. You can join again"))
	{

		int32_t sec = secondsFromMessage(std::string(szNonColorEmbeddedMsg));

		if (sec == -1)
			resetPools(ctx, 120);
		else
			resetPools(ctx, sec);
	}

	if (!strcmp(szNonColorEmbeddedMsg, "=> [KICK-ERROR] You need to rent/buy a house in order to connect using RakSAMP.") ||
		!strcmp(szNonColorEmbeddedMsg, "=> [KICK-ERROR] You cannot connect using RakSAMP when you have wanted levels.") ||
		!strcmp(szNonColorEmbeddedMsg, "=> [KICK-ERROR] You cannot connect using RakSAMP when you are in jail.") ||
		!strcmp(szNonColorEmbeddedMsg, "Error: Shoma bayad ba launcher varede bazi shavid. (Varede linke ru beru shavid: ag5.ir/L)") ||
		!strcmp(szNonColorEmbeddedMsg, "Error: This account is already logged in.") ||
		!strcmp(szNonColorEmbeddedMsg, "You are banned."))
	{
		sampDisconnect(ctx);
		ctx->running.store(false);
	}

	if (!ctx->client.logined && (!strcmp(szNonColorEmbeddedMsg, "It appears that you're using RakSAMP.") || !strcmp(szNonColorEmbeddedMsg, "You will be automatically put to sleep and you cannot get out from asleep mode.") || isSubstring(szNonColorEmbeddedMsg, "Welcome ")))
	{
		Log(ctx, "{00FF00}Login successfully {FFDE21}%s (%d)", ctx->client.nickName, ctx->client.playerid);
		sampSpawn(ctx);
		ctx->client.logined = true;
	}
}

void RequestClass(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	BYTE byteRequestOutcome = 0;

	bsData.Read(byteRequestOutcome);

	if (byteRequestOutcome)
	{
		bsData.Read((PCHAR)&ctx->client.SpawnInfo, sizeof(PLAYER_SPAWN_INFO));
	}
}

void ScrDialogBox(RPCParameters *rpcParams)
{
	RPC_CTX
	if (!ctx->client.gameInited)
		return;

	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;
	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	bsData.Read(ctx->client.dialogid);
	bsData.Read(ctx->client.sampDialog.bDialogStyle);

	bsData.Read(ctx->client.sampDialog.bTitleLength);
	bsData.Read(ctx->client.sampDialog.szTitle, ctx->client.sampDialog.bTitleLength);
	ctx->client.sampDialog.szTitle[ctx->client.sampDialog.bTitleLength] = 0;

	bsData.Read(ctx->client.sampDialog.bButton1Len);
	bsData.Read(ctx->client.sampDialog.szButton1, ctx->client.sampDialog.bButton1Len);
	ctx->client.sampDialog.szButton1[ctx->client.sampDialog.bButton1Len] = 0;

	bsData.Read(ctx->client.sampDialog.bButton2Len);
	bsData.Read(ctx->client.sampDialog.szButton2, ctx->client.sampDialog.bButton2Len);
	ctx->client.sampDialog.szButton2[ctx->client.sampDialog.bButton2Len] = 0;

	stringCompressor->DecodeString(ctx->client.sampDialog.szInfo, 256, &bsData);
	if (ctx->client.dialogid == 1)
	{
		sampSpawn(ctx);
		sendDialogResponse(ctx, ctx->client.dialogid, 1, 0, "");
	}
	else if (ctx->client.dialogid == 2)
	{
		sendDialogResponse(ctx, ctx->client.dialogid, 1, 0, ctx->userPassword);
	}
	else if (ctx->client.dialogid == 3)
	{
		Log(ctx, "{FF0000}Your password doesn't correct.");
		sampDisconnect(ctx);
		ctx->running.store(false);
	}

	ctx->client.dialogid = 0;
}

void ScrSetPlayerPos(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	bsData.Read(ctx->client.normalModePos[0]);
	bsData.Read(ctx->client.normalModePos[1]);
	bsData.Read(ctx->client.normalModePos[2]);
}

void ScrSetPlayerFacingAngle(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);
	bsData.Read(ctx->client.normalModeRot);
}

void ScrSetSpawnInfo(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	bsData.Read((PCHAR)&ctx->client.SpawnInfo, sizeof(PLAYER_SPAWN_INFO));

	ctx->client.normalModePos[0] = ctx->client.SpawnInfo.vecPos[0];
	ctx->client.normalModePos[1] = ctx->client.SpawnInfo.vecPos[1];
	ctx->client.normalModePos[2] = ctx->client.SpawnInfo.vecPos[2];
}

void ScrSetPlayerHealth(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	bsData.Read(ctx->client.playerHealth);
}

void ScrSetPlayerArmour(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	bsData.Read(ctx->client.playerArmour);
}

void ScrTogglePlayerSpectating(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	BOOL bToggle;
	bsData.Read(bToggle);

	if (ctx->client.isSpectating && !bToggle && !ctx->client.spawned)
	{
		sampSpawn(ctx);
		ctx->client.spawned = true;
	}

	ctx->client.isSpectating = bToggle;
}

void ScrSetDrunkLevel(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	bsData.Read(ctx->client.drunkLevel);
}

void ScrHaveSomeMoney(RPCParameters *rpcParams)
{
	RPC_CTX
	PCHAR Data = reinterpret_cast<PCHAR>(rpcParams->input);
	int iBitLength = rpcParams->numberOfBitsOfData;

	RakNet::BitStream bsData((unsigned char *)Data, (iBitLength / 8) + 1, false);

	int iGivenMoney;
	bsData.Read(iGivenMoney);

	ctx->client.money += iGivenMoney;
}

void ScrResetMoney(RPCParameters *rpcParams)
{
	RPC_CTX
	ctx->client.money = 0;
}

void RegisterRPCs(MNRakSampContext *ctx)
{
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_InitGame, InitGame);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ConnectionRejected, ConnectionRejected);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ClientMessage, ClientMessage);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_RequestClass, RequestClass);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrDialogBox, ScrDialogBox);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrSetPlayerPos, ScrSetPlayerPos);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrSetPlayerFacingAngle, ScrSetPlayerFacingAngle);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrSetSpawnInfo, ScrSetSpawnInfo);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrSetPlayerHealth, ScrSetPlayerHealth);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrSetPlayerArmour, ScrSetPlayerArmour);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrTogglePlayerSpectating, ScrTogglePlayerSpectating);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrSetPlayerDrunkLevel, ScrSetDrunkLevel);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrHaveSomeMoney, ScrHaveSomeMoney);
	ctx->client.rakClient->RegisterAsRemoteProcedureCall(&RPC_ScrResetMoney, ScrResetMoney);
}
