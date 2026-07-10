# nix-on-droid_hm

nix-on-droid (Android / Termux 上の Nix ディストリビューション) から、
home-manager リポジトリ [github:tongsama/home-manager](https://github.com/tongsama/home-manager)
を使って home 環境をセットアップするための flake。sshd の起動/停止スクリプトと
初期セットアップ (host 鍵・authorized_keys の生成) 付き。

## 構成

| ファイル | 役割 |
|---|---|
| `flake.nix` | 入力 (nixpkgs / nix-on-droid / home-manager) のバージョン固定と出力定義。home-manager 本体は `myhome` (文字列パス) で参照 |
| `nix-on-droid.nix` | 端末 (system) 設定 — パッケージ, sshd, timezone, termux 統合。`home-manager.config` で home-manager のモジュールを上書き |
| `HM-update.sh` | 2 回目以降の更新/反映スクリプト (ローカル home-manager を clone/pull して反映) |

`myhome` = home-manager 本体 (このユーザの config repo) のローカルパス。
**nix-on-droid の `switch` は `--override-input` を受け付けない** (nix / home-manager コマンドとは別物)
ため、flake input で切り替える手が使えない。そこで `myhome` を **flake input にせず「文字列パス」**
として渡している (flake.nix の `outputs` 内)。switch は `--impure` なのでこの絶対パスが毎回読み直され、
ローカル編集がそのまま反映される。**`flake.lock` には現れない**ので環境依存の churn も起きない。
よって普段は clone 済みの home-manager を編集して `--flake .` で反映する。初回だけ、まだ clone が
無いので先に git で clone してから switch する (後述)。

## 対象バージョン (揃える必要あり)

nix-on-droid が対応するリリースに、nixpkgs / home-manager / stateVersion をすべて合わせる。
現状は **24.05 系**に固定:

| 対象 | 値 |
|---|---|
| nix-on-droid | `release-24.05` |
| nixpkgs | `nixos-24.05` |
| home-manager | `release-24.05` |
| system.stateVersion / home.stateVersion | `24.05` |
| vim 埋め込み python | `python312` (24.05 系は python314 が無く python313 もビルド不可のため) |

別バージョンへ上げる場合は `flake.nix` の各 `url`、`nix-on-droid.nix` の `stateVersion`、
`my.vim.python` を揃えて変更する (home-manager 側は `nix-on-droid_home.nix` が
`home.stateVersion = "24.05"` を持つので、それも合わせる)。

### 利用可能な nix-on-droid の release を調べる

nix-on-droid のバージョンは release ブランチ名 (`release-XX.YY`) で指定する。まず今どの
バージョンが出ているかを確認してから、それに nixpkgs / home-manager を合わせる。

**Web で見る:**

- ブランチ一覧: <https://github.com/nix-community/nix-on-droid/branches>
  - `release-XX.YY` … 安定リリース (これを使うのが基本)
  - `prerelease-XX.YY` … 次期リリースの準備ブランチ
  - `master` … 開発版 (最新の nixpkgs unstable 相当)
- README の Installation は「F-Droid から入れる」以上の版指定を書いていないので、
  対応版は上のブランチ一覧で判断する。アプリ側 (F-Droid) の版に合わせるのが無難。

**コマンドで見る** (git がある環境。read-only):

```sh
# 安定 release ブランチ一覧
git ls-remote --heads https://github.com/nix-community/nix-on-droid.git \
  'refs/heads/release-*' | sed 's#.*refs/heads/##' | sort -V

# prerelease も含めて見る
git ls-remote --heads https://github.com/nix-community/nix-on-droid.git \
  'refs/heads/release-*' 'refs/heads/prerelease-*' | sed 's#.*refs/heads/##' | sort -V
```

現状 (最終確認時点):

- 安定最新: **`release-24.05`** ← 本 flake が使用中
- 次期プレリリース: **`prerelease-25.11`** (まだ安定 `release-25.11` は無い)
- 開発版: **`master`**

`release-24.05` より新しくしたい場合は `prerelease-25.11` または `master` を使い、
`flake.nix` の nixpkgs / home-manager も同じ系列 (例: 25.11 / unstable) に、`stateVersion` と
`my.vim.python` も対応するものへ合わせる。プレリリース/開発版は安定性が下がる点に注意。

---

## 初回セットアップ (端末で最小手順)

前提: nix-on-droid アプリはインストール済みで `nix` / `nix-on-droid` コマンドが使える。
まだ `git` も `sshd` も入っていない、まっさらな状態を想定。

`myhome` がローカル path 既定 (nix-on-droid は `--override-input` 非対応のため) なので、
初回は「home-manager を clone → その path を使って switch」する。`git` はまだ無いが
`nix shell nixpkgs#git` で一時的に使える。**age 秘密鍵を switch 前に置いておけば、
この switch で secret 一式まで配置**される。

### 0. (PC) home-manager を一時的に public にする

private のままだと初回の github fetch に認証が要る。この時点では端末にはまだ何も
入っていない (`gh` も無い) ので、**PC 側**で切り替える。gh があれば:

```sh
gh repo edit tongsama/home-manager --visibility public
```

gh が無ければ GitHub の repo → Settings → General → Change repository visibility から手動で。
(nix-on-droid_hm 自体は public のままでよい)

### 1. (端末) sops の age 秘密鍵を配置する

home-manager の secret (SSH 秘密鍵 / `~/.vimrc-secrets` / OCI 鍵) は sops + age で暗号化されている。
**switch より先**にこの age 秘密鍵を置いておくと、手順 2 の switch 一発で secret まで復号・配置される。
配置先・方法は home-manager 側の記載に合わせる:
[doc/secrets-recovery.md](https://github.com/tongsama/home-manager/blob/main/doc/secrets-recovery.md)
の「Secret復元手順」/ [doc/ssh.md](https://github.com/tongsama/home-manager/blob/main/doc/ssh.md) の「age key」節。

ssh も scp もまだ無いが、鍵はテキストの貼り付けだけで置ける (エディタ不要):

```sh
SOPSCONF_DIR="$HOME/.config/sops/age"
mkdir -p "$SOPSCONF_DIR"
chmod 700 -R "$SOPSCONF_DIR"

cat << 'EOF' > "$SOPSCONF_DIR/keys.txt"
# created: ...
# public key: age1xwsw8...
AGE-SECRET-KEY-...            # ← PC の ~/.config/sops/age/keys.txt の中身を貼る
EOF

chmod 600 "$SOPSCONF_DIR/keys.txt"
```

> - この age 秘密鍵は `.sops.yaml` の公開鍵 (`age1xwsw8...`) に対応する **PC と同じ鍵**。
>   PC の `~/.config/sops/age/keys.txt` をバックアップして持ち込む
>   (新規生成した鍵では既存の暗号化 secret を復号できない)。`keys.txt` は Git 管理しない。
> - この鍵を置かずに手順 2 を実行しても、secret deploy は **soft スキップ**されるだけで switch
>   自体は完走する (後から鍵を置いて再 switch すれば反映される)。状態は
>   `hm-ssh-secrets status` / `hm-vim-secrets status` / `hm-oci-secrets status` で確認できる。

### 2. (端末) 2 つの repo を clone して switch

`myhome` がローカル path 既定 (nix-on-droid は `--override-input` 非対応) なので、
先に home-manager と nix-on-droid_hm を clone する。`git` はまだ無いので `nix shell nixpkgs#git`
で一時的に使う (home-manager は手順 0 で public にしてあるので HTTPS で clone できる):

```sh
mkdir -p ~/.config

nix shell nixpkgs#git -c \
  git clone https://github.com/tongsama/nix-on-droid_hm ~/.config/nix-on-droid_hm
nix shell nixpkgs#git -c \
  git clone https://github.com/tongsama/home-manager ~/.config/home-manager

nix-on-droid switch --flake ~/.config/nix-on-droid_hm
```

これで:

- `git` / `openssh` などのパッケージが入る (`environment.packages`)
- `build.activation.sshdSetup` が走り、**sshd の host 鍵・`sshd_config`・`authorized_keys`** が生成される
- home 環境 (home-manager) が適用される
- 手順 1 の age 鍵があるので、**secret 一式 (SSH 秘密鍵・`~/.vimrc-secrets`・OCI 鍵) も配置**される

> flakes が未有効でエラーになる場合は、`nix-on-droid` に CLI フラグを渡すのではなく
> (受け付けないため) 環境変数で有効化してから実行する:
> ```sh
> export NIX_CONFIG='experimental-features = nix-command flakes'
> ```

### 3. (端末) sshd を起動し、PC から接続

```sh
sshd-bg      # sshd をバックグラウンド起動 (Port 8023)
ifconfig     # 端末の IP を確認 (nettools 同梱)
```

PC 側 (`nix-on-droid.nix` の `authorizedKey` に登録済みの鍵を持つクライアント) から:

```sh
ssh -p 8023 <user>@<端末IP>
```

以降の作業はすべて ssh 経由で行える。

### 4. home-manager を private に戻す

以後はローカル運用 (`--flake .`) で github fetch を伴わないため、private のままで問題ない。
手順 2 の switch で (home-manager 経由で) **`gh` が入る**ので、端末からでも戻せる (PC からでも可):

```sh
gh auth login                                        # 端末で gh を使うなら初回のみ
gh repo edit tongsama/home-manager --visibility private
```

> gh のバージョンによっては `--visibility private` に
> `--accept-visibility-change-consequences` の付与が必要 (新しめの gh)。
> エラーになったら付けて再実行する。

---

## 2 回目以降 (ローカル編集 + commit)

初回セットアップで clone 済みの `~/.config/home-manager` を直接編集し、`HM-update.sh` で反映する。
`myhome` がローカル path なので **private のままで OK**、**未コミットの編集もそのまま反映** される。

### 反映

```sh
~/.config/nix-on-droid_hm/HM-update.sh
```

`HM-update.sh` が行うこと:

1. `~/.config/home-manager` を pull (無ければ clone)
2. `nix-on-droid switch --flake ~/.config/nix-on-droid_hm`

- `myhome` は文字列パス (flake input ではない) で、switch は `--impure` なので毎回ローカル内容を
  読み直す。よって `~/.config/home-manager` を直接編集 → `HM-update.sh` で反映される
  (`nix flake update` 不要・未コミット変更も反映)。編集はそのまま `git commit` / `push` できる。
- `nix-on-droid.nix` (system 設定) を編集した場合もそのまま反映される (`--flake` がローカルの nix-on-droid_hm を指すため)。
- `flake.lock` は home-manager のローカル内容に依存しない (myhome は input でないため)。編集しても churn しない。

### git 認証

初回セットアップで **sops の SSH 秘密鍵が `~/.ssh/` に配置済み**なので、その鍵で
private repo の pull / commit / push ができる。端末で改めて SSH 鍵を作り直す必要はない。
(GitHub に未登録の鍵しか無い場合のみ、公開鍵を GitHub に登録するか https + PAT を使う)

### base 入力 (nixpkgs 等) の更新

nixpkgs / home-manager / nix-on-droid 自体を更新したいときは:

```sh
cd ~/.config/nix-on-droid_hm && nix flake update
```

---

## sshd 運用

nix-on-droid には systemd が無いため、sshd は**手動起動**する。

| コマンド | 内容 |
|---|---|
| `sshd-bg` | バックグラウンド起動 (log: `~/.local/share/sshd/sshd.log`) |
| `sshd-start` | フォアグラウンド起動 (`-D -e`) |
| `sshd-stop` | 停止 (pid file、無ければ `pkill sshd`) |

- **Port**: 8023
- 認証: 公開鍵のみ (パスワード認証・root ログインは無効)
- host 鍵 / 設定: `~/.local/share/sshd/`
- 接続を許可するクライアント鍵は `nix-on-droid.nix` の `authorizedKey` に記載。
  別クライアントを許可するときはここに公開鍵を追記して再 switch する。
- 端末を起動するたびに `sshd-bg` を実行する必要がある
  (常用するなら Termux:Boot 等での自動起動を別途検討)。
