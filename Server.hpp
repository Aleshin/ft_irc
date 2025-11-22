#ifndef IRCSERV_H
# define IRCSERV_H

# include <stdio.h>
# include <unistd.h>
#include <string>

class Ircserv
{

    private:
        int port;
        std::string password;
    public:
        Ircserv();
        Ircserv(int port, std::string password);
        Ircserv &operator=(const Ircserv &src);
        ~Ircserv();

        //methods
        
        Server(int port, std::string password);


};

#endif

/* A. Server

Stores global state:

server socket FD

list of client objects

list of channels

password

port

pollfd array

main loop

Handles:

new connections

reading data

parsing commands

routing to handlers */