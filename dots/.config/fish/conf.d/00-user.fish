# User-specific fish configuration.
# Kept in conf.d so upstream changes to config.fish do not overwrite it.

if status is-interactive

    # Terminal greeting depends on the active desktop profile.
    function __ii_terminal_style
        if test -f ~/.local/state/illogical-impulse/terminal
            cat ~/.local/state/illogical-impulse/terminal
        else if test -f ~/.local/state/illogical-impulse/mode
            if test (cat ~/.local/state/illogical-impulse/mode) = weeb
                echo pokemon
            else
                echo cachyos
            end
        else
            echo pokemon
        end
    end

    function fastfetch
        if not command -q fastfetch
            return
        end
        if test (__ii_terminal_style) = pokemon; and command -q pokemon-colorscripts
            pokemon-colorscripts -r --no-title -s | command fastfetch --raw - --logo-width 40 --logo-padding-right 2 $argv
        else
            command fastfetch --logo CachyOS $argv
        end
    end

    fastfetch

    # --- Tools with automatic approval: <cmd> -auto ---
    function opencode
        if test "$argv[1]" = "-auto"
            command opencode --auto $argv[2..-1]
        else
            command opencode $argv
        end
    end

    function claude
        if test "$argv[1]" = "-auto"
            command claude --dangerously-skip-permissions $argv[2..-1]
        else
            command claude $argv
        end
    end

    function agy
        if test "$argv[1]" = "-auto"
            command agy --dangerously-skip-permissions $argv[2..-1]
        else
            command agy $argv
        end
    end
end

# Make locally installed tools available without duplicating PATH entries.
fish_add_path -g "$HOME/.local/bin"
