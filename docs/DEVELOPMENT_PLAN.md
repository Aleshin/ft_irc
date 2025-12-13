# План Разработки FT_IRC

> Последнее обновление: 13 декабря 2025

## 📊 Текущее Состояние: 25% → Фаза 1 Завершена ✅

### ✅ Фаза 1 ЗАВЕРШЕНА (13 декабря 2025):
- ✅ Архитектура классов (Server, Client, Channel, Message)
- ✅ Полный сетевой стек с poll() - неблокирующий I/O
- ✅ SO_REUSEADDR для быстрого перезапуска
- ✅ Динамический POLLOUT для эффективной отправки
- ✅ Безопасная итерация с отложенным удалением
- ✅ Корректная обработка disconnect (recv() == 0)
- ✅ Проверка дублирования FD
- ✅ Извлечение команд из inputBuffer
- ✅ Управление ресурсами (cleanup, RAII)
- ✅ Нет утечек памяти (проверено valgrind/leaks)
- ✅ 7/7 тестов проходят
- ✅ Код оптимизирован (426 строк)

**Коммит:** `dbaaf49` в ветке `phase1`  
**Документация:** [PHASE1_COMPLETED.md](PHASE1_COMPLETED.md), [PHASE1_CHECKLIST.md](PHASE1_CHECKLIST.md)

### 🔄 В работе - Фаза 2:
- IRC протокол парсинг (RFC 2812)
- Построение ответов сервера
- Валидация nickname/channel

### ❌ Планируется - Фазы 3-5:
- Регистрация клиентов (PASS/NICK/USER)
- Работа с каналами (JOIN/PART/PRIVMSG)
- Операторские команды (KICK/INVITE/TOPIC/MODE)

---

## ✅ ФАЗА 1: Базовая Сетевая Инфраструктура - ЗАВЕРШЕНА

**Статус:** ✅ ЗАВЕРШЕНА (13 декабря 2025)  
**Ветка:** `phase1`  
**Коммит:** `dbaaf49`  
**Тесты:** 7/7 PASSED

### Выполненные задачи:

