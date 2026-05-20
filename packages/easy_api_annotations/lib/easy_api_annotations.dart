/// Canonical entry point for the `easy_api_annotations` package.
///
/// Re-exports all annotations and types from `mcp_annotations.dart` so that
/// consumers can follow the standard convention of importing
/// `package:easy_api_annotations/easy_api_annotations.dart`.
///
/// The legacy import `package:easy_api_annotations/mcp_annotations.dart`
/// continues to work for backward compatibility.
library;

export 'mcp_annotations.dart';
export 'prompt_types.dart';
