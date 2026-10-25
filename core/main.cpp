
#include "main.h"
#include <random>
#include <fstream>
#include <chrono>

static std::unordered_map<RakPeerInterface *, MNRakSampContext *> g_ctxMap;
static std::mutex g_ctxMutex;

static std::unordered_map<std::string, MNRakSampContext *> g_userToCtx;
static std::mutex g_userToCtxMutex;

constexpr size_t MAX_LOGS = 500;

MNRakSampContext *mn_ctx_from_rpc(RPCParameters *p)
{
      std::lock_guard<std::mutex> lock(g_ctxMutex);

      // Use find(), not operator[].  operator[] default-constructs and INSERTS a
      // null entry for an unknown recipient, so a stray RPC (or a context that
      // was already unregistered) would grow this map forever and leak one
      // dangling key per bad packet.
      auto it = g_ctxMap.find(p->recipient);
      if (it != g_ctxMap.end())
            return it->second;

      return nullptr;
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
EXPORT int mn_get_logs(mn_handle h, char *out, int outSize)
{
      if (!out || outSize <= 0)
            return 0;

      out[0] = '\0';

      auto *ctx = (MNRakSampContext *)h;
      if (!ctx)
            return 0;

      // Guard against a concurrent mn_destroy on another thread.
      if (ctx->destroyed.load())
            return 0;

      std::lock_guard<std::mutex> lock(ctx->logsMutex);

      // Re-check under the lock: mn_destroy takes this same mutex before
      // deleting ctx, so a read that raced in is either ordered before the
      // delete (and completes safely here) or after this check (and bails out).
      if (ctx->destroyed.load())
            return 0;

      // Write the log straight into the caller's buffer.  The previous version
      // returned a pointer into a static thread_local string, which meant every
      // account polled from the same thread shared one buffer and a later call
      // could clobber a pointer the caller still held.
      //
      // The log view re-reads the whole deque on every poll, so when the lines do
      // not all fit we must decide *which* ones to drop.  Keep the NEWEST and
      // drop from the front: a chat log cares about the latest messages.  The
      // old code wrote as many bytes as would fit and then cut the next line
      // short mid-character, which corrupts UTF-8 (the whole line renders as
      // replacement boxes) and silently loses the tail entirely.
      const int capacity = outSize - 1;

      // Walk back from the newest line, accumulating whole lines only.
      size_t start = ctx->logs.size();
      int needed = 0;
      while (start > 0)
      {
            int need = (int)ctx->logs[start - 1].size() + 1; // + '\n'
            if (needed + need > capacity)
                  break;
            needed += need;
            --start;
      }

      int written = 0;
      for (size_t i = start; i < ctx->logs.size(); ++i)
      {
            const std::string &line = ctx->logs[i];

            memcpy(out + written, line.data(), line.size());
            written += (int)line.size();

            // 'needed' already reserved room for every separator we emit.
            if (written < capacity)
                  out[written++] = '\n';
      }

      out[written] = '\0';
      return written;
}

EXPORT void mn_clear_logs(mn_handle h)
{
      auto *ctx = (MNRakSampContext *)h;
      if (!ctx)
            return;

      std::lock_guard<std::mutex> lock(ctx->logsMutex);
      if (ctx->destroyed.load())
            return;

      ctx->logs.clear();
}

// The server publishes how often it wants on-foot / in-car updates.  Sending
// faster than that is what gets multi-account clients falsely flagged for
// teleport hacking, so derive the loop delay from the advertised rate instead of
// using a hardcoded constant.  Values are taken from the per-account context, so
// concurrent accounts never share this state.
static std::chrono::milliseconds sendRateDelay(MNRakSampContext *ctx)
{
      constexpr int kDefaultRate = 3; // ~333ms, used before RPC_InitGame arrives
      constexpr int kMinRate = 1;

      int rate = kDefaultRate;

      if (ctx->client.hasSendRate)
      {
            int multiplier = ctx->client.netModeSendMultiplier;
            if (multiplier < 1)
                  multiplier = 1;

            // This core only emits on-foot and spectator syncs (no vehicle sync
            // path), so the on-foot rate is the applicable one.
            rate = ctx->client.netModeNormalOnfootSendRate;

            // iNetModeSendMultiplier scales the base rate for servers that ask for
            // denser updates.
            rate *= multiplier;
      }

      if (rate < kMinRate)
            rate = kMinRate;

      // Clamp the derived delay, not the rate.  '1000 / rate' is integer
      // division, so any rate above 1000 collapses the delay to 0 and core_loop
      // stops sleeping entirely - it becomes a busy spin that pegs one core per
      // account.  A misbehaving or hostile server can advertise that in four
      // bytes of RPC_InitGame, and it costs nothing to defend: 100 Hz is far
      // above anything a SA-MP server asks for, and the pre-RPC default was
      // 333 ms anyway.
      constexpr int kMaxRateHz = 100;    // 10 ms floor
      constexpr int kMinDelayMs = 1000 / kMaxRateHz;
      constexpr int kMaxDelayMs = 1000;

      int delayMs = 1000 / rate;
      if (delayMs < kMinDelayMs)
            delayMs = kMinDelayMs;
      if (delayMs > kMaxDelayMs)
            delayMs = kMaxDelayMs;

      return std::chrono::milliseconds(delayMs);
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
                                    // Per-context RNG.  rand() is process-global and its
                                    // thread-safety is not guaranteed by the standard; with
                                    // one core_loop per account these threads all pull from
                                    // the same generator.
                                    ctx->client.drunkLevel -= (int)(ctx->rng() % 90u + 20u);
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

            std::this_thread::sleep_for(sendRateDelay(ctx));
      }
      rs_unregister_ctx(peerPtr);
      RakNetworkFactory::DestroyRakClientInterface(ctx->client.rakClient);
      // Clear the pointer so nothing can reach the destroyed interface.  core_loop
      // is the only owner, and mn_start() joins this thread before it assigns a
      // new one, but leaving a dangling pointer behind makes that contract
      // implicit rather than enforced.
      ctx->client.rakClient = nullptr;
}

EXPORT bool mn_isrunning(mn_handle h)
{
      auto *ctx = (MNRakSampContext *)h;
      if (!ctx)
            return false;

      if (ctx->destroyed.load())
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

      // Mark the context dead and take logsMutex so any mn_get_logs call that
      // already passed its destroyed check finishes against valid memory before
      // we free it.  After this block no new reader can get in.
      {
            std::lock_guard<std::mutex> lock(ctx->logsMutex);
            ctx->destroyed.store(true);
      }

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
      if (!ctx)
            return;

      if (ctx->destroyed.load())
            return;

      if (!ctx->running.load())
            return;

      ctx->running.store(false);
}

EXPORT void mn_sendchat(mn_handle h, const char *chat)
{
      auto *ctx = (MNRakSampContext *)h;
      if (!ctx || !chat)
            return;

      if (ctx->destroyed.load())
            return;

      if (!ctx->running.load())
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
