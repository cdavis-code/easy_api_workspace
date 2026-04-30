---
name: dart-flutter-code-review
description: Library-agnostic Flutter/Dart code review checklist covering Widget best practices, state management patterns (BLoC, Riverpod, Provider, GetX, MobX, Signals), Dart idioms, performance, accessibility, security, and clean architecture.
---

# Flutter/Dart Code Review Best Practices

A comprehensive, library-agnostic checklist for reviewing Flutter/Dart applications. These principles apply regardless of which state management solution, routing library, or dependency injection framework is used.

***

## 1. General Project Health

* [ ] Project follows a consistent folder structure (feature-first or layer-first)
* [ ] Proper separation of concerns: UI, business logic, data layer
* [ ] No business logic in widgets; widgets are purely presentational
* [ ] `pubspec.yaml` is clean — no unused dependencies, versions properly pinned
* [ ] `analysis_options.yaml` contains a strict lint rule set with strict analyzer settings enabled
* [ ] No `print()` statements in production code — use `dart:developer` `log()` or logging packages
* [ ] Generated files (`.g.dart`, `.freezed.dart`, `.gr.dart`) are up-to-date or in `.gitignore`
* [ ] Platform-specific code is isolated through abstractions

***

## 2. Dart Language Pitfalls

* [ ] **Implicit dynamic types**: Missing type annotations resulting in `dynamic` — enable `strict-casts`, `strict-inference`, `strict-raw-types`
* [ ] **Null safety misuse**: Overuse of `!` (bang operator) instead of proper null checks or Dart 3 pattern matching (`if (value case var v?)`)
* [ ] **Type promotion failures**: Using `this.field` where local variable type promotion would work
* [ ] **Overly broad catches**: `catch (e)` without `on` clause; should always specify exception type
* [ ] **Catching `Error`**: `Error` subtypes indicate bugs and should not be caught
* [ ] **Unused `async`**: Functions marked `async` but never `await` — unnecessary overhead
* [ ] **`late` overuse**: Using `late` where nullable types or constructor initialization would be safer; defers errors to runtime
* [ ] **String concatenation in loops**: Use `StringBuffer` instead of `+` for iterative string building
* [ ] **Mutable state in `const` contexts**: Fields in `const` constructor classes should not be mutable
* [ ] **Ignored `Future` return values**: Use `await` or explicitly call `unawaited()` to indicate intent
* [ ] **Using `var` where `final` is available**: Prefer `final` for local variables, `const` for compile-time constants
* [ ] **Relative imports**: Use `package:` imports for consistency
* [ ] **Exposing mutable collections**: Public APIs should return unmodifiable views, not raw `List`/`Map`
* [ ] **Missing Dart 3 pattern matching**: Prefer switch expressions and `if-case` over verbose `is` checks and manual type casting
* [ ] **Using one-off classes for multiple return values**: Use Dart 3 records `(String, int)` instead of one-off DTOs
* [ ] **`print()` in production code**: Use `dart:developer` `log()` or project's logging package; `print()` has no log level and cannot be filtered

***

## 3. Widget Best Practices

### Widget Decomposition:

* [ ] No single widget's `build()` method exceeds about 80-100 lines
* [ ] Widgets are split by encapsulation and by way of change (rebuild boundaries)
* [ ] Private `_build*()` helper methods that return widgets are extracted into separate widget classes (supports element reuse, constant propagation, and framework optimizations)
* [ ] Prefer stateless widgets over stateful widgets where mutable local state is not needed
* [ ] Extracted widgets are placed in separate files when reusable

### Const Usage:

* [ ] Use `const` constructors whenever possible — prevents unnecessary rebuilds
* [ ] Use `const` literals for unchanging collections (`const []`, `const {}`)
* [ ] Declare constructors as `const` when all fields are final

### Key Usage:

* [ ] Use `ValueKey` in lists/grids to maintain state during reordering
* [ ] Use `GlobalKey` sparingly — only when truly needed to access state across the tree
* [ ] Avoid `UniqueKey` in `build()` — forces rebuild every frame
* [ ] Use `ObjectKey` when identity is based on data objects rather than single values

### Theming and Design Systems:

* [ ] Colors come from `Theme.of(context).colorScheme` — no hardcoded `Colors.red` or hex values
* [ ] Text styles come from `Theme.of(context).textTheme` — no inline `TextStyle` and raw font sizes
* [ ] Dark mode compatibility verified — don't assume light backgrounds
* [ ] Spacing and sizing use consistent design tokens or constants, not magic numbers

