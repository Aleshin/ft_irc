# Структура Интерфейсов для Параллельной Разработки

## 📋 Обзор

Проект содержит минимальный набор интерфейсов, которые позволяют студентам независимо разрабатывать различные части IRC сервера без конфликтов.

## 🔧 Базовые Компоненты

### 1. Types.hpp
**Назначение:** Общие структуры данных  
**Ключевая структура:**
- `IRCMessage` - результат парсинга IRC сообщения (prefix, command, params)

**Использование:** Обмен данными между парсером и обработчиками команд

### 2. Client.hpp
**Назначение:** Представление клиента  
**Поля:**
- Информация о соединении (fd, input/output буферы)
- Регистрационные данные (nickname, username, hasPass/Nick/User)
- Статус регистрации (registered)

**Использование:** Хранение состояния клиента

### 3. Channel.hpp
**Назначение:** Представление канала  
**Поля:**
- Базовая информация (name, topic)
- Участники (members, operators)
- Режимы (+i, +t, +k, +l)

**Использование:** Хранение состояния канала

### 4. Server.hpp
**Назначение:** Главный класс сервера  
**Хранит:**
- Коллекцию клиентов (_clients)
- Коллекцию каналов (_channels)
- Сетевое состояние

**Использование:** Центральная точка доступа к данным

## 🔌 Интерфейсы для Реализации

### 1. CommandParser (обязательный)
**Файл:** `include/CommandParser.hpp`  
**Метод:** `static IRCMessage parse(const std::string& rawMessage)`  
**Задача:** Разобрать строку IRC сообщения в структуру IRCMessage

**Пример разработки:**
```cpp
// src/CommandParser.cpp - студент реализует
IRCMessage CommandParser::parse(const std::string& rawMessage) {
    IRCMessage msg;
    // TODO: парсинг prefix, command, params
    return msg;
}
```

### 2. MessageBuilder (обязательный)
**Файл:** `include/MessageBuilder.hpp`  
**Методы:** 
- `buildWelcome()` - построение welcome сообщения
- `buildJoin()` - построение JOIN сообщения
- `buildPrivmsg()` - построение PRIVMSG
- `buildError()` - построение сообщения об ошибке

**Задача:** Генерация правильно отформатированных IRC ответов

**Пример разработки:**
```cpp
// src/MessageBuilder.cpp - студент реализует
std::string MessageBuilder::buildWelcome(const std::string& serverName, 
                                          const std::string& nick) {
    // TODO: создать строку формата ":server 001 nick :Welcome..."
    return "";
}
```

### 3. Utils (обязательный)
**Файл:** `include/Utils.hpp`  
**Методы:**
- `split()` - разделение строки
- `trim()` - удаление пробелов
- `toUpper()` - верхний регистр
- `isValidNickname()` - валидация nickname
- `isValidChannelName()` - валидация имени канала

**Задача:** Вспомогательные функции общего назначения

### 4. Numerics.hpp (справочный)
**Файл:** `include/Numerics.hpp`  
**Содержит:** Определения констант IRC numeric codes  
**Использование:** 
```cpp
#include "Numerics.hpp"
// Используем константы вместо magic numbers
std::string error = buildError(server, nick, ERR_NOSUCHNICK, "No such nick");
```

### 5. IRCCommand (опциональный, для масштабирования)
**Файл:** `include/IRCCommand.hpp`  
**Паттерн:** Command Pattern - абстрактный базовый класс  
**Метод:** `virtual void execute(Server&, Client&, const IRCMessage&) = 0`

**Назначение:** Инкапсуляция логики каждой IRC команды в отдельный класс

**Пример использования:**
```cpp
// Создаём класс для команды JOIN
class JoinCommand : public IRCCommand {
public:
    void execute(Server& server, Client& client, const IRCMessage& msg) {
        // Логика команды JOIN
        std::string channel = msg.params[0];
        // ... добавление в канал, отправка ответов ...
    }
};

// В коде сервера
IRCCommand* joinCmd = new JoinCommand();
joinCmd->execute(server, client, parsedMessage);
```

**Преимущества:**
- Каждая команда = отдельный класс (Single Responsibility)
- Легко добавлять новые команды без изменения Server
- Удобно для тестирования команд по отдельности

**Альтернатива:** Простой if-else в `Server::processLine()`

### 6. CommandDispatcher (опциональный, для масштабирования)
**Файл:** `include/CommandDispatcher.hpp`  
**Паттерн:** Registry/Dispatcher для централизованной маршрутизации  
**Методы:**
- `registerCommand(name, IRCCommand*)` - регистрация обработчика
- `dispatch(Server&, Client&, IRCMessage&)` - вызов нужного обработчика

