# A/B telemetry coverage preflight — 2026-10-29

**Status:** offline-only analyzer/test improvement. No native bot source, DLL,
Northstar profile, saves, installed mods or current gameplay settings changed.

## Why this matters

The existing `tools/Analyze-BotAITrial.mjs` counted `BOT_PATH`,
`BOT_STALL`, `BOT_CLEARANCE` and frag-input diagnostics without validating
whether baseline and trial logs covered the **same map or comparable sampled
windows**. Such counts are not rates or reliable evidence of improvement.

The native `BOT_FRAME` producer is in
`bp_ort/src/bots/cmds_exec.rs` and emits engine `t`, map name and epoch
only when `bot_telemetry_interval` is positive. The analyzer already
recognized this event but previously discarded its timing information.

## New output

Each epoch now adds `telemetry_window` with:
- `frame_samples`: number of finite nonnegative `BOT_FRAME` times;
- `observed_span_s`: latest minus earliest sampled engine timestamp
  (null if fewer than two samples);
- `map_conflict`: different valid map labels within one epoch;
- `invalid_frame_samples`: malformed or missing frame times.

Paired `--baseline`/`--trial` outputs now also contain `coverage_review`,
which lists shared and unmatched maps, unknown/conflicted epochs and
per-map sampled spans. Warnings are raised for missing labels, mismatched
maps, unequal cohort counts, absent sampled windows or more than 10%
difference in observed span for a one-epoch-per-map comparison.

The success-like status **never means gameplay validated**:
`metadata_present_manual_review_required` merely says no structural
warnings were detected. All actual playtime, alive bot-seconds, comparable
loadouts/configuration, deaths, hit rates, ability activations and traversal
outcomes still require independent evidence.

## Commands

From the checked-out project root, with Node 22:

```powershell
node --test tests/bot_ai_trial.test.mjs
node tools/Analyze-BotAITrial.mjs --baseline <PRIVATE-BASELINE.log> --trial <PRIVATE-TRIAL.log> --out <PRIVATE-OUTPUT.json>
```

Preserve source logs locally. The report does not include raw identifiers,
positions or raw lines. Compare matched Eden, War Games, Complex and Meadow
rounds, verifying `bot_telemetry_interval` was enabled on both runs and
the `BOT_FRAME` series covers the actual test period. Pair output with
independent validated played-window and weapon-notebook death attribution.

## Validation and review

Twelve Node tests executed successfully in the editing environment
(previous eight plus four new coverage cases). The committed analyzer and
test source blobs match the exact locally tested files. This does not
replace native Rust compilation, local PowerShell test runner, Northstar
startup, movement checks, or full isolated map-cycle trials.

**Do not merge this tooling PR into a test run mid-match.** The new output
schema is additive, but keep a stable analyzer version for each comparison.
