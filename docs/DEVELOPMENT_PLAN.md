# План Разработки FT_IRC

> Последнее обновление: 13 декабря 2025

## 📊 Текущее Состояние: 40-50%

### ✅ Готово:
- Архитектура классов (Server, Client, Channel, Message)
- Основной сетевой стек (socket, bind, accept, poll)
- Неблокирующий I/O (O_NONBLOCK)
- Обработка ошибок системных вызовов
- Управление ресурсами (cleanup, RAII)
- Буферизация ввода/вывода

### ❌ Не готово:
- Парсинг IRC команд
- Обработка регистрации (PASS/NICK/USER)
- Работа с каналами (JOIN/PART/PRIVMSG)
- Операторские команды (KICK/INVITE/TOPIC/MODE)

---

## 🚀 ФАЗА 1: Исправление Критических Проблем (2-3 дня)

**Статус:** 🟡 В РАБОТЕ  
**Ветка:** `phase1`  
**Тесты:** `tests/phase1_tests.sh`

### Задачи:

#### 1.1 Исправить расположение listen()
**Проблема:** `listen()` находится в `run()`, а должен быть в `initSocket()`  
**Файл:** `src/Server.cpp`  
**Приоритет:** Средний  
**Тест:** `test_init_socket`

```cpp
// Переместить из run() в конец initSocket():
if (listen(_serverFd, 10) < 0) {
    throw std::runtime_error("listen() failed: " + std::string(strerror(errno)));
}
```

---

#### 1.2 Реализовать динамический POLLOUT флаг
**Проблема:** POLLOUT не добавляется когда есть данные для отправки  
**Файл:** `src/Server.cpp`  
**Приоритет:** КРИТИЧЕСКИЙ  
**Тест:** `test_pollout_dynamic`

**Требуется:**
- Метод `updatePollEvents(int fd)` для обновления флагов poll
- Добавлять POLLOUT когда `outputBuffer` не пуст
- Убирать POLLOUT когда буфер пуст

```cpp
void Server::updatePollEvents(int fd, short events) {
    for (size_t i = 0; i < _pollfds.size(); ++i) {
        if (_pollfds[i].fd == fd) {
            _pollfds[i].events = events;
            return;
        }
    }
}
```

**Использование:**
```cpp
// После добавления данных в outputBuffer:
if (!client.getOutputBuffer().empty()) {
    updatePollEvents(fd, POLLIN | POLLOUT);
}

// После отправки всех данных:
if (client.getOutputBuffer().empty()) {
    updatePollEvents(fd, POLLIN);
}
```

---

#### 1.3 Исправить итерацию по _pollfds
**Проблема:** Удаление элемента во время итерации нарушает индексы  
**Файл:** `src/Server.cpp`  
**Приоритет:** КРИТИЧЕСКИЙ  
**Тест:** `test_safe_iteration`

**Решение 1:** Отложенное удаление
```cpp
// В run():
std::vector<int> fds_to_remove;

for (size_t i = 0; i < _pollfds.size(); ++i) {
    try {
        // ... обработка
    } catch (const std::exception &e) {
        fds_to_remove.push_back(_pollfds[i].fd);
    }
}

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

#### 2.1 Реализовать Message::parse()
**Формат IRC:** `[:prefix] COMMAND [param1] [param2] [:trailing]`

```cpp
Message Message::parse(const std::string& raw) {
    // Реализация парсинга
    // См. docs/GETTING_STARTED.md - там полный пример
}
```

**Тесты:**
- `test_parse_simple` - "NICK john"
- `test_parse_with_params` - "USER john 0 * :John Doe"
- `test_parse_with_prefix` - ":nick!user@host PRIVMSG #test :Hi"

---

#### 2.2 Реализовать Message::build*() методы
- `buildWelcome()`
- `buildJoin()`
- `buildPart()`
- `buildPrivmsg()`
- `buildNumericReply()`

**Тесты:**
- `test_build_welcome`
- `test_build_join`
- `test_build_numeric`

---

#### 2.3 Реализовать валидацию
- `isValidNickname()`
- `isValidChannelName()`

**Тесты:**
- `test_validate_nickname`
- `test_validate_channel`

---

#### 2.4 Реализовать processCommand()
Диспетчеризация команд к обработчикам

**Тесты:**
- `test_dispatch_pass`
- `test_dispatch_nick`
- `test_dispatch_unknown`

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
