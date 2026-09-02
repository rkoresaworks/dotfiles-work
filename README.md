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

Raycast はアプリのみインストール（個人用スクリプト・拡張は含まない）。

## 個人リポジトリとの関係

[rkoresaworks/dotfiles](https://github.com/rkoresaworks/dotfiles)（個人用フル構成）から work-safe な部分を切り出したもの。共通設定の変更は必要に応じて手動で同期する。
