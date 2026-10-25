void onFootUpdateAtNormalPos(MNRakSampContext* ctx);
void spectatorUpdate(MNRakSampContext* ctx);
int sampConnect(MNRakSampContext* ctx);
void sampDisconnect(MNRakSampContext* ctx);
void sampRequestClass(MNRakSampContext* ctx);
void sampSpawn(MNRakSampContext* ctx);
void sendChat(MNRakSampContext* ctx,char* szMessage);
void sendServerCommand(MNRakSampContext* ctx,const char* szCommand);
void sendDialogResponse(MNRakSampContext* ctx,WORD wDialogID, BYTE bButtonID, WORD wListBoxItem, const char* szInputResp);
