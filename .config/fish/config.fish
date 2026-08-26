source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
set -gx TERMINAL ghostty
set -gx EDITOR nvim
set -gx VISUAL nvim

if status is-interactive
    keychain add --eval --quiet id_ed25519 | source
end
fnm env --use-on-cd --shell fish | source


# Added by Antigravity CLI installer
set -gx PATH "/home/batmicho/.local/bin" $PATH
