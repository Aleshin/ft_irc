#ifndef CLIENT_HPP
#define CLIENT_HPP

#include <string>

struct Client {
    int         fd;
    std::string input;
    std::string output;
    std::string nickname;
    std::string username;
    bool        hasPass;
    bool        hasNick;
    bool        hasUser;
    bool        registered;

    Client(int fd_)
        : fd(fd_),
          input(),
          output(),
          nickname(),
          username(),
          hasPass(false),
          hasNick(false),
          hasUser(false),
          registered(false)
    {}
};

#endif // CLIENT_HPP
