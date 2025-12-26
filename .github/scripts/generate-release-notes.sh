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

# Get the previous tag
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")

if [ -z "$PREV_TAG" ]; then
  # First release, get all commits
  ALL_COMMITS=$(git log --pretty=format:"%s|%h|%an" --no-merges)
else
  # Get commits since previous tag
  ALL_COMMITS=$(git log $PREV_TAG..HEAD --pretty=format:"%s|%h|%an" --no-merges)
fi

# Initialize category arrays
FEATURES=""
PERFORMANCE=""
FIXES=""
DOCS=""
REFACTOR=""
TESTS=""
CHORE=""
BREAKING=""
OTHER=""

# Parse commits by type using conventional commit format
while IFS='|' read -r message hash author; do
  # Skip empty lines
  [ -z "$message" ] && continue

  # Extract the type and description
  if [[ $message =~ ^([a-z]+)(\([a-z0-9_-]+\))?(!)?:\ (.+)$ ]]; then
    type="${BASH_REMATCH[1]}"
    scope="${BASH_REMATCH[2]}"
    breaking="${BASH_REMATCH[3]}"
    desc="${BASH_REMATCH[4]}"

    # Remove parentheses from scope if present
    scope="${scope#(}"
    scope="${scope%)}"

    # Handle breaking changes
    if [[ -n "$breaking" ]]; then
      BREAKING="${BREAKING}- **BREAKING:** $desc (\`$hash\`)\n"
      continue
    fi

    # Capitalize first letter of description
    desc="$(tr '[:lower:]' '[:upper:]' <<< ${desc:0:1})${desc:1}"

    # Add scope to description if present
    if [[ -n "$scope" ]]; then
      desc="**$scope:** $desc"
    fi

    # Categorize by type
    case "$type" in
      feat)
        FEATURES="${FEATURES}- $desc (\`$hash\`)\n"
        ;;
      fix)
        FIXES="${FIXES}- $desc (\`$hash\`)\n"
        ;;
      doc|docs)
        DOCS="${DOCS}- $desc (\`$hash\`)\n"
        ;;
      refactor)
        REFACTOR="${REFACTOR}- $desc (\`$hash\`)\n"
        ;;
      perf)
        PERFORMANCE="${PERFORMANCE}- $desc (\`$hash\`)\n"
        ;;
      test)
        TESTS="${TESTS}- $desc (\`$hash\`)\n"
        ;;
      chore|ci|build)
        CHORE="${CHORE}- $desc (\`$hash\`)\n"
        ;;
      *)
        OTHER="${OTHER}- $desc (\`$hash\`)\n"
        ;;
    esac
  else
    # Non-conventional commit
    OTHER="${OTHER}- $message (\`$hash\`)\n"
  fi
done <<< "$ALL_COMMITS"

# Count total commits
COMMIT_COUNT=$(echo "$ALL_COMMITS" | grep -c '^' || echo "0")

# Build release notes
cat > release_notes.md << 'HEADER'
## 🎉 What's New

HEADER

# Add breaking changes first (if any)
if [ -n "$BREAKING" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### ⚠️ Breaking Changes

SECTION_HEADER
  echo -e "$BREAKING" >> release_notes.md
fi

# Add features
if [ -n "$FEATURES" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### ✨ Features

SECTION_HEADER
  echo -e "$FEATURES" >> release_notes.md
fi

# Add bug fixes
if [ -n "$FIXES" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### 🐛 Bug Fixes

SECTION_HEADER
  echo -e "$FIXES" >> release_notes.md
fi

# Add performance improvements
if [ -n "$PERFORMANCE" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### 🚀 Performance Improvements

SECTION_HEADER
  echo -e "$PERFORMANCE" >> release_notes.md
fi

# Add refactoring
if [ -n "$REFACTOR" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### ♻️ Code Refactoring

SECTION_HEADER
  echo -e "$REFACTOR" >> release_notes.md
fi

# Add documentation
if [ -n "$DOCS" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### 📚 Documentation

SECTION_HEADER
  echo -e "$DOCS" >> release_notes.md
fi

# Add tests
if [ -n "$TESTS" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### 🧪 Tests

SECTION_HEADER
  echo -e "$TESTS" >> release_notes.md
fi

# Add chore/maintenance
if [ -n "$CHORE" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### 🔧 Maintenance

SECTION_HEADER
  echo -e "$CHORE" >> release_notes.md
fi

# Add other changes
if [ -n "$OTHER" ]; then
  cat >> release_notes.md << 'SECTION_HEADER'
### 📝 Other Changes

SECTION_HEADER
  echo -e "$OTHER" >> release_notes.md
fi

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

echo "Release notes generated successfully!"
cat release_notes.md
