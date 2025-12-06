# Руководство для начинающих

> Пошаговая инструкция для тех, кто впервые работает с IRC и сетевым программированием

## 📚 Что нужно знать перед началом

### Минимальные знания:

1. **C++98**
   - Классы и наследование
   - Конструкторы/деструкторы
   - STL: `std::string`, `std::vector`, `std::map`, `std::set`

2. **Сетевое программирование (базово)**
   - TCP/IP протокол
   - Клиент-серверная архитектура
   - Сокеты (socket, bind, listen, accept)

3. **Системные вызовы Unix**
   - `poll()` для множественных соединений
   - `fcntl()` для неблокирующего I/O
   - `read()` / `write()` / `send()` / `recv()`

### Не обязательно знать заранее:
- IRC протокол (изучите по ходу)
- Продвинутые сетевые концепции
- Многопоточность (проект однопоточный!)

## 🎯 Пошаговый план работы

### Этап 1: Понимание IRC (1-2 дня)

#### 1.1 Установите IRC клиент
```bash
# macOS (Homebrew)
brew install irssi

# Linux (Ubuntu/Debian)
sudo apt-get install irssi

# Альтернатива: WeeChat
brew install weechat
```

#### 1.2 Подключитесь к реальному IRC серверу
```bash
irssi

# В irssi:
/connect irc.libera.chat
/nick your_nickname
/join #test
Hello, IRC!
/part #test
/quit
```

#### 1.3 Понаблюдайте за протоколом
```bash
# Запустите с отладкой
telnet irc.libera.chat 6667

# Вы увидите сырые IRC сообщения:
NICK test123
USER test 0 * :Test User
JOIN #test
PRIVMSG #test :Hello world
QUIT
```

**Что изучить:**
- Как выглядят IRC команды (простой текст)
- Формат ответов сервера
- Порядок регистрации (PASS → NICK → USER)
- Как работают каналы

### Этап 2: Базовый сетевой сервер (2-3 дня)

#### 2.1 Создайте простой echo-сервер
Это ваш первый шаг - научиться принимать подключения.

**Файл:** `test_echo_server.cpp`
```cpp
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <iostream>
#include <vector>

int main() {
    // 1. Создаем сокет
    int serverFd = socket(AF_INET, SOCK_STREAM, 0);
    
    // 2. Настраиваем адрес
    sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(6667);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    // 3. Привязываем и слушаем
    bind(serverFd, (sockaddr*)&addr, sizeof(addr));
    listen(serverFd, 10);
    
    std::cout << "Server listening on port 6667" << std::endl;
    
    // 4. Event loop с poll()
    std::vector<pollfd> fds;
    pollfd serverPoll = {serverFd, POLLIN, 0};
    fds.push_back(serverPoll);
    
    while (true) {
        poll(&fds[0], fds.size(), -1);
        
        // Проверяем серверный сокет (новое подключение)
        if (fds[0].revents & POLLIN) {
            int clientFd = accept(serverFd, NULL, NULL);
            pollfd clientPoll = {clientFd, POLLIN, 0};
            fds.push_back(clientPoll);
            std::cout << "New client connected: " << clientFd << std::endl;
        }
        
        // Проверяем клиентов
        for (size_t i = 1; i < fds.size(); i++) {
            if (fds[i].revents & POLLIN) {
                char buffer[512];
                int n = read(fds[i].fd, buffer, sizeof(buffer));
                if (n <= 0) {
                    std::cout << "Client disconnected: " << fds[i].fd << std::endl;
                    close(fds[i].fd);
                    fds.erase(fds.begin() + i);
                } else {
                    buffer[n] = '\0';
                    std::cout << "Received: " << buffer;
                    write(fds[i].fd, buffer, n); // Echo back
                }
            }
        }
    }
    
    return 0;
}
```

**Тестирование:**
```bash
# Терминал 1: Запуск сервера
c++ test_echo_server.cpp -o echo && ./echo

# Терминал 2: Подключение
nc localhost 6667
Hello
Hello  # Ответ от сервера
```

