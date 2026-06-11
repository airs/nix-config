# 会社標準の home 層（home-manager モジュール）。
# 個人 flake から合成されることを前提に、スカラ値は lib.mkDefault で宣言して
# 上書き可能にする。home.stateVersion はここに置かず mkDarwinConfig 側で宣言する。
# シェル設定（programs.zsh 等）は会社標準では提供しない（個人側の責務）。
{ pkgs, lib, ... }:

{
  # 会社標準の CLI util。git / gh は programs.* が個別に導入する。
  # 開発ツールは会社標準にしない（プロジェクト単位の環境は devbox の責務）。
  home.packages = [
    pkgs.fd
    pkgs.jq
    pkgs.nkf
    pkgs.ripgrep
    pkgs.tree
    pkgs.wget
  ];

  # git は中立設定のみ。identity・署名・alias・ignores は個人側で上乗せする。
  programs.git = {
    enable = lib.mkDefault true;
    settings = {
      fetch.prune = lib.mkDefault true;
      init.defaultBranch = lib.mkDefault "main";
    };
  };

  # GitHub 運用の会社標準。flake update 時の `gh auth token` にも使う。
  programs.gh.enable = lib.mkDefault true;
}
