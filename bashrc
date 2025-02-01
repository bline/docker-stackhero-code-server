# ~/.bashrc - Enhanced Bash Experience

# Load bash completions if available
if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi

# Enable colors in terminal
export LS_COLORS="di=34:fi=0:ln=36:pi=33:so=35:bd=34;46:cd=34;43:or=31;1:mi=31;1:ex=32:*.tar=31:*.zip=31:*.gz=31"
export CLICOLOR=1

# Load Fly environment variables
FLY_APP_NAME=${FLY_APP_NAME:-unknown}
FLY_REGION=${FLY_REGION:-unknown}

# Extract machine type and memory from fly.toml
FLY_MACHINE_TYPE=$(grep 'size' /fly.toml | awk -F '"' '{print $2}')
FLY_MEMORY=$(grep 'memory' /fly.toml | awk -F '"' '{print $2}')

# Enable Git branch display in prompt
if [ -f /usr/share/git/completion/git-prompt.sh ]; then
  source /usr/share/git/completion/git-prompt.sh
elif [ -f /etc/bash_completion.d/git-prompt ]; then
  source /etc/bash_completion.d/git-prompt
fi

# Set custom PS1 with current directory
export PS1="\[\e[32m\]$FLY_APP_NAME@$FLY_REGION-$FLY_MACHINE_TYPE-$FLY_MEMORY \[\e[34m\]\w\[\e[33m\]$(__git_ps1 ' (%s)')\[\e[0m\] \$ "

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
