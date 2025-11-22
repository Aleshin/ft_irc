#include <iostream>
#include <cstdlib>

#include "Server.hpp"

int main(int argc, char **argv) {
    if (argc != 3) {
        std::cerr << "Usage: ./ircserv <port> <password>\n";
        return 1;
    }

    int port = atoi(argv[1]);
    std::string password = argv[2];

    Server s(port, password);
    s.run();

    return 0;
}