**Что вы изучили:**
- ✅ Создание сокета
- ✅ Привязка к порту
- ✅ Принятие подключений
- ✅ Использование `poll()`
- ✅ Чтение/запись данных

#### 2.2 Добавьте неблокирующий I/O
```cpp
void setNonBlocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

// После accept():
int clientFd = accept(serverFd, NULL, NULL);
setNonBlocking(clientFd);
```

**Зачем?** Чтобы `read()` не блокировал всю программу, если данные еще не пришли.

### Этап 3: Реализация класса Client (1 день)

Теперь вам нужна структура для хранения данных каждого клиента.

**Что уже готово:**
- ✅ `Client.hpp` - интерфейс класса
- ✅ `Client.cpp` - полная реализация

**Что делать:**
1. Изучите файл `src/Client.cpp`
2. Поймите, как работают буферы:
   ```cpp
   client.appendToInput("NICK john\r\nUSER");
   std::string line = client.extractLine(); // "NICK john"
   ```
3. Обратите внимание на флаги регистрации:
   ```cpp
   client.setPassword(true);   // PASS получен
   client.setNickname("john"); // NICK получен
   client.setUsername("j_doe"); // USER получен
   // Теперь можно проверить: isRegistered()
   ```

**Тест:**
```cpp
// Создайте тестовый файл
#include "Client.hpp"
#include <iostream>

int main() {
    Client client(42);
    
    // Тест буферов
    client.appendToInput("NICK john\r\n");
    client.appendToInput("USER john 0 * :John\r\n");
    
    std::string line1 = client.extractLine();
    std::cout << "Line 1: " << line1 << std::endl; // "NICK john"
    
    std::string line2 = client.extractLine();
    std::cout << "Line 2: " << line2 << std::endl; // "USER john 0 * :John"
    
    // Тест регистрации
    client.setPassword(true);
    client.setNickname("john");
    client.setUsername("john");
    client.setRegistered(true);
    
    std::cout << "Is registered: " << client.isRegistered() << std::endl;
    
    return 0;
}
```

### Этап 4: Реализация класса Channel (1 день)

Канал - это группа пользователей.

**Что уже готово:**
- ✅ `Channel.hpp` - интерфейс класса
- ✅ `Channel.cpp` - полная реализация

**Что делать:**
1. Изучите файл `src/Channel.cpp`
2. Поймите структуру:
   ```cpp
   Channel channel("#general");
   channel.addMember("john");       // Добавить участника
   channel.addOperator("john");     // Сделать оператором
   channel.setTopic("Welcome!");    // Установить топик
   channel.setInviteOnly(true);     // Режим +i
   ```

**Тест:**
```cpp
#include "Channel.hpp"
#include <iostream>

int main() {
    Channel channel("#test");
    
    // Добавляем участников
    channel.addMember("alice");
    channel.addMember("bob");
    channel.addOperator("alice"); // alice - оператор
    
    // Проверки
    std::cout << "Has alice: " << channel.hasMember("alice") << std::endl;
    std::cout << "Alice is op: " << channel.isOperator("alice") << std::endl;
    std::cout << "Bob is op: " << channel.isOperator("bob") << std::endl;
    
    // Режимы
    channel.setInviteOnly(true);
    channel.setKey("secret123");
    
    std::cout << "Invite only: " << channel.isInviteOnly() << std::endl;
    std::cout << "Key: " << channel.getKey() << std::endl;
    
    return 0;
}
```

### Этап 5: Парсинг IRC сообщений (2-3 дня)

Это критически важная часть. IRC сообщения имеют формат:
```
[:prefix] COMMAND [param1] [param2] ... [:trailing parameter]
```

**Примеры:**
```irc
NICK john
USER john 0 * :John Doe
JOIN #general
PRIVMSG #general :Hello everyone!
:john!john@localhost PRIVMSG #general :Hello
```

