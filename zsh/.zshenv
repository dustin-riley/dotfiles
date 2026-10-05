if [[ -r /etc/profile.d/ona-secrets.sh ]]; then
  source /etc/profile.d/ona-secrets.sh
fi

if [[ -r "$HOME/.nix-profile/etc/profile.d/nix.sh" && "$PATH" != *"$HOME/.nix-profile/bin"* ]]; then
  if [[ -z "$USER" ]]; then
    export USER="$(whoami)"
  fi
  source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
