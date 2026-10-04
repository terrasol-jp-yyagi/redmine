# Redmine コンテナ

Redmine 7.0 をコンテナで動かすためのファイル一式です。使用するデータベースと接続先は、イメージを作り直さずに環境変数だけで切り替えられます。

| ファイル | 役割 |
|---|---|
| `Dockerfile` | Ruby 3.4 (Debian trixie) ベースのマルチステージビルド。全 DB アダプタの gem を同梱 |
| `docker/entrypoint.sh` | 起動時に `config/database.yml` と `config/configuration.yml` を生成し、マイグレーションと初期データ投入を行う |
| `docker/Gemfile.local` | 実行時の adapter に依存せず gem 構成を固定するための Gemfile.local |
| `docker/puma.rb` | スレッド数・ワーカー数を環境変数で制御する puma 設定 |
| `docker/config.ru` | `RAILS_RELATIVE_URL_ROOT` によるサブディレクトリ配信に対応した rackup ファイル |
| `compose.yml` | Redmine 単体 (SQLite) と、PostgreSQL / MySQL / SQL Server を組み合わせるためのプロファイル |
| `.env.example` | 環境変数のテンプレート。コピーして `.env` を作成する |

## 使い方

```bash
cp .env.example .env          # DB のブロックを 1 つ選んで編集
docker compose up -d --build  # SQLite (既定)
```

他の DB をコンテナで一緒に起動する場合は `.env` の該当ブロックを有効にしてプロファイルを指定します。

```bash
docker compose --profile postgres up -d --build
docker compose --profile mysql    up -d --build
docker compose --profile mssql    up -d --build
```

既存の DB サーバーに接続する場合はプロファイルを付けず、`.env` の `REDMINE_DB_HOST` などに接続先を書くだけです。

初期管理者は admin / admin で、初回ログイン時にパスワード変更を求められます。

### compose を使わない場合

```bash
docker build -t redmine-custom:7.0.2 .
docker run -d --name redmine -p 3000:3000 \
  -e REDMINE_DB_ADAPTER=postgresql -e REDMINE_DB_HOST=db.example.com \
  -e REDMINE_DB_DATABASE=redmine -e REDMINE_DB_USERNAME=redmine -e REDMINE_DB_PASSWORD=secret \
  -v redmine-files:/usr/src/redmine/files \
  redmine-custom:7.0.2
```

## 環境変数

優先順位は「完成済みファイルの指定 (`REDMINE_DATABASE_YML` / `REDMINE_CONFIGURATION_YML`) > 個別の環境変数 > 既定値」です。`*_FILE` が付く変数はファイルのパスを受け取り、Docker secrets と組み合わせて使えます。同名の変数と同時に設定するとエラーになります。

### データベース接続

| 変数名 | 既定値 | 説明 |
|---|---|---|
| `REDMINE_DB_ADAPTER` | `sqlite3` | `mysql2` / `trilogy` / `postgresql` / `sqlite3` / `sqlserver` |
| `REDMINE_DB_HOST` | `localhost` | DB サーバーのホスト名。sqlite3 では未使用 |
| `REDMINE_DB_PORT` | アダプタ依存 (3306 / 5432 / 1433) | 未指定なら各 DB の標準ポート |
| `REDMINE_DB_DATABASE` | `redmine` | DB 名。sqlite3 ではファイルパスで、既定は `/usr/src/redmine/sqlite/redmine.sqlite3` |
| `REDMINE_DB_USERNAME` | `redmine` | 接続ユーザー |
| `REDMINE_DB_PASSWORD` | (空) | 接続パスワード |
| `REDMINE_DB_PASSWORD_FILE` | (未設定) | パスワードを書いたファイルのパス |
| `REDMINE_DB_ENCODING` | mysql: `utf8mb4` / postgresql: `unicode` | 文字コード |
| `REDMINE_DB_POOL` | `RAILS_MAX_THREADS` と同じ | コネクションプール数 |
| `REDMINE_DB_SSLMODE` | (未設定) | postgresql の `sslmode`、mysql2 / trilogy の `ssl_mode` に反映 |
| `REDMINE_DB_TRANSACTION_ISOLATION` | `READ-COMMITTED` | mysql2 / trilogy のみ。Redmine 推奨値 |
| `REDMINE_DB_TIMEOUT` | (未設定) | アダプタの `timeout` オプション |
| `REDMINE_DB_ENCRYPT` | `false` | sqlserver 専用。`true` で TLS 暗号化接続 |
| `REDMINE_DB_TDS_VERSION` | `7.3` | sqlserver 専用。FreeTDS のプロトコル版 |
| `REDMINE_DB_AZURE` | `false` | sqlserver 専用。Azure SQL Database なら `true` |
| `REDMINE_DATABASE_YML` | (未設定) | 完成済み database.yml のパス。指定時は上記からの生成を行わない |