**Что реализовать в `Message.cpp`:**

#### 5.1 Функция `parse()`
```cpp
Message Message::parse(const std::string& raw) {
    Message msg;
    std::string line = raw;
    
    // 1. Извлечь prefix (если есть)
    if (line[0] == ':') {
        size_t space = line.find(' ');
        msg._prefix = line.substr(1, space - 1);
        line = line.substr(space + 1);
    }
    
    // 2. Извлечь command
    size_t space = line.find(' ');
    if (space == std::string::npos) {
        msg._command = line;
        return msg;
    }
    msg._command = line.substr(0, space);
    line = line.substr(space + 1);
    
    // 3. Извлечь параметры
    while (!line.empty()) {
        if (line[0] == ':') {
            // Trailing parameter (остаток строки)
            msg._params.push_back(line.substr(1));
            break;
        }
        size_t space = line.find(' ');
        if (space == std::string::npos) {
            msg._params.push_back(line);
            break;
        }
        msg._params.push_back(line.substr(0, space));
        line = line.substr(space + 1);
    }
    
    return msg;
}
```

**Тест парсинга:**
```cpp
// Тест 1: Простая команда
Message msg1 = Message::parse("NICK john");
// msg1._command = "NICK"
// msg1._params = ["john"]

// Тест 2: Команда с trailing
Message msg2 = Message::parse("USER john 0 * :John Doe");
// msg2._command = "USER"
// msg2._params = ["john", "0", "*", "John Doe"]

// Тест 3: С prefix
Message msg3 = Message::parse(":john!j@localhost PRIVMSG #test :Hi");
// msg3._prefix = "john!j@localhost"
// msg3._command = "PRIVMSG"
// msg3._params = ["#test", "Hi"]
```

#### 5.2 Функции построения ответов

```cpp
std::string Message::buildWelcome(const std::string& nick) {
    return ":server 001 " + nick + " :Welcome to the IRC Network\r\n";
}

std::string Message::buildJoin(const std::string& nick, 
                               const std::string& channel) {
    return ":" + nick + " JOIN " + channel + "\r\n";
}

std::string Message::buildNumericReply(int code, 
                                       const std::string& target,
                                       const std::string& message) {
    std::ostringstream oss;
    oss << ":server " << std::setw(3) << std::setfill('0') << code 
        << " " << target << " " << message << "\r\n";
    return oss.str();
}
```

### Этап 6: Интеграция в Server (3-4 дня)

Теперь соединяем все вместе в классе `Server`.

#### 6.1 Метод `initSocket()`
```cpp
void Server::initSocket() {
    // 1. Создаем сокет
    _serverFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_serverFd < 0)
        throw std::runtime_error("socket() failed");
    
    // 2. Опция SO_REUSEADDR (чтобы не ждать TIME_WAIT)
    int opt = 1;
    setsockopt(_serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    // 3. Привязка к порту
    sockaddr_in addr = {};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_port);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(_serverFd, (sockaddr*)&addr, sizeof(addr)) < 0)
        throw std::runtime_error("bind() failed");
    
    // 4. Начинаем слушать
    if (listen(_serverFd, SOMAXCONN) < 0)
        throw std::runtime_error("listen() failed");
    
    // 5. Неблокирующий режим
    setNonBlocking(_serverFd);
    
    // 6. Добавляем в poll
    pollfd pfd = {_serverFd, POLLIN, 0};
    _pollfds.push_back(pfd);
}
```

#### 6.2 Метод `acceptClient()`
```cpp
void Server::acceptClient() {
    sockaddr_in clientAddr;
    socklen_t len = sizeof(clientAddr);
    
    int clientFd = accept(_serverFd, (sockaddr*)&clientAddr, &len);
    if (clientFd < 0)
        return; // Non-blocking: нет клиентов
    
    // Неблокирующий режим для клиента
    setNonBlocking(clientFd);
    
    // Создаем объект Client
    Client* client = new Client(clientFd);
    _clients[clientFd] = client;
    
    // Добавляем в poll
    pollfd pfd = {clientFd, POLLIN, 0};
    _pollfds.push_back(pfd);
    
    std::cout << "New client connected: " << clientFd << std::endl;
}
```

