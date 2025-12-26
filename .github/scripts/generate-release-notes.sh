#!/bin/bash
set -e

# Script to generate categorized release notes from conventional commits

VERSION_NAME="$1"
VERSION_CODE="$2"
FLUTTER_VERSION="$3"

if [ -z "$VERSION_NAME" ]; then
  echo "Error: VERSION_NAME is required"
  exit 1
fi

# ============================================================================
# Repository Information
# ============================================================================

# Get GitHub repository URL
GIT_REMOTE=$(git config --get remote.origin.url)
# Convert SSH URL to HTTPS URL format and extract owner/repo
if [[ $GIT_REMOTE =~ git@github\.com:(.+)\.git ]]; then
  REPO_PATH="${BASH_REMATCH[1]}"
elif [[ $GIT_REMOTE =~ https://github\.com/(.+)\.git ]]; then
  REPO_PATH="${BASH_REMATCH[1]}"
elif [[ $GIT_REMOTE =~ https://github\.com/(.+) ]]; then
  REPO_PATH="${BASH_REMATCH[1]}"
else
  REPO_PATH=""
fi

if [ -n "$REPO_PATH" ]; then
  REPO_URL="https://github.com/$REPO_PATH"
else
  REPO_URL=""
fi

# Get the previous tag
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")

# ============================================================================
# Get Commits
# ============================================================================

if [ -z "$PREV_TAG" ]; then
  # First release, get all commits
  ALL_COMMITS=$(git log --pretty=format:"%s|%h|%an|%ae" --no-merges)
else
  # Get commits since previous tag
  ALL_COMMITS=$(git log $PREV_TAG..HEAD --pretty=format:"%s|%h|%an|%ae" --no-merges)
fi

# ============================================================================
# Initialize Storage
# ============================================================================

# Initialize category arrays
declare -A CATEGORIES=(
  [feat]=""
  [fix]=""
  [docs]=""
  [refactor]=""
  [perf]=""
  [test]=""
  [chore]=""
  [breaking]=""
  [other]=""
)

# Track unique contributors
declare -A USERNAME_CACHE
declare -A UNIQUE_CONTRIBUTORS

# ============================================================================
# Helper Functions
# ============================================================================

# Get GitHub username from commit hash with caching
get_github_username() {
  local commit_hash="$1"
  local fallback_author="$2"

  # Check cache first
  if [ -n "${USERNAME_CACHE[$commit_hash]}" ]; then
    echo "${USERNAME_CACHE[$commit_hash]}"
    return
  fi

  # Skip API call if no token or repo path
  if [ -z "$REPO_PATH" ] || [ -z "$GITHUB_TOKEN" ]; then
    USERNAME_CACHE[$commit_hash]="$fallback_author"
    echo "$fallback_author"
    return
  fi

  # Fetch from GitHub API
  local response=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO_PATH/commits/$commit_hash" 2>/dev/null)

  # Extract username from author.login field
  local username=$(echo "$response" | grep -o '"author"[[:space:]]*:[[:space:]]*{[^}]*"login"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"login"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"login"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')

  if [ -n "$username" ]; then
    USERNAME_CACHE[$commit_hash]="$username"
    echo "$username"
  else
    USERNAME_CACHE[$commit_hash]="$fallback_author"
    echo "$fallback_author"
  fi
}

# Create commit link (markdown format or backticks)
create_commit_link() {
  local hash="$1"
  if [ -n "$REPO_URL" ]; then
    echo "[#${hash}]($REPO_URL/commit/$hash)"
  else
    echo "\`$hash\`"
  fi
}

# Add item to category
add_to_category() {
  local category="$1"
  local item="$2"
  CATEGORIES[$category]="${CATEGORIES[$category]}$item\n"
}

# Capitalize first letter of string
capitalize() {
  local str="$1"
  echo "$(tr '[:lower:]' '[:upper:]' <<< ${str:0:1})${str:1}"
}

# ============================================================================
# Parse Commits
# ============================================================================

while IFS='|' read -r message hash author email; do
  # Skip empty lines
  [ -z "$message" ] && continue

  # Get GitHub username (with caching and fallback to git author)
  github_user=$(get_github_username "$hash" "$author")
  commit_link=$(create_commit_link "$hash")

  # Track unique contributors
  UNIQUE_CONTRIBUTORS["$github_user"]=1

  # Extract the type and description
  if [[ $message =~ ^([a-z]+)(\([a-z0-9_-]+\))?(!)?:\ (.+)$ ]]; then
    type="${BASH_REMATCH[1]}"
    scope="${BASH_REMATCH[2]}"
    breaking="${BASH_REMATCH[3]}"
    desc="${BASH_REMATCH[4]}"

    # Build the full prefix (type + scope if present)
    prefix="$type$scope"

    # Handle breaking changes
    if [[ -n "$breaking" ]]; then
      add_to_category "breaking" "- **BREAKING:** $prefix: $desc by @$github_user in $commit_link"
      continue
    fi

    # Capitalize first letter of description
    desc=$(capitalize "$desc")

    # Format: prefix: description by @github_user in hash
    item="- $prefix: $desc by @$github_user in $commit_link"

    # Categorize by type
    case "$type" in
      feat)
        add_to_category "feat" "$item"
        ;;
      fix)
        add_to_category "fix" "$item"
        ;;
      doc|docs)
        add_to_category "docs" "$item"
        ;;
      refactor)
        add_to_category "refactor" "$item"
        ;;
      perf)
        add_to_category "perf" "$item"
        ;;
      test)
        add_to_category "test" "$item"
        ;;
      chore|ci|build)
        add_to_category "chore" "$item"
        ;;
      *)
        add_to_category "other" "$item"
        ;;
    esac
  else
    # Non-conventional commit
    add_to_category "other" "- $message by @$github_user in $commit_link"
  fi
