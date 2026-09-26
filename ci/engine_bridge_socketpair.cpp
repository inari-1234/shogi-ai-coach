// GPL-3.0-or-later
#include "engine_bridge.h"

#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>
#include <iostream>
#include <mutex>
#include <streambuf>
#include <thread>

#include "bitboard.h"
#include "misc.h"
#include "position.h"
#include "types.h"

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

class SocketIn : public std::streambuf {
 public:
  explicit SocketIn(int fd) : fd_(fd) {}

 protected:
  int underflow() override {
    for (;;) {
      const ssize_t n = ::read(fd_, &ch_, 1);
      if (n > 0) {
        setg(&ch_, &ch_, &ch_ + 1);
        return static_cast<unsigned char>(ch_);
      }
      if (n < 0 && errno == EINTR) continue;
      return EOF;
    }
  }

 private:
  int fd_;
  char ch_ = 0;
};

void runEngine(int fd) {
  SocketOut out(fd);
  SocketIn in(fd);

  auto* previousOut = std::cout.rdbuf(&out);
  auto* previousIn = std::cin.rdbuf(&in);
  std::cout.clear();
  std::cin.clear();

  const char* ready = "info string bridge_stream_ready\n";
  ::write(fd, ready, std::strlen(ready));

  const char* prog = "yaneuraou";
  char* argv[] = {const_cast<char*>(prog), nullptr};
  CommandLine::g.set_arg(1, argv);
  Bitboards::init();
  const char* bitboards = "info string bridge_bitboards_ready\n";
  ::write(fd, bitboards, std::strlen(bitboards));

  Position::init();
  const char* position = "info string bridge_position_ready\n";
  ::write(fd, position, std::strlen(position));

  run_engine_entry();

  const char* exited = "info string bridge_engine_exit\n";
  ::write(fd, exited, std::strlen(exited));
  std::cout.rdbuf(previousOut);
  std::cin.rdbuf(previousIn);
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
