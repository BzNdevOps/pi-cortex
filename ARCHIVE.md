# Archive Notice

Date: 2026-06-20

## Status

This repository is archived as a historical predecessor of Argos.

Active development has moved to:

- Local path: `/home/bzn/Projects/BzNdevOps/argos`
- Remote: `git@github.com:BzNdevOps/argos.git`
- GitHub: `https://github.com/BzNdevOps/argos`

## Reason

`pi-cortex` captured the earlier Neo4j/API/agent-memory design for persistent
agent knowledge. The maintained implementation and operational direction are
now consolidated in Argos, the local-first modular knowledge brain used by
Claude, Codex, and Pi agents.

## Reference State

- Repository: `BzNdevOps/pi-cortex`
- Pre-archive baseline commit: `b21ccf5`
- Default branch: `main`

The commit that adds this file is the archive marker. After this file is pushed
and visible on GitHub, the remote repository can be archived.

## Operational Notes

- Do not deploy new services from this repository.
- Do not add new features here; port any still-useful documentation or design
  notes into Argos instead.
- Older files in this repository may describe planned or live deployment
  workflows. Those references are historical after this archive notice is
  committed.
- Keep this repository available for history and provenance.
- If rollback is required, unarchive the GitHub repository and restore the local
  folder location before resuming work here.
