# 🚀 Быстрый старт для разработчиков

> Кратк ая справка: что уже готово, что нужно сделать, с чего начать

## ✅ Что уже работает

### Инфраструктура (100% готова):
- ✅ **Client.cpp** - Полностью реализован
  - Буферы ввода/вывода
  - Регистрационные флаги
  - Метод `extractLine()` для извлечения команд
  
- ✅ **Channel.cpp** - Полностью реализован
  - Управление участниками
  - Управление операторами  
  - Режимы каналов (+i, +t, +k, +o, +l)

- ✅ **main.cpp** - Точка входа готова
  - Валидация аргументов
  - Создание сервера

### Event loop (частично готов):
- ✅ **Server::run()** - Структура event loop есть
- ✅ Использование `poll()` для множественных клиентов
- ⚠️ Методы сетевого уровня - заглушки (TODO)

## ⚠️ Что нужно реализовать

### 🟢 Модуль 1: Сетевой уровень (НЕЗАВИСИМЫЙ)
**Где:** `src/Server.cpp`  
**Сложность:** ⭐⭐⭐  
**Время:** 2-3 дня

```cpp
void initSocket();        // Создать TCP сокет, bind, listen
void acceptClient();      // accept() новых клиентов
void readFromClient();    // recv() данных, добавить в inputBuffer
void writeToClient();     // send() из outputBuffer
void removeClient();      // Закрыть соединение, очистить структуры
```

**Что изучить:**
- `socket()`, `bind()`, `listen()`, `accept()`
- `poll()` для множественных соединений
- `fcntl()` для неблокирующего I/O
- `recv()` / `send()`

**Тест:**
```bash
./ircserv 6667 pass
nc localhost 6667  # Должно подключиться
```

---

### 🟡 Модуль 2: IRC протокол (НЕЗАВИСИМЫЙ)
**Где:** `src/Message.cpp`  
**Сложность:** ⭐⭐  
**Время:** 2-3 дня

```cpp
// Парсинг
Message::parse("NICK john")           // → command="NICK", params=["john"]
Message::parse(":a!b@c PRIVMSG #t :Hi") // → prefix="a!b@c", command="PRIVMSG", params=["#t", "Hi"]

// Построение ответов
Message::buildWelcome("john")         // → ":server 001 john :Welcome...\r\n"
Message::buildJoin("john", "#test")   // → ":john JOIN #test\r\n"
Message::buildNumericReply(...)       // → ":server 401 nick :No such nick\r\n"

// Валидация
Message::isValidNickname("john")      // → true
Message::isValidChannelName("#test")  // → true
```

**Формат IRC:**
```
[:prefix] COMMAND [param1] [param2] [:trailing parameter]\r\n
```

**Тест:**
```cpp
Message msg = Message::parse("USER john 0 * :John Doe");
assert(msg.getCommand() == "USER");
assert(msg.getParams()[0] == "john");
assert(msg.getParams()[3] == "John Doe");
```

---

### 🔵 Модуль 3: Регистрация (зависит от Модуля 2)
**Где:** `src/Server.cpp`  
**Сложность:** ⭐⭐  
**Время:** 1-2 дня

```cpp
void handlePass();      // Проверить пароль
void handleNick();      // Установить nickname, проверить занятость
void handleUser();      // Установить username
void tryRegisterClient(); // Проверить все 3 флага, отправить welcome
```

**Последовательность:**
```
Client → PASS password → hasPassword = true
       → NICK john     → hasNickname = true, nickname = "john"
       → USER john ... → hasUsername = true
       → tryRegisterClient() → isRegistered = true, отправить RPL_WELCOME (001)
```

**Тест:**
```bash
echo -e "PASS pass\nNICK test\nUSER test 0 * :Test" | nc localhost 6667
# Ожидаем: :server 001 test :Welcome to the IRC Network
```

---

### 🟣 Модуль 4: Каналы (зависит от Модулей 2 и 3)
**Где:** `src/Server.cpp`  
**Сложность:** ⭐⭐⭐  
**Время:** 2-3 дня

```cpp
void handleJoin();            // Создать/присоединиться к каналу
void handlePart();            // Покинуть канал
void handlePrivmsg();         // Отправить сообщение в канал/пользователю
void broadcastToChannel();    // Разослать сообщение всем в канале
```

**Логика:**
- JOIN создает канал, если его нет
- Первый участник = оператор
- Все в канале получают уведомление о JOIN/PART
- PRIVMSG в канал → broadcast всем (кроме отправителя)

**Тест:**
```bash
# Терминал 1:
nc localhost 6667
PASS pass
NICK alice
USER alice 0 * :Alice
JOIN #test

# Терминал 2:
nc localhost 6667
PASS pass
NICK bob
USER bob 0 * :Bob
JOIN #test
PRIVMSG #test :Hello Alice!

# В терминале 1 должно появиться: :bob PRIVMSG #test :Hello Alice!
```

---