#### 6.3 Метод `readFromClient()`
```cpp
void Server::readFromClient(Client& client, size_t index) {
    char buffer[512];
    int n = recv(client.getFd(), buffer, sizeof(buffer) - 1, 0);
    
    if (n <= 0) {
        // Клиент отключился
        removeClient(index);
        return;
    }
    
    buffer[n] = '\0';
    client.appendToInput(buffer);
    
    // Обрабатываем все полные строки
    while (true) {
        std::string line = client.extractLine();
        if (line.empty())
            break;
        
        // Парсим и обрабатываем команду
        processCommand(client, line);
    }
}
```

#### 6.4 Метод `processCommand()`
```cpp
void Server::processCommand(Client& client, const std::string& line) {
    Message msg = Message::parse(line);
    
    // Диспетчеризация команд
    if (msg.getCommand() == "PASS")
        handlePass(client, msg);
    else if (msg.getCommand() == "NICK")
        handleNick(client, msg);
    else if (msg.getCommand() == "USER")
        handleUser(client, msg);
    else if (msg.getCommand() == "JOIN")
        handleJoin(client, msg);
    else if (msg.getCommand() == "PRIVMSG")
        handlePrivmsg(client, msg);
    // ... остальные команды
}
```

### Этап 7: Реализация команд (4-5 дней)

#### 7.1 Команда PASS
```cpp
void Server::handlePass(Client& client, const Message& msg) {
    if (msg.getParams().empty()) {
        sendToClient(client, Message::buildNumericReply(
            461, "*", "PASS :Not enough parameters"));
        return;
    }
    
    if (msg.getParams()[0] == _password) {
        client.setPassword(true);
    } else {
        sendToClient(client, Message::buildNumericReply(
            464, "*", ":Password incorrect"));
    }
}
```

#### 7.2 Команда NICK
```cpp
void Server::handleNick(Client& client, const Message& msg) {
    if (msg.getParams().empty()) {
        sendToClient(client, Message::buildNumericReply(
            431, "*", ":No nickname given"));
        return;
    }
    
    std::string newNick = msg.getParams()[0];
    
    // Проверка валидности
    if (!Message::isValidNickname(newNick)) {
        sendToClient(client, Message::buildNumericReply(
            432, "*", newNick + " :Erroneous nickname"));
        return;
    }
    
    // Проверка на занятость
    if (getClientByNick(newNick) != NULL) {
        sendToClient(client, Message::buildNumericReply(
            433, "*", newNick + " :Nickname is already in use"));
        return;
    }
    
    client.setNickname(newNick);
    client.setHasNickname(true);
    
    // Попытка завершить регистрацию
    tryRegisterClient(client);
}
```

#### 7.3 Команда JOIN
```cpp
void Server::handleJoin(Client& client, const Message& msg) {
    if (!client.isRegistered()) {
        sendToClient(client, Message::buildNumericReply(
            451, "*", ":You have not registered"));
        return;
    }
    
    if (msg.getParams().empty()) {
        sendToClient(client, Message::buildNumericReply(
            461, client.getNickname(), "JOIN :Not enough parameters"));
        return;
    }
    
    std::string channelName = msg.getParams()[0];
    
    // Проверка валидности имени канала
    if (!Message::isValidChannelName(channelName)) {
        sendToClient(client, Message::buildNumericReply(
            403, client.getNickname(), channelName + " :No such channel"));
        return;
    }
    
    // Получаем/создаем канал
    Channel* channel = getChannel(channelName);
    if (!channel) {
        channel = new Channel(channelName);
        _channels[channelName] = channel;
        // Первый участник становится оператором
        channel->addOperator(client.getNickname());
    }
    
    // Проверка режимов канала
    if (channel->isInviteOnly()) {
        // Проверить invite list (TODO)
    }
    
    if (!channel->getKey().empty()) {
        // Проверить ключ (TODO)
    }
    
    // Добавляем участника
    channel->addMember(client.getNickname());
    
    // Уведомляем всех в канале
    std::string joinMsg = Message::buildJoin(client.getNickname(), channelName);
    broadcastToChannel(channelName, joinMsg, "");
    
    // Отправляем топик
    if (!channel->getTopic().empty()) {
        sendToClient(client, Message::buildNumericReply(
            332, client.getNickname(), 
            channelName + " :" + channel->getTopic()));
    }
}
```

