# Git Workflow для FT_IRC

> Стратегия работы для команды из 2+ разработчиков

## 🌳 Структура веток

```
master (main)         ← Стабильная версия, всегда компилируется
  ├─ v0.1.0 (tag)    ← Phase 1 complete
  ├─ v0.2.0 (tag)    ← Phase 2 complete (будущее)
  ├─ v0.3.0 (tag)    ← Phase 3 complete (будущее)
  │
  ├─ phase1          ← Фича-ветка (завершена, можно удалить)
  ├─ phase2          ← Фича-ветка (в работе)
  └─ phase3          ← Фича-ветка (будущая)
```

---

## 📋 Workflow для каждой фазы

### 1️⃣ Начало новой фазы

```bash
# Убедиться что master актуален
git checkout master
git pull origin master

# Создать ветку от master
git checkout -b phase2

# Проверить
git branch -vv
```

### 2️⃣ Работа над фазой

```bash
# Регулярные коммиты (несколько раз в день)
git add .
git commit -m "feat: implement IRC command parser"

# Пушить в удаленный репозиторий
git push origin phase2

# Периодически синхронизироваться с master
git checkout master
git pull origin master
git checkout phase2
git merge master  # или rebase если нет конфликтов
```

### 3️⃣ Завершение фазы

```bash
# 1. Финальный коммит
git add .
git commit -m "Phase 2 complete: IRC Protocol Parsing"

# 2. Запустить все тесты
make clean && make
cd tests && make phase2

# 3. Проверить статус
git status
git log --oneline -5

# 4. Переключиться на master
git checkout master

# 5. Мердж с --no-ff (создает merge commit)
git merge phase2 --no-ff -m "Merge Phase 2: IRC Protocol Parsing

✅ Features:
- CommandParser for IRC messages
- MessageBuilder for server responses
- Nickname/channel validation
- Numeric replies (RFC 2812)

📊 Metrics:
- 8/8 tests passing
- Code coverage: XX%
- No memory leaks

🎯 Ready for Phase 3"

# 6. Проверить компиляцию и тесты
make clean && make
cd tests && make all

# 7. Создать тег
git tag -a v0.2.0 -m "Phase 2: IRC Protocol Parsing Complete"

# 8. Пуш в удаленный репозиторий
git push origin master
git push origin v0.2.0

# 9. Опционально: удалить ветку (локально и удаленно)
git branch -d phase2
git push origin --delete phase2
```

---

## 🔄 Откат на любую фазу

### Посмотреть все версии
```bash
git tag -l -n1
```

Результат:
```
v0.1.0    Phase 1: Network Infrastructure Complete
v0.2.0    Phase 2: IRC Protocol Parsing Complete
v0.3.0    Phase 3: Client Authentication Complete
```

### Откатиться на конкретную фазу

```bash
# Временный откат (для просмотра)
git checkout v0.1.0

# Создать ветку от старой версии
git checkout -b fix-phase1 v0.1.0

# Вернуться к текущей версии
git checkout master
```

### Откатить master на предыдущую фазу (опасно!)

```bash
# ТОЛЬКО если точно знаете что делаете!
git checkout master
git reset --hard v0.1.0
git push origin master --force  # ОПАСНО для команды!
```

**⚠️ Лучше:** создать новую ветку для исправлений:
```bash
git checkout -b hotfix-phase1 v0.1.0
# ... исправления ...
git checkout master
git merge hotfix-phase1
```

---

## 👥 Работа в команде из 2 человек

### Сценарий 1: Параллельная работа над разными фичами

**Разработчик 1:**
```bash
git checkout -b phase2-parser master
# работает над парсером
```

**Разработчик 2:**
```bash
git checkout -b phase2-builder master
# работает над builder
```

**Интеграция:**
```bash
# Разработчик 1 финиширует первым
git checkout master
git merge phase2-parser --no-ff

# Разработчик 2 синхронизируется
git checkout phase2-builder
git merge master  # получает изменения разработчика 1
# ... завершает работу ...
git checkout master
git merge phase2-builder --no-ff
```

---

### Сценарий 2: Последовательная работа

**Разработчик 1 начинает:**
```bash
git checkout -b phase2 master
# делает базовую структуру
git push origin phase2
```