done <<< "$ALL_COMMITS"

# Count total commits
COMMIT_COUNT=$(echo "$ALL_COMMITS" | grep -c '^' || echo "0")

# ============================================================================
# Generate Release Notes
# ============================================================================

# Start release notes
cat > release_notes.md << 'HEADER'
## 🎉 What's New

HEADER

# Define sections with their titles and categories
declare -A SECTIONS=(
  [breaking]="⚠️ Breaking Changes"
  [feat]="✨ Features"
  [fix]="🐛 Bug Fixes"
  [perf]="🚀 Performance Improvements"
  [refactor]="♻️ Code Refactoring"
  [docs]="📚 Documentation"
  [test]="🧪 Tests"
  [chore]="🔧 Maintenance"
  [other]="📝 Other Changes"
)

# Add sections in order
for category in breaking feat fix perf refactor docs test chore other; do
  if [ -n "${CATEGORIES[$category]}" ]; then
    echo "" >> release_notes.md
    echo "### ${SECTIONS[$category]}" >> release_notes.md
    echo "" >> release_notes.md
    echo -e "${CATEGORIES[$category]}" >> release_notes.md
  fi
done

# Add build information
cat >> release_notes.md << EOF

---

### 📦 Build Information
- **Version:** $VERSION_NAME
- **Build Number:** $VERSION_CODE
- **Flutter Version:** $FLUTTER_VERSION
- **Build Date:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Total Commits:** $COMMIT_COUNT

### 📥 Installation
Download the APK file below and install it on your Android device.

**Note:** You may need to enable "Install from Unknown Sources" in your device settings.
EOF

# ============================================================================
# Add Contributors Section
# ============================================================================

if [ ${#UNIQUE_CONTRIBUTORS[@]} -gt 0 ]; then
  cat >> release_notes.md << 'SECTION_HEADER'

---

### 👥 Contributors

SECTION_HEADER

  # Add each contributor with avatar
  for username in "${!UNIQUE_CONTRIBUTORS[@]}"; do
    echo "[![@$username](https://github.com/$username.png?size=50)](https://github.com/$username) " >> release_notes.md
  done
  echo "" >> release_notes.md
fi

# ============================================================================
# Add Full Changelog Link
# ============================================================================

if [ -n "$REPO_URL" ] && [ -n "$PREV_TAG" ]; then
  cat >> release_notes.md << EOF

---

**Full Changelog**: $REPO_URL/compare/$PREV_TAG...$VERSION_NAME
EOF
elif [ -n "$REPO_URL" ]; then
  # First release, link to all commits
  cat >> release_notes.md << EOF

---

**Full Changelog**: $REPO_URL/commits/$VERSION_NAME
EOF
fi

echo "Release notes generated successfully!"
cat release_notes.md
