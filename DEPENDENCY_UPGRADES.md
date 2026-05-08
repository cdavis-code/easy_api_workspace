# Dependency Upgrade Reminders

## analyzer ^12.1.0 → ^13.0.0

**Status:** Scheduled
**Deadline:** Before June 7, 2026 (30-day pana grace period)
**Packages affected:**
- `packages/easy_api_annotations/pubspec.yaml`
- `packages/easy_api_generator/pubspec.yaml`

**Reason:** Pana reports that `analyzer ^12.1.0` does not support stable version `13.0.0` (published ~May 2026). After 30 days from publication, this will deduct points from the "Support up-to-date dependencies" score.

**Upgrade steps:**
1. Update both pubspec.yaml files: `analyzer: ^12.1.0` → `analyzer: ^13.0.0`
2. Run `melos bootstrap`
3. Run `melos run analyze` — verify no breaking API changes
4. Run `melos run test` — verify functionality
5. If breaking changes exist, update generator code to use new analyzer APIs
6. Commit and push

**Notes:** Major version bumps of `analyzer` often introduce breaking API changes in the AST/element APIs. Review the [analyzer changelog](https://pub.dev/packages/analyzer/changelog) before upgrading.
