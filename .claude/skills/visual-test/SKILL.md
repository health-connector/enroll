---
name: visual-test
description: Run visual UI testing with Playwright MCP after frontend changes. Use this to verify UI works correctly.
---

You are now operating as the UI Visual Testing Agent. Follow the workflow from:

!`cat .aidocs/agents/ui_visual_testing_agent.md`

---

## Core Testing Pattern: Reconnaissance-Then-Action

**ALWAYS inspect before interacting.** Dynamic webapps render content via JavaScript. You must wait for the page to stabilize before testing.

### The Pattern
```
1. NAVIGATE  → browser_navigate(url)
2. WAIT      → browser_wait_for(text) or pause for JS (~2s)
3. SNAPSHOT  → browser_snapshot() to discover selectors
4. ACT       → browser_click/type/select using refs from snapshot
5. WAIT      → Wait for response (Turbo Frame update, new content)
6. VERIFY    → browser_snapshot() + browser_take_screenshot()
7. DOCUMENT  → Record pass/fail with evidence
```

### Why This Matters
- Turbo Frames update asynchronously - clicking too fast misses updates
- Snapshot gives you accurate `ref` values for elements
- Screenshots alone don't tell you element refs - always snapshot first

---

## Wait Strategies

| Scenario | Wait Method |
|----------|-------------|
| Initial page load | `browser_wait_for("expected text")` |
| After Turbo Frame submit | Wait 2 seconds, then snapshot |
| After clicking filter | Wait 1-2 seconds for debounced submit |
| Modal/Slideover opening | `browser_wait_for("modal title text")` |
| After form submission | `browser_wait_for("Success")` or error text |

**Turbo-specific:** This app uses Turbo Frames with debounce on filters. Always wait after interactions.

---

## Selector Discovery

1. **Take a snapshot first** - `browser_snapshot()` returns the accessibility tree with `ref` values
2. **Use refs from snapshot** - Don't guess selectors, use what the snapshot gives you
3. **Re-snapshot after changes** - Refs may change after DOM updates

### Example Flow
```
→ browser_snapshot()
  Returns: [button "Submit" ref="btn-42"]

→ browser_click(element="Submit button", ref="btn-42")

→ browser_wait_for("Success")

→ browser_snapshot()  # Get new refs after update
```

---

## Testing Instructions

$ARGUMENTS

If no specific URL provided, ask the user what to test.

---

## Quick Reference

### Common Test URLs
- Local dev: `http://localhost:3000`

### Key MCP Commands
| Command | Purpose |
|---------|---------|
| `browser_navigate(url)` | Go to URL |
| `browser_snapshot()` | Get accessibility tree with refs (preferred) |
| `browser_take_screenshot()` | Visual capture for documentation |
| `browser_click(element, ref)` | Click using ref from snapshot |
| `browser_type(element, ref, text)` | Type into input |
| `browser_wait_for(text)` | Wait for text to appear |
| `browser_console_messages()` | Check for JS errors |
| `browser_resize(width, height)` | Test responsive (375x667 for mobile) |

---

## Test Report Format

```markdown
## Visual Test: [Feature Name]

### Environment
- URL: http://localhost:3000/...
- Viewport: Desktop (1280x720) / Mobile (375x667)

### Tests Performed

#### 1. [Test Name]
- **Action:** What was done
- **Expected:** What should happen
- **Actual:** What happened
- **Result:** ✅ PASS / ❌ FAIL
- **Screenshot:** [if relevant]

### Console Errors
- None / [List any errors]

### Summary
- ✅ X tests passed
- ❌ Y tests failed
- 🎯 Ready for production: Yes/No
```

---

## Cleanup

After the testing task is complete, delete all Playwright MCP temp files:
```bash
rm -f .playwright-mcp/*.png .playwright-mcp/*.yml .playwright-mcp/*.log
```
Screenshots should be uploaded to ClickUp before deletion. Reports are saved to `.aidocs/reports/`.

---

## Remember
1. **Snapshot before acting** - Get refs from current page state
2. **Wait after interactions** - Turbo needs time to update
3. **Check console errors** - JS errors indicate problems
4. **Test mobile** - Resize to 375x667 for mobile testing
5. **Document with screenshots** - Offer to add to PR when done
