# Higgsfield

**Gate: no generation until the owner approves the phase in chat.** Plan and prompts live in [`jobs.json`](jobs.json); budget in [`../planning/credit-budget.md`](../planning/credit-budget.md).

Outputs go to `outputs/` (git-ignored). Only the selected take is registered in `../assets/manifest.json`.

## Procedure per approved phase

```bash
higgsfield account status
```

Re-estimate each job with its real inputs (must match `jobs.json`; if not, stop and report):

```bash
higgsfield generate cost gpt_image_2_5 --prompt "<K1a prompt>" --aspect_ratio 16:9 --quality high --resolution 2k
```

```bash
higgsfield generate cost kling_o3_flf --prompt "<V1 prompt>" --start-image outputs/K1a.png --duration 5 --mode pro --sound off --multi_shots false
```

Only after the estimate is confirmed and the phase is approved, swap `cost` for `create` and record the job id next to the job in `jobs.json`.
