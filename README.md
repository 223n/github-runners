# GitHub Actions Self-hosted Runners

Docker Composeを使用してGitHub Actionsのセルフホステッドランナーをローカル環境で一括管理する構成です。

`REPLACE_EXISTING_RUNNER`により、Docker Desktopのアップデート・再起動後も自動復旧します。

## 対象リポジトリ

| リポジトリ                       | ランナー数 | パッケージマネージャー | 備考                     |
| -------------------------------- | ---------- | ---------------------- | ------------------------ |
| 223n/kigurumi-event-hub          | 3          | pnpm                   | CI + deploy              |
| 223n/vehicle-management          | 3          | npm                    | CI + deploy              |
| 223n/CatPro-Cloudflare           | 2          | pnpm                   | CI + E2E                 |
| 223n/devcontainer-base           | 1          | -                      | 手動実行のみ             |
| 223n/okusuri.223n.tech           | 2          | pnpm                   | CI + deploy              |
| 223n/node_japanese_lint_template | 1          | pnpm                   | 日本語Lintテンプレート   |
| 223n-tech/haru.223n.tech         | 2          | pnpm                   | deploy + scheduled-build |

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

管理スクリプト（`runner.ps1`）を使用します。Docker Desktopが未起動の場合は自動で起動します。

```powershell
.\runner.ps1 start              # ランナーを起動（Docker Desktop自動起動）
.\runner.ps1 stop               # ランナーを停止（GitHub登録自動解除）
.\runner.ps1 restart            # ランナーを再起動
.\runner.ps1 status             # ランナーの状態を表示
.\runner.ps1 logs               # 全ランナーのログを表示
.\runner.ps1 logs runner-node-japanese-lint-template  # 特定ランナーのログを表示
.\runner.ps1 clean              # 停止 + キャッシュボリューム全削除
```

docker composeコマンドを直接使用することもできます。

```bash
docker compose up -d
docker compose ps
docker compose down
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
├── runner.ps1          # 管理スクリプト（PowerShell）
└── README.md
```
