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

    # home-manager 本体は flake input にしない (下記 outputs の myhome 参照)。
  };

  outputs = { self, nixpkgs, nix-on-droid, home-manager, ... }:
    let
      # home-manager 本体 (このユーザの config repo) のローカルパス。
      # flake input (path 型) にすると flake.lock に環境依存の narHash が入り、
      # ローカル編集の度に churn する。そこで flake input ではなく「文字列パス」として渡す。
      # nix-on-droid の switch は --impure なので、nix-on-droid.nix 側の
      #   imports = [ (myhome + "/nix-on-droid_home.nix") ]
      # は絶対パスとして読め、ローカル編集も毎回反映される。flake.lock には現れない。
      # このパスは nix-on-droid ではどの端末でも同じ ($HOME=/data/data/com.termux.nix/files/home)。
      # 初回は先に nix shell nixpkgs#git で home-manager / nix-on-droid_hm を clone してから
      # `--flake .` で switch する (README 参照)。
      myhome = "/data/data/com.termux.nix/files/home/.config/home-manager";
    in
    {
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = import nixpkgs { system = "aarch64-linux"; };
        modules = [ ./nix-on-droid.nix ];
        # nix-on-droid.nix から myhome (文字列パス) を参照できるようにする
        extraSpecialArgs = { inherit myhome; };

        # home-manager 連携を有効化
        home-manager-path = home-manager.outPath;
      };
    };
}