DB サーバーに接続する場合、データベースが無ければ `rake db:prepare` が作成を試みます。作成権限が無いユーザーで接続する場合は、あらかじめ空のデータベースを用意してください。

### アプリケーションと初期化

| 変数名 | 既定値 | 説明 |
|---|---|---|
| `RAILS_ENV` | `production` | 実行環境 |
| `SECRET_KEY_BASE` | 自動生成 | セッション暗号鍵。未設定なら初回起動時に生成し `SECRET_KEY_BASE_FILE` に保存して再利用 |
| `SECRET_KEY_BASE_FILE` | `<添付ファイル保存先>/.secret_key_base` | 生成した鍵の保存先。添付ファイルのボリュームに置かれるので再作成しても失われない |
| `RAILS_RELATIVE_URL_ROOT` | (未設定) | サブディレクトリ配下で公開する場合に `/redmine` のように指定 |
| `RAILS_LOG_TO_STDOUT` | `true` | ログを標準出力へ出す |
| `PORT` | `3000` | 待ち受けポート |
| `RAILS_MAX_THREADS` | `5` | puma のスレッド数 |
| `WEB_CONCURRENCY` | `0` | puma のワーカープロセス数。0 は単一プロセス |
| `TZ` | `UTC` | コンテナのタイムゾーン |
| `REDMINE_LANG` | `en` | 初期データの言語。日本語なら `ja` |
| `REDMINE_LOAD_DEFAULT_DATA` | `true` | 起動時にデフォルトデータを投入。既にデータがあればスキップ |
| `REDMINE_SKIP_DB_MIGRATE` | `false` | `true` でマイグレーションを実行しない |
| `REDMINE_PLUGINS_MIGRATE` | `true` | `plugins/` にプラグインがあればそのマイグレーションも実行 |
| `REDMINE_DB_WAIT_TIMEOUT` | `60` | DB が接続可能になり `db:prepare` が成功するまで待つ秒数 |

### メール送信と添付ファイル (任意)

`REDMINE_SMTP_ADDRESS` を設定したときだけ、生成する `configuration.yml` にメール設定が含まれます。

| 変数名 | 既定値 | 説明 |
|---|---|---|
| `REDMINE_SMTP_ADDRESS` | (未設定) | SMTP サーバー |
| `REDMINE_SMTP_PORT` | `587` | SMTP ポート |
| `REDMINE_SMTP_DOMAIN` | (未設定) | HELO ドメイン |
| `REDMINE_SMTP_USER_NAME` | (未設定) | SMTP 認証ユーザー。設定時のみ認証情報を出力 |
| `REDMINE_SMTP_PASSWORD` | (未設定) | SMTP 認証パスワード |
| `REDMINE_SMTP_PASSWORD_FILE` | (未設定) | パスワードファイルのパス |
| `REDMINE_SMTP_AUTHENTICATION` | `plain` | `plain` / `login` / `cram_md5` |
| `REDMINE_SMTP_ENABLE_STARTTLS_AUTO` | `true` | STARTTLS を自動使用 |
| `REDMINE_SMTP_OPENSSL_VERIFY_MODE` | `peer` | 証明書検証。自己署名なら `none` |
| `REDMINE_ATTACHMENTS_STORAGE_PATH` | `/usr/src/redmine/files` | 添付ファイルの保存先 |
| `REDMINE_CONFIGURATION_YML` | (未設定) | 完成済み configuration.yml のパス。指定時は上記からの生成を行わない |

## ボリューム

| パス | 内容 |
|---|---|
| `/usr/src/redmine/files` | 添付ファイルと、自動生成した `.secret_key_base` |
| `/usr/src/redmine/sqlite` | SQLite のデータファイル (sqlite3 使用時のみ) |
| `/usr/src/redmine/plugins` | プラグイン。ホストのディレクトリをマウントする |
| `/usr/src/redmine/themes/<名前>` | 追加テーマ。テーマごとにマウントする |

`files` と `sqlite` は Dockerfile で `VOLUME` 宣言しているため、明示的にマウントしなくても匿名ボリュームに保存されます。

## 補足

- コンテナは root で起動し、ボリュームの所有権を整えたあと uid 1000 の `redmine` ユーザーに降格して Rails を実行します。`--user` で別ユーザーを指定した場合は所有権の調整を行いません。
- `config/database.yml` や `config/configuration.yml` をバインドマウントした場合、entrypoint はそのファイルが自分の生成物でないことを検知して上書きしません。
- SQL Server 用の `mcr.microsoft.com/mssql/server` イメージは amd64 専用です。Apple Silicon ではエミュレーションで動くため起動に時間がかかります。既存の SQL Server に接続するだけならこの制約はありません。
- アセットは起動時に Redmine が自動でコンパイルします (`config.assets.redmine_detect_update`)。
