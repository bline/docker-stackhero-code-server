# ~/.bashrc - Enhanced Bash Experience

# Load bash completions if available
if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi

# Enable colors in terminal
export LS_COLORS="di=34:fi=0:ln=36:pi=33:so=35:bd=34;46:cd=34;43:or=31;1:mi=31;1:ex=32:*.tar=31:*.zip=31:*.gz=31"
export CLICOLOR=1

# Better PS1 Prompt with Git Branch Info (from bash-completion)
export PS1='\[\e[1;32m\]\u@\h \[\e[1;34m\]\w\[\e[1;31m\]$(__git_ps1)\[\e[0m\]$ '

# Some useful aliases
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias cls='clear'
alias df='df -h'
alias du='du -h -c'
alias free='free -m'
alias tree='tree -C'
alias ports='netstat -tulnp'

# Git aliases
alias g='git'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gs='git status'
alias gb='git branch'
alias gd='git diff'
alias gco='git checkout'
alias gl='git log --oneline --graph --decorate'

# Jump to workspace by default
cd "${DEFAULT_WORKSPACE}"
