## Releasing a new version of the library

1. Merge all changes for the release into `main` via pull request and make sure CI is green.
2. Check out `main` and pull the latest so your local branch matches origin: `git checkout main && git pull`.
3. Run the release script with the new version. This updates `sdkVersion` in `Sources/TelemetryDeck/Processors/AppInfoProcessor.swift`, commits, and creates a version tag.

   ```bash
   ./tag-release.sh 3.0.0
   ```

   The script aborts if the working tree is dirty, so commit or stash unrelated changes first.
4. Push the bump commit together with the new tag:

   ```bash
   git push --follow-tags
   ```

Tags use bare semantic versioning with no `v` prefix (`3.0.0`, `2.14.0`).

### Publishing the release on GitHub

Pushing the tag in step 4 already makes the version installable through Swift Package Manager. Create a GitHub Release from the new tag to publish release notes:

e.g. using the GitHub CLI

```bash
gh release create 3.0.0 --generate-notes
```

### Releasing a pre-release

A beta can be cut from a branch instead of `main`. Run the script on that branch with a pre-release version, push the tag, then mark the GitHub Release as a pre-release:

```bash
./tag-release.sh 3.0.0-beta.1
git push --follow-tags
gh release create 3.0.0-beta.1 --prerelease --target feat/processors --generate-notes
```