**Разработчик 2 подключается:**
```bash
git fetch origin
git checkout phase2
# продолжает работу
git pull origin phase2  # регулярно синхронизируется
```

---

## 📊 Визуализация истории

```bash
# Красивый граф всех веток
git log --oneline --graph --all --decorate

# История конкретной ветки
git log --oneline phase2

# Сравнить ветки
git diff master..phase2

# Что в phase2, чего нет в master
git log master..phase2 --oneline
```

---

## 🏷️ Соглашения о тегах

### Формат версий: `vX.Y.Z`
- **X** - мажорная версия (breaking changes)
- **Y** - минорная версия (новые фичи, фазы)
- **Z** - патч версия (багфиксы)

### Теги для фаз:
```
v0.1.0 - Phase 1: Network Infrastructure
v0.2.0 - Phase 2: IRC Protocol Parsing
v0.3.0 - Phase 3: Client Authentication
v0.4.0 - Phase 4: Channel Management
v0.5.0 - Phase 5: Operator Commands
v1.0.0 - Release: Complete IRC Server
```

### Промежуточные теги (опционально):
```
v0.2.1 - Bugfix: Parser memory leak
v0.2.2 - Bugfix: Nickname validation
```

---

## 📝 Соглашения о коммитах

### Формат:
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Типы:
- `feat:` - новая фича
- `fix:` - исправление бага
- `docs:` - документация
- `refactor:` - рефакторинг кода
- `test:` - добавление тестов
- `style:` - форматирование
- `chore:` - обновление зависимостей

### Примеры:
```bash
git commit -m "feat(parser): add IRC command parsing

- Implement CommandParser::parse()
- Support prefix, command, params, trailing
- Add validation for special characters

Closes #42"

git commit -m "fix(server): handle disconnect gracefully"

git commit -m "docs: update Phase 2 roadmap"

git commit -m "test: add parser unit tests"
```

---

## 🚨 Важные правила

### ✅ DO:
1. **Всегда тестировать перед мерджем** - `make && make test`
2. **Создавать merge commits** - `--no-ff` для истории
3. **Писать описательные commit messages**
4. **Тегать каждую завершенную фазу**
5. **Регулярно пушить** - минимум раз в день
6. **Синхронизироваться с master** - перед мерджем
7. **Удалять завершенные ветки** - держать репозиторий чистым

### ❌ DON'T:
1. **Не коммитить в master напрямую** - только через merge
2. **Не делать force push в shared ветки** - потеряете чужую работу
3. **Не оставлять висящие ветки** - мердж или удалить
4. **Не мерджить без тестов** - сломаете master
5. **Не использовать `git reset --hard` на shared ветках**

---

## 🔍 Troubleshooting

### Конфликт при мердже
```bash
git merge phase2
# CONFLICT (content): Merge conflict in src/Server.cpp

# Решить конфликты вручную в файле
vim src/Server.cpp

# Добавить разрешенные файлы
git add src/Server.cpp

# Завершить мердж
git commit
```

### Отменить последний коммит (локально)
```bash
git reset --soft HEAD~1  # оставить изменения
git reset --hard HEAD~1  # удалить изменения (ОПАСНО!)
```

### Забыли создать ветку, закоммитили в master
```bash
# Создать ветку с текущего состояния
git branch phase2

# Откатить master на один коммит назад
git reset --hard HEAD~1

# Переключиться на новую ветку
git checkout phase2
```

---

## 📈 Текущее состояние проекта

```bash
# Последний коммит:
$ git log -1 --oneline
e78f814 Merge Phase 1: Server fixes

# Текущая ветка:
$ git branch
  master
  phase1
* phase2

# Теги:
$ git tag
v0.1.0
```

**Визуализация:**
```
* e78f814 (HEAD -> phase2, tag: v0.1.0, master) Merge Phase 1
|\
| * 40df087 (phase1) docs: Update development plan
| * dbaaf49 SO_REUSEADDR for rapid restart...
|/
* d07a9bf (origin/master) added headers in Server
```

---

## 🎯 Следующие шаги

1. **Работаем в ветке phase2**
2. **Регулярно коммитим прогресс**
3. **После завершения Phase 2:**
   - Тестируем: `make test`
   - Мерджим в master
   - Создаем тег v0.2.0
   - Создаем phase3

**Хорошей работы!** 🚀
