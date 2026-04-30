---
name: dart-flutter-pana-review
description: Runs pana analysis on Dart packages, identifies scoring issues, and suggests fixes to achieve higher pub scores. Use when improving package quality, preparing for pub.dev publication, or when pana score issues are mentioned.
---

# Dart Package Review with Pana

## Prerequisites

Before running pana, ensure it's installed:

```bash
# Check if pana is installed
command -v pana
```

If not installed, run the installation script:

```bash
bash scripts/install_pana.sh
```

Or install manually:

```bash
dart pub global activate pana
```

## Quick start

Run pana on the current package:

```bash
pana .
```

## Important: Skip example packages

**Do NOT run pana on example packages.** Example packages (typically in `example/` directories) are demonstration code, not publishable packages. They often:
- Lack CHANGELOG.md, LICENSE, and other pub.dev requirements
- Use path dependencies to local packages
- Contain generated code that may have formatting differences
- Are binary-only packages without library APIs to document

Instead, only run pana on actual packages intended for publication (e.g., `packages/easy_mcp_annotations`, `packages/easy_mcp_generator`).

To identify example packages, look for:
- Directory names containing "example"
- pubspec.yaml with `publish_to: none`
- Path dependencies like `../packages/package_name`
- No `lib/` directory with public APIs

## Workflow

Copy this checklist and track your progress:

```
Package Review Progress:
- [ ] Step 1: Verify pana installation
- [ ] Step 2: Run pana analysis
- [ ] Step 3: Identify scoring issues
- [ ] Step 4: Categorize by severity
- [ ] Step 5: Suggest resolutions
- [ ] Step 6: Apply fixes (with user confirmation)
- [ ] Step 7: Verify improvements
```

**Step 1: Verify pana installation**

Check that pana is available. If not, use `scripts/install_pana.sh`.

**Step 1.5: Identify target packages**

Before running pana, identify which packages should be analyzed:
- ✅ Run pana on packages in `packages/` directory intended for pub.dev publication
- ❌ Skip example packages (see "Important: Skip example packages" section above)
- ❌ Skip test packages, demo packages, or packages with `publish_to: none`

**Step 2: Run pana analysis**

Execute `pana .` and review the output. The tool scores packages on:
- Dart file conventions (30 points)
- Documentation (20 points)
- Platform support (20 points)
- Static analysis (50 points)
- Dependencies (40 points)

**Step 3: Identify scoring issues**

Look for sections marked with ✗ or [~] (partial credit). Parse the output for:
- Critical: Missing files, invalid pubspec, analysis failures
- Warnings: Platform compatibility, documentation gaps
- Suggestions: Topics, examples, description improvements

**Step 4: Categorize by severity**

**Critical Issues** (must fix):
- Package score below 100
- Missing README, CHANGELOG, or LICENSE
- Invalid pubspec.yaml
- Failing static analysis

**Warnings** (should fix):
- Platform compatibility issues (especially WASM)
- Documentation coverage below 20%
- Outdated dependencies

**Suggestions** (nice to have):
- Add topics to pubspec
- Improve package description
- Add more examples

**Step 5: Suggest resolutions**

For each issue, provide:
1. Clear explanation of the problem
2. Specific fix recommendation
3. Example code or command if applicable

**Step 6: Apply fixes**

Ask user for confirmation before making changes. Present as:
```
Issue: [description]
Fix: [specific action]
Apply? (yes/no)
```

**Step 7: Verify improvements**

Re-run `pana .` and compare scores. Iterate if issues remain.

## Common issues and fixes

### Missing files

**README.md**: Create with standard structure (title, description, installation, usage, license)

**CHANGELOG.md**: Use Keep a Changelog format:
```markdown
# Changelog

## [Unreleased]

## [0.1.0] - 2025-01-01
### Added
- Initial release
```

**LICENSE**: Add MIT, BSD, or appropriate license file

### Platform compatibility

Common issues:
- **WASM incompatibility**: Usually caused by `dart:io` imports. Use conditional exports to provide platform-specific implementations.
- **Platform-specific APIs**: Abstract platform-specific code behind interfaces with conditional imports.

### Static analysis failures

Run `dart analyze` and fix all issues before re-running pana.

### Documentation coverage

Add dartdoc comments to public APIs:
```dart
/// Returns the user's display name.
/// 
/// Returns null if the user has not set a display name.
String? getDisplayName() { ... }
```

## Examples

### Example 1: WASM compatibility issue

**Pana output:**
```
## ✗ Platform support (10 / 20)
Package not compatible with runtime wasm

Because:
* `package:myapp/main.dart` that imports:
* `package:example_package/example_package.dart` that imports:
* `dart:io`
```

**Fix:**
Replace the problematic package with conditional exports:
```dart
// Create platform-specific implementations and export conditionally
export 'my_class_native.dart' 
    if (dart.library.js) 'my_class_web.dart';
```

### Example 2: Missing documentation

**Pana output:**
```
20% or more of the public API has dartdoc comments
45 out of 200 API elements (22.5%) have documentation comments
```

**Fix:**
Add documentation to undocumented elements:
```dart
// Before
class User {
  String? name;
  int? age;
}

// After
/// Represents a user in the system.
class User {
  /// The user's display name.
  String? name;
  
  /// The user's age in years.
  int? age;
}
```

### Example 3: Formatting issues

**Pana output:**
```
lib/main.dart doesn't match the Dart formatter
```

**Fix:**
```bash
dart format .
```

## Reference

- [Pana documentation](https://pub.dev/packages/pana)
- [Pub package requirements](https://pub.dev/help)
