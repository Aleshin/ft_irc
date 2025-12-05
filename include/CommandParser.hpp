#ifndef COMMANDPARSER_HPP
#define COMMANDPARSER_HPP

#include <string>
#include "Types.hpp"

// Класс для парсинга IRC сообщений
// Студенты должны реализовать метод parse()
class CommandParser {
public:
    // Разбирает строку IRC сообщения в структуру IRCMessage
    // Формат: [":"prefix SPACE] command [params] CRLF
    // Возвращает заполненную структуру IRCMessage
    static IRCMessage parse(const std::string& rawMessage);
};

#endif // COMMANDPARSER_HPP
