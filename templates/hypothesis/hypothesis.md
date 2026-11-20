---
id: <kebab-case id, equal to this directory's name>
steady_state: <one measurable sentence naming what is observed and the threshold>
fault: <one line saying what is broken, on what, for how long>
# The fault ends on its own or is reverted after this long.
duration: 60s
# Time between applying the fault and running the check.
wait: 5s
# Longest the check may run. wait + check_timeout + 10s must fit inside duration.
check_timeout: 30s
# After revert, how long the steady state may take to hold again. Default: wait + check_timeout.
recovers_within: 30s
# true for a single event with nothing to revert (a process kill). Its status may stay "inactive".
one_off: false
# Optional: how often abort checks run while the fault is active. An abort check is an executable
# named `abort` next to this file (and/or chaos/sandbox/abort): exit 0 = keep going, non-zero = stop now.
abort_interval: 5s
# Optional: compare a control and an experimental group measured at the same time. The check then takes
# `control` or `experiment` and prints `value: <number>`; the fault must affect the experimental group only.
control: false
tolerance: 10%
# Optional: the incident, postmortem or document this hypothesis came from.
source:
---
**Steady state:** <the same expectation, with how it is measured>

<Why this matters: what real-world event the fault stands for, and what a violation would mean for users.>
