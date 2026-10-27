# Windows v20 playtest rollout — October 27

Installed in normal and working isolated profiles after Windows validation.
Native SHA256: `3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89`.
Source base: `44ffeb762d9f01476bf9adc2709af44550cbb4e9`, plus the runtime fixes
in this rollout. Rebuilt with nightly2025-09-11 GNU and the existing LLVM-MinGW
toolchain. The binary stays local. Northstar1.31.14.0 is unchanged.

## Start testing

Use the existing **Northstar - Solo Bots (8v8)** shortcut. Its default is
**Movement**: new combat movement, proximity correction, diagnostics and the
read-only ammo-expenditure sampler. Human+15bots,fullscreen,Eden,loopback,
aim0.78,existing0.8sfiring warm-up, damage/RPM, human tactical recharge0.5,
five-gun reload0.9 and human ADS/role modifiers are retained.

An optional desktop shortcut, **Northstar - Full Bot Trial (8v8)**, selects the
Full preset without terminal commands. It uses the same normal saves. Close the
game before switching shortcuts; the usual shortcut returns to Movement.

The installed audit-root CMD accepts cumulative presets:

| Command | Behavior |
|---|---|
| `Play-Solo-Bots.cmd baseline` | New gameplay levers off; diagnostics and expenditure sampling remain on |
| `Play-Solo-Bots.cmd` | Movement + proximity correction |
| `Play-Solo-Bots.cmd height` | Movement + height/cover response |
| `Play-Solo-Bots.cmd roster` | Above + stock eight-gun bot roster |
| `Play-Solo-Bots.cmd skills` | Above + matched tacticals/ordnance, skill and defensive policies |
| `Play-Solo-Bots.cmd full` | Above + weapon personalities |

Close the game before selecting another preset. Selection atomically updates
only the explicit trial switches in server autoexec and backs up the previous
config. This makes it survive map changes and prevents server autoexec from
silently undoing command-line settings. Every default shortcut launch returns
to Movement. Metadata records the selected preset and overrides. Loadouts and
progress continue in the SAME normal profile under the migrated save namespace.

Crouch recovery, route guard, jump timing, perception correction and view-kick
sampling remain OFF in every preset. The older unmerged low-clearance prototype
was not added; the reviewed main candidate supersedes that approach.

## What passed

-86pure Rust tests across17suites,47Node tests across9suites, migration/rollback
 and versioned-state fixtures, plus preset preservation/idempotency checks.
-[Compatibility suite](compatibility-validation.json): correct16bot observer
 phase,11gun classes,32human reload/ADS/role/strip cases, respawn, lobby and
 human+15bot return. Checks now throw explicitly: the game's `Assert` is inactive
 in this runtime and had allowed a wrong observer population to continue.
-[Staged smoke](capability-validation.json): diagnostics-only, movement/proximity,
 roster, skills/personality/height, switch-off/respawn, lobby/new map and one
 deliberately interrupted roster assignment.8primaries and6tacticals read back
 correctly; all8primaries also appeared in native weapon observations.35roster
 assignments,64skill requests,12cover selections; these are functional evidence,
 not proof of good tactical decisions or confirmed ability casts.
-Two independent loadout-snapshot checks passed. The cancelled probe restored
 its baseline without reporting success; one expected caught error was isolated
 to that test. Other bots' normal concurrent assignments were counted separately.
-Two expenditure samples captured4deliberately simulated magazine rounds.
 Zoom access worked. This validates polling, not accuracy, real firing rate or
 view-kick measurements. View-kick remained off.
-[Live rollback](rollback-validation.json): original v19 DLL/mod naming, current
 migrated progress carried back,902restored fields, bots and no runtime errors.
 The isolated profile was then migrated back to the candidate with harnesses off.
-[Actual normal shortcut](normal-validation.json): Movement selected through
 Windows PowerShell,902fields restored,62same-frame human+15bot observations,
 no runtime errors,0preset-definition changes,3original save files unchanged.
 Collector finalized44pilot deaths/5qualifying episodes with0damage/fire errors.
 The short unattended check is not a human difficulty result. Test games closed.

## Runtime defects fixed

The sampler's `d<-180` was lexed as a new-slot operator; fixed the comparison.
Logger is now1.1.1. The roster could not pass a table-held `var` as a typed
`PilotLoadoutDef`, and this dialect forbids casting structs. It now captures the
typed baseline directly inside its protected restore closure; roster is0.1.1.

Northstar1.31 Version1 enablement requires per-version false entries. The old
migration wrote bare false, which the loader treated as missing and auto-enabled.
Both migration and rollback now use a shared version-aware helper, clone state
before disabling, preserve CURRENT progress and enforce profile path bounds.
An explicit versioned migration/rollback regression fixture covers the failure.

The integration starter now enforces observer population after autoexec and has
an explicit isolated UI bootstrap option. Critical integration assertions use
throwing helpers. Earlier wrong-population/startup attempts stay failed or
invalidated; they are not successful validation coverage.

## What diagnostics changed about our understanding

109plausible hull/view observations showed stand height72,duck height47 in the
observed cases. Raw `view_angles` had norm~1and matched the forward vector from
eye angles to within1.3e-7. It is NOT raw degrees in this runtime. Keep the
perception change off; the eye-level sight-line change still needs a fair A/B.

The short diagnostic run grouped46stall incidents: link-or-partial share54.35%,
duck-only share0%,partial-route sample share1.07%. These mixed functional phases
are not the prescribed multi-map route/crouch experiment. They do not justify
enabling crouch or claiming better navigation. Dedicated link/jump follow-up
remains useful. No visual watching or FPS/p95 certification occurred.

The3:1pilot K/D target is still a PLAYTEST goal. Human map pairs/fairness feedback,
performance comparisons and longer stability tests remain outstanding. Do not
claim the bots are balanced or human-like from this smoke test.

## Recovery

Immediate behavior rollback: close the game and run `Play-Solo-Bots.cmd baseline`.
It keeps the same saves and installed candidate with gameplay switches off.

Full original deployment backup:
`Notes/backups/before-v20-normal-20261027-175459` under the audit root. Use its
ORIGINAL migration backup with `tools/Restore-BT7274Rename.ps1`, then restore
its plugin DLL and launcher. The helper carries CURRENT migrated progress back
to old keys and disables renamed packages per version. Never restore historical
save_data over newer play. The older initial backup is
`before-v20-20261027-165920`; failed attempts remain private for diagnosis.

Only authored source, aggregate validation and hashes are published. Full logs,
saved state, IDs, compiled binaries and private backups remain on the PC.
