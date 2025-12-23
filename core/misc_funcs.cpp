#include "main.h"

void onFootUpdateAtNormalPos(MNRakSampContext *ctx)
{
	ONFOOT_SYNC_DATA ofSync;
	memset(&ofSync, 0, sizeof(ONFOOT_SYNC_DATA));

	ofSync.byteHealth = (BYTE)ctx->client.playerHealth;
	ofSync.byteArmour = (BYTE)ctx->client.playerArmour;
	ofSync.fQuaternion[3] = ctx->client.normalModeRot;
	ofSync.vecPos[0] = ctx->client.normalModePos[0];
	ofSync.vecPos[1] = ctx->client.normalModePos[1];
	ofSync.vecPos[2] = ctx->client.normalModePos[2];
	RakNet::BitStream bsPlayerSync;
	ctx->client.currentPosition[0] = ofSync.vecPos[0];
	ctx->client.currentPosition[1] = ofSync.vecPos[1];
	ctx->client.currentPosition[2] = ofSync.vecPos[2];

	bsPlayerSync.Write((BYTE)ID_PLAYER_SYNC);
	bsPlayerSync.Write((PCHAR)&ofSync, sizeof(ONFOOT_SYNC_DATA));

	ctx->client.rakClient->Send(&bsPlayerSync, HIGH_PRIORITY, UNRELIABLE_SEQUENCED, 0);
}

void spectatorUpdate(MNRakSampContext *ctx)
{
	SPECTATOR_SYNC_DATA spSync;
	memset(&spSync, 0, sizeof(SPECTATOR_SYNC_DATA));

	spSync.vecPos[0] = ctx->client.normalModePos[0];
	spSync.vecPos[1] = ctx->client.normalModePos[1];
	spSync.vecPos[2] = ctx->client.normalModePos[2];
	RakNet::BitStream bsSpecSync;

	bsSpecSync.Write((BYTE)ID_SPECTATOR_SYNC);
	bsSpecSync.Write((PCHAR)&spSync, sizeof(SPECTATOR_SYNC_DATA));

	ctx->client.rakClient->Send(&bsSpecSync, HIGH_PRIORITY, UNRELIABLE_SEQUENCED, 0);
}

int sampConnect(MNRakSampContext *ctx)
{
	if (ctx->client.rakClient == NULL)
		return 0;
	Log(ctx, "{FFFFFF}Connecting...");
	strcpy(ctx->client.nickName, ctx->userName);

	ctx->client.rakClient->SetPassword("");
	return (int)ctx->client.rakClient->Connect("185.112.33.99", 7777, 0, 0, 5);
}

void sampDisconnect(MNRakSampContext *ctx)
{
	if (ctx->client.rakClient == NULL)
		return;
	ctx->client.rakClient->Disconnect(500);
}

void sampRequestClass(MNRakSampContext *ctx)
{
	if (ctx->client.rakClient == NULL)
		return;

	RakNet::BitStream bsSpawnRequest;
	bsSpawnRequest.Write(19);
	ctx->client.rakClient->RPC(&RPC_RequestClass, &bsSpawnRequest, HIGH_PRIORITY, RELIABLE, 0, FALSE, UNASSIGNED_NETWORK_ID, 0);
}

void sampSpawn(MNRakSampContext *ctx)
{
	if (ctx->client.rakClient == NULL)
		return;
	if (ctx->client.spawned == false)
	{
		ctx->client.normalModePos[0] = ctx->client.SpawnInfo.vecPos[0];
		ctx->client.normalModePos[1] = ctx->client.SpawnInfo.vecPos[1];
		ctx->client.normalModePos[2] = ctx->client.SpawnInfo.vecPos[2];
		ctx->client.normalModeRot = ctx->client.SpawnInfo.fRotation;
	}

	RakNet::BitStream bsSendRequestSpawn;
	ctx->client.rakClient->RPC(&RPC_RequestSpawn, &bsSendRequestSpawn, HIGH_PRIORITY, RELIABLE, 0, FALSE, UNASSIGNED_NETWORK_ID, 0);

	RakNet::BitStream bsSendSpawn;
	ctx->client.rakClient->RPC(&RPC_Spawn, &bsSendSpawn, HIGH_PRIORITY, RELIABLE, 0, FALSE, UNASSIGNED_NETWORK_ID, 0);

	ctx->client.isSpectating = false;

	Log(ctx, "{FFDE21}You have been spawned!");
}

void sendServerCommand(MNRakSampContext *ctx, const char *szCommand)
{
	RakNet::BitStream bsParams;
	int iStrlen = strlen(szCommand);
	bsParams.Write(iStrlen);
	bsParams.Write(szCommand, iStrlen);
	ctx->client.rakClient->RPC(&RPC_ServerCommand, &bsParams, HIGH_PRIORITY, RELIABLE, 0, FALSE, UNASSIGNED_NETWORK_ID, 0);
}

void sendChat(MNRakSampContext *ctx, char *szMessage)
{
	RakNet::BitStream bsSend;
	BYTE byteTextLen = static_cast<BYTE>(strlen(szMessage));
	bsSend.Write(byteTextLen);
	bsSend.Write(szMessage, byteTextLen);
	ctx->client.rakClient->RPC(&RPC_Chat, &bsSend, HIGH_PRIORITY, RELIABLE, 0, FALSE, UNASSIGNED_NETWORK_ID, 0);
}

void sendDialogResponse(MNRakSampContext *ctx, WORD wDialogID, BYTE bButtonID, WORD wListBoxItem, const char *szInputResp)
{
	BYTE respLen = (BYTE)strlen(szInputResp);
	RakNet::BitStream bsSend;
	bsSend.Write(wDialogID);
	bsSend.Write(bButtonID);
	bsSend.Write(wListBoxItem);
	bsSend.Write(respLen);
	bsSend.Write(szInputResp, respLen);
	ctx->client.rakClient->RPC(&RPC_DialogResponse, &bsSend, HIGH_PRIORITY, RELIABLE_ORDERED, 0, FALSE, UNASSIGNED_NETWORK_ID, 0);
}
