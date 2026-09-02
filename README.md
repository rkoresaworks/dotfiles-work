# dotfiles-work

会社 PC 向けの持ち込み可能な dotfiles コア。個人環境依存（自作 CLI、LaunchAgents、Raycast スクリプト、個人アカウント設定）を除外した最小構成。

## セットアップ

```bash
git clone https://github.com/rkoresaworks/dotfiles-work.git ~/src/github.com/rkoresaworks/dotfiles-work
cd ~/src/github.com/rkoresaworks/dotfiles-work
./install.sh
```

インストール後:

1. `~/.gitconfig.local` に会社用の name / email を記入
2. 社内プロキシ・社内ツールの PATH 等は `~/.zshrc.local` に記述（git 管理外）

## 構成

- `zshrc` / `zshenv` — シェル設定（fzf 連携キーバインド含む）
- `gitconfig` — user 情報は `~/.gitconfig.local` に分離
- `Brewfile` — CLI ツール・フォント・ターミナルのみ
- `config/nvim` — Neovim
- `config/starship.toml` — プロンプト
- `config/ghostty` — ターミナル
- `config/mise` — ランタイムバージョン管理
- `config/gh` — GitHub CLI（認証情報 hosts.yml は含まない）
- `config/aerospace` — ウィンドウ管理
- `config/herdr` — エージェントマルチプレクサ
- `claude/starter-kit.conf` — Claude Code の wizard 選択（本体は starter kit 管理。下記参照）

Raycast はアプリのみインストール（個人用スクリプト・拡張は含まない）。

## Claude Code

`~/.claude` 配下（`CLAUDE.md` / `agents` / `commands` / `rules` / `skills` / `hooks` / `settings.json`）は
[cloudnative-co/claude-code-starter-kit](https://github.com/cloudnative-co/claude-code-starter-kit) が管理するため、
このリポジトリでは symlink を張らない。`settings.json` の hooks には絶対パスが埋め込まれるので持ち回さない。

ここで管理するのは wizard の選択結果 1 ファイルのみ。

```bash
git clone https://github.com/cloudnative-co/claude-code-starter-kit.git ~/.claude-starter-kit
cp ~/src/github.com/rkoresaworks/dotfiles-work/claude/starter-kit.conf ~/.claude-starter-kit.conf
~/.claude-starter-kit/setup.sh
```

conf を先に置くことで profile・言語・hooks・プラグイン選択が引き継がれ、wizard の対話を省略できる。
選択を変えたら `cp` の向きを逆にしてこのリポジトリへ戻し、コミットする。

`~/.claude.json`（machineID・キャッシュ）、`history.jsonl`、`sessions/`、`projects/` はマシン固有のため管理外。

## 個人リポジトリとの関係

[rkoresaworks/dotfiles](https://github.com/rkoresaworks/dotfiles)（個人用フル構成）から work-safe な部分を切り出したもの。共通設定の変更は必要に応じて手動で同期する。
