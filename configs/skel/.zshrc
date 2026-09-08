# katusaOS Default Zsh Configuration
# ~/.zshrc

# Terminal normalization for UTM / QEMU serial consoles
if [ "$TERM" = "vt100" ] || [ -z "$TERM" ]; then
    export TERM=linux
fi

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# Prompt
PROMPT='%F{cyan}katusaOS%f:%F{blue}%~%f%# '

# Aliases
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias k='katusa'
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias py='python3'
alias v='nvim'

export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"
export EDITOR="nvim"

# Welcome
if [ -x /usr/local/bin/katusa ] && [ -z "$KATUSA_MOTD_SHOWN" ]; then
    export KATUSA_MOTD_SHOWN=1
    /usr/local/bin/katusa info
fi
