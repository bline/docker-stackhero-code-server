# ~/.bashrc - Enhanced Bash Experience

# Load bash completions if available
if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi

source /usr/local/bin/functions.lib.sh

# Enable colors in terminal
export LS_COLORS="di=34:fi=0:ln=36:pi=33:so=35:bd=34;46:cd=34;43:or=31;1:mi=31;1:ex=32:*.tar=31:*.zip=31:*.gz=31"
export CLICOLOR=1

# Load Fly environment variables
FLY_APP_NAME=${FLY_APP_NAME:-unknown}
FLY_REGION=${FLY_REGION:-unknown}

FLY_TOML="/config/fly.toml"

# Try to extract cpu_kind and cpus.
# This assumes that if they exist they are in a line like:
#   cpu_kind = "shared"
#   cpus = 2

cpu_kind=$(extract_toml_value "vm.cpu_kind")
cpus=$(extract_toml_value "vm.cpus")


if [[ -n "$cpu_kind" && -n "$cpus" ]]; then
  # If both values are present, build the machine type string.
  FLY_MACHINE_TYPE="${cpu_kind}-cpu-${cpus}x"
else
  # Otherwise, fall back to the size setting.
  # This expects a line like: size = "shared-cpu-2x"
  FLY_MACHINE_TYPE=$(extract_toml_value "vm.size")
fi

# If no valid value was found, default to shared-cpu-1x.
if [[ -z "$FLY_MACHINE_TYPE" ]]; then
  FLY_MACHINE_TYPE="shared-cpu-1x"
fi

FLY_MEMORY=$(extract_toml_value "vm.memory")

# Enable Git branch display in prompt
if [ -f /usr/share/git/completion/git-prompt.sh ]; then
  source /usr/share/git/completion/git-prompt.sh
elif [ -f /etc/bash_completion.d/git-prompt ]; then
  source /etc/bash_completion.d/git-prompt
else
  # Define a fallback __git_ps1 if the git prompt scripts are not available.
  __git_ps1() {
    local branch

    # Check if we're in a Git repository.
    if git rev-parse --git-dir > /dev/null 2>&1; then
      # Try to get the short symbolic reference (i.e. the branch name).
      branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
      # If the symbolic ref failed (for example in a detached HEAD state), use the commit hash.
      if [ -z "$branch" ]; then
        branch=$(git rev-parse --short HEAD 2>/dev/null)
      fi
      # If we got a branch or commit, print it formatted with the provided format string.
      if [ -n "$branch" ]; then
        printf "$1" "$branch"
      fi
    fi
  }
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

# For flyctl
export FLYCTL_INSTALL="${HOME}/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH:/usr/local/bin"