### Build Method Complexity:

* [ ] No network calls, file I/O, or heavy computations in `build()`
* [ ] No `Future.then()` or `async` work in `build()`
* [ ] No creating subscriptions (`.listen()`) in `build()`
* [ ] `setState()` localized to smallest possible subtree

***

## 4. State Management (Library-Agnostic)

These principles apply to all Flutter state management solutions (BLoC, Riverpod, Provider, GetX, MobX, Signals, ValueNotifier, etc.).

### Architecture:

* [ ] Business logic is located outside the widget layer — in state management components (BLoC, Notifier, Controller, Store, ViewModel, etc.)
* [ ] State managers receive dependencies through dependency injection, not constructed internally
* [ ] Service or repository layer abstracts data sources — widgets and state managers should not directly call APIs or databases
* [ ] State managers have a single responsibility — no "god" managers handling unrelated responsibilities
* [ ] Cross-component dependencies follow the solution's conventions:
  * In **Riverpod**: Providers depending on other providers via `ref.watch` is expected — only flag circular or overly complex chains
  * In **BLoC**: BLoCs should not directly depend on other BLoCs — prefer shared repositories or presentation layer coordination
  * In other solutions: Follow documentation conventions for inter-component communication

### Immutability and Value Equality (for immutable state solutions: BLoC, Riverpod, Redux):

* [ ] State objects are immutable — create new instances via `copyWith()` or constructors, never modify in place
* [ ] State classes properly implement `==` and `hashCode` (all fields included in comparison)
* [ ] Mechanism is consistent throughout the project — manual overrides, `Equatable`, `freezed`, Dart records, or other approaches
* [ ] Collections inside state objects are not exposed as raw mutable `List`/`Map`

### Reactive Discipline (for reactive mutation solutions: MobX, GetX, Signals):

* [ ] State is only modified through the solution's reactive API (`@action` in MobX, `.value` in Signals, `.obs` in GetX) — direct field modification bypasses change tracking
* [ ] Derived values use the solution's computed mechanism, not stored redundantly
* [ ] Reactions and disposers are properly cleaned up (`ReactionDisposer` in MobX, effect cleanup in Signals)

### State Shape Design:

* [ ] Mutually exclusive states use sealed types, union variants, or solution's built-in async state types (e.g., Riverpod's `AsyncValue`) — not boolean soup (`isLoading`, `isError`, `hasData`)
* [ ] Each async operation models loading, success, and error as distinct states
* [ ] UI exhaustively handles all state variants — no silently ignored cases
* [ ] Error states carry error information for display; loading states don't carry stale data
* [ ] Nullable data is not used as loading indicator — state is explicit

```dart
// BAD — boolean flag soup allows impossible states
class UserState {
  bool isLoading = false;
  bool hasError = false; // isLoading && hasError is representable!
  User? user;
}

// GOOD (immutable approach) — sealed types make impossible states unrepresentable
sealed class UserState {}
class UserInitial extends UserState {}
class UserLoading extends UserState {}
class UserLoaded extends UserState {
  final User user;
  const UserLoaded(this.user);
}
class UserError extends UserState {
  final String message;
  const UserError(this.message);
}

// GOOD (reactive approach) — observable enum + data, mutations via reactivity API
// enum UserStatus { initial, loading, loaded, error }
// Use your solution's observable/signal to wrap status and data separately
```

### Rebuild Optimization:

* [ ] State consumer widgets (Builder, Consumer, Observer, Obx, Watch, etc.) are scoped as narrowly as possible
* [ ] Use selectors to rebuild only on specific field changes — not on every state emission
* [ ] Use `const` widgets to stop rebuild propagation in the tree
* [ ] Computed/derived state is reactively computed, not stored redundantly

### Subscriptions and Cleanup:

* [ ] All manual subscriptions (`.listen()`) are canceled in `dispose()` / `close()`
* [ ] Stream controllers are closed when no longer needed
* [ ] Timers are canceled in cleanup lifecycle
* [ ] Prefer framework-managed lifecycle over manual subscriptions (declarative builders over `.listen()`)
* [ ] Check `mounted` before `setState` in async callbacks
* [ ] Use `BuildContext` after `await` without checking `context.mounted` (Flutter 3.7+) — stale context leads to crashes
* [ ] No navigation, showing dialogs, or scaffold messages after async gaps without verifying widget is still mounted
* [ ] `BuildContext` is never stored in singletons, state managers, or static fields

