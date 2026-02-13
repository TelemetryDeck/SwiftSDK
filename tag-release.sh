#!/bin/bash
set -euo pipefail

# Invoke this script via: ./tag-release.sh MAJOR.MINOR.PATCH

# Validate that there are no changes in Git prior making a release commit
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR! There are uncommitted changes, can't tag a release without a clean state.";
  exit 1
fi

version=$1

# Replace version String in AppInfoProcessor.swift with specified version
sed -i '' "s/let sdkVersion = \".*\"/let sdkVersion = \"$version\"/" Sources/TelemetryDeck/Processors/AppInfoProcessor.swift

# Make a commit & tag it
git add Sources/TelemetryDeck/Processors/AppInfoProcessor.swift
git commit -m "Bump Version to $version"
git tag $version $(git rev-parse HEAD)

echo "Successfully created a bump commit & tagged it with '$version'."
echo "After checking everything, push the commit including the new tag!"
