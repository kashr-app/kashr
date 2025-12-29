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

### Complete Workflow Example

**Note:** A changelog label is required. The script will fail if no label or an invalid label is provided.

```bash
# Create feature branch and make commits
git checkout -b refactor/tag_pickers
git commit -m 'refactor: merge AddTagDialog into TagPickerDialog'

# Create PR 
bin/git-pr changelog:refactor
# Enable auto-merge with rebase for current PR + delete remote branch
bin/git-ship

# After GitHub merges (you'll get a notification), sync local
# switch to main, fetch & merge main, cleanup local branches
bin/git-sync
```

## Other Utils

### generate
Runs `build_runner`.

### emulator
Starts an android emulator, please check the script where it expectes android SDK and which avd it defatuls to.

### db_pull & db_push
Pulls/pushs the app database to/from the current directory
