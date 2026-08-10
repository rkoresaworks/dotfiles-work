# フロー制御を無効化 (Ctrl+S/Ctrl+Q)
stty -ixon

# mise: Node/Python/etc バージョン管理 (プロジェクトごと自動切替)
eval "$(mise activate zsh)"

eval "$(starship init zsh)"

export EDITOR='nvim'
alias vi='nvim'
alias vim='nvim'
alias view='nvim -R'

export PATH="$HOME/.local/bin:$PATH"

# zoxide (smart cd)
eval "$(zoxide init zsh)"

# auto ls on cd + git fetch check
function chpwd() {
  ls

  # git リポジトリなら、バックグラウンドで remote 更新を確認
  # (直近10分以内に fetch 済みならスキップ — cd 連発時のネットワーク負荷対策)
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [ -f "$git_dir/FETCH_HEAD" ] && [ -n "$(find "$git_dir/FETCH_HEAD" -mmin -10 2>/dev/null)" ]; then
      return
    fi
    (
      git fetch --quiet 2>/dev/null

      local local_ref=$(git rev-parse HEAD 2>/dev/null)
      local tracking=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
      if [ -n "$tracking" ]; then
        local remote_ref=$(git rev-parse "$tracking" 2>/dev/null)
        if [ "$local_ref" != "$remote_ref" ]; then
          local behind=$(git rev-list --count HEAD.."$tracking" 2>/dev/null)
          if [ "$behind" -gt 0 ] 2>/dev/null; then
            print -P "\n%F{yellow}↓ リモートに ${behind} コミットの更新があります (${tracking})%f"
          fi
        fi
      fi
    ) &!
  fi
}


# ghq + fzf
function ghq-fzf() {
  local src=$(
    ghq list | fzf \
      --height=70% \
      --layout=reverse \
      --border=rounded \
      --margin=1 \
      --padding=1 \
      --preview '
        bat --color=always --style=plain --line-range :120 \
        $(ghq root)/{}/README* 2>/dev/null
      ' \
      --preview-window=right:50%:wrap
  )
  if [ -n "$src" ]; then
    BUFFER="cd $(ghq root)/$src"
    zle accept-line
  fi
  zle -R -c
}
zle -N ghq-fzf
bindkey '^g' ghq-fzf

# file search + open (Ctrl+F)
function find-fzf() {
  local file=$(
    fd --type f --hidden --exclude .git | fzf \
      --height=70% \
      --layout=reverse \
      --border=rounded \
      --preview 'bat --color=always --style=numbers --line-range :200 {}'
  )
  if [ -n "$file" ]; then
    BUFFER="nvim -- $file"
    zle accept-line
  fi
  zle -R -c
}
zle -N find-fzf
bindkey '^f' find-fzf

# cd directory (Ctrl+T)
function cd-fzf() {
  local dir=$(
    fd --type d --hidden --exclude .git | fzf \
      --height=70% \
      --layout=reverse \
      --border=rounded \
      --preview 'ls -la {}'
  )
  if [ -n "$dir" ]; then
    BUFFER="cd $dir"
    zle accept-line
  fi
  zle -R -c
}
zle -N cd-fzf
bindkey '^t' cd-fzf

# command history (Ctrl+R)
function history-fzf() {
  local cmd=$(
    history -n -r 1 | fzf \
      --height=70% \
      --layout=reverse \
      --border=rounded \
      --no-sort
  )
  if [ -n "$cmd" ]; then
    BUFFER="$cmd"
    zle end-of-line
  fi
  zle -R -c
}
zle -N history-fzf
bindkey '^r' history-fzf

# git branch switch (Ctrl+B)
# enter: open worktree │ F1: checkout (main worktree のブランチ切替 — 通常は worktree 推奨) │ F2: remove worktree
function git-branch-fzf() {
  local result=$(
    git branch -a --sort=-committerdate | fzf \
      --height=70% \
      --layout=reverse \
      --border=rounded \
      --header="enter: open worktree │ F1: checkout │ F2: remove worktree" \
      --preview 'git log --oneline --graph -20 {}' \
      --expect="f1,f2"
  )
  local key=$(echo "$result" | head -1)
  local branch=$(echo "$result" | tail -1)
  if [ -z "$branch" ]; then
    zle -R -c
    return
  fi
  branch=$(echo "$branch" | sed 's/^[+* ]*//' | sed 's|remotes/origin/||')

  local repo_root=$(git rev-parse --show-toplevel)
  local repo_name=$(basename "$repo_root")
  local parent_dir=$(dirname "$repo_root")
  local safe_branch=$(echo "$branch" | tr '/' '-')
  local wt_path="${parent_dir}/${repo_name}-${safe_branch}"

  case "$key" in
    f1)
      BUFFER="git checkout $branch"
      zle accept-line
      ;;
    f2)
      local wt_dir=$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '
        /^worktree / { path = substr($0, 10) }
        /^branch /   { if (substr($0, 8) == b) print path; path = "" }
      ')
      if [ -z "$wt_dir" ]; then
        BUFFER="echo 'No worktree for $branch'"
      else
        BUFFER="git worktree remove '$wt_dir'"
      fi
      zle accept-line
      ;;
    *)
      if [ -d "$wt_path" ]; then
        BUFFER="cd '$wt_path'"
      elif git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        BUFFER="git worktree add '$wt_path' '$branch' && cd '$wt_path'"
      else
        BUFFER="git worktree add '$wt_path' -b '$branch' && cd '$wt_path'"
      fi
      zle accept-line
      ;;
  esac
  zle -R -c
}
zle -N git-branch-fzf
bindkey '^b' git-branch-fzf

# マシンローカル設定 (社内プロキシ・社内ツール PATH 等は ~/.zshrc.local へ)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
