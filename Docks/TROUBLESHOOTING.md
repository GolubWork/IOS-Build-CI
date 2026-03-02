# Устранение неполадок

## Требования к окружению

Для локальной сборки и CI необходимо:

- **macOS** — 12+
- **Xcode** — 14+ (рекомендуется 16.x)
- **Целевая версия iOS** — 16.0 (из Podfile) 
- **Target Version** - 77
- **Ruby** — 3.3+
- **Bundler** — для установки гемов
- **CocoaPods** — 1.16+

---

## Частые проблемы

### 1. CI: `The list of sources changed, but the lockfile can't be updated because frozen mode is set`

**Ошибка (exit code 16):**

```
The list of sources changed, but the lockfile can't be updated because frozen mode is set

You have deleted from the Gemfile:
* <gem_name>
```

**Причина:** `Gemfile.lock` содержит зависимости, которых уже нет в `Gemfile`. CI запускает `bundle install` в frozen/deployment режиме, который запрещает автоматическое обновление lockfile.

Типичный сценарий: при создании нового проекта из шаблона `Gemfile` был обновлён (или скопирован из новой версии шаблона), а `Gemfile.lock` остался от старой версии.

**Решение:**

```bash
# На локальной машине, в корне проекта:
bundle install
git add Gemfile.lock
git commit -m "Regenerate Gemfile.lock to match current Gemfile"
git push
```

**Важно:** любое изменение `Gemfile` (добавление, удаление или обновление гема) требует повторного запуска `bundle install` и коммита обновлённого `Gemfile.lock` до пуша в CI.

---

### 2. CI: `Error cloning certificates repo` / `fatal: could not read Username for 'https://github.com': terminal prompts disabled`

**Ошибка (exit status 128):**

```
fatal: could not read Username for 'https://github.com': terminal prompts disabled
Error cloning certificates git repo, please make sure you have access to the repository
```

**Причина:** `fastlane match` не может клонировать репозиторий сертификатов. GitHub отклоняет аутентификацию через `MATCH_GIT_BASIC_AUTHORIZATION`. Это проблема доступа, а не отсутствия сертификатов.

Типичные причины:
- `GH_PAT` (Personal Access Token) истёк или был отозван
- Репозиторий сертификатов (указанный в `MATCH_GIT_URL`) удалён
- Fine-grained PAT не имеет доступа к репозиторию сертификатов (нужны `Contents: Read and Write`)
- Пользователь, указанный в `MATCH_GIT_BASIC_AUTHORIZATION`, потерял доступ к репозиторию

**Решение (подтверждено):** пересоздание `GH_PAT` и обновление секрета в репозитории решает проблему.

1. Убедиться, что репозиторий сертификатов существует (если удалён — создать заново, пустой, **private**)
2. Пересоздать `GH_PAT`:
   - Classic PAT: scope `repo`
   - Fine-grained PAT: `Contents: Read and Write` для репозитория сертификатов
3. Обновить секрет `GH_PAT` в GitHub Actions Secrets проекта (`Settings → Secrets and variables → Actions`)
4. Перезапустить CI — `match` с `force: true` создаст новые сертификаты автоматически

**Быстрая проверка:** `git clone <MATCH_GIT_URL> /tmp/test-certs-access` — если 404, репозиторий удалён; если auth error, проблема в токене.

**Про обновление приложения после удаления сертификатов:**
Перегенерация signing certificate **не** создаёт новое приложение. Идентичность приложения в App Store Connect / TestFlight определяется по Bundle ID + Team ID, а не по сертификату подписи. Новый сертификат позволяет подписать и загрузить обновление того же приложения.