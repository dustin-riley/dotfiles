# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's included

| Package | Manages | Target |
|---------|---------|--------|
| `ghostty` | Terminal config (padding, cursor style) | `~/.config/ghostty/config` |
| `vscode` | Editor settings (formatting, linting, TypeScript) | `~/Library/Application Support/Code/User/settings.json` |
| `zsh` | Shell config (Oh My Zsh, plugins, PATH) | `~/.zshrc`, `~/.zprofile` |

## Setup

### Prerequisites

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# GNU Stow
brew install stow

# Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```

### Install

```bash
git clone git@github.com:dustin-riley/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -t ~ ghostty vscode zsh
```
