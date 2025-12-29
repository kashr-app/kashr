## Git Workflow Scripts

Streamlined scripts for the PR workflow with automatic changelog labeling.

The aims are:
- Maintain a linear git history (rebase merge),
- Enforce changelog labels
- As few steps as possible without manual GitHub UI interaction
- Automatic branch cleanup

### Usage

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
git checkout -b refactor/tag_pickers
git commit -m 'refactor: merge AddTagDialog into TagPickerDialog'

# Create PR
kashr-git-pr changelog:refactor
# Enable auto-merge with rebase for current PR + delete remote branch
kashr-git-ship

# After GitHub merges (you'll get a notification), sync local
# switch to main, fetch --prune, merge --ff-only origin/main
kashr-git-sync
```

## Other Utils

### generate
Runs `build_runner`.

### emulator
Starts an android emulator, please check the script where it expectes android SDK and which avd it defatuls to.

### db_pull & db_push
Pulls/pushs the app database to/from the current directory
