#ifndef MESSAGEBUILDER_HPP
#define MESSAGEBUILDER_HPP

#include <string>

// Класс для построения IRC сообщений
// Студенты должны реализовать методы для построения ответов сервера
class MessageBuilder {
public:
    // Построение welcome сообщения (RPL_WELCOME)
    static std::string buildWelcome(const std::string& serverName, 
                                     const std::string& nick);
    
    // Построение сообщения о присоединении к каналу
    static std::string buildJoin(const std::string& prefix, 
                                  const std::string& channel);
    
    // Построение сообщения PRIVMSG
    static std::string buildPrivmsg(const std::string& prefix, 
                                     const std::string& target, 
                                     const std::string& message);
    
    // Построение сообщения об ошибке (общий метод)
    static std::string buildError(const std::string& serverName,
                                   const std::string& nick,
                                   const std::string& code,
                                   const std::string& message);
};

#endif // MESSAGEBUILDER_HPP
