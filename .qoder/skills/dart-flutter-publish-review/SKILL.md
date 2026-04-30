---
name: dart-flutter-publish-review
description: Prepares Dart and Flutter packages for publication to pub.dev, ensuring all metadata, documentation, and requirements are met. Use when preparing to publish a package, updating package metadata, or reviewing package publication readiness.
---

# Publishing Dart Packages

Prepare your Dart or Flutter package for publication to pub.dev.

## When to Use

Use this skill when:

- **Publishing a new package** - Before your first publication to pub.dev
- **Updating package metadata** - Adding topics, funding, or improving discoverability
- **Preparing version updates** - Ensuring all documentation and metadata is current
- **Improving package quality** - Reviewing completeness before publication
- **Setting up verified publisher** - Transferring packages to organizational publishers

This skill is particularly useful for:
- First-time package authors learning pub.dev requirements
- Teams ensuring consistent package quality
- Open source maintainers improving package discoverability
- Projects preparing for public release

## When Not to Use

Do not use this skill when:

- **Private packages** - Packages meant only for internal use
- **Packages with `publish_to: none`** - Explicitly configured to prevent publication
- **Incomplete development** - Core functionality not yet implemented or tested
- **Breaking changes without migration guide** - Major version updates lacking documentation
- **Packages with security issues** - Known vulnerabilities should be fixed first

## Prerequisites

Before publishing, run pana analysis to identify scoring issues:

```bash
pana .
```

Target a score of at least 140/160 before publishing. See the `reviewing-dart-packages` skill for details.

## Workflow

Copy this checklist and track your progress:

```
Package Publication Readiness:
- [ ] Step 1: Verify required files exist
- [ ] Step 2: Complete pubspec.yaml metadata
- [ ] Step 3: Add discoverability fields (topics, funding)
- [ ] Step 4: Validate content quality
- [ ] Step 5: Check package size
- [ ] Step 6: Run static analysis
- [ ] Step 7: Test publish (dry run)
- [ ] Step 8: Review dry run results and fix issues
- [ ] Step 9: Publish to pub.dev
```

**Step 1: Verify required files exist**

Check for these required files:
- `LICENSE` - Required (BSD 3-clause recommended)
- `README.md` - Required for package page
- `CHANGELOG.md` - Strongly recommended
- `pubspec.yaml` - Required, must be valid YAML

**Optional: Agent Skills directory**

