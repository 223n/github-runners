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
| 223n/npo-tool             | 1    | 1            | composer               | CI + Dependabot          |
| 223n/sleep-diary-php      | 1    | 1            | composer               | CI + Dependabot          |
| 223n/FursuitWeather_iOS   | -    | 1            | npm                    | Dependabotのみ           |

合計: **17台**（CI用12台 + Dependabot用5台）と、CI用の共有MySQL 1台

kigurumi-event-hubとokusuri.223n.techのランナーは、リポジトリがアーカイブされたため削除しました。

## CI用の共有MySQL

`npo-tool`と`sleep-diary-php`のCIはMySQLを必要とします。
しかし**GitHub Actionsの`services:`は、この構成では使えません。**

`services:`で起動したコンテナーのポートはDockerホスト側に公開されます。
一方、ジョブはランナーコンテナーの中で動くため、ジョブから見た`127.0.0.1`は
ランナーコンテナー自身を指します。両者がつながりません。
docker.sockをマウントしてホストのDockerを操作する構成（docker-out-of-docker）に
共通する制約です。

そのため、常設のMySQLを同じcomposeネットワークへ置いています。
composeの既定ネットワークではサービス名で名前解決できるため、
ワークフローからは**ホスト名`mysql`**で参照します。

データベースは`mysql-init/01-databases.sql`で作成します。
ジョブを分離したい場合はここへ足して、ワークフロー側の接続先を向け替えてください。

| データベース | 用途 |
| ------------ | ---- |
| `npo_tool_test` | npo-tool |
| `sleep_diary_test` | sleep-diary-php |
| `sleep_diary_test_lowest` / `_highest` | sleep-diary-php のマトリクス用 |
| `sleep_diary_test_coverage` | sleep-diary-php のカバレッジ用 |

CIランナーを各1台に絞っているのは、共有MySQLを使うためです。
同一リポジトリのジョブが並走するとデータベースを取り合います。
台数を増やす場合は、ジョブごとにデータベースを分けてください。

### リポジトリ側に必要な変更

ランナーを用意しただけでは動きません。各リポジトリのワークフローで次を行います。

1. `runs-on`を`self-hosted`にする
   （`CatPro-Cloudflare`のように`${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}`と
   書けば、リポジトリ変数の切り替えだけで戻せます）
2. `services:`のブロックを削除する
3. 接続先のホストを`127.0.0.1`から`mysql`へ変える

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

## ランナーイメージ

`myoung34/github-runner:ubuntu-noble`（Ubuntu 24.04 / glibc 2.39）を使用します。

`latest`タグはUbuntu 20.04ベース（glibc 2.31）で、`@cloudflare/workerd-linux-64`が要求する
`GLIBC_2.32`〜`GLIBC_2.35`を満たしません。この状態では`vitest-pool-workers`を使うテストが
workerdを起動できず、`Test Files: no tests`のまま失敗します。

イメージを更新する場合は明示的にpullします。`docker compose up -d`だけでは
取得済みイメージが再利用され、タグを変えても反映されません。

```bash
docker compose pull
docker compose up -d
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
├── mysql-init/         # CI用MySQLの初期化SQL
├── runner.ps1          # 管理スクリプト（PowerShell）
└── README.md
```
