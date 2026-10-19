# Omnitask Local

Приватный local-first менеджер задач для Windows и Android (Flutter).

- **ТЗ и архитектура:** [AGENTS.md](AGENTS.md)
- **Приложение:** [app/](app/) — Flutter-проект (см. [app/README.md](app/README.md))

Данные хранятся в одном SQLite-файле (`tasks.db`) в папке, выбранной
пользователем (vault). Облака нет: синхронизация — внешними инструментами
(рекомендуется Syncthing). Функционал и оформление портированы с
справочного проекта OmniTask (`mcp-todo`), без пользователей, аутентификации,
вебхуков и MCP.

## Разработка

```bash
cd app
flutter pub get

# Тесты (на Linux нужен libsqlite3.so в LD_LIBRARY_PATH или libsqlite3-dev)
flutter test

flutter build windows --release   # Windows
flutter build apk --release       # Android (нужен Android SDK)
```
