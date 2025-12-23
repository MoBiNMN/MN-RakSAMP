#include "main.h"

void Packet_AUTH_KEY(MNRakSampContext *ctx, Packet *p)
{
	RakNet::BitStream bsAuth((unsigned char *)p->data, p->length, false);

	BYTE byteAuthLen;
	char szAuth[260];

	bsAuth.IgnoreBits(8); // ID_AUTH_KEY
	bsAuth.Read(byteAuthLen);
	bsAuth.Read(szAuth, byteAuthLen);
	szAuth[byteAuthLen] = '\0';

	// char szAuthKey[260];

	// gen_auth_key(szAuthKey, szAuth);
	const char *szAuthKey = GetClientKey(szAuth);
	RakNet::BitStream bsKey;
	BYTE byteAuthKeyLen = (BYTE)strlen(szAuthKey);

	bsKey.Write((BYTE)ID_AUTH_KEY);
	bsKey.Write((BYTE)byteAuthKeyLen);
	bsKey.Write(szAuthKey, byteAuthKeyLen);
	ctx->client.rakClient->Send(&bsKey, SYSTEM_PRIORITY, RELIABLE, 0);
}

void Packet_ConnectionSucceeded(MNRakSampContext *ctx, Packet *p)
{
	RakNet::BitStream bsSuccAuth((unsigned char *)p->data, p->length, false);

	unsigned int uiChallenge;

	bsSuccAuth.IgnoreBits(8);  // ID_CONNECTION_REQUEST_ACCEPTED
	bsSuccAuth.IgnoreBits(32); // binaryAddress
	bsSuccAuth.IgnoreBits(16); // port

	bsSuccAuth.Read(ctx->client.playerid);
	bsSuccAuth.Read(uiChallenge);

	ctx->client.isConnected = true;
	Log(ctx, "{FFFFFF}Connected. Joining the game...");

	int iVersion = NETGAME_VERSION;
	unsigned int uiClientChallengeResponse = uiChallenge ^ iVersion;
	BYTE byteMod = 1;

	const char *auth_bs = GetAuthBS();

	BYTE byteAuthBSLen;
	byteAuthBSLen = (BYTE)strlen(auth_bs);
	BYTE byteNameLen = (BYTE)strlen(ctx->client.nickName);
	BYTE byteClientVerLen = strlen(SAMP_VERSION);

	RakNet::BitStream bsSend;

	bsSend.Write(iVersion);
	bsSend.Write(byteMod);
	bsSend.Write(byteNameLen);
	bsSend.Write(ctx->client.nickName, byteNameLen);
	bsSend.Write(uiClientChallengeResponse);

	bsSend.Write(byteAuthBSLen);
	bsSend.Write(auth_bs, byteAuthBSLen);
	bsSend.Write(byteClientVerLen);
	bsSend.Write(SAMP_VERSION, byteClientVerLen);

	ctx->client.rakClient->RPC(&RPC_ClientJoin, &bsSend, HIGH_PRIORITY, RELIABLE, 0, false, UNASSIGNED_NETWORK_ID, nullptr);

	ctx->client.areWeConnected = true;
}

void resetPools(MNRakSampContext *ctx, int second)
{

	ctx->client.sleepTime = GETTICKCOUNT() + (second * 1000);
	ctx->client.areWeConnected = false;
	ctx->client.callSampRequestClass = false;
	ctx->client.spawned = false;
	ctx->client.playerHealth = 100.0f;
	ctx->client.playerArmour = 0.0f;
	ctx->client.logined = false;
	ctx->client.money = 0;
	ctx->client.drunkLevel = 0;
	sampDisconnect(ctx);
	Log(ctx, "{FFFFFF}Reconnecting in %d seconds.", second);
}

void UpdateNetwork(MNRakSampContext *ctx)
{
	unsigned char packetIdentifier;
	Packet *pkt;

	while ((pkt = ctx->client.rakClient->Receive()) != nullptr)
	{
		if ((unsigned char)pkt->data[0] == ID_TIMESTAMP)
		{
			if (pkt->length > sizeof(unsigned char) + sizeof(unsigned int))
				packetIdentifier = (unsigned char)pkt->data[sizeof(unsigned char) + sizeof(unsigned int)];
			else
				return;
		}
		else
			packetIdentifier = (unsigned char)pkt->data[0];

		switch (packetIdentifier)
		{
		case ID_DISCONNECTION_NOTIFICATION:
			Log(ctx, "{FF0000}Connection was closed by the server.");
			resetPools(ctx);
			break;
		case ID_CONNECTION_BANNED:
			Log(ctx, "{FF0000}You are banned.");
			resetPools(ctx, 60);
			break;
		case ID_CONNECTION_ATTEMPT_FAILED:
			Log(ctx, "{FF0000}Connection attempt failed.");
			resetPools(ctx);
			break;
		case ID_NO_FREE_INCOMING_CONNECTIONS:
			Log(ctx, "{FF0000}The server is full.");
			sampDisconnect(ctx);
			ctx->running.store(false);
			break;
		case ID_INVALID_PASSWORD:
			Log(ctx, "{FF0000}Invalid server password.");
			resetPools(ctx);
			break;
		case ID_CONNECTION_LOST:
			Log(ctx, "{FF0000}The connection was lost.");
			resetPools(ctx);
			break;
		case ID_CONNECTION_REQUEST_ACCEPTED:
			Packet_ConnectionSucceeded(ctx, pkt);
			break;
		case ID_AUTH_KEY:
			Packet_AUTH_KEY(ctx, pkt);
			break;
		case ID_PLAYER_SYNC:
		case ID_VEHICLE_SYNC:
		case ID_PASSENGER_SYNC:
		case ID_AIM_SYNC:
		case ID_TRAILER_SYNC:
		case ID_UNOCCUPIED_SYNC:
		case ID_MARKERS_SYNC:
		case ID_BULLET_SYNC:
			break;
		}

		ctx->client.rakClient->DeallocatePacket(pkt);
	}

	if ((GETTICKCOUNT() - ctx->client.dwLastUpdateTick) > 3000)
	{
		ctx->client.dwLastUpdateTick = GETTICKCOUNT();
		RakNet::BitStream bsParams;
		ctx->client.rakClient->RPC(&RPC_UpdateScoresPingsIPs, &bsParams, HIGH_PRIORITY, RELIABLE, 0, FALSE, UNASSIGNED_NETWORK_ID, 0);
	}
}
