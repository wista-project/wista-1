#!/usr/bin/env bash
set -euo pipefail

# Interactive script to find and replace 'lovable' with 'wista' or 'woolisbest'.
# Usage: bash scripts/remove-lovable.sh
# Must run from repo root. Make sure you have committed all changes before running.

BRANCH_NAME="remove-lovable"
SEARCH_TERM="lovable"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not a git repository."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Warning: Working tree is not clean. Please commit or stash changes before running."
  read -p "Continue anyway? (y/N): " cont
  [[ "$cont" == "y" || "$cont" == "Y" ]] || exit 1
fi

echo "Creating branch ${BRANCH_NAME}..."
git checkout -b "${BRANCH_NAME}"

echo "Searching for occurrences of '${SEARCH_TERM}'..."
FILES=$(git grep -l "${SEARCH_TERM}" || true)
if [[ -z "$FILES" ]]; then
  echo "No matches for '${SEARCH_TERM}'. Nothing to do."
  exit 0
fi

echo "Found matches in these files:"
echo "$FILES"
echo

# For each file, show matches and ask action
for file in $FILES; do
  echo "------------------------------"
  echo "File: $file"
  echo "Matches:"
  git --no-pager grep -n "${SEARCH_TERM}" -- "$file" || true
  echo "----- Context (5 lines around each match) -----"
  # Show context per occurrence
  git --no-pager grep -n "${SEARCH_TERM}" -- "$file" | while IFS=: read -r lineno line; do
    start=$((lineno>3 ? lineno-3 : 1))
    echo "---- around line $lineno ----"
    sed -n "${start},$((lineno+3))p" "$file" | nl -ba -v"$start"
  done

  # Heuristic default suggestion: if file contains "author" key or is package.json/README/CONTRIBUTORS -> suggest "woolisbest"
  suggestion="wista"
  if grep -qi '"author"\|"Author"\|package.json\|README' <<< "$file" || grep -qi '"author"' "$file" 2>/dev/null || [[ "$file" == "package.json" || "$file" == "README.md" || "$file" == "CONTRIBUTORS" ]]; then
    suggestion="woolisbest"
  fi

  PS3="Choose action for $file (default: ${suggestion}): "
  options=("replace_with_wista" "replace_with_woolisbest" "skip" "edit_manually" "preview_diff_then_decide")
  select opt in "${options[@]}"; do
    case $opt in
      replace_with_wista)
        perl -pi.bak -e 's/\blovable\b/wista/g' "$file"
        git add "$file"
        git commit -m "Replace 'lovable' -> 'wista' in $file"
        echo "Committed replacement to wista for $file"
        break
        ;;
      replace_with_woolisbest)
        perl -pi.bak -e 's/\blovable\b/woolisbest/g' "$file"
        git add "$file"
        git commit -m "Replace 'lovable' -> 'woolisbest' in $file"
        echo "Committed replacement to woolisbest for $file"
        break
        ;;
      skip)
        echo "Skipped $file"
        break
        ;;
      edit_manually)
        ${EDITOR:-vi} "$file"
        git add "$file"
        git commit -m "Manual edit to remove/replace 'lovable' in $file"
        break
        ;;
      preview_diff_then_decide)
        echo "Previewing diff (uncommitted). Press Enter to continue."
        perl -pi.bak -e 's/\blovable\b/<<TEMP_REPLACE>>/g' "$file"
        git --no-pager diff -- "$file" || true
        # revert temp change
        git checkout -- "$file"
        echo "Now choose an action:"
        ;;
      *)
        echo "Invalid option. Choose 1-5."
        ;;
    esac
  done
done

echo "All files processed. Summary:"
git --no-pager log --oneline --decorate -n 20
echo
echo "Create patches with one of these commands:"
echo "  1) Single patch file: git diff origin/main...${BRANCH_NAME} > change.patch"
echo "  2) Series of patch files: git format-patch origin/main..${BRANCH_NAME} -o patches/"
echo
echo "When satisfied, push branch and open a PR:"
echo "  git push -u origin ${BRANCH_NAME}"
echo
echo "If you want me to review produced patch(es), paste the generated 'change.patch' or 'patches/' here."
