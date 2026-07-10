#!/usr/bin/env bash
# 2回目以降の home 環境の更新/反映スクリプト。
#
# home-manager 本体は flake input ではなく文字列パス (flake.nix の myhome) として
# 渡している。nix-on-droid の switch は --impure なので、その絶対パスが毎回読み直され、
# ローカル編集 (未コミット変更含む) がそのまま反映される。flake.lock は触らない。
#
# - ~/.config/home-manager が無ければ clone、あれば pull
# - 編集した home-manager はそのまま git commit / push もできる
set -eu

HM_DIR="$HOME/.config/home-manager"
HM_URL="git@github.com:tongsama/home-manager.git"
# symlink 経由でも、どのディレクトリから実行しても動くよう、スクリプト実体の場所を解決する
# (readlink -f で symlink をたどって絶対パス化)。
SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
ND_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"   # このスクリプト実体のある nix-on-droid_hm

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

# --flake は「.」(カレント) ではなく実体の絶対パスを渡す (symlink/任意 cwd 対応)。
nix-on-droid switch --flake "$ND_DIR"

# 補足:
# - nix-on-droid.nix (system 設定) を編集した場合も上記でそのまま反映される
#   (--flake が local の nix-on-droid_hm を指しているため)。
# - nixpkgs / home-manager / nix-on-droid 自体も更新したいときは:
#     cd "$ND_DIR" && nix flake update
