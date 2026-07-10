{ config, lib, pkgs, myhome, ... }:

let
  sshdPort = 8023;
  sshdDir = "${config.user.home}/.local/share/sshd";

  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDwTE4pMH8/FXmxoZNIN87mUv6u6XaD8T/PkL187WugM kwatanabe@ODPC240501";

  sshdConfig = ''
    Port ${toString sshdPort}
    HostKey ${sshdDir}/ssh_host_ed25519_key
    AuthorizedKeysFile .ssh/authorized_keys
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PubkeyAuthentication yes
    PermitRootLogin no
    PidFile ${sshdDir}/sshd.pid
    Subsystem sftp ${pkgs.openssh}/libexec/sftp-server
  '';
in
{
  # Simply install just the packages
  environment.packages = with pkgs; [
    # User-facing stuff that you really really want to have
    #vim # or some other editor, e.g. nano or neovim

    # Some common stuff that people expect to have
    #procps
    #killall
    #diffutils
    #findutils
    #utillinux
    #tzdata
    #hostname
    #man
    #gnugrep
    #gnupg
    #gnused
    #gnutar
    #bzip2
    #gzip
    #xz
    #zip
    #unzip

    # commandline utils
    git
    curl
    nettools  #for ifconfig
    procps
    findutils
    gnugrep
    gnused
    gnutar
    gawk
    xz
    zstd
    which
    openssh

    # GUI test
    #xfce.xfce4-session
    #xfce.xfce4-terminal
    #xfce.thunar
    #xterm


    # Start sshd in foreground
    (writeShellScriptBin "sshd-start" ''
      set -eu
      exec ${openssh}/bin/sshd -f "${sshdDir}/sshd_config" -D -e
    '')

    # Start sshd in background
    (writeShellScriptBin "sshd-bg" ''
      set -eu
      mkdir -p "${sshdDir}"
      ${openssh}/bin/sshd -f "${sshdDir}/sshd_config" -E "${sshdDir}/sshd.log"
      echo "sshd started on Port:${toString sshdPort}"
      echo "log: ${sshdDir}/sshd.log"
    '')

    # Stop sshd
    (writeShellScriptBin "sshd-stop" ''
      set -eu
      if [ -f "${sshdDir}/sshd.pid" ]; then
        kill "$(cat "${sshdDir}/sshd.pid")" || true
        rm -f "${sshdDir}/sshd.pid"
      else
        pkill sshd || true
      fi
    '')
  ];

  # Create/update sshd files on every nix-on-droid switch
  build.activation.sshdSetup = ''
    $DRY_RUN_CMD mkdir -p "${sshdDir}"
    $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
    $DRY_RUN_CMD chmod 700 "$HOME/.ssh"

    if [ ! -f "${sshdDir}/ssh_host_ed25519_key" ]; then
      $VERBOSE_ECHO "Generating ssh host key..."
      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "${sshdDir}/ssh_host_ed25519_key" -N ""
    fi

    $VERBOSE_ECHO "Writing sshd_config..."
    $DRY_RUN_CMD cat > "${sshdDir}/sshd_config" <<'SSHD_CONFIG_EOF'
${sshdConfig}
SSHD_CONFIG_EOF

    $DRY_RUN_CMD touch "$HOME/.ssh/authorized_keys"

    if ! grep -qxF '${authorizedKey}' "$HOME/.ssh/authorized_keys"; then
      $VERBOSE_ECHO "Adding authorized key: kwatanabe@ODPC240501"
      $DRY_RUN_CMD sh -c 'printf "%s\n" "${authorizedKey}" >> "$HOME/.ssh/authorized_keys"'
    else
      $VERBOSE_ECHO "Authorized key already exists: kwatanabe@ODPC240501"
    fi

    $DRY_RUN_CMD chmod 600 "$HOME/.ssh/authorized_keys"
  '';

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  # Read the changelog before changing this value
  system.stateVersion = "24.05";

  # Set up nix for flakes
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Set your time zone
  time.timeZone = "Asia/Tokyo";

  android-integration.termux-open.enable = true;
  android-integration.termux-open-url.enable = true;
  android-integration.termux-reload-settings.enable = true;
  android-integration.termux-setup-storage.enable = true;

  # my home manager
  home-manager.config = {
    imports = [
      (myhome + "/nix-on-droid_home.nix")
    ];
    my.modules.vim    = true;
    my.modules.nvim   = true;
    my.modules.nodejs = true;
    my.modules.oci    = true;
    my.modules.kubernetes    = true;
    my.modules.fonts    = false;

    my.fcitx5.enable  = false;
    my.gui.profile    = "none";
    my.vim.python     = pkgs.python312;   # pkgs は外側の引数から使える
    my.googleDrive.dir = "~/Gdrive_kwatanb";

    my.modules.pyenv = "clone";     # or "nix"
    my.modules.nodenv = "clone";    # or "nix"。clone は ~/.nodenv (+node-build)
    my.modules.rustup = "nix";      # rustup は nix のみ
    my.modules.goenv = "clone";     # goenv は nixpkgs に無いので clone のみ
    my.modules.plenv = "clone";     # plenv は nixpkgs に無いので clone のみ (~/.plenv +perl-build)

  };
}
