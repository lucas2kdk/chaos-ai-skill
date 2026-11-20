---
name: profile
description: Describe this repo's system as a chaos target - write chaos/target.md (what it is, blast radius, fidelity) and the chaos/sandbox/ executables (up, down, guard, evidence) - and have the user review them. Use when the user wants to set up chaos experiments in a repo, or when /chaos:run says the binding is missing or not reviewed.
---

# /chaos:profile

Draft the binding that lets the chaos plugin run experiments against this repo's system, then have the user review it. Nothing is injected here.

Contracts: `${CLAUDE_PLUGIN_ROOT}/docs/contracts.md`. Worked examples: `${CLAUDE_PLUGIN_ROOT}/examples/docker/chaos/` and `${CLAUDE_PLUGIN_ROOT}/examples/kubernetes/chaos/`.

## 1. Understand the system

Read the repo: Dockerfiles and compose files, Kubernetes manifests or Helm charts, Ansible playbooks and inventories, Gradle/Android projects, server configs (e.g. a Minecraft `server.properties`), READMEs, CI files. Work out:

- what runs, and how a disposable copy could be started;
- the externally observable signals of health (a port answers, a ping succeeds, an activity resumes, a second Ansible run reports `changed=0`);
- where logs and state can be read from;
- what the sandbox cannot reproduce faithfully (a private base image, shared storage, a load balancer).

If `chaos/` already exists, read it and improve it instead of starting over.

## 2. Choose the target kind

- **sandbox** (default): `up` creates a disposable instance, `down` removes it. Prefer this whenever the system can be started locally.
- **existing**: an instance the user already runs. Use only if the user asks for it. Every run will ask them to confirm it.

If it is unclear, ask the user one question with your recommendation.

**When production can't be reproduced** (a private registry refuses the pull, a licensed component, hardware): stop and ask the user whether to stop or to fall back (for example, a public base image with the same app code). On a fallback, describe the difference in one line in `target.md` `fidelity:`. It is copied into every run record and finding, so a fixer knows what was really tested.

## 3. Write the files

1. `chaos/config.yaml` from `${CLAUDE_PLUGIN_ROOT}/templates/config.yaml`. Leave `sink: local` unless the user wants GitHub issues.
2. `chaos/target.md` from `${CLAUDE_PLUGIN_ROOT}/templates/target.md`. Fill `kind`, `name`, `may_affect`, `must_not_affect`, `fidelity` (empty when the sandbox matches production) and every section of the body.
3. `chaos/sandbox/guard`, `chaos/sandbox/evidence`, and for sandboxes `chaos/sandbox/up` and `chaos/sandbox/down`. Make them executable. Put settings the binding shares in `chaos/sandbox/lib.sh`.
4. Optionally, `chaos/sandbox/abort`: a target-wide abort check that applies to every hypothesis (for example: a container restarts in a loop, the host's disk is nearly full, an error rate passes a limit). It runs every few seconds while a fault is active. Exit 0 to keep going, non-zero to stop at once. Never change the target. It is part of the reviewed binding.
5. Helpers that hypotheses will use (an HTTP probe, a staleness reader) go in `chaos/lib/`, not `chaos/sandbox/`. Everything in `chaos/sandbox/` is part of the reviewed binding, so a helper added there later would invalidate the review.
6. Add `chaos/.gitignore` with `runs/*`, `!runs/.gitkeep` and any state file `up` writes. State files must not live in `chaos/sandbox/`, for the same reason.
7. Platform notes: on SELinux hosts (Fedora, RHEL), bind mounts need `:z`; on macOS, Docker runs in a VM, so `127.0.0.1` ports work but host paths are slower.

### The guard is the most important file

`guard` must prove that the live target is this one and nothing else. It exits 0 only on a match and never changes anything. Use an identity that cannot be confused:

| Target | Strong guard | Weak (do not use alone) |
|---|---|---|
| Docker / compose | label with a random instance id written by `up`, checked on every container | container name |
| Kubernetes | dedicated kind/k3d context name and namespace, plus scoped credentials | current context |
| Minecraft or other game server | container label + instance id; for an existing server, its RCON-reported MOTD or seed matches `target.md` | hostname, port |
| Ansible | inventory file is the sandbox inventory (molecule/containers) and each host carries a sandbox marker | group name |
| Android | `adb -s <serial>` with the AVD name `up` created (`adb -s <serial> emu avd name`) | "the only device connected" |

**Prove the endpoint the check probes.** When a check talks to a port or URL, the guard must also prove that this instance is what answers there, not just that a container with the right labels exists. Have `up` bake the instance id into something the service serves (a version file, a header, an MOTD) and have `guard` fetch it from the exact endpoint the check uses.

`up` should create something the guard can recognise (a label, an AVD name, a context). `down` should remove only what `up` created, selected by that identity.

## 4. Try it

Outside a run you may run the binding's scripts directly. Do it, and fix what fails:

1. `${CLAUDE_PLUGIN_ROOT}/scripts/validate --draft binding`
2. `chaos/sandbox/up` (sandboxes), then `chaos/sandbox/guard`. Expect exit 0.
3. `chaos/sandbox/evidence <tmpdir> <a minute ago, ISO 8601 UTC>`, and look at what it wrote.
4. Negative guard cases. In each, `guard` must exit non-zero:
   - **Stale identity:** temporarily change the recorded instance id (or AVD name, or context), run `guard`, then restore it.
   - **Nothing running:** `chaos/sandbox/down` (sandboxes), then `guard`.
   - **Look-alike:** with the sandbox down, create an object with the same name but without the sandbox label (for Docker: `docker create --name <container-name> <image>`), run `guard`, then remove the object.

## 5. Review with the user

Summarise for the user: the target and kind, the blast radius, the fidelity note, what each script does, and exactly how the guard identifies the target and the endpoint. Point them at the files. Ask whether they approve the binding.

Only after they say yes: run `${CLAUDE_PLUGIN_ROOT}/scripts/validate --stamp binding`. It records a hash of `target.md` and `chaos/sandbox/` in `chaos/.review`. Any later edit to those files blocks runs until it is reviewed and stamped again. Never stamp without an explicit yes.

If `validate` says review stamps moved from `target.md` to `chaos/.review` (a repo set up with an earlier version of the plugin), remove the old `reviewed_hash:` line, review the binding with the user, and stamp it again.

Then suggest `/chaos:hypothesize` to write the first hypotheses.
