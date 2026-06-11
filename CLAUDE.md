# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリの性質

airs 標準の macOS（aarch64-darwin）環境を **nix-darwin + home-manager で宣言管理する flake** で、2 層構成の **会社標準レイヤー**。個人 flake から input として取り込まれるか、`darwinConfigurations.<ユーザー名>` で単体適用される（使い分けは README 参照）。**公開リポジトリ**であり、コミット内容・全 Git 履歴は誰でも閲覧できる前提で扱う。

## 検証コマンド

- **eval/ビルド検証（sudo 不要・編集後は必ずこれで確認）**:
  ```sh
  NIX_CONFIG="access-tokens = github.com=$(gh auth token)" \
    /run/current-system/sw/bin/darwin-rebuild build --flake .#<ユーザー名>
  ```
  生成された設定値の確認は `nix eval --raw .#darwinConfigurations.<ユーザー名>.config.<path>` が使える。
- **lint / format（編集後・sudo 不要）**: `nix fmt`（nixfmt で整形）/ `nix flake check`（nixfmt・statix・deadnix を検証、CI の checks ジョブと同一）/ `nix develop`（ツール入り開発シェル）。
- **適用（switch）は Claude のセッションから実行しない**。sudo パスワードが必要なうえ、`cleanup = "uninstall"` により宣言外の cask が消えるため、build までで止めてユーザーに依頼する。
- setup.sh を編集したら `bash -n setup.sh` と shellcheck（`nix run nixpkgs#shellcheck -- setup.sh`）を通す。

### 必須の落とし穴

- `sudo darwin-rebuild ...` は **command not found**（sudo の secure_path に nix が無い）。常にフルパス `/run/current-system/sw/bin/darwin-rebuild` を使う。
- flake input を再解決する操作（`nix flake update`・新規 input 追加・初回解決）は **GitHub API のレート制限(403)** を踏む。`NIX_CONFIG="access-tokens = github.com=$(gh auth token)"` を付ける（`--access-tokens` は darwin-rebuild の引数ではなく nix 側オプションなので `NIX_CONFIG` 経由で渡す）。flake.lock 解決済み・ストア充填後は不要。
- `git tree is dirty` 警告は未コミット変更があると出るだけで無害（flake は git 追跡ファイルを読む。逆に **新規ファイルは `git add` するまで flake から見えない**）。

## 構成と責務分担

| ファイル | 役割 |
| --- | --- |
| `flake.nix` | inputs（nixpkgs-unstable / nix-darwin / home-manager / nix-homebrew）と outputs（`darwinModules.base`・`homeModules.base`・`lib.mkDarwinConfig`・`darwinConfigurations.*`・`formatter`・`checks`・`devShells`） |
| `darwin/base.nix` | 会社標準の system 層: system/nix 設定・nix-homebrew（Homebrew 本体）・`homebrew.casks` |
| `home/base.nix` | 会社標準の home 層: `home.packages`（CLI）・`programs.git`（中立設定のみ）・`programs.gh` |
| `setup.sh` | 単体適用のキッティング（Nix 導入〜初回 switch、冪等）。`~/.zshrc.local` の雛形生成もここ |
| `.github/workflows/ci.yml` | push / PR 時に `nix flake check`（Linux）と全 `darwinConfigurations` の実ビルド（macOS、switch なし） |
| `statix.toml` | dotted notation は意図的なので `repeated_keys` を無効化 |

**ツールをどこで管理するかの原則**:
- CLI → **home-manager**（`home.packages` か `programs.*`）。**Homebrew formula としては入れない**。
- GUI アプリ → **`homebrew.casks`**。
- プロジェクト単位の環境 → **devbox**（このリポの対象外）。
- Claude Code CLI → **宣言管理しない**（公式インストーラ＋自己アップデート優先）。
- 会社標準に入れるのは全社員が使う最小集合のみ。個人の好み・開発ツールは個人 flake の責務。

## 編集時の注意（モジュール設計規約）

- **base のスカラ値は `lib.mkDefault` で宣言する**。個人 flake 側が素の代入で上書きできるようにするため（mkDefault 無しだと重複定義で評価エラー）。リスト型（`homebrew.casks` / `home.packages`）は module system が自動連結マージするので素のまま。
- **ユーザー依存の値は base に書かない**。`system.primaryUser`・`users.users.<name>`・`nix-homebrew.user`・`home-manager.users.<name>` はすべて `mkDarwinConfig` が `username` 引数から導出する。`--impure` や `builtins.getEnv` は使わない。
- **`system.stateVersion` / `home.stateVersion` も base に書かない**。`mkDarwinConfig` の引数（既定値あり）で受ける。既存値は安易に変更しない。
- **`programs.zsh` には触れない**。シェル設定（エイリアス含む）は個人の責務で、会社標準では一切提供しない。日常コマンドは README にフルコマンドで記載する。
- **`homebrew.onActivation.cleanup = "uninstall"`**: 宣言に無い cask/formula は switch 時に自動アンインストールされる。会社標準 cask の追加・削除は全社員のマシンに波及するので慎重に。
- **git 設定は `programs.git.settings`**（新スキーマ）を使う。旧 `userName/aliases/extraConfig` は deprecation。
- **公開リポジトリ前提**: 秘匿値・ライセンスキー・内部 URL・社内固有名詞・個人情報をコミットに含めない。マシン固有値は `~/.zshrc.local`（リポ外・未追跡）へ。履歴も公開されるため、混入後の除去には filter-repo 等での履歴書き換えが要る。

## Git / PR

- ユーザーのグローバルルール（`~/.claude/CLAUDE.md`）に従う: 日本語・簡潔、1 コミット 1 論理変更、PR 本文は「指示の要点／変更概要／レビューのポイント／検証方法」の 4 点。
- 単体適用する社員の追加は `darwinConfigurations` への 1 行 PR で受け付ける。
