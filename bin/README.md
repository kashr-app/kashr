## Git Workflow Scripts

Streamlined scripts for the PR workflow with automatic changelog labeling.

The aims are:
- Maintain a linear git history (rebase merge),
- Enforce changelog labels
- As few steps as possible without manual GitHub UI interaction
- Automatic branch cleanup

### Usage

```bash
bin/git-pr <changelog:type> [title:"custom title"]
```

The PR title must start with a conventional commit type that agrees with the
changelog label. Without `title:` the single commit's subject is used, and a
branch with more than one commit is rejected — summarize it yourself.

```bash
bin/git-pr changelog:fix                                # fix: <commit subject>
bin/git-pr changelog:fix title:"keep totals in sync"    # fix: keep totals in sync
bin/git-pr changelog:fix title:"fix(sync): keep totals" # kept as is
bin/git-pr changelog:fix title:"feat: keep totals"      # fails, type mismatch
bin/git-pr changelog:enhance title:"feat: faster sync"  # any type, enhance is none
```

### Requirements

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- Repository settings:
  - `allow_auto_merge`: enabled
  - `delete_branch_on_merge`: enabled

### Setup Shell Integration
Add `source /path/to/kashr/bin/.bashrc` to your `~/.bashrc` for aliases (`kashr-git-pr`, `kashr-git-ship`, `kashr-git-sync`) and tab completion. Or replace the `kashr-git` with `./bin/git`.

### Complete Workflow Example

**Note:** A changelog label is required. The script will fail if no label or an invalid label is provided.

```bash
# Create feature branch and make commits
git checkout -b feature/some_feature
# do work... git add ... etc.
git commit -m 'feat: some feature'

# Create PR
kashr-git-pr changelog:refactor
# ff-merge and close current PR + delete remote branch
kashr-git-ship

# After GitHub merges (you'll get a notification), sync local
# switch to main, fetch --prune, merge --ff-only origin/main
kashr-git-sync

# Release
kashr-git-bump-version patch # major|minor|patch
kashr-git-ship
kashr-git-sync
git tag vx.y.z
git push origin vx.y.z

```

## Other Utils

### generate
Runs `build_runner`.

### emulator
Starts an android emulator, please check the script where it expectes android SDK and which avd it defatuls to.

### db_pull & db_push
Pulls/pushs the app database to/from the current directory
