# Sweep Script Template

The sweep script is the automated garbage collector for the harness. It catches drift, stale docs, and principle violations before they compound.

## Base Script

A ready-to-use sweep script is available at `../scripts/sweep.sh`. Copy it into the target project's `tools/` directory and adapt the marked `# ADAPT:` sections to the project's tech stack.

## Adapting to Other Ecosystems

### Node.js / TypeScript
- Lint: `npx eslint . --format compact`
- Golden principles: check for `any` type usage, missing error boundaries, untyped API responses
- Doc drift: check if modified API routes have corresponding OpenAPI spec updates

### Python
- Lint: `ruff check .` or `flake8 .`
- Golden principles: check for bare `except:`, missing type hints on public functions, raw SQL
- Doc drift: check if modified modules have corresponding docstrings

### Rust
- Lint: `cargo clippy -- -W warnings`
- Golden principles: check for `unwrap()` in non-test code, missing error types
- Doc drift: check if public API changes have doc comment updates

### Go
- Lint: `golangci-lint run`
- Golden principles: check for ignored errors (`_ = func()`), missing context propagation
- Doc drift: check if exported functions have godoc comments
