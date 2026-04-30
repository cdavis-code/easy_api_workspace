// Re-export build types from package:build
// These make the generator compile during development
// When build_runner runs, the real packages are available

export 'package:build/build.dart'
    show Builder, BuilderOptions, BuildStep, AssetId;