### 🟠 Модуль 5: Операторские команды (зависит от Модуля 4)
**Где:** `src/Server.cpp`  
**Сложность:** ⭐⭐⭐⭐  
**Время:** 2-3 дня

```cpp
void handleKick();     // Исключить пользователя (только operator)
void handleInvite();   // Пригласить в invite-only канал
void handleTopic();    // Изменить топик (проверить +t)
void handleMode();     // Изменить режимы +i, +t, +k, +o, +l
```

**Режимы каналов:**
```
+i  invite-only       Только по приглашению
+t  topic restricted  Топик меняют только операторы
+k  key              Пароль для входа
+o  operator         Дать/снять права оператора
+l  limit            Лимит пользователей
```

**Тест:**
```bash
MODE #test +i          # Включить invite-only
MODE #test +k secret   # Установить пароль
MODE #test +o bob      # Дать bob права оператора
KICK #test alice       # Исключить alice (если есть права)
```

---

## 🎯 Рекомендуемый порядок работы

### Для новичков:
1. **Прочитать документацию:**
   - `README.md` - обзор IRC и проекта
   - `docs/GETTING_STARTED.md` - пошаговое руководство
   - `docs/ARCHITECTURE.md` - архитектура
   
2. **Начать с простого (Модуль 2 - парсинг):**
   - Создать тестовый файл `test_parser.cpp`
   - Реализовать `Message::parse()`
   - Протестировать на разных примерах
   
3. **Изучить примеры:**
   - Посмотреть `src/Client.cpp` - как реализованы геттеры/сеттеры
   - Посмотреть `src/Channel.cpp` - как работать с `std::set`

4. **Перейти к сетевому уровню (Модуль 1):**
   - Создать простой echo-сервер (см. GETTING_STARTED.md)
   - Интегрировать в `Server::initSocket()`

### Для опытных:
1. **Модуль 2** (парсинг) → **Модуль 1** (сеть) → **Модуль 3** (регистрация)
2. Параллельно можно:
   - Один человек - Модуль 1 (сеть)
   - Другой - Модуль 2 (парсинг)
   - После объединения - Модули 3, 4, 5

---

## 🔍 Как тестировать

### Компиляция:
```bash
make          # Собрать проект
make clean    # Очистить объектники
make fclean   # Полная очистка
make re       # Пересобрать
```

### Запуск сервера:
```bash
./ircserv 6667 password123
```

### Простое тестирование (netcat):
```bash
nc localhost 6667
PASS password123
NICK test
USER test 0 * :Test User
JOIN #test
PRIVMSG #test :Hello!
QUIT
```

### Продвинутое тестирование (irssi):
```bash
irssi -c localhost -p 6667 -w password123

# В irssi:
/nick mynick
/join #test
/msg #test Hello everyone!
```

### Отладка:
```bash
# Запуск с выводом в лог
./ircserv 6667 pass 2>&1 | tee server.log

# Проверка открытых портов
lsof -i :6667

# Проверка соединений
netstat -an | grep 6667
```

---

## 📊 Статистика задач

| Модуль | Методов | Сложность | Время | Зависимости |
|--------|---------|-----------|-------|-------------|
| 🟢 Сетевой уровень | 5 | ⭐⭐⭐ | 2-3 дня | Нет |
| 🟡 IRC протокол | 8 | ⭐⭐ | 2-3 дня | Нет |
| 🔵 Регистрация | 4 | ⭐⭐ | 1-2 дня | Модуль 2 |
| 🟣 Каналы | 4 | ⭐⭐⭐ | 2-3 дня | Модули 2, 3 |
| 🟠 Операторы | 4 | ⭐⭐⭐⭐ | 2-3 дня | Модуль 4 |

**Итого:** ~25 методов, 10-15 дней работы

---

## 💡 Полезные советы

1. **Всегда тестируйте инкрементально:**
   - Написали метод → протестировали
   - Не накапливайте нереализованный код

2. **Используйте логирование:**
   ```cpp
   std::cout << "[DEBUG] Command: " << msg.getCommand() << std::endl;
   ```

3. **Проверяйте утечки памяти:**
   ```bash
   valgrind --leak-check=full ./ircserv 6667 pass
   ```

4. **Читайте RFC 2812:**
   - https://tools.ietf.org/html/rfc2812
   - Там все ответы на вопросы

5. **Не бойтесь спрашивать:**
   - Обсуждайте проблемы с командой
   - Делитесь решениями

---

## 📚 Ссылки на документацию

- **README.md** - Обзор проекта
- **docs/GETTING_STARTED.md** - Руководство для начинающих
- **docs/ARCHITECTURE.md** - Детальная архитектура
- **docs/INTERFACES.md** - Полное описание всех методов
- **docs/QUICKSTART.md** - Этот файл

---

**Удачи в разработке! 🚀**

_Если застряли - сначала прочитайте GETTING_STARTED.md, там примеры реализации всех методов._
