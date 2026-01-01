# Git workflow aliases
alias kashr-git-pr='bin/git-pr'
alias kashr-git-ship='bin/git-ship'
alias kashr-git-sync='bin/git-sync'
alias kashr-git-bump-version='bin/bump_version'

# Tab completion for kashr-git-pr (suggest changelog types)
_kashr-git-pr_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local types="breaking feat enhance fix perf docs chore refactor translation skip"

    # Case 1: First argument - suggest "changelog:" prefix
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local changelog_types=""
        for type in $types; do
            changelog_types="$changelog_types changelog:$type"
        done
        COMPREPLY=($(compgen -W "$changelog_types" -- "$cur"))

    # Case 2: After "changelog:" (bash splits this at the colon)
    # COMP_WORDS will be: [kashr-git-pr, changelog, :] or [kashr-git-pr, changelog, :, partial]
    elif [[ ${COMP_CWORD} -eq 2 && "$prev" == "changelog" && "$cur" == ":" ]]; then
        # User typed "changelog:" and pressed TAB
        COMPREPLY=($(compgen -W "$types" -- ""))
    elif [[ ${COMP_CWORD} -eq 2 && "$prev" == "changelog" ]]; then
        # User typed "changelog:x" and pressed TAB (cur is ":x" or just partial after colon)
        local suffix="${cur#:}"
        COMPREPLY=($(compgen -W "$types" -- "$suffix"))
    elif [[ ${COMP_CWORD} -eq 3 && "${COMP_WORDS[1]}" == "changelog" && "${COMP_WORDS[2]}" == ":" ]]; then
        # User typed "changelog:par" where "par" is a partial type
        COMPREPLY=($(compgen -W "$types" -- "$cur"))
    fi
}

# Enable completion for kashr-git-pr
complete -F _kashr-git-pr_completion kashr-git-pr

# Tab completion for kashr-git-bump-version (suggest version bump types)
_kashr-git-bump-version_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local types="major minor patch"

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$types" -- "$cur"))
    fi
}

# Enable completion for kashr-git-bump-version
complete -F _kashr-git-bump-version_completion kashr-git-bump-version
