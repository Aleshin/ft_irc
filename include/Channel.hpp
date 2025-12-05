#ifndef CHANNEL_HPP
#define CHANNEL_HPP

#include <string>
#include <set>

// Минимальная структура для канала
// Студенты могут расширять по мере необходимости
struct Channel {
    std::string name;                    // Имя канала (например, "#general")
    std::string topic;                   // Топик канала
    std::set<std::string> members;       // Никнеймы участников
    std::set<std::string> operators;     // Никнеймы операторов канала
    
    // Режимы канала (можно расширять)
    bool inviteOnly;                     // +i режим
    bool topicRestricted;                // +t режим
    std::string key;                     // +k режим (пароль)
    int userLimit;                       // +l режим (0 = нет лимита)

    Channel(const std::string& channelName) 
        : name(channelName),
          topic(),
          members(),
          operators(),
          inviteOnly(false),
          topicRestricted(true),
          key(),
          userLimit(0)
    {}
};

#endif // CHANNEL_HPP
