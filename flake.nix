{
  description = "Basic example of Nix-on-Droid system config.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      #url = "github:nix-community/nix-on-droid"; #25.11
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager = {
      #url = "github:nix-community/home-manager/release-26.05";
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # home-manager 本体。初回ブートストラップを git/clone 不要にするため既定は github。
    # (public な間に fetch される。初回だけ手動で public にして完走後 private に戻す運用)
    # 端末でローカル編集を反映したいときは switch 時に override する:
    #   nix-on-droid switch --flake . \
    #     --override-input myhome "path:$HOME/.config/home-manager"
    # override なら github fetch を伴わないので private のままでよい (HM-update.sh 参照)。
    myhome = {
      url = "github:tongsama/home-manager";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix-on-droid, home-manager, myhome, ... }: {

    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = import nixpkgs { system = "aarch64-linux"; };
      modules = [ ./nix-on-droid.nix ];
      # nix-on-droid.nix から myhome を参照できるようにする
      extraSpecialArgs = { inherit myhome; };

      # home-manager 連携を有効化
      home-manager-path = home-manager.outPath;
    };

  };
}
