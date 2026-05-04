# Vitest 3 — CLI Cheat Sheet for pi-cortex
> Source: https://vitest.dev/guide/cli  https://vitest.dev/guide/filtering
> Fetched: 2026-05-04

## Run all tests

```bash
npx vitest run              # run once and exit (CI mode)
npx vitest                  # watch mode
npm test                    # alias if package.json has "test": "vitest run"
```

## Filter by test name (-t)

```bash
npx vitest run -t "pattern"
npx vitest run --testNamePattern "pattern"
```

Matches against the **full test name** (describe block name + test name joined by space).

```bash
# Run all tests in a describe block named "guardrail":
npx vitest run -t "guardrail"

# Run tests whose name contains "injection":
npx vitest run -t "injection"

# Regex pattern:
npx vitest run -t "context.*injection"

# Match multiple words (AND not supported in single -t — use separate runs or describe naming):
npx vitest run -t "guardrail"
npx vitest run -t "session_before_compact"
```

**Note:** `-t` filter checks string inclusion, not full regex match in all versions. Prefer simple substring patterns over complex regex.

## Run specific file

```bash
npx vitest run src/index.test.ts
npx vitest run src/index.test.ts:42        # Vitest 3+: specific line number
```

## Reporter options

```bash
npx vitest run --reporter verbose          # show all test names + pass/fail
npx vitest run --reporter dot              # compact dots
npx vitest run --reporter json             # JSON output (for CI parsing)
npx vitest run --reporter default          # default (short summary)
```

## Useful combinations for TEST-PLAN steps

```bash
# Step 3.3 — context injection tests:
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension
npx vitest run -t "context injection" --reporter verbose 2>&1 | tail -15

# Step 3.5 — guardrail tests:
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension
npx vitest run -t "guardrail" --reporter verbose 2>&1 | tail -10

# Step 3.7 — all tests:
cd /home/bzn/Projects/BzNdevOps/pi-cortex/app/extension
npx vitest run --reporter verbose 2>&1 | tail -20
```

## package.json setup

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:verbose": "vitest run --reporter verbose"
  },
  "devDependencies": {
    "vitest": "^3.0.0"
  }
}
```

## Test file structure (for pi-cortex extension)

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

describe("category routing", () => {
  it("routes infra keywords correctly", () => {
    // test body
  });

  it("falls back to general when confidence < 0.3", () => {
    // test body
  });
});

describe("guardrail", () => {
  it("blocks 0.0.0.0", () => { ... });
  it("blocks --no-verify", () => { ... });
  it("blocks rm -rf /", () => { ... });
});
```

## Mocking fetch (for context injection tests)

```typescript
import { vi } from "vitest";

// Mock global fetch:
const fetchMock = vi.fn().mockResolvedValue({
  ok: true,
  json: async () => [{ id: "test", title: "Test", content: "...", score: 0.9 }],
} as Response);
vi.stubGlobal("fetch", fetchMock);

// After test:
vi.unstubAllGlobals();

// Mock fetch to simulate timeout:
const fetchMock = vi.fn(() => new Promise((_r, reject) =>
  setTimeout(() => reject(new Error("AbortError")), 50)
));
vi.stubGlobal("fetch", fetchMock);

// Mock fetch to simulate 500 error:
const fetchMock = vi.fn().mockResolvedValue({ ok: false, status: 500 } as Response);
vi.stubGlobal("fetch", fetchMock);
```

## PASS conditions used in TEST-PLAN.md

| Step | Command | PASS condition |
|------|---------|---------------|
| 3.3 | `npx vitest run -t "context injection" 2>&1 \| tail -10` | ≥1 test passing, 0 failing |
| 3.5 | `npx vitest run -t "guardrail" 2>&1 \| tail -10` | ≥3 tests passing, 0 failing |
| 3.7 | `npm test 2>&1 \| tail -10` | ≥10 tests passing, 0 failing |
| 2a.X | `npm test -- -t "stemmer" 2>&1 \| tail -5` | ≥1 passing, 0 failing |