## 🔍 Отладка и тестирование

### Логирование
Добавьте отладочные сообщения:
```cpp
void Server::processCommand(Client& client, const std::string& line) {
    std::cout << "[" << client.getFd() << "] << " << line << std::endl;
    
    Message msg = Message::parse(line);
    
    std::cout << "[DEBUG] Command: " << msg.getCommand() << std::endl;
    std::cout << "[DEBUG] Params: ";
    for (size_t i = 0; i < msg.getParams().size(); i++)
        std::cout << msg.getParams()[i] << " ";
    std::cout << std::endl;
    
    // ... обработка
}
```

### Пошаговое тестирование

**Тест 1: Подключение**
```bash
nc localhost 6667
# Ожидаем: Соединение установлено
# Проверяем: В логах сервера видим "New client connected"
```

**Тест 2: Регистрация**
```bash
nc localhost 6667
PASS password123
NICK alice
USER alice 0 * :Alice Smith
# Ожидаем: Приветственное сообщение (001 RPL_WELCOME)
```

**Тест 3: Создание канала**
```bash
# После регистрации:
JOIN #test
# Ожидаем: JOIN подтверждение
```

**Тест 4: Два клиента**
```bash
# Терминал 1:
nc localhost 6667
PASS password123
NICK alice
USER alice 0 * :Alice
JOIN #test

# Терминал 2:
nc localhost 6667
PASS password123
NICK bob
USER bob 0 * :Bob
JOIN #test
PRIVMSG #test :Hello Alice!

# В терминале 1 должно появиться сообщение от bob
```

## 🎓 Советы по разработке

1. **Начинайте с малого** - не пытайтесь реализовать все сразу
2. **Тестируйте каждый шаг** - один метод = один тест
3. **Используйте valgrind** - проверяйте утечки памяти
4. **Читайте RFC 2812** - там все ответы
5. **Общайтесь с командой** - делитесь проблемами и решениями

## 📚 Дополнительные ресурсы

- `docs/ARCHITECTURE.md` - детальная архитектура проекта
- `docs/INTERFACES.md` - описание всех интерфейсов
- [RFC 2812](https://tools.ietf.org/html/rfc2812) - спецификация IRC
- [Beej's Guide to Network Programming](https://beej.us/guide/bgnet/) - отличный гайд по сокетам

## ❓ Частые вопросы

**Q: Что делать, если `bind()` возвращает "Address already in use"?**  
A: Порт еще занят предыдущим запуском. Используйте `SO_REUSEADDR` или подождите ~60 секунд.

**Q: Как обрабатывать частичные данные?**  
A: Используйте буферы в классе `Client`. Метод `extractLine()` извлекает полные строки.

**Q: Нужна ли многопоточность?**  
A: Нет! Используйте `poll()` для однопоточной обработки множественных клиентов.

**Q: Как тестировать без реального IRC клиента?**  
A: Используйте `netcat` (nc) или `telnet` для ручной отправки команд.

**Q: Что делать с медленными клиентами?**  
A: Неблокирующий I/O решает эту проблему. `poll()` уведомит, когда данные готовы.

---

**Удачи в разработке! 🚀**
