# nix-config

airs 標準の macOS（aarch64-darwin）環境を nix-darwin + home-manager で宣言的・再現可能・rollback 可能に管理する flake。

## 位置づけ（2層構成の会社標準レイヤー）

本リポジトリは 2 層構成の **会社標準レイヤー** で、使い方は 2 通り:

1. **単体適用** — 個人 flake を持たない場合。本リポジトリの `darwinConfigurations.<ユーザー名>` を直接 switch する。キッティングは [setup.sh](./setup.sh) 一発で完結する。
2. **個人 flake からの取り込み** — 本リポジトリを flake input に取り、エクスポートされたモジュール・ヘルパーを自分の構成に合成する。switch は個人 flake 側から 1 回。

公開リポジトリのため、社内固有情報（ライセンスキー・内部 URL 等）・秘匿値・マシン固有値はコミットしない。マシン固有値は `~/.zshrc.local`（リポ外・未追跡）に置く（[後述](#シークレットマシン固有値zshrclocal)）。

## 提供する outputs

| 出力 | 内容 |
| --- | --- |
| `darwinModules.base` | system/nix 設定・nix-homebrew（Homebrew 本体）・会社標準の `homebrew.casks` |
| `homeModules.base` | 会社標準 CLI の `home.packages`・共通 `programs.*` 設定 |
| `lib.mkDarwinConfig` | base 一式と home-manager の配線をまとめるヘルパー（`username` 必須、`extraModules` / `extraHomeModules` で上乗せ可能） |
| `darwinConfigurations.<ユーザー名>` | 単体適用のエントリ。各自 PR で 1 行追加する |

## 会社標準の内容

| 領域 | 内容 | 場所 |
| --- | --- | --- |
| GUI アプリ（cask） | Google Chrome / Google Drive / Slack | [`darwin/base.nix`](./darwin/base.nix) |
| CLI util | fd / jq / nkf / ripgrep / tree / wget | [`home/base.nix`](./home/base.nix) |
| GitHub CLI | `programs.gh`（GitHub 運用の会社標準） | [`home/base.nix`](./home/base.nix) |
| git | 中立設定のみ（`init.defaultBranch` / `fetch.prune`）。identity・署名・alias は個人側で上乗せ | [`home/base.nix`](./home/base.nix) |
| Homebrew 本体 | nix-homebrew で導入・管理（既存環境は `autoMigrate` で引き継ぐ） | [`darwin/base.nix`](./darwin/base.nix) |
| system / nix 設定 | flakes 有効化・unfree 許可など | [`darwin/base.nix`](./darwin/base.nix) |

提供しないもの（個人の責務）:

- **シェル設定の一切**（zsh の設定・プロンプト・エイリアス）。日常コマンドは下記のフルコマンドを使うか、各自エイリアス化する。
- 開発ツール（プロジェクト単位の環境は devbox の責務）。
- Claude Code CLI（公式インストーラのまま。自己アップデートを優先し宣言管理しない）。

> 注意: `homebrew.onActivation.cleanup = "uninstall"` のため、宣言に無い cask・formula は switch 時に自動アンインストールされる。GUI アプリを追加・存続させたい場合は宣言（本リポジトリの `casks` か個人 flake 側）に必ず足すこと。

## 単体適用（キッティング）

前提: Apple Silicon (aarch64-darwin)。通常ユーザーで実行する（途中で sudo パスワードを求められる）。Xcode CLT は不要。

1. `flake.nix` の `darwinConfigurations` に自分のエントリ（属性キーは macOS のログインユーザー名 = `id -un` の値）を PR で 1 行追加し、merge する:

   ```nix
   darwinConfigurations.<ユーザー名> = self.lib.mkDarwinConfig { username = "<ユーザー名>"; };
   ```

2. セットアップを実行する。Nix 未導入なら導入し、clone・`~/.zshrc.local` 生成・初回 switch まで一気に行う:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/airs/nix-config/main/setup.sh | bash
   ```

   - clone 先は既定で `~/src/nix-config`（`NIX_CONFIG_FLAKE` 設定済みならそれを使う）。
   - `~/.zshrc.local` は無い場合のみ雛形を作成し、既存ファイルは上書きしない。
   - 再実行安全（既存マシンでは Nix 導入をスキップし、`/etc` 退避も衝突時のみ行う）。

### 日常の適用・更新

エイリアスは提供しないため、フルコマンドで実行する（`~/.zshrc.local` の `NIX_CONFIG_FLAKE` / `NIX_CONFIG_ATTR` を参照する）。

適用（switch。`darwin-rebuild` は sudo の secure_path に無いためフルパス）:

```sh
source ~/.zshrc.local
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$NIX_CONFIG_FLAKE#$NIX_CONFIG_ATTR"
```

input 更新を伴う適用（flake update は GitHub API を叩くのでレート制限回避にトークンを渡す）:

```sh
source ~/.zshrc.local
( cd "$NIX_CONFIG_FLAKE" && NIX_CONFIG="access-tokens = github.com=$(gh auth token)" nix flake update )
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake "$NIX_CONFIG_FLAKE#$NIX_CONFIG_ATTR"
```

世代一覧・rollback:

```sh
sudo /run/current-system/sw/bin/darwin-rebuild --list-generations
sudo /run/current-system/sw/bin/darwin-rebuild --rollback
```

## 個人 flake からの取り込み

本リポジトリを input に追加し、`mkDarwinConfig` に個人モジュールを渡すのが基本形:

```nix
{
  inputs = {
    airs.url = "github:airs/nix-config";
  };

  outputs =
    { airs, ... }:
    {
      darwinConfigurations.<ユーザー名> = airs.lib.mkDarwinConfig {
        username = "<ユーザー名>";
        extraModules = [ ./darwin.nix ]; # 個人の cask・system 設定など
        extraHomeModules = [ ./home.nix ]; # 個人の CLI・dotfiles・シェル設定など
      };
    };
}
```

- base のリスト型（`homebrew.casks` / `home.packages`）は自動で連結マージされるので、個人側は追加分だけ宣言すればよい。
- base のスカラ値は `lib.mkDefault` で宣言してあるので、個人側は素の代入で上書きできる。
- nixpkgs / nix-darwin / home-manager / nix-homebrew は本リポジトリの input を経由して解決されるため、個人 flake 側で重ねて持つ必要はない（自前の nixpkgs に統一したい場合は `airs.inputs.nixpkgs.follows` を使う）。

`darwinSystem` の組み立てを自分で行いたい場合は `darwinModules.base` / `homeModules.base` を直接合成してもよい。その場合は `system.primaryUser`・`users.users.<name>`・`nix-homebrew.user`・home-manager の配線・各 stateVersion を自前で宣言する（`mkDarwinConfig` が行っている内容は [flake.nix](./flake.nix) を参照）。

## シークレット・マシン固有値（`~/.zshrc.local`）

リポジトリに含めたくない値は `~/.zshrc.local`（リポ外・未追跡）に置く。setup.sh が生成する雛形:

```sh
# Local secrets / machine-specific overrides. NOT tracked in any repo.
# 適用する flake のクローン先の絶対パス。
export NIX_CONFIG_FLAKE="$HOME/src/nix-config"
# 適用する darwinConfigurations の属性名（単体適用ではログインユーザー名）。
export NIX_CONFIG_ATTR="<ユーザー名>"
```

`chmod 600 ~/.zshrc.local` で自分のみ可読にする。個人 flake から取り込む場合は `NIX_CONFIG_FLAKE` を個人 flake のクローン先、`NIX_CONFIG_ATTR` を個人 flake のエントリ名にする。

## 開発（lint / format）

`.nix` の整形・静的解析は flake の output として提供する。GitHub Actions（[`.github/workflows/ci.yml`](./.github/workflows/ci.yml)）が push / PR 時に `nix flake check` を Linux で実行する（darwin の実ビルドは CI 対象外でローカル switch に委ねる）。

```sh
nix fmt            # nixfmt で整形（formatter = nixfmt-tree）
nix flake check    # nixfmt(--check) / statix / deadnix をまとめて検証（CI と同一）
nix develop        # nixfmt・statix・deadnix が入った開発シェル
```
