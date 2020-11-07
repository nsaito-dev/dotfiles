#****************************************
# Common settings for every platform
#****************************************

function set4general {
    # Alias
    alias ll='ls -Al'
    alias la='ls -al'
    alias l='ls'
    alias rm='rm -i'
    alias cp='cp -i'
    alias mv='mv -i'
    alias less='less -r'
    alias whence='type -a'
    alias h=history
    alias x=exit
    alias ..='cd ..'
    # Prompt colors
    export PS1="-- \[\033[1;37m\]\u@\h \[\033[1;33m\]\w \[\033[0m\]-- \n> "
    export LC_ALL=en_US.UTF-8
}

#****************************************
# Settings for specific platfrom
#****************************************

function set4osx() {
    # Alias
    alias ls='ls -wFG'
    alias pip="pip3"
    alias e="emacsclient -n"
    alias ee='open -a /Applications/Emacs.app $1'
    alias enw="emacsclient -nw"
    # Autojump
    [[ -s `brew --prefix`/etc/autojump.sh ]] && . `brew --prefix`/etc/autojump.sh
}

function set4linux() {
    # Alias
    alias ls='ls -CF --color=auto'
    alias c2x='~/Applications/c2x/c2x'
    alias bader='~/Applications/bader/bader'
    alias den2vasp='~/Applications/den2vasp/den2vasp'
    source /usr/share/autojump/autojump.sh
}

#****************************************
# Main routine
#****************************************

set4general
if [[ `uname` == "Darwin" ]]; then set4osx
elif [[ `uname` == "Linux" ]]; then set4linux
fi
