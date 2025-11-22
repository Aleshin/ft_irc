#include "ircserv.hpp"

int main(int argc, char **argv)
{
    if(srgc != 3)
        std::cout << "Wrong args! Input should be ./ircserv <port> <password>" << std::endl;
    
    try {
        Ircserv serv(argv[1], argv[2]);
    }
    catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }
    catch (...) {
        std::cerr << "Unknown error" << std::endl;
    }


    return 0;
}