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

---

## Дополнения из IOS-Base-App

Ниже добавлены дополнительные кейсы, которых не было в исходной версии этого файла.

### 3. Fastlane: `Could not find Fastfile at path '.../fastlane/./lanes/ios'`

**Где падает:** шаг CI, запускающий Fastlane.

**Фикс:**
- В `fastlane/Fastfile` использовать `import "./lanes/ios.rb"` (с `.rb`).
- Запускать lane по имени: `bundle exec fastlane build_for_testflight`.
- В GitHub Actions выставить `working-directory` на корень репозитория.

---

### 4. Bundler platform mismatch

**Ошибка:**

```
Your bundle only supports platforms ["x86_64-darwin"] but your local platform is arm64-darwin-23
```

**Фикс:**

```bash
bundle lock --add-platform arm64-darwin-23
# опционально:
bundle lock --add-platform x86_64-darwin
```

Закоммитьте `Gemfile.lock` и перезапустите workflow.

---

### 5. Bundler: empty CHECKSUMS in lockfile

**Ошибка:**

```
Your lockfile has an empty CHECKSUMS entry for "...", but can't be updated because frozen mode is set
```

**Фикс:** локально выполнить `bundle lock --add-checksums` (или `bundle install`), закоммитить `Gemfile.lock`. В CI frozen mode не отключать.

---

### 6. CocoaPods / xcodeproj: object version

**Ошибка:**

```
[Xcodeproj] Unable to find compatibility version string for object version `71`
```

**Фикс:** в `*.xcodeproj/project.pbxproj` выставить `objectVersion = 77` (или изменить формат Project Document в Xcode на совместимый). Затем commit + перезапуск CI.

---

### 7. Match: пустой `MATCH_GIT_URL` или неверный URL

**Ошибки:**
- `fatal: The empty string is not a valid path`
- `fatal: repository 'owner/repo' does not exist`

**Фикс:**
- Secret: `GH_PAT` (доступ к repo сертификатов)
- Variable: `MATCH_GIT_URL` (лучше полный HTTPS URL, например `https://github.com/owner/repo.git`)

---

### 8. Match / Apple Developer Portal: `'' is not a valid filter`

**Причина:** не заданы переменные `BUNDLE_IDENTIFIER` и/или `APPLE_TEAM_ID`.

**Фикс:** добавить их в GitHub Actions Variables и убедиться, что они проброшены в env шага build.

---

### 9. Match: лимит Distribution сертификатов

**Ошибка:**

```
Could not create another Distribution certificate, reached the maximum number
```

**Фикс:** удалить (revoke) неиспользуемые Distribution сертификаты в Apple Developer Portal или использовать существующие из match-репозитория в readonly-режиме.

---

### 10. App Store Connect API key: `invalid curve name`

**Ошибка:** `OpenSSL::PKey::ECError invalid curve name`.

**Фикс:** проверить точные имена Secrets:
- `APPSTORE_KEY_ID`
- `APPSTORE_ISSUER_ID`
- `APPSTORE_P8` (Base64 содержимое `.p8`)

---

### 11. Code signing не применяется к основному target / `ipa_path.txt` отсутствует

**Признаки:**
- `targets | []`
- `None of the specified targets has been modified`
- `cat: ipa_path.txt: No such file or directory`

**Фикс:** задать Variable `XC_TARGET_NAME` (имя основного target/scheme, например `ProjectName`).

---

### 12. Чеклист CI переменных

**Secrets:** `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_P8`, `GH_PAT`, `MATCH_PASSWORD`.

**Variables:** `APPLE_TEAM_ID`, `BUNDLE_IDENTIFIER`, `XC_TARGET_NAME`, `MATCH_GIT_URL`, `LAST_UPLOADED_BUILD_NUMBER`, `APPLE_APP_ID`.
