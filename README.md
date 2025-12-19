_This project has been created as part of the 42 curriculum by saleshin._

# ft_irc

A fully functional **IRC (Internet Relay Chat) server** implementation in C++98, compliant with RFC 1459 and RFC 2812. The server handles multiple concurrent clients using non-blocking I/O and the `poll()` system call, implementing core IRC functionality including user registration, channels, private messaging, and channel operator commands.

## Description

This project implements an IRC server from scratch following the 42 School guidelines. The server architecture consists of 4 clean C++ classes following the Orthodox Canonical Form:

- **Server**: Main class managing network operations, client connections, and command dispatch
- **Client**: Represents a connected user with registration state and I/O buffers
- **Channel**: Manages IRC channels with members, operators, modes, and topic
- **Message**: Handles IRC protocol parsing, serialization, and numeric replies

Key features:
- **Non-blocking I/O** with `poll()` multiplexing for scalability
- **IRC protocol** compliance with proper numeric replies and error handling
- **Channel management** with operator privileges and invite-only/topic-restricted/password-protected modes
- **User limit** enforcement on channels
- **Signal handling** for graceful shutdown (SIGINT/SIGTERM)
- **Keep-alive** mechanism via PING/PONG

The project has been thoroughly tested with 92 automated tests covering all IRC commands and edge cases.

## Instructions

### Requirements

- **Compiler**: `c++` (C++98 standard)
- **OS**: Linux/macOS (any UNIX-like system with `poll()`)
- **IRC Client**: `nc` (netcat), `irssi`, `HexChat`, or any RFC-compliant IRC client

### Compilation

```bash
make
```

This creates the `ircserv` executable.

### Running the Server

```bash
./ircserv <port> <password>
```

**Parameters:**
- `<port>`: Port number for incoming connections (1024-65535)
- `<password>`: Server password required for client connection

**Example:**
```bash
./ircserv 6667 secretpass
```

The server will start listening on the specified port. Press `Ctrl+C` for graceful shutdown.

### Connecting with a Client

#### Using netcat (manual testing):

```bash
nc localhost 6667
```

Then type the following commands:
```
PASS secretpass
NICK john
USER john 0 * :John Doe
```

You should receive a welcome message (numeric replies 001-004).

#### Using irssi (recommended):

```bash
irssi -c localhost -p 6667 -w secretpass
```

Once connected:
```
/nick john
/join #general
/msg #general Hello everyone!
```

### Basic IRC Commands

| Command | Description | Example |
|---------|-------------|---------|
| `PASS <password>` | Authenticate with server | `PASS secretpass` |
| `NICK <nickname>` | Set or change your nickname | `NICK john` |
| `USER <username> 0 * :<realname>` | Register user | `USER john 0 * :John Doe` |
| `JOIN <channel>` | Join or create a channel | `JOIN #general` |
| `PART <channel>` | Leave a channel | `PART #general` |
| `PRIVMSG <target> :<message>` | Send message to user/channel | `PRIVMSG #general :Hello!` |
| `TOPIC <channel> [:<topic>]` | View or set channel topic | `TOPIC #general :New topic` |
| `KICK <channel> <user>` | Kick user from channel (op only) | `KICK #general bob` |
| `INVITE <user> <channel>` | Invite user to channel (op only) | `INVITE alice #general` |
| `MODE <channel> <modes>` | Set channel modes (op only) | `MODE #general +i` |
| `QUIT :<message>` | Disconnect from server | `QUIT :Goodbye!` |

### Channel Modes

| Mode | Description | Example |
|------|-------------|---------|
| `+i` | Invite-only (users must be invited) | `MODE #general +i` |
| `-i` | Remove invite-only | `MODE #general -i` |
| `+t` | Topic restricted (only ops can change) | `MODE #general +t` |
| `-t` | Topic unrestricted | `MODE #general -t` |
| `+k <key>` | Set channel password | `MODE #general +k secret` |
| `-k <key>` | Remove channel password | `MODE #general -k secret` |
| `+o <nick>` | Give operator privileges | `MODE #general +o alice` |
| `-o <nick>` | Remove operator privileges | `MODE #general -o alice` |
| `+l <limit>` | Set user limit | `MODE #general +l 10` |
| `-l` | Remove user limit | `MODE #general -l` |

### Testing Example Session

Start the server:
```bash
make && ./ircserv 6667 testpass
```

In another terminal, connect with netcat:
```bash
nc localhost 6667
```

Test basic flow:
```
PASS testpass
NICK alice
USER alice 0 * :Alice Smith
JOIN #test
TOPIC #test :Welcome to the test channel
PRIVMSG #test :Hello, is anyone here?
MODE #test +i
PART #test :Leaving now
QUIT :Goodbye
```

### Running Automated Tests

The project includes comprehensive test suites:

```bash
# Run all 92 tests (recommended)
./tests/comprehensive_test.sh

# Quick test (13 tests - registration only)
./tests/quick_test.sh

# Full test (59 tests - all commands)
./tests/full_test.sh

# Extra test (20 tests - PING/PONG, edge cases)
./tests/extra_test.sh

# Signal handling test (10 tests)
./tests/signal_test.sh
```

