# Use bash
set shell := ["bash", "-uc"]

# Default task
default:
  @just --list

# ---------- Bootstrap ----------
# Install project dependencies
get:
  flutter pub get

# ---------- Codegen ----------
# Run build_runner once
gen:
  dart run build_runner build --delete-conflicting-outputs

# Run build_runner in watch mode
gen-watch:
  dart run build_runner watch --delete-conflicting-outputs

# ---------- Quality ----------
# Format code
fmt:
  dart format .

# Run linter
lint:
  flutter analyze

# Fix linting issues
fix:
  dart fix --apply

# Run format and lint checks
check: fix fmt lint
  @echo "✓ format and analyze OK"

# ---------- Tests ----------
# Run all tests with coverage
test:
  flutter test --coverage

# Update golden test baselines
golden-update:
  flutter test --update-goldens

# ---------- Run / Build ----------
# Run app on macOS
run: gen
  flutter run -d macos

# Run app on macOS in profile mode
profile-macos:
  flutter run -d macos --profile

# Build macOS release
build-macos:
  flutter build macos --release

# ---------- Clean ----------
# Clean build artifacts
clean:
  flutter clean && rm -rf coverage/ .dart_tool/ build/

# ---------- Logs ----------
# Tail application logs
log-tail:
  tail -f "$HOME/Library/Logs/goodbar/app.log"

# ---------- Docs ----------
# Copy CLAUDE.md to AGENTS.md
agents-sync:
  mkdir -p .github
  cp CLAUDE.md AGENTS.md
  cp CLAUDE.md .github/copilot-instructions.md
  @echo "✓ AGENTS.md updated from CLAUDE.md"
  @echo "✓ .github/copilot-instructions.md updated from CLAUDE.md"
