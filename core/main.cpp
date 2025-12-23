
#include "main.h"
#include <random>
#include <fstream>

static std::unordered_map<RakPeerInterface *, MNRakSampContext *> g_ctxMap;
static std::mutex g_ctxMutex;

static std::unordered_map<std::string, MNRakSampContext *> g_userToCtx;
static std::mutex g_userToCtxMutex;

constexpr size_t MAX_LOGS = 500;

MNRakSampContext *mn_ctx_from_rpc(RPCParameters *p)
{
      std::lock_guard<std::mutex> lock(g_ctxMutex);
      return g_ctxMap[p->recipient];
}

void rs_register_ctx(RakPeerInterface *peer, MNRakSampContext *ctx)
{
      std::lock_guard<std::mutex> lock(g_ctxMutex);
      g_ctxMap[peer] = ctx;
}

void rs_unregister_ctx(RakPeerInterface *peer)
{
      std::lock_guard<std::mutex> lock(g_ctxMutex);
      g_ctxMap.erase(peer);
}

void Log(MNRakSampContext *ctx, const char *fmt, ...)
{
      if (!ctx)
            return;

      time_t now = time(0);
      struct tm tstruct;
      char ts[32];
      tstruct = *localtime(&now);
      // [11:13:20]
      strftime(ts, sizeof(ts), "[%H:%M:%S] ", &tstruct);

      char buf[1024];
      va_list args;
      va_start(args, fmt);
      vsnprintf(buf, sizeof(buf), fmt, args);
      va_end(args);

      std::string color = std::string(buf).substr(0, 8);
      std::string chat = std::string(buf).substr(8);

      std::string finalLog = color + std::string(ts) + chat;

      // fflush(stdout);
      std::lock_guard<std::mutex> lock(ctx->logsMutex);

      if (ctx->logs.size() >= MAX_LOGS)
            ctx->logs.pop_front();

      ctx->logs.emplace_back(finalLog);
}
EXPORT const char *mn_get_logs(mn_handle h)
{
      static thread_local std::string result;

      auto *ctx = (MNRakSampContext *)h;
      if (!ctx)
            return "";

      std::lock_guard<std::mutex> lock(ctx->logsMutex);

      result.clear();
      for (auto &l : ctx->logs)
      {
            result += l;
            result += '\n';
      }
      return result.c_str();
}

EXPORT void mn_clear_logs(mn_handle h)
{
      auto *ctx = (MNRakSampContext *)h;
      if (!ctx)
            return;

      std::lock_guard<std::mutex> lock(ctx->logsMutex);
      ctx->logs.clear();
}

static void core_loop(MNRakSampContext *ctx)
{

      ctx->client.rakClient = RakNetworkFactory::GetRakClientInterface();
      if (ctx->client.rakClient == NULL)
            return;
      ctx->client.rakClient->SetMTUSize(576);
      RakPeerInterface *peerPtr = dynamic_cast<RakPeerInterface *>(ctx->client.rakClient);
      rs_register_ctx(peerPtr, ctx);
      RegisterRPCs(ctx);

      while (ctx->running.load())
      {
            UpdateNetwork(ctx);

            if (ctx->client.sleepTime)
            {
                  if (GETTICKCOUNT() > ctx->client.sleepTime)
                  {
                        ctx->client.connectionRequested = false;
                        ctx->client.sleepTime = 0;
                  }
            }
            else
            {
                  if (!ctx->client.connectionRequested)
                  {
                        sampConnect(ctx);
                        ctx->client.connectionRequested = true;
                  }

                  if (ctx->client.areWeConnected && ctx->client.gameInited)
                  {
                        if (!ctx->client.spawned)
                        {
                              if (!ctx->client.callSampRequestClass)
                              {
                                    sampRequestClass(ctx);
                                    ctx->client.callSampRequestClass = 1;
                              }
                        }
                        else
                        {
                              if (!ctx->client.isSpectating)
                                    onFootUpdateAtNormalPos(ctx);
                              else
                                    spectatorUpdate(ctx);

                              const auto tickCount = GETTICKCOUNT();
                              if (tickCount - ctx->client.lastStatsUpdate >= 1000 || ctx->client.money != ctx->client.lastMoney || ctx->client.drunkLevel != ctx->client.lastDrunkLevel)
                              {
                                    RakNet::BitStream bsSend;
                                    bsSend.Write((BYTE)ID_STATS_UPDATE);
                                    ctx->client.drunkLevel -= (rand() % 90 + 20);
                                    if (ctx->client.drunkLevel < 0)
                                          ctx->client.drunkLevel = 0;
                                    bsSend.Write(ctx->client.money);
                                    bsSend.Write(ctx->client.drunkLevel);
                                    ctx->client.rakClient->Send(&bsSend, HIGH_PRIORITY, RELIABLE, 0);
                                    ctx->client.lastMoney = ctx->client.money;
                                    ctx->client.lastDrunkLevel = ctx->client.drunkLevel;
                                    ctx->client.lastStatsUpdate = tickCount;
                              }
                        }
                  }
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(333));
      }
      rs_unregister_ctx(peerPtr);
      RakNetworkFactory::DestroyRakClientInterface(ctx->client.rakClient);
}

