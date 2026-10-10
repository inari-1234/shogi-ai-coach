// GPL-3.0-or-later
#include "engine_bridge.h"

#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>
#include <iostream>
#include <mutex>
#include <streambuf>
#include <string>
#include <thread>

#include "bitboard.h"
#include "misc.h"
#include "position.h"
#include "types.h"
#include "usi.h"
#include "engine/yaneuraou-engine/yaneuraou-search.h"

using namespace YaneuraOu;

namespace {

class SocketOut : public std::streambuf {
 public:
  explicit SocketOut(int fd) : fd_(fd) {}

 protected:
  int overflow(int c) override {
    if (c == EOF) return c;
    const char ch = static_cast<char>(c);
    return writeAll(&ch, 1) ? c : EOF;
  }

  std::streamsize xsputn(const char* s, std::streamsize n) override {
    return writeAll(s, static_cast<size_t>(n)) ? n : 0;
  }

 private:
  bool writeAll(const char* s, size_t n) {
    size_t offset = 0;
    while (offset < n) {
      const ssize_t written = ::write(fd_, s + offset, n - offset);
      if (written > 0) {
        offset += static_cast<size_t>(written);
        continue;
      }
      if (written < 0 && errno == EINTR) continue;
      return false;
    }
    return true;
  }

  int fd_;
};

bool readLine(int fd, std::string& line) {
  line.clear();
  for (;;) {
    char ch = 0;
    const ssize_t n = ::read(fd, &ch, 1);
    if (n > 0) {
      if (ch == '\n') return true;
      if (ch != '\r') line.push_back(ch);
      continue;
    }
    if (n < 0 && errno == EINTR) continue;
    return false;
  }
}

void runEngine(int fd) {
  SocketOut out(fd);
  auto* previousOut = std::cout.rdbuf(&out);
  std::cout.clear();

  const char* prog = "yaneuraou";
  char* argv[] = {const_cast<char*>(prog), nullptr};
  CommandLine::g.set_arg(1, argv);

  Bitboards::init();
  Position::init();

  YaneuraOuEngine engine;
  USIEngine usi;
  usi.set_engine(engine);

  // VE1-B completion telemetry: YaneuraOu's node-limit stop check uses this
  // same ThreadPool::nodes_searched() counter. Emit the final value immediately
  // before the ordinary bestmove callback so the Swift side can distinguish a
  // true node-budget completion from an engine-side early termination. The
  // line is legal scoreless USI info and is retained losslessly without
  // replacing the selected scored PV.
  auto originalBestmove = engine.get_on_bestmove();
  engine.set_on_bestmove(
      [&engine, originalBestmove](auto bestmove, auto ponder) {
        const auto finalNodes = engine.get_threads().nodes_searched();
        sync_cout << "info nodes " << finalNodes
                  << " string ve1b_final_nodes" << sync_endl;
        originalBestmove(bestmove, ponder);
      });

  sync_cout << "info string bridge_dispatch_ready" << sync_endl;

  std::string command;
  while (readLine(fd, command)) {
    if (usi.mobile_execute_command(command)) break;
  }

  engine.stop();
  engine.wait_for_search_finished();

  std::cout.rdbuf(previousOut);
  std::cout.clear();
}

std::mutex engineMutex;
std::thread engineThread;

void replaceEngine(std::thread previous, int engineFd) {
  if (previous.joinable()) previous.join();
  runEngine(engineFd);
  ::close(engineFd);
}

void setNoSigPipe(int fd) {
#ifdef SO_NOSIGPIPE
  int yes = 1;
  ::setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
#else
  (void)fd;
#endif
}

}  // namespace

extern "C" int yaneuraou_open_session(void) {
  int pair[2] = {-1, -1};
  if (::socketpair(AF_UNIX, SOCK_STREAM, 0, pair) != 0) {
    return -errno;
  }

  setNoSigPipe(pair[0]);
  setNoSigPipe(pair[1]);

  std::lock_guard<std::mutex> lock(engineMutex);
  std::thread previous = std::move(engineThread);
  engineThread = std::thread(replaceEngine, std::move(previous), pair[1]);
  return pair[0];
}
