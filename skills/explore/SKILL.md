---
name: explore
description: Read-only look at this repo through a chaos-engineering lens - what the system is, what it depends on, what its steady state is, and where it is likely to break - ending in a ranked list of candidate hypotheses. Use when the user asks where their system might fail, what to chaos-test, or how to start with chaos experiments. Makes no changes.
argument-hint: "[area to focus on]"
---

# /chaos:explore

A thinking partner for "how could this break?". **Read only.** Do not write or edit files, and do not start, stop or change anything. Do not run `chaos/sandbox/*` or any fault. Reading files and running read-only commands such as `git log` or `docker ps` is fine.

If the user named an area to focus on, it is here: $ARGUMENTS. Otherwise look at the whole repo.

For each candidate you propose, also say what the sandbox must be able to do for the fault to run (a second container, a slow network, a hanging mount). `/chaos:profile` reads that when it builds the binding.

## Look

- **What runs:** Dockerfiles, compose, manifests, playbooks, app entry points, server configs.
- **Dependencies:** databases, caches, other services, external APIs, disks, the network, the device (for apps).
- **How it fails today:** timeouts and retries (or their absence), restart policies, health checks, idempotence (Ansible), process-death handling (Android), persistence on crash (game servers).
- **Past incidents:** postmortem or incident docs in the repo, and commits that mention an outage, an incident or a revert. A failure that happened before is the first thing to test.
- **What already exists:** `chaos/target.md`, `chaos/hypotheses/`, `chaos/findings/` and recent `chaos/runs/*/record.json`. Do not re-propose a hypothesis that already exists.

## Answer

1. **The system in a few lines**, with a small ASCII diagram if it helps.
2. **Steady state**: the signals a user would notice, and how to measure them.
3. **Target kind**: would a disposable sandbox work, or is only an existing instance available? What would make the guard's identity check strong?
4. **Candidate hypotheses, ranked by likely impact**, each with:
   - steady state (measurable),
   - fault (a realistic event) and a sensible duration. Think beyond crashes: request spikes, config changes, malformed responses and inputs,
   - why you suspect it might be violated (point at the code, config or past incident),
   - internal signals that would make a good abort check,
   - whether it stays inside the blast radius, if one is declared.

Stop there. Next steps: `/chaos:profile` if there is no reviewed binding yet, then `/chaos:hypothesize <candidate>`.
