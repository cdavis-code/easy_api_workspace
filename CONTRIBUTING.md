# Contributing to Easy API

Thanks for your interest in contributing! This document describes how to set up
your environment, the expected workflow, and the standards your change should
meet before it can be merged.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Ways to Contribute](#ways-to-contribute)
- [Project Layout](#project-layout)
- [Local Setup](#local-setup)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Commit & Pull Request Guidelines](#commit--pull-request-guidelines)
- [Release Process](#release-process)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

Be respectful, constructive, and inclusive. Harassment or exclusionary behavior
will not be tolerated in issues, pull requests, or any other project space.

## Ways to Contribute

- Report bugs or request features via [GitHub Issues](https://github.com/cdavis-code/easy_api_workplace/issues)
- Improve documentation (README, CHANGELOG, DartDoc comments, skills)
- Add tests or improve existing coverage
- Fix bugs or implement features listed in open issues
- Suggest new annotations, transports, or generator capabilities

If you plan a large change, please open an issue first so we can align on scope
and design before you invest time in a pull request.

## Project Layout

This repo is a Melos-managed monorepo:

```text
packages/
├── easy_api_annotations/   # Annotation definitions (@Server, @Tool, @Parameter)
└── easy_api_generator/     # build_runner generator producing MCP / OpenAPI output
example/                    # Runnable sample that exercises the generator
```

See [AGENTS.md](AGENTS.md) for a deeper breakdown of the package contents.

## Local Setup

### Prerequisites

- Dart SDK **^3.11.0**
- [Melos](https://melos.invertase.dev/) for workspace management
  ```bash
  dart pub global activate melos
  ```
- Node.js (only required if you are working on Code Mode features)

### Bootstrap

```bash
git clone https://github.com/cdavis-code/easy_api_workplace.git
cd easy_api_workplace
melos bootstrap
```

`melos bootstrap` installs dependencies and links the workspace packages so
`example/` picks up your local changes in `packages/`.

## Development Workflow

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feat/<short-description>
   ```
2. Make your changes inside `packages/easy_api_annotations/`,
   `packages/easy_api_generator/`, or `example/`.
3. Regenerate code when generator or annotation changes affect the example:
   ```bash
   cd example
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Run the full verification suite before opening a PR:
   ```bash
   melos run format
   melos run analyze
   melos run test
   ```
5. If you touched shared dependencies (e.g. `analyzer`), also run:
   ```bash
   melos run deps:check
   melos run pana
   ```

## Coding Standards

- Follow standard Dart conventions; `dart format` must pass.
- Use PascalCase for annotation classes: `@Server`, `@Tool`, `@Parameter`.
- Prefer `peek()` over `read()` for optional annotation fields in the generator.
- Always escape backslashes and dollar signs in generated string literals.
- Add DartDoc comments to every public API.
- Do not expose internal error details in generated code — use generic messages
  like `"An error occurred while processing the request"`.

Refer to [AGENTS.md](AGENTS.md) for the full style guide used by both humans
and AI agents working on this repo.

## Testing

- Unit tests live next to the code they exercise, under each package's `test/`
  folder.
- Generator changes must include at least one test covering the new output
  shape.
- Run tests with:
  ```bash
  melos run test
  ```
- When changing the example's annotations, verify the generated artifacts
  (`example.mcp.dart`, `example.mcp.json`, `example.openapi.json`) still match
  expectations and include the regenerated files in your commit.

## Documentation

- Update the root [`README.md`](README.md) when user-facing behavior, flags, or
  annotations change.
- Update [`CHANGELOG.md`](CHANGELOG.md) with a short entry under the upcoming
  version for every user-visible change.
- Keep DartDoc comments accurate — they feed the annotation docs and help AI
  agents consume the skills.

## Commit & Pull Request Guidelines

**Commit messages**

- Use imperative mood: "Add HTTP transport test", not "Added" or "Adds".
- Keep the subject line ≤72 characters; add a blank line and a longer body if
  context is useful.
- Reference issues with `Fixes #123` or `Refs #123` when applicable.

**Pull requests**

- Target the `main` branch.
- Include a clear description of what changed and why.
- Link any related issues.
- Confirm the verification checklist in the PR description:
  - [ ] `melos run format`
  - [ ] `melos run analyze`
  - [ ] `melos run test`
  - [ ] Updated `CHANGELOG.md` (if user-visible)
  - [ ] Updated `README.md` / DartDoc (if behavior changed)
- Keep PRs focused; split unrelated changes into separate PRs.

## Release Process

Releases are cut by maintainers. The high-level checklist is:

1. Bump the version in **both** `packages/*/pubspec.yaml` files together.
2. Update `CHANGELOG.md` with the new version entry.
3. Run `melos run deps:check`, `dart analyze`, `melos run pana`, and
   `dart pub publish --dry-run`.
4. Commit, tag, and publish both packages with `dart pub publish --force`.
5. Push the tag to GitHub.

See the **Publishing Checklist** and **Shared Dependency Strategy** sections
in [AGENTS.md](AGENTS.md) for the detailed policy.

## Reporting Issues

When filing a bug, please include:

- Dart SDK version (`dart --version`)
- `easy_api_annotations` and `easy_api_generator` versions
- A minimal reproduction (annotated Dart source + generated output if relevant)
- Expected vs actual behavior
- Any build_runner or analyzer errors printed to the console

Thanks again for helping make Easy API better!
