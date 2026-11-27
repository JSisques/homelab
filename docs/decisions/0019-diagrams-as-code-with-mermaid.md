# ADR-0019: Diagrams as code with Mermaid

- **Status:** Accepted
- **Date:** 2026-11-27

## Decision

Architecture diagrams are written in **Mermaid**, inside the Markdown documents they illustrate. No image files or external diagram tools.

## Context

The owner wants diagrams for the architecture, and everything in this repository is documented and reviewed through Git.

## Reasoning

| Option | Problem |
|--------|---------|
| Exported images (PNG, SVG) | A change cannot be reviewed line by line, and the image drifts from the source it was drawn from |
| draw.io files | Verbose XML; the diff is unreadable in a pull request |
| PlantUML | GitHub does not render it in Markdown without extra tooling |
| **Mermaid** | Plain text, rendered natively by GitHub, reviewed in the pull request like any other line |

## Consequences

- Diagrams stay as simple as Mermaid allows. That is acceptable for architecture overviews.
- A diagram that no longer matches the design is a documentation bug, under the same policy as text ([documentation policy](../README.md#documentation-policy)).
