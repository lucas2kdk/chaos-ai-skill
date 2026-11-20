---
# sandbox: a disposable instance created by chaos/sandbox/up and removed by down.
# existing: an instance you already run. Every run asks you to confirm it first.
kind: sandbox
name: <short name of the target, e.g. "api container" or "pixel-7 emulator">
# What a fault may touch, and what it must never touch. Faults outside this are refused.
may_affect: <e.g. the container labelled chaos.target=api and its network>
must_not_affect: <e.g. other containers, host files, anything outside docker>
# Optional: how this target differs from production, e.g. "public php:8-apache base instead of the internal image".
fidelity:
---

# Target

What the system is and how it is normally used, in a few sentences.

## Steady state

The externally observable signals that mean "healthy" (a port answers, a ping succeeds, an activity resumes).

## Identity

How `chaos/sandbox/guard` proves the live target is this one and not something else
(a label and container id, an emulator serial, a kube context name). A hostname alone is not enough.

## Evidence

What `chaos/sandbox/evidence` collects (logs, state dumps) and from where.
