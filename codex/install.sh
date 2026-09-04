#!/bin/bash
set -euo pipefail

CODEX_DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_CONFIG_DIR="$HOME/.codex"
CODEX_CONFIG_PATH="$CODEX_CONFIG_DIR/config.toml"
CODEX_CONFIG_TEMPLATE="$CODEX_DOTFILES_DIR/config.toml"
CODEX_AGENTS_PATH="$CODEX_CONFIG_DIR/AGENTS.md"
CODEX_AGENTS_TEMPLATE="$CODEX_DOTFILES_DIR/AGENTS.md"
CODEX_SKILLS_DIR="$CODEX_CONFIG_DIR/skills"
CODEX_SKILLS_TEMPLATE_DIR="$CODEX_DOTFILES_DIR/skills"
CODEX_CONFIG_TEMP="$(mktemp)"

cleanup() {
    rm -f "$CODEX_CONFIG_TEMP"
}
trap cleanup EXIT

cp "$CODEX_CONFIG_TEMPLATE" "$CODEX_CONFIG_TEMP"

if [ -f "$CODEX_CONFIG_PATH" ]; then
    awk '
        /^\[projects\./ || /^\[hooks\.state\./ {
            preserve = 1
            print ""
            print
            next
        }
        /^\[/ && !(/^\[projects\./ || /^\[hooks\.state\./) {
            preserve = 0
        }
        preserve && NF { print }
    ' "$CODEX_CONFIG_PATH" >> "$CODEX_CONFIG_TEMP"
fi

mkdir -p "$CODEX_CONFIG_DIR"
chmod 600 "$CODEX_CONFIG_TEMP"
mv "$CODEX_CONFIG_TEMP" "$CODEX_CONFIG_PATH"
trap - EXIT

install -m 644 "$CODEX_AGENTS_TEMPLATE" "$CODEX_AGENTS_PATH"

mkdir -p "$CODEX_SKILLS_DIR"
for CODEX_SKILL_TEMPLATE in "$CODEX_SKILLS_TEMPLATE_DIR"/*; do
    [ -d "$CODEX_SKILL_TEMPLATE" ] || continue
    CODEX_SKILL_NAME="$(basename "$CODEX_SKILL_TEMPLATE")"
    CODEX_SKILL_PATH="$CODEX_SKILLS_DIR/$CODEX_SKILL_NAME"
    rm -rf "$CODEX_SKILL_PATH"
    cp -R "$CODEX_SKILL_TEMPLATE" "$CODEX_SKILL_PATH"
done

printf '\033[32m[ ok ]\033[0m Codex config installed\n'
