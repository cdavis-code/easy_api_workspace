/// Minimal stubs used when the real `meta` and `super_annotations`
/// packages are not yet available.
///
/// These stubs provide just enough types for the annotation library to
/// compile without requiring external dependencies. They are not intended
/// for production use.
library;

/// Marker annotation indicating a class is immutable.
///
/// This is a stub implementation that does nothing at runtime.
/// It exists for compatibility with code that expects the `meta` package.
class Immutable {
  /// Creates an immutable marker annotation.
  const Immutable();
}

/// Abstract base class for class-level annotations.
///
/// This stub mimics `ClassAnnotation` from `super_annotations`.
/// The real package provides richer functionality, but for compilation
/// we only need the `apply` method signature.
abstract class ClassAnnotation {
  /// Applies this annotation to a target class.
  ///
  /// [target] - The class being annotated.
  /// [output] - The builder used to generate output code.
  void apply(Object target, Object output);
}

/// Placeholder for a class description.
///
/// Used by [ClassAnnotation.apply] as a stand-in for actual class metadata.
class Class {}

/// Placeholder for a library builder.
///
/// Used by [ClassAnnotation.apply] as a stand-in for actual code generation
/// infrastructure.
class LibraryBuilder {}