EXPORT bool mn_isrunning(mn_handle h)
{
      auto *ctx = (MNRakSampContext *)h;
      if (!ctx)
            return false;

      return ctx->running.load();
}

EXPORT mn_handle mn_create(void)
{
      return new MNRakSampContext();
}

EXPORT mn_handle mn_find_handle(const char *username)
{
      if (!username)
            return nullptr;
      std::lock_guard<std::mutex> lock(g_userToCtxMutex);
      auto it = g_userToCtx.find(username);
      if (it != g_userToCtx.end())
            return it->second;
      return nullptr;
}

EXPORT void mn_destroy(mn_handle h)
{
      if (!h)
            return;

      auto *ctx = (MNRakSampContext *)h;
      {
            std::lock_guard<std::mutex> lock(g_userToCtxMutex);
            if (ctx->userName[0] != 0)
            {
                  g_userToCtx.erase(ctx->userName);
            }
      }

      mn_stop(h);
      if (ctx->thread.joinable())
            ctx->thread.join();

      delete ctx;
}

EXPORT int mn_start(mn_handle h, const char *username, const char *password)
{
      auto *ctx = (MNRakSampContext *)h;
      if (!ctx || ctx->running.load())
            return 0;

      memset(ctx->userName, 0, sizeof(ctx->userName));
      memset(ctx->userPassword, 0, sizeof(ctx->userPassword));
      strncpy(ctx->userName, username, sizeof(ctx->userName) - 1);
      strncpy(ctx->userPassword, password, sizeof(ctx->userPassword) - 1);

      {
            std::lock_guard<std::mutex> lock(g_userToCtxMutex);
            g_userToCtx[username] = ctx;
      }

      if (ctx->thread.joinable())
            ctx->thread.join();

      ctx->client = stRakClient();

      ctx->running.store(true);
      ctx->thread = std::thread(core_loop, ctx);

      Log(ctx, "{FFFFFF}Starting account %s...", ctx->userName);
      return 1;
}

EXPORT void mn_stop(mn_handle h)
{
      auto *ctx = (MNRakSampContext *)h;

      if (!ctx->running.load())
            return;

      ctx->running.store(false);
}

EXPORT void mn_sendchat(mn_handle h, const char *chat)
{
      auto *ctx = (MNRakSampContext *)h;
      if (!ctx || !ctx->running.load())
            return;

      char szCMD[512];
      strncpy(szCMD, chat, sizeof(szCMD) - 1);
      szCMD[sizeof(szCMD) - 1] = 0;

      if (szCMD[0] == 0x00)
            return;

      if (!strnicmp(szCMD, "/reconnect", 9) || !strnicmp(szCMD, "/rec", 9))
      {
            resetPools(ctx, 5);
            return;
      }

      if (szCMD[0] == '/')
            sendServerCommand(ctx, szCMD);
      else
            sendChat(ctx, szCMD);
}

bool isSubstring(const char *input, const char *substr)
{
      while (*input != '\0')
      {
            const char *p1 = input;
            const char *p2 = substr;
            while (*p1 != '\0' && *p2 != '\0' && *p1 == *p2)
            {
                  ++p1;
                  ++p2;
            }
            if (*p2 == '\0')
            {
                  return true; // Found a match
            }
            ++input;
      }
      return false; // No match found
}
