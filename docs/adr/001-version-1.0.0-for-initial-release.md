# ADR-001: Version 1.0.0 for Initial Public Release

**Status:** Accepted
**Date:** 2025-01-24

## Context

`gday-cli` was extracted from a dot-rot script, versioned at 3.11.0. What version number should we use for this new implementation and standalone public release?

## Considerations
- Major upgrade, e.g.`4.0.0`: Would imply 3 previous major versions of this CLI, but
dot-rot was a different codebase.
- Alpha version, e.g.`0.1.0`: Suggests alpha/experimental, but gday is more mature than that
- Keep `3.11.0`: Misleading since this is a new repo/product
- Re-start numbering at `1.0.0` because this is effectively a new product.

## Decision

Release as version `1.0.0`.

## Rationale

- First public release of standalone product
- Feature-complete and production-ready
- 1.0.0 signals stable public API per semver
- Previous version history belongs to dot-rot, not this CLI