### Local State vs Global State:

* [ ] Temporary UI state (checkboxes, sliders, animations) uses local state (`setState`, `ValueNotifier`)
* [ ] Shared state is only elevated to required height — not over-globalized
* [ ] State scoped to features is properly cleaned up when feature is no longer active

***

## 5. Performance

### Unnecessary Rebuilds:

* [ ] Don't call `setState()` at root widget level — localize state changes
* [ ] Use `const` widgets to stop rebuild propagation
* [ ] Use `RepaintBoundary` around complex subtrees that repaint independently
* [ ] Use `AnimatedBuilder`'s child parameter to handle subtrees independent of animation

### Expensive Operations in build():

* [ ] Don't sort, filter, or map large collections in `build()` — compute in state management layer
* [ ] Don't compile regular expressions in `build()`
* [ ] Use `MediaQuery.of(context)` specifically (e.g., `MediaQuery.sizeOf(context)`)

### Image Optimization:

* [ ] Network images use caching (any caching solution suitable for the project)
* [ ] Use appropriate image resolution for target device (don't load 4K images for thumbnails)
* [ ] Use `Image.asset` with `cacheWidth`/`cacheHeight` to decode at display size
* [ ] Provide placeholder and error widgets for network images

### Lazy Loading:

* [ ] Use `ListView.builder` / `GridView.builder` for large or dynamic lists instead of `ListView(children: [...])` (constructors are fine for small, static lists)
* [ ] Implement pagination for large datasets
* [ ] Use deferred loading (`deferred as`) for heavy libraries in web builds

### Other:

* [ ] Avoid using `Opacity` widget in animations — use `AnimatedOpacity` or `FadeTransition`
* [ ] Avoid clipping in animations — pre-clip images
* [ ] Don't override `operator ==` on widgets — use `const` constructors instead
* [ ] Use intrinsic size widgets (`IntrinsicHeight`, `IntrinsicWidth`) sparingly (additional layout passes)

***

## 6. Testing

### Test Types and Expectations:

* [ ] **Unit tests**: Cover all business logic (state managers, repositories, utility functions)
* [ ] **Widget tests**: Cover individual widget behavior, interactions, and visual output
* [ ] **Integration tests**: End-to-end coverage of critical user flows
* [ ] **Golden tests**: Pixel-perfect comparison for design-critical UI components

### Coverage Targets:

* [ ] Target 80%+ line coverage for business logic
* [ ] All state transitions have corresponding tests (loading → success, loading → error, retry, etc.)
* [ ] Test edge cases: empty states, error states, loading states, boundary values

### Test Isolation:

* [ ] External dependencies (API clients, databases, services) are mocked or faked
* [ ] Each test file tests only one class/unit
* [ ] Tests verify behavior, not implementation details
* [ ] Stubs define only behavior needed for each test (minimal stubbing)
* [ ] No shared mutable state between test cases

### Widget Test Quality:

* [ ] `pumpWidget` and `pump` are used correctly for async operations
* [ ] `find.byType`, `find.text`, `find.byKey` are used properly
* [ ] No flaky tests dependent on timing — use `pumpAndSettle` or explicit `pump(Duration)`
* [ ] Tests run in CI, failures block merges

***

## 7. Accessibility

### Semantic Widgets:

* [ ] Use `Semantics` widget to provide screen reader labels where automatic labels are insufficient
* [ ] Use `ExcludeSemantics` for purely decorative elements
* [ ] Use `MergeSemantics` to group related widgets into single accessible element
* [ ] Images have `semanticLabel` property set

### Screen Reader Support:

* [ ] All interactive elements are focusable and have meaningful descriptions
* [ ] Focus order is logical (follows visual reading order)

### Visual Accessibility:

* [ ] Text contrast with background >= 4.5:1
* [ ] Clickable targets are at least 48x48 pixels
* [ ] Color is not the only indicator of state (use icons/text as well)
* [ ] Text scales with system font size settings

### Interaction Accessibility:

* [ ] No no-op `onPressed` callbacks — every button has an action or is disabled
* [ ] Error fields suggest corrections
* [ ] Context doesn't change accidentally while user is entering data

***

## 8. Platform-Specific Considerations

### iOS/Android Differences:

* [ ] Use platform-adaptive widgets where appropriate
* [ ] Back navigation handled correctly (Android back button, iOS swipe back)
* [ ] Handle status bars and safe areas via `SafeArea` widget
* [ ] Platform-specific permissions declared in `AndroidManifest.xml` and `Info.plist`

### Responsive Design:

* [ ] Use `LayoutBuilder` or `MediaQuery` for responsive layouts
* [ ] Breakpoints defined consistently (phone, tablet, desktop)
* [ ] Text doesn't overflow on small screens — use `Flexible`, `Expanded`, `FittedBox`
* [ ] Tested landscape orientation or explicitly locked
* [ ] Web-specific: Support mouse/keyboard interaction, hover states exist

***

## 9. Security

### Secure Storage:

* [ ] Sensitive data (tokens, credentials) stored using platform secure storage (Keychain on iOS, EncryptedSharedPreferences on Android)
* [ ] Never store secrets in plain text
* [ ] Consider biometric authentication gating for sensitive operations

### API Key Handling:

* [ ] API keys NOT hardcoded in Dart source code — use `--dart-define`, `.env` files excluded from VCS, or compile-time configuration
* [ ] Secrets not committed to git — check `.gitignore`
* [ ] Use backend proxy for truly secret keys (client should not hold server secrets)

### Input Validation:

* [ ] All user input validated before sending to API
* [ ] Form validation uses appropriate validation patterns
* [ ] No raw SQL or user-input string interpolation
* [ ] Deep link URLs validated and sanitized before navigation

### Network Security:

* [ ] Enforce HTTPS for all API calls
* [ ] Consider certificate pinning for high-security apps
* [ ] Authentication tokens properly refreshed and expired
* [ ] No logging or printing sensitive data

***

## 10. Package/Dependency Review

### Evaluating pub.dev Packages:

* [ ] Check **pub score** (target 130+/160)
* [ ] Check **likes** and **popularity** as community signals
* [ ] Verify publisher is **verified** on pub.dev
* [ ] Check last publish date — outdated packages (>1 year) are risky
* [ ] Review maintainer's open issues and response time
* [ ] Check license compatibility with project
* [ ] Verify platform support covers your targets

### Version Constraints:

* [ ] Use caret syntax for dependencies (`^1.2.3`) — allows compatible updates
* [ ] Pin exact versions only when absolutely necessary
* [ ] Regularly run `flutter pub outdated` to track outdated dependencies
* [ ] No dependency overrides in production `pubspec.yaml` — only for temporary fixes with comments/issue links
* [ ] Minimize number of transitive dependencies — each is an attack surface

### Monorepo-Specific (melos/workspace):

* [ ] Internal packages import only from public API — no `package:other/src/internal.dart` (breaks Dart package encapsulation)
* [ ] Internal package dependencies use workspace resolution, not hardcoded `path: ../../` relative strings
* [ ] All sub-packages share or inherit root `analysis_options.yaml`

***

## 11. Navigation and Routing

### General Principles (applies to any routing solution):

* [ ] Consistent use of one routing approach — don't mix imperative `Navigator.push` and declarative routers
* [ ] Route parameters are typed — no `Map<String, dynamic>` or `Object?` casting
* [ ] Route paths defined as constants, enums, or generated — no magic strings scattered in code
* [ ] Authentication guards/redirects centralized — not duplicated in individual screens
* [ ] Deep linking configured for both Android and iOS
* [ ] Deep link URLs validated and sanitized before navigation
* [ ] Navigation state is testable — route changes can be verified in tests
* [ ] Back behavior works correctly on all platforms

***

## 12. Error Handling

### Framework Error Handling:

* [ ] Override `FlutterError.onError` to catch framework errors (build, layout, paint)
* [ ] Set up `PlatformDispatcher.instance.onError` to handle Flutter's uncaught async errors
* [ ] Customize `ErrorWidget.builder` for release mode (user-friendly rather than red screen)
* [ ] Use global error catch wrapper around `runApp` (e.g., `runZonedGuarded`, Sentry/Crashlytics wrapper)

### Error Reporting:

* [ ] Integrated error reporting service (Firebase Crashlytics, Sentry, or equivalent)
* [ ] Report non-fatal errors with stack traces
* [ ] State management error observers connected to error reporting (e.g., BlocObserver, ProviderObserver, or equivalent for your solution)
* [ ] User-identifiable information (user ID) attached to error reports for debugging

### Graceful Degradation:

* [ ] API errors result in user-friendly error UI, not crashes
* [ ] Retry mechanisms for transient network failures
* [ ] Handle offline state gracefully
* [ ] Error states in state management carry error information for display
* [ ] Raw exceptions (network, parsing) are mapped to user-friendly localized messages before reaching UI — never show raw exception strings to users

***

## 13. Internationalization (l10n)

### Setup:

* [ ] Localization solution configured (Flutter's built-in ARB/l10n, easy_localization, or equivalent)
* [ ] Supported locales declared in app configuration

### Content:

* [ ] All user-visible strings use localization system — no hardcoded strings in widgets
* [ ] Template files include descriptions/context for translators
* [ ] Use ICU message syntax for plurals, gender, select
* [ ] Use typed placeholders
* [ ] No missing keys across locales

### Code Review:

* [ ] Consistent use of localization accessors throughout project
* [ ] Date, time, number, and currency formatting is locale-aware
* [ ] Support for text directionality (RTL) if targeting Arabic, Hebrew, etc.
* [ ] No string concatenation in localized text — use parameterized messages

***

## 14. Dependency Injection

### Principles (applies to any DI approach):

* [ ] Classes depend on abstractions (interfaces) at layer boundaries, not concrete implementations
* [ ] Dependencies provided externally via constructors, DI framework, or provider graph — not created internally
* [ ] Registration distinguishes lifecycle: singleton vs factory vs lazy singleton
* [ ] Environment-specific bindings (dev/staging/prod) use configuration, not runtime `if` checks
* [ ] No circular dependencies in DI graph
* [ ] Service locator calls (if used) are not scattered in business logic

***

## 15. Static Analysis

### Configuration:

* [ ] `analysis_options.yaml` exists with strict settings enabled
* [ ] Strict analyzer settings: `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`
* [ ] Comprehensive lint rule set included (very_good_analysis, flutter_lints, or custom strict rules)
* [ ] All sub-packages in monorepo inherit or share root analysis options

### Enforcement:

* [ ] No unresolved analyzer warnings in submitted code
* [ ] Lint suppressions (`// ignore:`) have comments explaining rationale
* [ ] `flutter analyze` runs in CI, failures block merges

### Key Rules to Verify Regardless of Lint Package Used:

* [ ] `prefer_const_constructors` — performance in widget tree
* [ ] `avoid_print` — use proper logging
* [ ] `unawaited_futures` — prevent fire-and-forget async errors
* [ ] `prefer_final_locals` — variable-level immutability
* [ ] `always_declare_return_types` — explicit contracts
* [ ] `avoid_catches_without_on_clauses` — concrete error handling
* [ ] `always_use_package_imports` — consistent import style

***

## State Management Quick Reference

This table maps general principles to implementations in popular solutions. Use this table to adapt review rules to whatever solution your project uses.

| Principle | BLoC/Cubit | Riverpod | Provider | GetX | MobX | Signals | Built-in |
|-----------|-----------|----------|----------|------|------|---------|----------|
| State Container | `Bloc`/`Cubit` | `Notifier`/`AsyncNotifier` | `ChangeNotifier` | `GetxController` | `Store` | `signal()` | `StatefulWidget` |
| UI Consumer | `BlocBuilder` | `ConsumerWidget` | `Consumer` | `Obx`/`GetBuilder` | `Observer` | `Watch` | `setState` |
| Selectors | `BlocSelector`/`buildWhen` | `ref.watch(p.select(...))` | `Selector` | N/A | computed | `computed()` | N/A |
| Side Effects | `BlocListener` | `ref.listen` | `Consumer` callbacks | `ever()`/`once()` | `reaction` | `effect()` | Callbacks |
| Disposal | Automatic via `BlocProvider` | `.autoDispose` | Automatic via `Provider` | `onClose()` | `ReactionDisposer` | Manual | `dispose()` |
| Testing | `blocTest()` | `ProviderContainer` | Direct `ChangeNotifier` | `Get.put` in tests | Direct store test | Direct signal test | Widget test |

***

## Sources

* [Effective Dart: Style](https://dart.dev/effective-dart/style)
* [Effective Dart: Usage](https://dart.dev/effective-dart/usage)
* [Effective Dart: Design](https://dart.dev/effective-dart/design)
* [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
* [Flutter Testing Overview](https://docs.flutter.dev/testing/overview)
* [Flutter Accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)
* [Flutter Internationalization](https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization)
* [Flutter Navigation and Routing](https://docs.flutter.dev/ui/navigation)
* [Flutter Error Handling](https://docs.flutter.dev/testing/errors)
* [Flutter State Management Options](https://docs.flutter.dev/data-and-backend/state-mgmt/options)