#### ✅ 1.1 listen() перемещен в initSocket()
**Статус:** ВЫПОЛНЕНО ✅  
**Файл:** [src/Server.cpp](../src/Server.cpp#L152-L157)

#### ✅ 1.2 Динамический POLLOUT реализован
**Статус:** ВЫПОЛНЕНО ✅  
**Метод:** `updatePollEvents(int fd, short events)`  
**Файлы:** [Server.hpp](../include/Server.hpp#L64), [Server.cpp](../src/Server.cpp#L87-L97)

#### ✅ 1.3 Безопасная итерация реализована
**Статус:** ВЫПОЛНЕНО ✅  
**Подход:** Обратный цикл + отложенное удаление  
**Файл:** [src/Server.cpp](../src/Server.cpp#L114-L145)

#### ✅ 1.4 Корректная обработка disconnect
**Статус:** ВЫПОЛНЕНО ✅  
**Файл:** [src/Server.cpp](../src/Server.cpp#L288-L294)

#### ✅ 1.5 SO_REUSEADDR включен
**Статус:** ВЫПОЛНЕНО ✅  
**Файл:** [src/Server.cpp](../src/Server.cpp#L176-L182)

#### ✅ 1.6 Проверка дублирования FD
**Статус:** ВЫПОЛНЕНО ✅  
**Файл:** [src/Server.cpp](../src/Server.cpp#L227-L233)

#### ✅ 1.7 Извлечение команд из буфера
**Статус:** ВЫПОЛНЕНО ✅  
**Файл:** [src/Server.cpp](../src/Server.cpp#L261-L278)

---

## 🔄 ФАЗА 2: IRC Парсинг и Протокол (2-3 дня) - В РАБОТЕ

**Статус:** 🔄 В РАБОТЕ  
**Ветка:** `phase2` (создается)  
**Документация:** [PHASE2_START.md](PHASE2_START.md)

### Цель
Реализовать полный парсинг IRC команд согласно RFC 2812 и построение корректных ответов сервера.

### Задачи:

// После цикла:
for (size_t i = 0; i < fds_to_remove.size(); ++i) {
    removeClient(fds_to_remove[i]);
}
```

**Решение 2:** Обратный цикл
```cpp
// Идем с конца, чтобы удаление не ломало индексы
for (size_t i = _pollfds.size(); i > 0; --i) {
    size_t index = i - 1;
    // ... обработка
}
```

---

#### 1.4 Исправить обработку отключения клиента
**Проблема:** `recv()` возвращает 0 → выбрасывается исключение (это норма!)  
**Файл:** `src/Server.cpp` → `readFromClient()`  
**Приоритет:** Средний  
**Тест:** `test_graceful_disconnect`

```cpp
if (n == 0) {
    // Клиент корректно отключился - это НЕ ошибка
    std::cout << "Client " << fd << " disconnected gracefully\n";
    removeClient(fd);
    return;  // НЕ выбрасывать исключение!
}
```

---

#### 1.5 Включить SO_REUSEADDR
**Проблема:** Закомментирован → "Address already in use" при перезапуске  
**Файл:** `src/Server.cpp` → `initSocket()`  
**Приоритет:** Низкий (удобство)  
**Тест:** `test_rapid_restart`

```cpp
// Раскомментировать:
int opt = 1;
if (setsockopt(_serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
    throw std::runtime_error("setsockopt(SO_REUSEADDR) failed: " +
                            std::string(strerror(errno)));
}
```

---

#### 1.6 Проверка дублирования FD при accept()
**Проблема:** Если FD уже есть в `_clients`, возможна утечка памяти  
**Файл:** `src/Server.cpp` → `acceptClient()`  
**Приоритет:** Средний  
**Тест:** `test_no_fd_duplication`

```cpp
// Проверить перед добавлением:
if (_clients.count(new_fd)) {
    std::cerr << "Warning: FD " << new_fd << " already exists!\n";
    delete _clients[new_fd];  // Освободить старый объект
}
_clients[new_fd] = new Client(new_fd);
```

---

#### 1.7 Обработка команд из inputBuffer
**Проблема:** Данные читаются, но команды не извлекаются  
**Файл:** `src/Server.cpp` → `handleClient()`  
**Приоритет:** КРИТИЧЕСКИЙ  
**Тест:** `test_command_extraction`

```cpp
void Server::handleClient(size_t index) {
    int fd = _pollfds[index].fd;
    Client* client = _clients[fd];
    if (!client) return;

    // 1. Читаем данные
    readFromClient(*client, index);

    // 2. Извлекаем и обрабатываем команды
    while (true) {
        std::string line = client->extractLine();
        if (line.empty()) break;
        
        try {
            processCommand(*client, line);
        } catch (const std::exception& e) {
            std::cerr << "Error processing command: " << e.what() << std::endl;
        }
    }

    // 3. Отправляем ответы (если есть)
    if (!client->getOutputBuffer().empty()) {
        writeToClient(*client);
    }
}
```

---

### Критерии Завершения Фазы 1:

- [x] ✅ Код компилируется без ошибок
- [ ] ✅ Все тесты phase1 проходят
- [ ] ✅ Сервер принимает соединения
- [ ] ✅ Сервер не крашится при отключении клиента
- [ ] ✅ POLLOUT корректно работает
- [ ] ✅ Нет утечек памяти (valgrind)
- [ ] ✅ Можно перезапустить сервер без ожидания

---

## 🔧 ФАЗА 2: Парсинг IRC Команд (3-5 дней)

**Статус:** 🔴 НЕ НАЧАТА  
**Ветка:** `phase2`  
**Тесты:** `tests/phase2_tests.sh`  
**Зависимости:** Фаза 1

### Задачи:

#### 2.1 Реализовать CommandParser
**Файл:** `src/CommandParser.cpp`  
**Формат IRC:** `[:prefix] COMMAND [param1] [param2] [:trailing]`

**Методы:**
```cpp
static Message parse(const std::string& line);
static bool isValidNickname(const std::string& nick);
static bool isValidChannelName(const std::string& channel);
```

**Примеры для парсинга:**
```
NICK testuser
USER testuser 0 * :Real Name
JOIN #general
PRIVMSG #general :Hello everyone!
:nick!user@host PRIVMSG #test :Message
```

**Тесты:**
- [ ] `test_parse_simple` - "NICK john"
- [ ] `test_parse_with_params` - "USER john 0 * :John Doe"
- [ ] `test_parse_with_prefix` - ":nick!user@host PRIVMSG #test :Hi"
- [ ] `test_validate_nickname` - проверка корректности
- [ ] `test_validate_channel` - проверка #канала

---

#### 2.2 Реализовать MessageBuilder
**Файл:** `src/MessageBuilder.cpp`

**Методы:**
```cpp
static std::string buildWelcome(const std::string& nick);
static std::string buildNumeric(int code, const std::string& target, 
                                 const std::string& message);
static std::string buildError(int code, const std::string& target,
                               const std::string& message);
static std::string buildReply(const std::string& prefix,
                               const std::string& command,
                               const std::vector<std::string>& params);
```

**Примеры ответов:**
```
:server 001 nick :Welcome to the IRC Network
:server 332 nick #general :Channel topic
:nick!user@host PRIVMSG #general :Hello!
:server 401 nick badnick :No such nick/channel
```

**Тесты:**
- [ ] `test_build_welcome` - Welcome message (001)
- [ ] `test_build_numeric` - Numeric replies
- [ ] `test_build_error` - Error messages (4xx, 5xx)
- [ ] `test_build_reply` - Команды с префиксом

---

#### 2.3 Обновить processCommand()
**Файл:** `src/Server.cpp`

**Интеграция парсера:**
```cpp
void Server::processCommand(Client& client, const std::string& line) {
    try {
        Message msg = CommandParser::parse(line);
        
        if (msg.command == "NICK")
            handleNick(client, msg);
        else if (msg.command == "USER")
            handleUser(client, msg);
        // ... остальные команды
        else
            sendError(client, ERR_UNKNOWNCOMMAND, msg.command);
            
    } catch (const std::exception& e) {
        std::cerr << "Parse error: " << e.what() << std::endl;
    }
}
```

**Тесты:**
- [ ] `test_dispatch_commands` - корректная диспетчеризация
- [ ] `test_unknown_command` - ERR_UNKNOWNCOMMAND
- [ ] `test_parse_errors` - обработка ошибок парсинга

---

#### 2.4 Добавить Numeric Codes
**Файл:** `include/Numerics.hpp` (новый)

**Требуется определить:**
```cpp
// Welcome (001-005)
#define RPL_WELCOME          001
#define RPL_YOURHOST         002
#define RPL_CREATED          003
#define RPL_MYINFO           004

// Channel replies (300-399)
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
```

### Критерии завершения Фазы 2:
- [x] CommandParser парсит все типы команд
- [x] MessageBuilder генерирует корректные ответы
- [x] Валидация nickname/channel работает
- [x] processCommand() интегрирован с парсером
- [x] Numeric codes определены
- [x] Минимум 8 тестов проходят

---

### Критерии Завершения Фазы 2:

- [ ] ✅ Message::parse() работает корректно
- [ ] ✅ Все build*() методы возвращают правильный формат
- [ ] ✅ Валидация nickname/channel работает
- [ ] ✅ processCommand() вызывает нужные обработчики
- [ ] ✅ Все тесты phase2 проходят

---

## 👤 ФАЗА 3: Регистрация Клиентов (2-3 дня)

**Статус:** 🔴 НЕ НАЧАТА  
**Ветка:** `phase3`  
**Тесты:** `tests/phase3_tests.sh`  
**Зависимости:** Фаза 2

### Задачи:

#### 3.1 handlePass() - проверка пароля
#### 3.2 handleNick() - установка nickname
#### 3.3 handleUser() - установка username
#### 3.4 tryRegisterClient() - завершение регистрации
#### 3.5 sendToClient() - отправка ответов

### Критерии Завершения:

- [ ] ✅ Клиент может зарегистрироваться
- [ ] ✅ Получает RPL_WELCOME (001)
- [ ] ✅ Проверка пароля работает
- [ ] ✅ Nickname уникален
- [ ] ✅ Все тесты phase3 проходят

---

## 📢 ФАЗА 4: Каналы и Сообщения (3-4 дня)

**Статус:** 🔴 НЕ НАЧАТА  
**Ветка:** `phase4`  
**Тесты:** `tests/phase4_tests.sh`  
**Зависимости:** Фаза 3

### Задачи:

#### 4.1 handleJoin() - присоединение к каналу
#### 4.2 handlePart() - выход из канала
#### 4.3 handlePrivmsg() - отправка сообщений
#### 4.4 broadcastToChannel() - рассылка

### Критерии Завершения:

- [ ] ✅ JOIN создает канал
- [ ] ✅ Первый участник = оператор
- [ ] ✅ PRIVMSG работает (канал + личка)
- [ ] ✅ PART удаляет из канала
- [ ] ✅ Все тесты phase4 проходят

---

## 👮 ФАЗА 5: Операторские Команды (2-3 дня)

**Статус:** 🔴 НЕ НАЧАТА  
**Ветка:** `phase5`  
**Тесты:** `tests/phase5_tests.sh`  
**Зависимости:** Фаза 4

### Задачи:

#### 5.1 handleKick() - исключение
#### 5.2 handleInvite() - приглашение
#### 5.3 handleTopic() - топик
#### 5.4 handleMode() - режимы +i/+t/+k/+o/+l

### Критерии Завершения:

- [ ] ✅ KICK работает (только operator)
- [ ] ✅ INVITE работает (+i режим)
- [ ] ✅ TOPIC работает (+t режим)
- [ ] ✅ MODE меняет флаги
- [ ] ✅ Все тесты phase5 проходят

---

## 📅 График Разработки

```
Неделя 1 (13-20 дек):  Фаза 1 + начало Фазы 2
Неделя 2 (20-27 дек):  Фаза 2 + Фаза 3
Неделя 3 (27 дек-3 янв): Фаза 4
Неделя 4 (3-10 янв):    Фаза 5 + финальное тестирование
```

**Итого:** ~4 недели до полной готовности

---

## ✅ Чеклист Перед Сдачей

### Обязательные требования:
- [ ] Makefile без релинков
- [ ] Компиляция с -Wall -Wextra -Werror -std=c++98
- [ ] Программа называется ircserv
- [ ] Запуск: ./ircserv <port> <password>
- [ ] Неблокирующий I/O на всех сокетах
- [ ] Один poll() для всех операций
- [ ] Нет fork()
- [ ] Нет внешних библиотек
- [ ] Проверка всех системных вызовов
- [ ] Нет утечек памяти (valgrind)
- [ ] Нет крашей при любых условиях

### IRC функциональность:
- [ ] Регистрация (PASS/NICK/USER)
- [ ] JOIN/PART работают
- [ ] PRIVMSG в канал и личку
- [ ] KICK/INVITE/TOPIC работают
- [ ] MODE +i/+t/+k/+o/+l работают
- [ ] Множественные команды в одном пакете
- [ ] Частичные команды корректно собираются
- [ ] irssi успешно подключается

### Тестирование:
- [ ] Все unit тесты проходят
- [ ] Все integration тесты проходят
- [ ] Stress test (100 клиентов)
- [ ] Проверка на утечки памяти
- [ ] Проверка на race conditions

---

## 📝 Заметки

### Важные детали:
- IRC команды разделены `\r\n`
- Команды могут прийти частями
- Несколько команд могут быть в одном пакете
- POLLOUT должен включаться/выключаться динамически
- Нельзя блокировать на send() или recv()

### Полезные ссылки:
- RFC 2812: https://tools.ietf.org/html/rfc2812
- docs/GETTING_STARTED.md - примеры реализации
- docs/INTERFACES.md - API всех классов
- docs/ARCHITECTURE.md - детальная архитектура

---

**Последнее обновление:** 13 декабря 2025  
**Версия:** 1.0
