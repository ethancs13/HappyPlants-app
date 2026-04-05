# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

HappyPlants is a Flutter application. The project is in early setup — Flutter source files have not yet been committed.

## Common Commands

```bash
# Run the app (debug mode)
flutter run

# Run on a specific device
flutter run -d <device-id>

# Build APK (Android)
flutter build apk

# Build App Bundle (Android release)
flutter build appbundle

# Build iOS
flutter build ios

# Run all tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart

# Lint / analyze
flutter analyze

# Format code
dart format lib/

# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Generate code (if build_runner is used)
dart run build_runner build --delete-conflicting-outputs
```

## Architecture

_To be documented once source files are added. Update this section with:_
- State management approach (e.g., Riverpod, Bloc, Provider)
- Navigation strategy (e.g., GoRouter, Navigator 2.0)
- Folder structure under `lib/` (features, shared, core, etc.)
- Key dependencies from `pubspec.yaml`
- Data layer / API integration patterns
