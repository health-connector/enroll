---
name: investigate
description: Debug and research issues by pulling context from ClickUp and the codebase. Accepts a ClickUp ticket, error message, or free text.
---

## Investigate

> **Codebase knowledge:** Consult `.claude/KNOWLEDGE.md` for dev environment quirks, known model
> behaviors, and common failure patterns before diving into the codebase.

A structured investigation workflow that gathers context from ClickUp and the codebase, then synthesizes findings into an actionable report.

### Configuration

- **ClickUp Base URL:** `https://app.clickup.com/t/`

### Step 0: Parse Input & Choose Mode

#### Classify `$ARGUMENTS`

Detect the input type using these rules (check in order):

| Pattern | Type | Example |
|---------|------|---------|
| Contains `clickup.com` | **ClickUp URL** | `https://app.clickup.com/t/12345xab/` |
| Contains `Error`, `Exception`, backtrace markers (`\.rb:\d+`, `in '`, `from /`) | **Stack trace / error** | `NoMethodError: undefined method 'foo'` |
| Any other non-empty text | **Free text** | `how does PIF application flow work` |
| Empty / no arguments | **No input** | — |

If no arguments were provided, ask the developer:
> "What would you like to investigate? You can provide:
> - A ClickUp task URL
> - An error message or stack trace
> - A question about the codebase"

#### Choose Investigation Mode

Ask the developer:
> "What type of investigation is this?
> 1. **Debug** — tracking down a production error _(default)_
> 2. **Understand** — learning how a feature/system works
> 3. **Research** — gathering context before creating a ticket or planning a fix"

If the developer doesn't choose, default to **Debug**.

### Step 1: Parallel Context Gathering (Read-Only)

**CRITICAL: This step is read-only. Never write to any external system during gathering.**

Launch parallel searches based on the input type and investigation mode. Use the Agent tool to run independent searches concurrently.

#### 1a. ClickUp Context

**When:** ClickUp URL or task ID given, OR always search for related tasks.

- Fetch the task if URL/ID given (include description, comments, linked tasks)
- Search for related tasks by error message keywords or component/area if identifiable

Extract from ClickUp results:
- Task description and acceptance criteria
- Comments with debugging context
- Linked tasks (blocks, is-blocked-by, relates-to)
- Referenced file paths or other task IDs

#### 1b. Codebase Context

**When:** Always.

Use Grep, Glob, Read, and the Explore agent to:
- Search for error messages, class names, method names from the input
- Find relevant controllers, services, models based on the context
- Read key files to understand the code path
- For stack traces: read the exact files and line numbers referenced

#### 1c. Git History

**When:** After identifying affected files from any of the above steps.

```bash
git log --oneline -20 -- <affected_files>
```

Look for recent changes that may have introduced or relate to the issue.

### Step 1.5: Cross-Reference & Deepen (Read-Only)

After the parallel gather completes, review **all** findings for references to things not yet examined.

#### Follow New Leads

| Finding from... | New lead type | Action |
|-----------------|---------------|--------|
| ClickUp task | Mentions a class/service name | Read that file, trace its callers |
| ClickUp task | References another task | Fetch that task |
| Codebase search | Reveals a service that delegates to another | Read the downstream service |
| Git log | Shows a recent change to the affected file | Read the diff: `git show <sha> -- <file>` |

#### Process

1. Collect all new leads from Step 1 results
2. Deduplicate — skip anything already examined
3. Fetch/read the new leads (in parallel where possible)
4. Check if *those* results surface further leads -> repeat (**max 2 rounds** total to prevent spiraling)
5. If after 2 rounds there are still promising unfollowed leads, note them in the report as "Areas for further investigation"

### Step 2: Structured Report

Present findings in this format:

---

## Investigation Report: `<input summary>`

### What's Happening
_Clear problem description synthesized from all sources. For Understand mode, describe the system/feature instead._

### Where
_File paths, methods, routes, endpoints. Use `file_path:line_number` format._

### When / Impact
_Frequency, affected users, scope. For Understand/Research modes, note the scope of the system._

### Root Cause Analysis
_Based on code reading and cross-referencing all sources. For Understand mode, this becomes "How It Works". For Research mode, "Key Findings"._

### Related Context
- **ClickUp:** List linked/related tasks with URLs
- **Git:** List recent relevant commits

### Evidence
_Key code snippets or relevant excerpts that support the analysis. Keep this concise — highlight the most important pieces._

### Areas for Further Investigation
_Any promising leads not yet followed, or questions that remain open._

---

### Step 3: Actionable Next Steps

Present options based on the mode and findings. **Do not execute any action without the developer choosing it.**

#### Debug Mode (root cause identified)

> "What would you like to do next?
> 1. **Fix it** — hand off to `/tdd` to write a failing test and implement the fix
> 2. **Update ClickUp** — comment on a task with these findings
> 3. **Dig deeper** — investigate specific areas further"

#### Debug Mode (root cause unclear)

> "What would you like to do next?
> 1. **Investigate further** — dig into [specific suggested areas]
> 2. **Create ClickUp task** — capture findings so far in a new task
> 3. **Search more** — broaden the codebase search"

#### Understand Mode

> "What would you like to do next?
> 1. **Go deeper** — explore a specific subsystem in more detail
> 2. **Document it** — create a ClickUp task with these findings
> 3. **Find related issues** — search for bugs or tasks related to this system"

#### Research Mode

> "What would you like to do next?
> 1. **Create ClickUp task** — turn this research into an actionable task
> 2. **Add to existing task** — comment on an existing ClickUp task with findings
> 3. **Continue researching** — explore additional areas"

### Step 4: Execute Chosen Action

Only proceed when the developer explicitly chooses an option.

#### Fix It -> Hand off to `/tdd`
Tell the developer to run `/tdd` with the relevant context:
> "Run `/tdd <description of the fix>` to start the red-green-refactor cycle."

#### Create ClickUp Task
Create a new task with:
- Summary from the investigation
- Description containing the structured report

#### Comment on ClickUp Task
Add the investigation findings as a comment on the existing task.

### Safety Rules

These rules are **non-negotiable**:

1. **Read-only by default** — Steps 0 through 3 never write to any external system
2. **Never modify code** — hand off to `/tdd` for fixes
3. **Never auto-execute** Step 4 actions — always wait for developer choice
