# GitHub Actions Self-hosted Runners

Docker Composeを使用してGitHub Actionsのセルフホステッドランナーをローカル環境で一括管理する構成です。

`REPLACE_EXISTING_RUNNER`により、Docker Desktopのアップデート・再起動後も自動復旧します。

## 対象リポジトリ

| リポジトリ                | CI用 | Dependabot用 | パッケージマネージャー | 備考                     |
| ------------------------- | ---- | ------------ | ---------------------- | ------------------------ |
| 223n/vehicle-management   | 3    | 1            | npm                    | CI + deploy              |
| 223n/CatPro-Cloudflare    | 2    | 1            | pnpm                   | CI + E2E                 |
| 223n/devcontainer-base    | 1    | -            | -                      | 手動実行のみ             |
| 223n-tech/haru.223n.tech  | 2    | -            | pnpm                   | deploy + scheduled-build |
| 223n/FursuitWeather_iMac  | 2    | -            | npm                    | CI + deploy              |
| 223n/npo-tool             | -    | 1            | composer               | Dependabotのみ           |
| 223n/sleep-diary-php      | -    | 1            | composer               | Dependabotのみ           |
| 223n/FursuitWeather_iOS   | -    | 1            | npm                    | Dependabotのみ           |

合計: **15台**（CI用10台 + Dependabot用5台）

kigurumi-event-hubとokusuri.223n.techのランナーは、リポジトリがアーカイブされたため削除しました。

## Dependabotランナー

`Dependabot on self-hosted runners`を有効にしたリポジトリでは、Dependabotのジョブが
**`dependabot`ラベルを持つランナーだけ**を探します。通常のワークフローと違い`runs-on`を
指定できないため、このラベルを持つランナーが1台も無いとジョブはキューに滞留したまま
24時間後にキャンセルされます。失敗として通知されないため気付きにくく、
依存更新もセキュリティ更新も止まったままになります。

CI用ランナーとは別のコンテナーに分けています。CI実行中に依存更新が待たされるのを避けるためです。

### 有効・無効の確認方法

```bash
# ジョブが要求しているラベルを確認する
gh api "repos/<owner>/<repo>/actions/runs?per_page=20" --jq '.workflow_runs[] | select(.name | startswith("npm_and_yarn")) | "\(.created_at) \(.conclusion)"'

# 登録済みランナーのラベルを確認する
gh api "repos/<owner>/<repo>/actions/runners" --jq '.runners[] | "\(.name) \(.labels | map(.name) | join(","))"'
```

ジョブ側が`dependabot`ラベルを要求しているのにランナー側に無ければ、この構成に追加します。
セルフホストで動かす必要が無いリポジトリなら、リポジトリのSettings > Code security >
`Dependabot on self-hosted runners`を無効にしてGitHubホステッドランナーへ戻す方法もあります。

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
.\runner.ps1 logs runner-sleep-diary  # 特定ランナーのログを表示
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
