# katusaOS Default Bash Configuration
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History control
HISTCONTROL=ignoreboth
HISTSIZE=5000
HISTFILESIZE=10000
shopt -s histappend
shopt -s checkwinsize

# Colors and prompt
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
else
    color_prompt=
fi

if [ "$color_prompt" = yes ]; then
    PS1='\[\033[01;36m\]katusaOS\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='katusaOS:\w\$ '
fi
unset color_prompt

# Enable color support for ls and commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# katusaOS Developer Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
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

# Path configuration
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"
export EDITOR="nvim"

# Print welcome banner on interactive login
if [ -x /usr/local/bin/katusa ] && [ -z "$KATUSA_MOTD_SHOWN" ]; then
    export KATUSA_MOTD_SHOWN=1
    /usr/local/bin/katusa info
fi
