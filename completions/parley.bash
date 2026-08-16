# parley bash completion - generated from the declared tables (CLI verbRows,
# CommandLine sourceFlags, modeFlags, publishLayouts, the question flags); do not edit by hand.
# environment: PARLEY_SOURCE, PARLEY_GIT, PARLEY_INDEX (flag > environment > parley.config.st)
_parley() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    case "$prev" in
        --source|--git|--index)
            COMPREPLY=( $(compgen -o default -- "$cur") )
            return
            ;;
        --layout)
            COMPREPLY=( $(compgen -W "flat sparse" -- "$cur") )
            return
            ;;
    esac
    case "$cur" in
        -*)
            COMPREPLY=( $(compgen -W "--source --git --index --offline --locked --layout --version --help -h" -- "$cur") )
            return
            ;;
    esac
    COMPREPLY=( $(compgen -W "init exec publish why update add remove resolve install search info outdated tree check" -- "$cur") )
}
complete -F _parley parley
