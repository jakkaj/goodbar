# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.




## Mermaid Diagram Guidelines

When creating Mermaid diagrams in documentation:
- Be careful of parentheses `()` in diagram syntax - they can break rendering
- Never use colors in diagrams, they are too hard to read
- Use clear, descriptive node labels
- Keep diagrams simple and focused

## Required Reading

**CRITICAL**: Always read these files before working on the codebase:

- `docs/rules/rules-idioms-architecture.md` - Core architectural rules and layer separation principles, project patterns, testing strategies, and code quality standards


## Project Rules and Workflow

### Core Principles
- **Expert autonomous software engineer** - Implement planned tasks accurately and efficiently

- **Primary build tool**: `just` for builds, tests, linting, and automation
- **Scratch directory**: All temporary/experimental work goes in `scratch/` (not tracked by git)
- **File editing preference**: Use partial edits (Edit/MultiEdit) over complete rewrites
- **Architecture compliance**: Must follow `docs/rules/architecture.md` layer separation rules


### Task Planning Protocol
1. **Plan Structure**: Organize into numbered Phases, break into numeric tasks
2. **One plan file** per issue: `docs/plans/<numbered-plan-folder>/1-<thing>-plan.md`
3. **Task tables** with Status, Task, Success Criteria, Notes columns
4. **Success criteria** must be explicit and testable
5. **No assumptios** - plans must be explicit about all requirements
6. **TDD approach** - build test, implement code, verify tests pass

### File Modification Logging When Following Plans
When implementing a plan and modifying files, use footnotes to track changes:

1. **In the task row**: Add a brief note about what was modified
2. **In the Notes column**: Write a one-line summary followed by a footnote tag (e.g., `[^1]`)
3. **At the bottom of the plan**: Add the detailed footnote with substrate node IDs
4. **Always mark steps complete as you do them**: But only once the tests pass!

#### Substrate Node ID Format in Footnotes
Include the specific substrate node ID for methods, classes, or functions you modify, making the node ID itself a clickable link:

- **Method**: `[method:path/to/file.py:ClassName.method_name](../../../path/to/file.py#L123)`
- **Function**: `[function:path/to/file.py:function_name](../../../path/to/file.py#L123)`
- **Class**: `[class:path/to/file.py:ClassName](../../../path/to/file.py#L123)`
- **File**: `[file:path/to/file.py](../../../path/to/file.py)`

Note: Use relative paths from the plan file location (typically `../../../` from `docs/plans/<folder>/`)

Example footnotes with clickable node IDs:
```markdown
| 2.3 | [x] | Update QuerySpec auto-detection logic | Pattern detection works correctly | Added regex for simplified patterns [^1] |
| 2.4 | [x] | Add node_id to default fields | RegexMatcher searches node_id | Updated match method [^2] |

...

[^1]: Modified [`method:src/core/query/query_spec.py:QuerySpec._detect_method`](../../../src/core/query/query_spec.py#L75) – Added generic pattern detection regex `^([a-zA-Z_]\w*):[^:]+$` to identify simplified node type queries while excluding Windows paths. This enables future node types without code changes.

[^2]: Modified [`method:src/core/query/matchers.py:RegexMatcher.match`](../../../src/core/query/matchers.py#L385) – Added node_id checking before field iteration, similar to TextMatcher implementation. Also updated [`method:src/core/query/query_spec.py:QuerySpec.get_effective_fields`](../../../src/core/query/query_spec.py#L369) to include "node_id" in priority_order list.
```

Keep footnote numbers sequential and unique throughout the plan.

### Updating GitHub Issues When Following Plans
When implementing a plan and updating progress:

1. **DO NOT change the issue title** to include phase numbers or progress indicators
2. **DO add progress comments** using `gh issue comment` to document phase completion
3. **DO update the issue body** to reflect progress and adjustments as needed
4. **DO reference the branch** in your progress comments

Example progress comment:
```bash
gh issue comment 123 --body "## Phase 1 Completed ✅
Successfully implemented [phase description]...
Branch: \`issue-123-phase-1\`"
```

### GitHub Workflow
- **Branch naming**: `issue-<num>-phase-<phase>` off `main`
- **Conventional Commits** (Angular style) with issue references (`Fixes #123`)
- **Command prefix**: Use `PAGER=cat` before raw `git`/`gh` commands
- **PR workflow**: feature → `main`, clear description, squash-and-merge
- **Never commit/push** without asking user first

### Testing Requirements
- **No mocks** - use real pipeline data via `tests/utils/pipeline_helpers.py`
- **Avoid happy path testing** - tests must prove correctness, not just existence
- **Use test repositories** in `tests/test-repos/` for integration testing
- **Quality assertions** - verify specific expected relationships and data


### Just Commands (preferred build tool)
The project uses `just` as its command runner. Run `just --list` to see all available commands.


