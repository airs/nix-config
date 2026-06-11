{
  description = "airs standard macOS environment (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      # 適用先(aarch64-darwin)と CI(x86_64-linux)の 2 system だけを対象にする。
      # flake-utils を入れず nixpkgs だけで forAllSystems 相当を手書き(YAGNI)。
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # 会社標準の system 層。nix-homebrew の darwinModule を同梱するので、
      # 取り込む側（個人 flake）は nix-homebrew を input に持つ必要がない。
      darwinModules.base = {
        imports = [
          nix-homebrew.darwinModules.nix-homebrew
          ./darwin/base.nix
        ];
      };

      # 会社標準の home 層（CLI と共通 programs.* 設定）。
      homeModules.base = import ./home/base.nix;

      # base モジュール一式と home-manager の配線をまとめるヘルパー。
      # 単体適用エントリ（下記 darwinConfigurations）と個人 flake の両方から使う。
      lib.mkDarwinConfig =
        {
          username,
          stateVersion ? 6,
          homeStateVersion ? "26.05",
          extraModules ? [ ],
          extraHomeModules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          modules = [
            self.darwinModules.base
            home-manager.darwinModules.home-manager
            {
              # ユーザー依存の値はすべて username 引数から導出する。
              system.primaryUser = username;
              users.users.${username}.home = "/Users/${username}";
              nix-homebrew.user = username;

              # stateVersion は base モジュールに置かず、構成単位でここで宣言する。
              system.stateVersion = stateVersion;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # 既存の実ファイル・symlink と衝突した場合は失敗させず退避する。
              home-manager.backupFileExtension = "hm-bak";
              home-manager.users.${username}.imports = [
                self.homeModules.base
                { home.stateVersion = homeStateVersion; }
              ]
              ++ extraHomeModules;
            }
          ]
          ++ extraModules;
        };

      # 単体適用（個人 flake を持たない場合）のエントリ。
      # 属性キーは macOS のユーザー名（setup.sh が `id -un` で参照する）。各自 PR で 1 行追加する。
      darwinConfigurations.kato = self.lib.mkDarwinConfig { username = "kato"; };

      # nix fmt 用。nixfmt 公式の treefmt ラッパー(ディレクトリ再帰・nix fmt 連携に対応)。
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      # nix flake check で format / lint をまとめて検証する。検出時は非ゼロ終了で fail。
      checks = forAllSystems (pkgs: {
        nixfmt = pkgs.runCommand "check-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
          cd ${./.}
          find . -name '*.nix' -print0 | xargs -0 nixfmt --check
          touch $out
        '';

        statix = pkgs.runCommand "check-statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
          cd ${./.}
          statix check .
          touch $out
        '';

        deadnix = pkgs.runCommand "check-deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
          cd ${./.}
          deadnix --fail .
          touch $out
        '';
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nixfmt
            pkgs.statix
            pkgs.deadnix
          ];
        };
      });
    };
}
