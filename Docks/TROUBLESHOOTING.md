# Устранение неполадок

## Технические требования

Требования к окружению для локальной сборки и CI:

- **macOS** — 12+
- **Xcode** — 14+ (рекомендуется 16.x)
- **Целевая версия iOS** — 16.0 (из Podfile)
- **Ruby** — 3.3+
- **Bundler** — для гемов
- **CocoaPods** — 1.16+

---

## Проблемы по этапам процесса сборки

Навигация:

- [2.1. Подготовка окружения](#21-подготовка-окружения)
- [2.2. Установка зависимостей](#22-установка-зависимостей)
- [2.3. Настройка сертификатов (Match)](#23-настройка-сертификатов-match)
- [2.4. Code Signing](#24-code-signing)
- [2.5. Сборка (Build)](#25-сборка-build)
- [2.6. Загрузка в TestFlight](#26-загрузка-в-testflight)

Формат: **Этап → Ошибка → Фикс.**

---

### 2.1. Подготовка окружения

#### Fastlane — Fastfile not found at lanes/ios

- **Этап:** Шаг CI, запускающий Fastlane (например `bundle exec fastlane build_for_testflight`).
- **Ошибка:**
  ```
  [!] Could not find Fastfile at path '.../fastlane/./lanes/ios'
  Error: Process completed with exit code 1.
  ```
- **Фикс:** В `fastlane/Fastfile` используйте `import "./lanes/ios.rb"` (с расширением `.rb`). Запускайте Fastlane из корня репозитория; вызывайте lane только по имени (например `bundle exec fastlane build_for_testflight`), а не `fastlane ios ...`. В GitHub Actions для шага укажите `working-directory` в корень репозитория. Перезапустите workflow.

---

### 2.2. Установка зависимостей

#### Bundler — platform not in lockfile

- **Этап:** `bundle install` (CI, например job Build IPA).
- **Ошибка:**
  ```
  Your bundle only supports platforms ["x86_64-darwin"] but your local platform is
  arm64-darwin-23. Add the current platform to the lockfile with
  `bundle lock --add-platform arm64-darwin-23` and try again.
  Error: The process '.../bundle' failed with exit code 16
  ```
- **Фикс:** На любой машине выполните `bundle lock --add-platform arm64-darwin-23`, закоммитьте `Gemfile.lock`. Опционально добавьте оба: `bundle lock --add-platform x86_64-darwin` и `bundle lock --add-platform arm64-darwin-23`. Перезапустите workflow.

#### Bundler — empty CHECKSUMS in lockfile

- **Этап:** `bundle install` (CI).
- **Ошибка:**
  ```
  Your lockfile has an empty CHECKSUMS entry for "rake", but can't be updated
  because frozen mode is set.

  Run `bundle install` elsewhere and add the updated Gemfile.lock to version
  control.

  If this is a development machine, remove the Gemfile.lock freeze by running
  `bundle config set frozen false`.
  Error: The process '.../bundle' failed with exit code 16
  ```
- **Фикс:** Локально выполните `bundle lock --add-checksums` или `bundle install` (с сетью), закоммитьте обновлённый `Gemfile.lock`. Не отключайте frozen mode в CI. Перезапустите workflow.

#### Build IPA — CocoaPods / Xcodeproj object version

- **Этап:** Build IPA → lane Fastlane (например `build_for_testflight`) → шаг CocoaPods («Analyzing dependencies», `pod install`).
- **Ошибка:**
  ```
  ArgumentError - [Xcodeproj] Unable to find compatibility version string for object version `71`.
  /vendor/bundle/.../gems/xcodeproj-1.27.0/lib/xcodeproj/project.rb:85:in `initialize'
  ...
  [!] Oh no, an error occurred.
  ```
- **Фикс:** Проект сохранён в Xcode 26 (или новее) и имеет `objectVersion = 71` в `*.xcodeproj/project.pbxproj`; гем xcodeproj 1.27.x знает строки совместимости только до object version 77. В `ProjectName.xcodeproj/project.pbxproj` установите `objectVersion = 77` (замените `71`). Закоммитьте изменение и перезапустите workflow. Если не хотите править файл вручную: откройте проект в Xcode → File Inspector (⌘⌥0) → Project Document → установите формат в версию, дающую object version 56 или 77.

---

### 2.3. Настройка сертификатов (Match)

#### Build IPA — Match: error cloning certificates repo

- **Этап:** Build IPA → lane Fastlane `build_for_testflight` → шаг **match** (клон репозитория сертификатов).
- **Ошибки (обе решаются настройкой секретов и переменных):**

  1. **Пустой URL:**
     ```
     fatal: The empty string is not a valid path
     Error cloning certificates git repo...
     git clone '' /var/folders/.../T/...
     ```
  2. **Репозиторий не найден (неверный формат URL):**
     ```
     fatal: repository 'owner/ProjectName-Certificates' does not exist
     Error cloning certificates git repo, please make sure you have read access to the repository
     ```

- **Фикс:** В настройках репозитория GitHub **Settings → Secrets and variables → Actions** добавьте:

  1. **Secret** `GH_PAT` — GitHub Personal Access Token с правом чтения репозитория сертификатов Match.
  2. **Variable** `MATCH_GIT_URL` — полный HTTPS URL репозитория сертификатов Match (например `https://github.com/owner/ProjectName-Certificates.git`).  
     Краткая форма `owner/repo` автоматически приводится к `https://github.com/owner/repo.git` в `fastlane/MatchFile`; если по-прежнему видите «repository '...' does not exist», укажите полный URL или проверьте, что репозиторий существует и у `GH_PAT` есть к нему доступ.

  Без `MATCH_GIT_URL` (или если он пустой) получите «empty string is not a valid path». Без `GH_PAT` клонирование не пройдёт из-за авторизации. После исправления обоих перезапустите workflow.

#### Build IPA — Match: '' is not a valid filter (Apple Developer Portal)

- **Этап:** Build IPA → lane Fastlane `build_for_testflight` → шаг **match** (после клонирования репозитория, при проверке в Apple Developer Portal).
- **Ошибка:**
  ```
  An error occurred while verifying your certificates and profiles with the Apple Developer Portal.
  A parameter has an invalid value - '' is not a valid filter
  ```
  В сводке match может отображаться `app_identifier | ["", ".notifications"]` (первый элемент пустой).
- **Причина:** Переменные **`BUNDLE_IDENTIFIER`** и (часто) **`APPLE_TEAM_ID`** не заданы в репозитории, поэтому Match передаёт в API Apple пустой фильтр.
- **Фикс:** В GitHub **Settings → Secrets and variables → Actions → Variables** задайте:
  - **`BUNDLE_IDENTIFIER`** — bundle ID приложения (например `com.yourcompany.ProjectName`).
  - **`APPLE_TEAM_ID`** — Apple Team ID (10 символов).

  Убедитесь, что шаг «Build for TestFlight» получает эти переменные (через `env` на уровне workflow или шага). После добавления обеих переменных перезапустите workflow.

#### Build IPA — Match: maximum number of Distribution certificates

- **Этап:** Build IPA → lane Fastlane `build_for_testflight` → шаг **match** (создание или проверка Distribution-сертификата в Apple).
- **Ошибка:**
  ```
  Could not create another Distribution certificate, reached the maximum number of available Distribution certificates.
  (Apple API: "You already have a current Distribution certificate or a pending certificate request.")
  ```
- **Причина:** В аккаунте Apple Developer достигнут лимит Distribution-сертификатов для команды, либо уже есть существующий (или ожидающий) сертификат, а Match пытается создать ещё один.
- **Фикс:** **Очистите уже созданные сертификаты в аккаунте Apple Developer**, чтобы Match мог создать новый, либо переиспользуйте существующий из git-репозитория Match.  
  1. Откройте [Apple Developer Portal](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Certificates**.
  2. Найдите **Distribution** (Apple Distribution) сертификаты для вашей команды и **Revoke** те, что больше не нужны (или были созданы для других приложений/команд). Apple разрешает ограниченное число Distribution-сертификатов на команду (например 3); отзыв освобождает слот.
  3. При необходимости отзовите неиспользуемые **Development** сертификаты, если упираетесь в лимиты.
  4. Если git-репозиторий Match уже содержит валидные сертификаты и профили для этого приложения, можно запускать Match в режиме **readonly**, чтобы он не пытался создавать новые сертификаты (использовать существующие из репозитория).  
  После отзыва перезапустите workflow. Если используете пустой репозиторий Match без сертификатов, после очистки Match создаст новый Distribution-сертификат.

#### Build IPA — App Store Connect API key: invalid curve name

- **Этап:** Build IPA → lane Fastlane после CocoaPods (например при использовании Match или шагов TestFlight, требующих ключ ASC API).
- **Ошибка:**
  ```
  invalid curve name (OpenSSL::PKey::ECError)
  .../spaceship/lib/spaceship/connect_api/token.rb:71:in `initialize'
  ```
- **Фикс:**
  1. **Секреты в GitHub:** Workflow ожидает секреты с именами **`APPSTORE_KEY_ID`**, **`APPSTORE_ISSUER_ID`**, **`APPSTORE_P8`** (Settings → Secrets and variables → Actions). Если вы создали `ASC_KEY_ID` / `ASC_KEY` и т.п., переменные окружения будут пустыми и OpenSSL выдаст «invalid curve name».
  2. Секреты: APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_P8

---

### 2.4. Code Signing

#### Build IPA — code signing not applied to main target / ipa_path.txt missing

- **Этап:** Build IPA → lane Fastlane `build_for_testflight` (после Match, при `update_code_signing_settings` или «Prepare IPA for artifact»).
- **Ошибки:**
  - В сводке lane: `targets | []` (пусто), «None of the specified targets has been modified», затем Xcode падает с «No profile for team …» или «No Accounts».
  - Следующий шаг: `cat: ipa_path.txt: No such file or directory`.
- **Причина:** Переменная **`XC_TARGET_NAME`** не задана в репозитории, поэтому lane не знает, какой таргет настраивать для code signing, и путь к IPA может не записываться.
- **Фикс:** В GitHub **Settings → Secrets and variables → Actions → Variables** добавьте переменную **`XC_TARGET_NAME`** со значением **`ProjectName`** (имя схемы и основного таргета приложения). Перезапустите workflow.

---

### 2.5. Сборка (Build)

*(Добавляйте конкретные ошибки и решения по мере появления: этап → ошибка → фикс.)*

---

### 2.6. Загрузка в TestFlight

*(Добавляйте конкретные ошибки и решения по мере появления: этап → ошибка → фикс.)*

---

## Локальная разработка (IDE / Git)

### IDE / Git — не отображаются изменения (например Git-Rider)

- **Этап:** Локальная работа в Rider (или аналоге) с VCS.
- **Ошибка:** Git не показывает изменения; корень репозитория не определяется.
- **Фикс:** Откройте родительскую директорию (папку, в которой лежит проект) как проект, чтобы корень репозитория был верным. Или в Rider: Settings → Version Control, добавьте директорию с `.git` как VCS root. При необходимости используйте File → Synchronize или Invalidate Caches / Restart.

---

## CI (GitHub Actions)

**Секреты** (Settings → Secrets and variables → Actions → Secrets; имена должны совпадать точно):

- `APPSTORE_KEY_ID` — ID ключа API App Store Connect (передаётся в env как ASC_KEY_ID)
- `APPSTORE_ISSUER_ID` — issuer ID App Store Connect (передаётся как ASC_ISSUER_ID)
- `APPSTORE_P8` — содержимое .p8 ключа App Store Connect, **в кодировке Base64** (передаётся как ASC_KEY)
- `GH_PAT` — GitHub PAT для доступа к репозиторию Match
- `MATCH_PASSWORD` — пароль для сертификатов Match. **Опционально:** если не задан, используется пустой пароль; это работает только если репозиторий сертификатов Match был создан (или перешифрован) с пустым паролем.

**Переменные** (Settings → Secrets and variables → Actions → Variables):

- `APPLE_TEAM_ID`
- `BUNDLE_IDENTIFIER`
- **`XC_TARGET_NAME`** — **обязательна.** Установите **`ProjectName`** (имя схемы и основного таргета приложения). Если переменная отсутствует или пуста, job Build IPA упадёт: code signing не применится к основному таргету (`targets | []`) и `ipa_path.txt` может отсутствовать. См. подраздел *Build IPA — code signing not applied to main target / ipa_path.txt missing* выше.
- `MATCH_GIT_URL` — URL репозитория сертификатов Match
- `LAST_UPLOADED_BUILD_NUMBER` — последний загруженный номер сборки (обновляется после загрузки)
- `APPLE_APP_ID` — числовой Apple app ID (для upload_to_testflight)

---

## Другое

### Build & sign

*(Добавляйте конкретные ошибки и решения по мере появления: этап → ошибка → фикс.)*

### Загрузка в TestFlight

*(Добавляйте конкретные ошибки и решения по мере появления: этап → ошибка → фикс.)*

### Match / сертификаты

- **Пустой пароль (нет секрета MATCH_PASSWORD):** Lane устанавливает `MATCH_PASSWORD` в `""`, когда секрет не задан, и применяет патч, чтобы гем Match принимал пустой пароль для шифрования. Расшифровка и шифрование пройдут только если репозиторий сертификатов был создан с пустой фразой (например `fastlane match appstore` и нажмите Enter при запросе пароля). Чтобы перевести существующий репозиторий на пустой пароль: `fastlane match change_password` и задайте новый пароль пустым. Секрет `MATCH_PASSWORD` можно удалить из GitHub Actions.

*(Добавляйте остальные ошибки и решения по мере появления: этап → ошибка → фикс.)*

### Firebase / GoogleService

*(Добавляйте конкретные ошибки и решения по мере появления: этап → ошибка → фикс.)*