If your package includes [Agent Skills](https://pub.dev/packages/skills) for AI assistants, include a `skills/` directory at the package root:

```
my_package/
  lib/
  skills/           # Optional: for AI assistant skills (pub.dev/packages/skills)
    my_skill/
      SKILL.md
```

The `skills/` directory is published with your package so users can run `skills get` to install them. Do not confuse with `.opencode/skills/` which is for opencode tool's internal use.

**Step 2: Complete pubspec.yaml metadata**

Review and add these fields:

```yaml
name: my_package
version: 1.0.0
description: A clear, concise description of what your package does.
homepage: https://github.com/username/my_package
repository: https://github.com/username/my_package
issue_tracker: https://github.com/username/my_package/issues
documentation: https://my_package.dev/docs  # optional

environment:
  sdk: '>=3.0.0 <4.0.0'
```

**Step 3: Add discoverability fields**

Add topics (max 5):

```yaml
topics:
  - http
  - api
  - networking
  - client
  - rest
```

Add funding links:

```yaml
funding:
  - https://github.com/sponsors/username
  - https://buymeacoffee.com/username
```

For Flutter packages, add screenshots (max 10):

```yaml
screenshots:
  - description: 'Main screen showing the app'
    path: screenshots/main.png
```

**Step 4: Validate content quality**

**README.md structure:**
- Package name and description
- Quick start / Installation
- Usage examples
- API reference link (if applicable)
- License information

**CHANGELOG.md format:**
Follow [Keep a Changelog](https://keepachangelog.com/):

```markdown
# Changelog

## [Unreleased]

## [1.0.0] - 2025-01-08
### Added
- Initial release
- Feature X
- Feature Y

### Fixed
- Bug in feature Z
```

**Step 5: Check package size**

Package limits:
- Recommended: < 100 MB (gzipped)
- Maximum: < 256 MB (uncompressed)

Large files to check:
- `example/` directories with assets
- Generated files
- Test fixtures
- `skills/` directory (if included for pub.dev/packages/skills)

Use `.pubignore` to exclude unnecessary files:

```
# .pubignore
.example/
coverage/
.dart_tool/
```

**Step 6: Run static analysis**

```bash
dart analyze
```

Fix all warnings and errors before publishing.

**Step 7: Test publish (dry run)**

```bash
dart pub publish --dry-run
```

This shows exactly what files will be published. Review the list carefully.

**Step 8: Review dry run results and fix issues**

After running `dart pub publish --dry-run`, carefully review any warnings or errors in the output and take action:

### Common dry run warnings and fixes

| Warning | Cause | Fix |
|---------|-------|-----|
| "checked-in files are modified in git" | Uncommitted changes | Commit changes: `git add . && git commit -m "Prepare for publishing"` |
| "checked-in files are ignored by .gitignore" | Files tracked by git but also ignored | Use `.pubignore` to exclude, or remove from git: `git rm --cached path/to/file` |
| "Rename the top-level 'docs' directory to 'doc'" | Wrong directory naming | Rename: `mv docs doc` |
| "Rename the top-level 'example' directory to 'example'" | Expected singular | Rename directory to `example/` (singular) |
| "Package has X warnings" | Validation issues | Review each warning and fix accordingly |
| "Version X.Y.Z already exists" | Version already published | Increment version in pubspec.yaml |
| "Package validation found the following issues" | Various | Address each issue listed |

### Workflow for reviewing dry run results:

1. **Run the dry run**: `dart pub publish --dry-run`
2. **Read the output**: Look for "Package validation found" section
3. **Identify issues**: Note each warning/error message
4. **Apply fixes**: Use the table above to resolve each issue
5. **Re-run dry run**: Confirm all issues are resolved
6. **Ask to publish**: Once all errors cleared, ask user if they want to publish:

```
✅ All dry run issues resolved! The package is ready for publishing.

Would you like me to publish now? (Run `dart pub publish --force`)
```

### If errors remain

If the dry run shows errors (not just warnings), do not proceed to publishing. Fix each error and re-run until dry run passes with no errors.

Only move to Step 9 when dry run shows no errors.

**Step 9: Publish to pub.dev**

When ready:

```bash
## non interactive publish
dart pub publish --force
```

The first time, this prompts for Google Account authentication.

## Common issues and fixes

### Missing LICENSE

**Issue:** No LICENSE file found

**Fix:** Create LICENSE file:
```
Copyright (c) 2025 Your Name

Redistribution and use in source and binary forms...
```

For BSD 3-clause, see [opensou rce.org](https://opensource.org/licenses/BSD-3-Clause).

### Incomplete README

**Issue:** README missing sections

**Fix:** Add standard sections:
```markdown
# package_name

Brief description.

## Installation

```yaml
dependencies:
  package_name: ^1.0.0
```

## Usage

```dart
import 'package:package_name/package_name.dart';
```

## License

MIT
```

### Missing topics

**Issue:** No topics in pubspec

**Fix:** Add relevant topics:
```yaml
topics:
  - networking
  - http
```

Choose topics that describe your package's purpose, not implementation details.

### No funding links

**Issue:** No funding field

**Fix:** Add support links:
```yaml
funding:
  - https://github.com/sponsors/yourusername
```

### Platform compatibility warnings

**Issue:** Package not compatible with all platforms

**Fix:** Specify supported platforms explicitly:
```yaml
platforms:
  android:
  ios:
  web:
```

Or use conditional imports for platform-specific code.

### Package too large

**Issue:** Package exceeds size limits

**Fix:** Add `.pubignore` to exclude large files:
```
example/assets/
test/fixtures/large_files/
*.png
*.jpg
```

### Version already published

**Issue:** "Version X.Y.Z of package_name already exists" error when publishing

**Fix:** Increment the version in pubspec.yaml:

```yaml
# Before
version: 1.0.0

# After (patch update - bug fixes)
version: 1.0.1

# After (minor update - new features, backward compatible)
version: 1.1.0

# After (major update - breaking changes)
version: 2.0.0
```

**Version increment guidelines:**
- **Patch** (1.0.0 → 1.0.1): Bug fixes, minor improvements
- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
- **Major** (1.0.0 → 2.0.0): Breaking changes

**Check current published version:**
```bash
# View on pub.dev
open https://pub.dev/packages/YOUR_PACKAGE_NAME
```

### CHANGELOG not updated

**Issue:** Version in pubspec.yaml doesn't match CHANGELOG.md

**Fix:** Add version entry to CHANGELOG.md:

```markdown
## [1.0.1] - 2025-01-08
### Fixed
- Bug in feature X

## [1.0.0] - 2025-01-01
### Added
- Initial release
```

Ensure the version number in CHANGELOG matches pubspec.yaml exactly.

## Examples

### Example 1: Complete pubspec.yaml

```yaml
name: http_client
version: 2.1.0
description: A type-safe HTTP client with automatic retry and caching.
homepage: https://github.com/example/http_client
repository: https://github.com/example/http_client
issue_tracker: https://github.com/example/http_client/issues
documentation: https://http_client.dev
funding:
  - https://github.com/sponsors/example
  - https://buymeacoffee.com/example
topics:
  - http
  - client
  - networking
  - api
  - rest

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  meta: ^1.9.0

dev_dependencies:
  test: ^1.24.0
  lints: ^3.0.0

executables:
  http_client:
```

### Example 2: Flutter package with screenshots

```yaml
name: awesome_widget
version: 1.0.0
description: A beautiful widget for displaying user profiles.
repository: https://github.com/example/awesome_widget
topics:
  - widget
  - ui
  - profile
  - user-interface
screenshots:
  - description: 'Profile widget in light mode'
    path: screenshots/light_mode.png
  - description: 'Profile widget in dark mode'
    path: screenshots/dark_mode.png

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
```

### Example 3: Publishing prerelease

For beta testing or active development:

```yaml
version: 2.0.0-dev.1
```

Prereleases don't affect stable version users. Use suffixes like:
- `-dev.1`, `-dev.2` (development)
- `-beta.1`, `-beta.2` (beta testing)
- `-rc.1`, `-rc.2` (release candidate)

### Example 4: Verified publisher

After creating a verified publisher at pub.dev:

1. Go to package admin page
2. Click "Transfer to Publisher"
3. Enter publisher domain

Advantages:
- Shows verified badge
- Hides personal email
- Team can publish updates

## Automated checks

Run the readiness check script:

```bash
bash scripts/check_readiness.sh
```

This verifies:
- Required files exist
- Pubspec has required fields
- Version differs from published version on pub.dev
- CHANGELOG.md contains current version
- Package size is acceptable
- Static analysis passes

## Reference

- [Publishing packages](https://dart.dev/tools/pub/publishing)
- [Pubspec format](https://dart.dev/tools/pub/pubspec)
- [Package layout conventions](https://dart.dev/tools/pub/package-layout)
- [Writing package pages](https://dart.dev/tools/pub/writing-package-pages)
