#ifndef COMMANDDISPATCHER_HPP
#define COMMANDDISPATCHER_HPP

#include <string>
#include <map>
#include "Types.hpp"
#include "IRCCommand.hpp"

// Диспетчер команд (опциональный, для масштабируемости)
// Централизованная регистрация и вызов обработчиков команд
//
// Использование:
// 1. Создайте экземпляр CommandDispatcher
// 2. Зарегистрируйте обработчики команд через registerCommand()
// 3. Вызывайте dispatch() для обработки IRCMessage
//
// Альтернатива: простая обработка через if-else в Server::processLine()

class Server; // forward declaration
struct Client; // forward declaration

class CommandDispatcher {
public:
    CommandDispatcher();
    ~CommandDispatcher();
    
    // Зарегистрировать обработчик команды
    // Параметры:
    //   commandName - имя команды (например, "JOIN", "PART")
    //   command - указатель на объект IRCCommand (ownership передается диспетчеру)
    void registerCommand(const std::string& commandName, IRCCommand* command);
    
    // Вызвать обработчик для команды
    // Возвращает true если команда найдена и обработана, false иначе
    bool dispatch(Server& server, Client& client, const IRCMessage& msg);

private:
    std::map<std::string, IRCCommand*> _commands;
    
    // Запрещаем копирование
    CommandDispatcher(const CommandDispatcher&);
    CommandDispatcher& operator=(const CommandDispatcher&);
};

#endif // COMMANDDISPATCHER_HPP
