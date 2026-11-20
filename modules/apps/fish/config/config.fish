set -g fish_greeting ""

function fish_title
end

# The default prompt shows user@host. Keep it only over SSH or as a user other
# than the one logged in at the console. The full stat path avoids GNU stat.
if status is-interactive
    and not set -q SSH_CONNECTION
    and test "$USER" = "$(/usr/bin/stat -f %Su /dev/console 2>/dev/null)"
    function prompt_login
    end
end

alias l 'eza --icons'
alias ls 'eza --icons'
alias ll 'eza -l --icons --git --group-directories-first'
alias la 'eza -la --icons --git --group-directories-first'
alias lt 'eza --tree --level=2 --icons'

zoxide init fish | source
direnv hook fish | source
