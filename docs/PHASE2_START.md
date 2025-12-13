# Переход к Фазе 2: IRC Парсинг и Протокол

## ✅ Фаза 1 - Завершена

### Достижения
- **7/7 тестов проходят** - все критические требования выполнены
- **Код оптимизирован** - 426 строк чистого, понятного кода
- **Память чиста** - проверено leaks/valgrind
- **Коммит сделан** - `dbaaf49` в ветке `phase1`

### Технические компоненты готовы
- ✅ Event loop с poll()
- ✅ Non-blocking I/O
- ✅ Управление подключениями
- ✅ Буферизация ввода/вывода
- ✅ Извлечение команд из буфера

---

## 🔄 Фаза 2 - IRC Парсинг и Протокол

### Цель
Реализовать парсинг и построение IRC сообщений согласно RFC 2812.

### Основные задачи

#### 1. CommandParser - Парсинг входящих команд
**Файл:** `src/CommandParser.cpp`

```cpp
class CommandParser {
public:
    // Парсит строку в структуру Message
    static Message parse(const std::string& line);
    
    // Валидация
    static bool isValidNickname(const std::string& nick);
    static bool isValidChannelName(const std::string& channel);
    static bool isValidUsername(const std::string& username);
};
```

**Примеры входных данных:**
```
NICK testuser
USER testuser 0 * :Real Name
JOIN #general
PRIVMSG #general :Hello everyone!
KICK #general baduser :Breaking rules
MODE #general +i
TOPIC #general :New topic here
```

**Формат IRC:** `[PREFIX] COMMAND [params] [:trailing]`

#### 2. MessageBuilder - Построение ответов сервера
**Файл:** `src/MessageBuilder.cpp`

```cpp
class MessageBuilder {
public:
    // Numeric replies (001-999)
    static std::string buildWelcome(const std::string& nick);
    static std::string buildNumeric(int code, const std::string& target, 
                                     const std::string& message);
    
    // Errors (400-599)
    static std::string buildError(int code, const std::string& target,
                                   const std::string& message);
    
    // Replies с префиксом
    static std::string buildReply(const std::string& prefix,
                                   const std::string& command,
                                   const std::vector<std::string>& params);
};
```

**Примеры ответов:**
```
:server 001 nick :Welcome to the IRC Network
:server 332 nick #general :Channel topic
:server 353 nick = #general :nick1 nick2 @op1
:nick!user@host PRIVMSG #general :Hello!
:server 401 nick badnick :No such nick/channel
:server 442 nick #general :You're not on that channel
```

#### 3. Интеграция с Server.cpp

```cpp
void Server::processCommand(Client& client, const std::string& line) {
    try {
        // Парсим команду
        Message msg = CommandParser::parse(line);
        
        // Диспетчеризация
        if (msg.command == "NICK")
            handleNick(client, msg);
        else if (msg.command == "USER")
            handleUser(client, msg);
        else if (msg.command == "PASS")
            handlePass(client, msg);
        // ... остальные команды
        else
            sendError(client, ERR_UNKNOWNCOMMAND, msg.command);
            
    } catch (const std::exception& e) {
        std::cerr << "Parse error: " << e.what() << std::endl;
    }
}
```

### Структура данных Message

```cpp
struct Message {
    std::string prefix;                      // опционально: источник
    std::string command;                     // NICK, JOIN, PRIVMSG и т.д.
    std::vector<std::string> params;         // параметры команды
    std::string trailing;                    // текст после ':'
    
    bool valid;                              // флаг корректности парсинга
};
```

### Ключевые правила RFC 2812

1. **Разделители:** пробел и CRLF (`\r\n`)
2. **Префикс:** начинается с `:`, опционален
3. **Команда:** буквы или 3 цифры
4. **Параметры:** до 15 параметров, разделены пробелами
5. **Trailing:** начинается с `:`, может содержать пробелы
6. **Максимальная длина:** 512 байт включая CRLF

### Numeric Codes для Фазы 2

```cpp
// Welcome messages (001-005)
#define RPL_WELCOME          001
#define RPL_YOURHOST         002
#define RPL_CREATED          003
#define RPL_MYINFO           004

// Channel operations (300-399)
#define RPL_NOTOPIC          331
#define RPL_TOPIC            332
#define RPL_NAMREPLY         353
#define RPL_ENDOFNAMES       366

// Errors (400-599)
#define ERR_NOSUCHNICK       401
#define ERR_NOSUCHCHANNEL    403
#define ERR_UNKNOWNCOMMAND   421
#define ERR_NONICKNAMEGIVEN  431
#define ERR_ERRONEUSNICKNAME 432
#define ERR_NICKNAMEINUSE    433
#define ERR_NEEDMOREPARAMS   461
#define ERR_ALREADYREGISTRED 462
```

### План работы Фазы 2

#### Шаг 1: Парсинг (1 день)
- [ ] Реализовать `CommandParser::parse()`
- [ ] Добавить валидацию nickname
- [ ] Добавить валидацию channel name
- [ ] Написать unit-тесты для парсера

#### Шаг 2: Построение ответов (1 день)
- [ ] Реализовать `MessageBuilder::buildNumeric()`
- [ ] Реализовать `MessageBuilder::buildError()`
- [ ] Реализовать `MessageBuilder::buildReply()`
- [ ] Написать тесты для builder

#### Шаг 3: Интеграция (0.5 дня)
- [ ] Обновить `processCommand()` в Server.cpp
- [ ] Добавить отправку numeric replies
- [ ] Добавить обработку ошибок парсинга

#### Шаг 4: Тестирование (0.5 дня)
- [ ] Создать `tests/phase2_tests.sh`
- [ ] Протестировать валидные команды
- [ ] Протестировать невалидные команды
- [ ] Протестировать граничные случаи

### Критерии завершения Фазы 2

- ✅ Парсер корректно обрабатывает все IRC команды
- ✅ Builder генерирует правильные ответы
- ✅ Валидация nickname/channel работает
- ✅ Обработка ошибок протокола
- ✅ Тесты фазы 2 проходят (минимум 5 тестов)

### Документация

**Создать:**
- `docs/PHASE2_STEP_BY_STEP.md` - пошаговое руководство
- `docs/IRC_PROTOCOL.md` - справочник по протоколу

**Обновить:**
- `docs/PHASE2_COMPLETED.md` - отчет после завершения

### Полезные ссылки

- [RFC 2812](https://tools.ietf.org/html/rfc2812) - IRC Client Protocol
- [RFC 1459](https://tools.ietf.org/html/rfc1459) - Original IRC Protocol
- [Modern IRC Documentation](https://modern.ircdocs.horse/) - современная документация

---

## Следующие шаги

1. **Изучить RFC 2812** - особенно разделы 2.3 (Messages), 5 (Replies), 6 (Numeric Replies)
2. **Создать ветку phase2** - `git checkout -b phase2`
3. **Начать с парсера** - самая критичная часть
4. **Писать тесты параллельно** - TDD подход

**Готовы начать Фазу 2?** 🚀
