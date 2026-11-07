# User-specific fish configuration.
# Kept in conf.d so upstream changes to config.fish do not overwrite it.

if status is-interactive

    # Terminal greeting: pokemon in weeb mode, CachyOS logo otherwise.
    function __ii_mode
        if test -f ~/.local/state/illogical-impulse/mode
            cat ~/.local/state/illogical-impulse/mode
        else
            echo weeb
        end
    end

    function fastfetch
        if test (__ii_mode) = weeb
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

# Added by the Antigravity CLI installer
set -gx PATH "$HOME/.local/bin" $PATH
