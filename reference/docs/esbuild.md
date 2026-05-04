# esbuild — Cheat Sheet for pi-cortex
> Source: https://esbuild.github.io/api/
> Fetched: 2026-05-04

## Critical flags for pi-cortex extension build

```bash
esbuild src/index.ts \
  --bundle \                                          # inline all imports
  --platform=node \                                   # Node.js target (marks fs, path, etc. as external)
  --external:@mariozechner/pi-coding-agent \          # do NOT bundle — Pi provides at runtime
  --external:@mariozechner/pi-tui \                   # same
  --external:@sinclair/typebox \                      # same
  --outfile=../../.pi/extensions/pi-cortex/index.ts   # output with .ts extension (Pi requires .ts)
```

**Why `.ts` extension on output?** Pi's extension loader expects `.ts` files. esbuild writes plain JS content regardless of the output filename extension — Pi reads it fine.

## Alternative: --outdir + --out-extension

```bash
esbuild src/index.ts \
  --bundle --platform=node \
  --external:@mariozechner/pi-coding-agent \
  --outdir=../../.pi/extensions/pi-cortex \
  --out-extension:.js=.ts           # renames output from index.js → index.ts
```

`--out-extension` only works with `--outdir`, not `--outfile`. With `--outfile` just set the filename directly to `.ts`.

## package.json scripts

```json
{
  "scripts": {
    "build": "esbuild src/index.ts --bundle --platform=node --external:@mariozechner/pi-coding-agent --external:@mariozechner/pi-tui --external:@sinclair/typebox --outfile=../../.pi/extensions/pi-cortex/index.ts",
    "build:watch": "npm run build -- --watch"
  }
}
```

## Option reference

| Flag | Purpose | Notes |
|------|---------|-------|
| `--bundle` | Inline all imports recursively | Required |
| `--platform=node` | Node.js target | Sets `process`, marks builtins external |
| `--platform=browser` | Browser target (default) | Do NOT use for Pi extensions |
| `--outfile=path` | Single output file | Use for single entry point |
| `--outdir=dir` | Output directory | Use for multiple entry points |
| `--out-extension:.js=.ts` | Rename output extension | Only works with `--outdir` |
| `--external:pkg` | Skip bundling a package | Applied per-package; wildcards: `--external:@mariozechner/*` |
| `--format=cjs` | CommonJS output | Default when `--platform=node` |
| `--format=esm` | ES module output | Use when consuming code has `"type":"module"` |
| `--minify` | Minify output | Good for production, bad for debugging |
| `--sourcemap` | Inline source map | `--sourcemap=inline` |
| `--watch` | Rebuild on file change | Dev mode |
| `--log-level=error` | Only show errors | Suppress warnings |

## Common errors and fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Cannot find module '@mariozechner/pi-coding-agent'` during bundle | Not marked external | Add `--external:@mariozechner/pi-coding-agent` |
| Output is `.js` but Pi can't find extension | Missing `.ts` filename | Use `--outfile=path/index.ts` or `--out-extension:.js=.ts` |
| `error: The "type" field in package.json` | ESM/CJS mismatch | Add `--format=cjs` or set `"type":"module"` in package.json |
| Build succeeds but output > 1 MB | Node built-ins bundled | Add `--platform=node` (marks `fs`, `path`, etc. as external automatically) |
