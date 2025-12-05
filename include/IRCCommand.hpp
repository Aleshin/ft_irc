#ifndef IRCCOMMAND_HPP
#define IRCCOMMAND_HPP

#include <string>
#include "Types.hpp"

// Абстрактный базовый класс для IRC команд (Command Pattern)
// Позволяет инкапсулировать логику каждой команды в отдельный класс
// 
// Использование (опционально):
// - Создайте класс-наследник для каждой команды (JoinCommand, PartCommand и т.д.)
// - Реализуйте метод execute() с логикой команды
// - Регистрируйте команды в CommandDispatcher
//
// Альтернатива: простая обработка через if-else в Server::processLine()

class Server; // forward declaration
struct Client; // forward declaration

class IRCCommand {
public:
    virtual ~IRCCommand() {}
    
    // Выполнить команду
    // Параметры:
    //   server - ссылка на сервер для доступа к каналам и клиентам
    //   client - клиент, отправивший команду
    //   msg - разобранное IRC сообщение (из CommandParser)
    virtual void execute(Server& server, Client& client, const IRCMessage& msg) = 0;
};

#endif // IRCCOMMAND_HPP