**Назначение:** Избежать длинного if-else/switch, централизовать диспетчеризацию

**Пример использования:**
```cpp
// Инициализация диспетчера
CommandDispatcher dispatcher;
dispatcher.registerCommand("JOIN", new JoinCommand());
dispatcher.registerCommand("PART", new PartCommand());
dispatcher.registerCommand("KICK", new KickCommand());

// В Server::processLine()
IRCMessage msg = CommandParser::parse(line);
if (!dispatcher.dispatch(*this, client, msg)) {
    // Команда не найдена - отправить ERR_UNKNOWNCOMMAND
}
```

**Преимущества:**
- Нет длинного if-else/switch
- Легко добавлять/удалять команды
- Четкая регистрация всех доступных команд

**Альтернатива:** Использовать `std::map<std::string, function_pointer>` или простой if-else

## 📝 Принципы Независимой Разработки

### Разделение Задач

#### Разработчик 1: Парсинг и Валидация
- Реализовать `CommandParser::parse()`
- Реализовать функции валидации в `Utils`
- Написать тесты для парсинга

#### Разработчик 2: Построение Сообщений
- Реализовать методы `MessageBuilder`
- Добавить новые методы по мере необходимости
- Написать тесты для форматирования

#### Разработчик 3: Команды Пользователей (простой подход)
- Добавить обработку команд в `ServerCommands.cpp`
- JOIN, PART, PRIVMSG, NOTICE
- Использовать if-else или парсер (если готов)

#### Разработчик 4: Команды Каналов (простой подход)
- TOPIC, NAMES, KICK, INVITE, MODE
- Работать с `_channels` в Server
- Использовать Channel структуру

#### Разработчик 5: Command Pattern (опциональный, для масштабирования)
- Создать классы-наследники IRCCommand для каждой команды
- Инкапсулировать логику команд
- Интегрировать с CommandDispatcher

#### Разработчик 6: CommandDispatcher (опциональный, для масштабирования)
- Реализовать registerCommand() и dispatch()
- Создать централизованный реестр команд
- Заменить if-else в processLine() на диспетчер

## 🔄 Как Добавить Новую Команду

1. **Использовать парсер** (если готов):
```cpp
void Server::processLine(Client &client, const std::string &line) {
    IRCMessage msg = CommandParser::parse(line);
    if (msg.command == "MYCOMMAND") {
        // обработка команды
    }
}
```

2. **Построить ответ** (если MessageBuilder готов):
```cpp
std::string response = MessageBuilder::buildWelcome(_serverName, client.nickname);
sendToClient(client, response);
```

3. **Работать с каналами**:
```cpp
if (_channels.find("#test") == _channels.end()) {
    _channels["#test"] = new Channel("#test");
}
_channels["#test"]->members.insert(client.nickname);
```

## ✅ Что Гарантируется

- Проект компилируется с пустыми интерфейсами
- Все заголовочные файлы имеют защиту от повторного включения
- Структуры данных (Client, Channel) готовы к использованию
- Сервер запускается и принимает соединения
- Базовая регистрация (PASS/NICK/USER) работает

## ⚠️ Что НЕ Реализовано (Задачи для Студентов)

- Парсинг IRC сообщений (CommandParser)
- Построение IRC ответов (MessageBuilder)
- Вспомогательные функции (Utils)
- Обработка команд каналов (JOIN, PART и т.д.)
- Отправка сообщений (PRIVMSG, NOTICE)
- Управление операторами и режимами
- Команды KICK, INVITE, TOPIC, MODE

## 📊 Текущее Состояние

```
✅ Готово:
- Сетевой слой (poll, accept, read, write)
- Базовые структуры (Client, Channel)
- Простейшая регистрация (PASS/NICK/USER)
- Интерфейсы для расширения

⏳ К Реализации:
- Парсинг IRC протокола
- Построение IRC сообщений
- Вспомогательные функции
- Все команды IRC (кроме PASS/NICK/USER)
```

## 🎯 Начало Работы

1. Выберите задачу (парсинг, построение сообщений, команды)
2. Реализуйте соответствующий интерфейс
3. Тестируйте независимо
4. Интегрируйте через общие интерфейсы

**Пример теста:**
```bash
# Запустить сервер
./ircserv 6667 password

# Подключиться
nc localhost 6667
PASS password
NICK testuser
USER testuser 0 * :Test User
# После регистрации увидите welcome message
```