### Cleaning

```bash
make clean   # Remove object files
make fclean  # Remove object files and executable
make re      # Rebuild from scratch
```

## Resources

### IRC Protocol Documentation
- [RFC 1459](https://tools.ietf.org/html/rfc1459) - Internet Relay Chat Protocol (original specification)
- [RFC 2812](https://tools.ietf.org/html/rfc2812) - Internet Relay Chat: Client Protocol (updated)
- [RFC 2813](https://tools.ietf.org/html/rfc2813) - Internet Relay Chat: Server Protocol
- [Modern IRC Documentation](https://modern.ircdocs.horse/) - Comprehensive modern IRC reference
- [IRC Numeric Replies](https://www.alien.net.au/irc/irc2numerics.html) - Complete list of numeric reply codes

### Network Programming
- [Beej's Guide to Network Programming](https://beej.us/guide/bgnet/) - Excellent introduction to socket programming
- [The C10K Problem](http://www.kegel.com/c10k.html) - Discussion of I/O multiplexing techniques
- Linux man pages: `man poll`, `man socket`, `man fcntl`

### Testing Tools
- [irssi](https://irssi.org/) - Terminal-based IRC client
- [HexChat](https://hexchat.github.io/) - Graphical IRC client
- [WeeChat](https://weechat.org/) - Terminal IRC client

### AI Usage

AI tools (GitHub Copilot, ChatGPT) were used throughout the development process for the following purposes:

**Code Generation:**
- Boilerplate code for Orthodox Canonical Form (constructors, copy constructors, destructors)
- Initial structure of IRC protocol parsing logic
- Test script scaffolding and automation

**Documentation:**
- Generating comprehensive code comments and documentation
- Creating README structure and formatting
- Writing user guides and command references

**Debugging:**
- Identifying edge cases in IRC protocol implementation
- Troubleshooting non-blocking I/O issues
- Analyzing poll() timeout behavior

**Research:**
- Understanding RFC 1459/2812 specifications
- Best practices for socket programming in C++98
- IRC numeric reply codes and their proper usage

**Code Review:**
- Identifying potential memory leaks or undefined behavior
- Suggesting more idiomatic C++98 constructs
- Improving error handling and validation

**Not generated by AI:**
- Core architecture design and class relationships
- Logic flow and algorithmic decisions
- Manual testing and validation
- Final integration and bug fixing

Approximately **30-40% of the codebase** was AI-assisted, primarily for repetitive patterns, documentation, and initial drafts. All AI-generated code was reviewed, tested, and significantly modified to meet project requirements.

## Project Structure

```
ft_irc/
├── Makefile                      # Build system
├── ircserv                       # Compiled executable
├── include/                      # Header files
│   ├── Server.hpp               # Server class declaration
│   ├── Client.hpp               # Client class declaration
│   ├── Channel.hpp              # Channel class declaration
│   └── Message.hpp              # IRC message parsing/building
├── src/                         # Source files
│   ├── main.cpp                 # Entry point + signal handling
│   ├── Client.cpp               # Client implementation
│   ├── Channel.cpp              # Channel implementation
│   ├── Message.cpp              # IRC protocol implementation
│   └── server/                  # Server implementation (modular)
│       ├── Core.cpp            # Lifecycle and main loop
│       ├── Network.cpp         # Socket, poll, accept
│       ├── IO.cpp              # Client I/O operations
│       ├── Dispatch.cpp        # Command routing
│       ├── CmdRegistration.cpp # PASS, NICK, USER, QUIT
│       ├── CmdChannel.cpp      # JOIN, PART, TOPIC, PRIVMSG
│       ├── CmdOperator.cpp     # KICK, INVITE
│       ├── CmdMode.cpp         # MODE command (all modes)
│       └── Helpers.cpp         # Utility functions
├── tests/                       # Test suite
│   ├── comprehensive_test.sh   # All 92 tests
│   ├── quick_test.sh           # Registration tests
│   ├── full_test.sh            # Command tests
│   ├── extra_test.sh           # PING/PONG tests
│   └── signal_test.sh          # Signal handling tests
└── docs/                        # Documentation
    ├── ARCHITECTURE.md         # Detailed architecture
    ├── QUICKSTART.md           # Developer quick start
    ├── TESTING_GUIDE.md        # Testing methodology
    └── evaluation.md           # Evaluation criteria
```

## Implementation Notes

- **C++98 Standard**: Strict compliance without C++11/14/17 features
- **No external libraries**: Only C++98 STL and POSIX system calls
- **Non-blocking I/O**: All sockets set to `O_NONBLOCK` mode
- **Single poll() loop**: All I/O multiplexed through one `poll()` call
- **Memory safe**: No leaks (verified with valgrind), proper cleanup in destructors
- **Error handling**: All system calls checked for errors
- **Signal safe**: Graceful shutdown without data loss

---

**Status**: ✅ 100% Complete (92/92 tests passing)  
**Grade**: Pending evaluation  
**Date**: December 2025
