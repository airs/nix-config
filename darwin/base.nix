# 会社標準の system 層（nix-darwin モジュール）。
# 個人 flake から合成されることを前提に、スカラ値は lib.mkDefault で宣言して
# 上書き可能にする（リスト型は module system が自動連結マージするので素のまま）。
# ユーザー依存の値（system.primaryUser / users.users.* / nix-homebrew.user）と
# system.stateVersion はここに置かず、mkDarwinConfig（flake.nix）側で宣言する。
{ lib, ... }:

{
  # 会社標準マシン (Apple Silicon) のプラットフォーム。
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";

  # unfree パッケージを許可する（個人 flake 側で unfree な CLI を追加できるように）。
  nixpkgs.config.allowUnfree = lib.mkDefault true;

  # flakes を恒久的に有効化する。/etc/nix/nix.conf は nix-installer 由来で
  # nix-command のみ有効なので、ここで flakes も足して nix-darwin に管理させる。
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Homebrew 本体を nix-homebrew で導入・管理する（bootstrap 前提を Nix のみにする）。
  # 既存の /opt/homebrew は autoMigrate で再インストールせず引き継ぐ。
  nix-homebrew = {
    enable = lib.mkDefault true;
    autoMigrate = lib.mkDefault true;
    # 宣言 cask はすべて arm 対応のため Intel(Rosetta) prefix は不要。
    enableRosetta = lib.mkDefault false;
  };

  # GUI cask は Homebrew(cask) を nix-darwin の homebrew モジュールで宣言管理する
  # （このモジュールは brew bundle を駆動する）。
  homebrew = {
    enable = lib.mkDefault true;
    # 宣言外の formula/cask を自動でアンインストールする。
    # formula は宣言しない方針（CLI は nix/home-manager、プロジェクトは devbox）なので
    # これにより手動導入の brew formula は一掃される。
    onActivation.cleanup = lib.mkDefault "uninstall";
    caskArgs.appdir = lib.mkDefault "/Applications";
    # 会社標準の GUI アプリ。個人 flake 側の homebrew.casks と自動連結される。
    casks = [
      "google-chrome"
      "google-drive"
      "slack"
    ];
  };
}
