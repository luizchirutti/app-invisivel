# Quality Check Pipeline

Use this script to run analysis and all test layers in sequence.

## Run from project root

PowerShell:

./scripts/quality_check.ps1

## Optional flag

Skip dependency restore if you already ran pub get:

./scripts/quality_check.ps1 -SkipPubGet

## What it runs

1. flutter --version
2. flutter pub get
3. flutter analyze
4. flutter test test/domain/usecases
5. flutter test test/data/repositories
6. flutter test test/services/platform
7. flutter test test/presentation/bloc
8. flutter test test/presentation/widgets
9. flutter test test/presentation/pages
10. flutter test

## If Flutter is missing

The script fails fast and prints guidance.

Quick check:

where.exe flutter
