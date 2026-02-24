# GitHub Actions Self-hosted Runners

Docker Composeを使用してGitHub Actionsのセルフホステッドランナーをローカル環境で一括管理する構成です。

`REPLACE_EXISTING_RUNNER`により、Docker Desktopのアップデート・再起動後も自動復旧します。

## 対象リポジトリ

| リポジトリ               | ランナー数 | パッケージマネージャー | 備考                     |
| ------------------------ | ---------- | ---------------------- | ------------------------ |
| 223n/kigurumi-event-hub  | 3          | pnpm                   | CI + deploy              |
| 223n/vehicle-management  | 3          | npm                    | CI + deploy              |
| 223n/CatPro-Cloudflare   | 2          | pnpm                   | CI + E2E                 |
| 223n/sleep-diary         | 1          | pnpm                   | ワークフローが少ない     |
| 223n/devcontainer-base   | 1          | -                      | 手動実行のみ             |
| 223n/okusuri.223n.tech   | 2          | pnpm                   | CI + deploy              |
| 223n-tech/haru.223n.tech | 2          | pnpm                   | deploy + scheduled-build |

合計: **14台**

## 前提条件

- Docker / Docker Compose
- GitHub Personal Access Token（PAT）
  - Fine-grained token（推奨）
  - Repository permissions: **Administration: Read and write**

## セットアップ

```bash
# 1. .env ファイルを作成
cp .env.example .env

# 2. .env を編集して GitHub PAT を設定
#    GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxx

# 3. ランナーを起動
docker compose up -d
```

## 基本操作

```bash
# 全ランナーの状態確認
docker compose ps

# 特定ランナーのログ確認
docker compose logs -f runner-kigurumi-event-hub-1

# 全ランナーの停止（自動的にGitHubからランナー登録解除）
docker compose down

# 停止 + キャッシュボリューム全削除
docker compose down -v
```

## キャッシュ管理

リポジトリごとにtoolcacheとパッケージマネージャーのキャッシュをDockerボリュームで永続化しています。

```bash
# キャッシュボリューム一覧
docker volume ls | grep github-runners
```

## Docker Desktopアップデート後の復旧

Docker Desktopのアップデートや強制再起動でランナーが停止した場合、以下のコマンドで復旧できます。

```bash
docker compose up -d
```

`REPLACE_EXISTING_RUNNER: "true"`により、古い設定ファイルが残っていても既存登録を上書きして再起動します。

## ファイル構成

```text
.
├── .env.example        # 環境変数テンプレート
├── .env                # 環境変数（Git管理外）
├── .gitattributes      # 改行コード設定
├── .gitignore
├── docker-compose.yml  # ランナー定義
└── README.md
```
