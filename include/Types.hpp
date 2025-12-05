#ifndef TYPES_HPP
#define TYPES_HPP

#include <string>
#include <vector>

// Структура для хранения разобранного IRC сообщения
struct IRCMessage {
    std::string prefix;                  // Опциональный prefix (например, "nick!user@host")
    std::string command;                 // Команда (NICK, JOIN, PRIVMSG и т.д.)
    std::vector<std::string> params;     // Параметры команды
};

#endif // TYPES_HPP
