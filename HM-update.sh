#### home-managerでのhome環境更新
cd ~/.config/home-manager
git pull
cd ~/.config/nix-on-droid_hm
#git pull
nix flake update
nix-on-droid switch --flake .

