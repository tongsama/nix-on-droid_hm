#!/usr/bin/env bash
# 2回目以降の home 環境の更新/反映スクリプト。
#
# - ~/.config/home-manager が無ければ clone、あれば pull してから switch する。
# - ローカルの home-manager を --override-input で使うので、home-manager が private
#   でも github fetch は不要 (clone/pull は sops で配置済みの SSH 鍵で認証)。
# - 未コミットのローカル編集も反映される。編集した home-manager はそのまま
#   git commit / push もできる。
set -eu

HM_DIR="$HOME/.config/home-manager"
HM_URL="git@github.com:tongsama/home-manager.git"
ND_DIR="$(cd "$(dirname "$0")" && pwd)"   # このスクリプトのある nix-on-droid_hm

# home-manager をローカルに用意 (無ければ clone、あれば fast-forward pull)。
# ローカルに未コミット変更/独自コミットがあり pull できない場合はスキップして
# 現状のローカル内容で反映する (ローカル編集を潰さない)。
if [ -d "$HM_DIR/.git" ]; then
  echo "[HM-update] pull: $HM_DIR"
  git -C "$HM_DIR" pull --ff-only \
    || echo "[HM-update] pull をスキップ (ローカル変更あり?)。今のローカル内容で反映します。"
else
  echo "[HM-update] clone: $HM_URL -> $HM_DIR"
  git clone "$HM_URL" "$HM_DIR"
fi

nix-on-droid switch \
  --flake "$ND_DIR" \
  --override-input myhome "path:$HM_DIR"

# 補足:
# - nix-on-droid.nix (system 設定) を編集した場合も上記でそのまま反映される
#   (--flake が local の nix-on-droid_hm を指しているため)。
# - nixpkgs / home-manager / nix-on-droid 自体を更新したいときのみ別途:
#     cd "$ND_DIR" && nix flake update
