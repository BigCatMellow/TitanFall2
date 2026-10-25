# Import and data provenance

The import preserves330 upstream commits and adds local source, custom add-ons,
historical snapshots, automation and sanitized research. Initial project import:
c4145bc426758ab2453930054ea856e12534c531.

LOCAL-IMPORT-MANIFEST.json records original artifact hashes, inclusion decisions
and published-copy hashes at import time. Git normalizes text endings using
.gitattributes, so a clone's text-file byte hash can differ from its Windows
import-copy hash. Original local backups remain for exact comparisons.
Historical DLL/ZIP hashes identify original local artifacts, not rebuilt
binaries or extracted/normalized source. Builds in another path/toolchain
may not reproduce identical binary hashes.

Auth fields/credential patterns are sanitized; account IDs become LOCAL_PLAYER_UID.
Private persistence, installed third-party bundles, game assets and build/dump
binaries are omitted. Logs are sanitized before gzip. PUBLICATION-CHECK.json
records pattern/path/size checks, not a guarantee of detecting every secret.

Current code is the undeployed observation-v17 candidate. Data is v16 unless
explicitly labeled otherwise. Retainedv13 raw-persistence/v14 route experiments
were rejected; filenames like final do not establish deployment or approval.

Original notes preserve machine-specific paths and chronological statuses.
Use PROJECT-STATUS.md, latest handoff entries and research/trends-20261025 for
the consolidated state. Old active-run/PID entries are historical, not live.
