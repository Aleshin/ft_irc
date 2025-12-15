/**
 * @file main.cpp
 * @brief Entry point - argument parsing and signal handling
 * 
 * Usage: ./ircserv <port> <password>
 * 
 * Signal handling:
 *   - SIGINT (Ctrl+C): graceful shutdown
 *   - SIGTERM: graceful shutdown
 * 
 * The g_running flag is checked in Server::run() to exit cleanly.
 */

#include "Server.hpp"
#include <iostream>
#include <cstdlib>
#include <csignal>

// Global flag for graceful shutdown (volatile for signal safety)
volatile sig_atomic_t g_running = 1;

/**
 * Signal handler - sets flag to stop main loop
 * Using sig_atomic_t ensures atomic read/write in signal context
 */
void signalHandler(int sig) {
    (void)sig;
    g_running = 0;
    std::cout << "\nShutdown signal received, exiting..." << std::endl;
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "Usage: ./ircserv <port> <password>" << std::endl;
        std::cerr << "Example: ./ircserv 6667 mypassword" << std::endl;
        return 1;
    }

    // Setup signal handlers
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);

    int port = std::atoi(argv[1]);
    if (port <= 0 || port > 65535) {
        std::cerr << "Error: Invalid port number" << std::endl;
        return 1;
    }

    std::string password = argv[2];
    if (password.empty()) {
        std::cerr << "Error: Password cannot be empty" << std::endl;
        return 1;
    }

    try {
        Server server(port, password);
        server.run();
    } catch (const std::exception& e) {
        std::cerr << "Server error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
