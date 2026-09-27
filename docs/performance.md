# Performance records

The measurements below come from development checks recorded on 2026-09-19.
They describe the earlier build. They are not fresh measurements of every
later change. See [Contributing](../CONTRIBUTING.md#checks) for automated checks.

## Environment for the earlier runs

The session used Omarchy 4.0.4-1, Hyprland 0.56.2, and Quickshell 0.3.1.
One physical display ran at 3840 by 2160, 60 Hz, and scale 1.6.
Tilelane shared the normal Omarchy shell process and its configured widgets.
The desktop had no UPower battery. Powerstat and Turbostat were unavailable.

An earlier stock-bar `ps` sample showed about 0.8% CPU and 458096 KiB RSS.
It was a point-in-time sample after startup. It is not comparable to the
controlled ten-minute result below.

## Ten-minute idle sample

The test read CPU ticks and resident memory from `/proc/$pid/stat` every
30 seconds for 600 seconds. It used `getconf CLK_TCK` and `getconf PAGESIZE`
to convert the values.

| Measurement                         | Recorded result                                    |
| ----------------------------------- | -------------------------------------------------- |
| CPU ticks across 600 seconds        | 24                                                 |
| Mean CPU usage for the shared shell | 0.0400% of one core                                |
| Interval CPU range                  | 0.0000% to 0.2663%                                 |
| Resident memory at start            | 452456 KiB                                         |
| Resident memory at end              | 451420 KiB                                         |
| Direct child processes              | One host plugin watcher and two clipboard watchers |

This measures the whole Omarchy shell. It does not isolate Tilelane's cost.
It does not establish an improvement over the stock bar or a battery benefit.
The source notes recorded these results; raw samples are not committed in this repository.

## Window events and lifecycle

A 100-cycle test opened and closed uniquely identified Foot windows.
It reported zero failures and returned to the original model count each time.
Shared-shell memory changed from 508392 KiB to 507676 KiB.

The 95th percentile was 101 ms from process launch to model entry and 73 ms
from close request to model removal. The first value includes process startup.

A separate 50-cycle run timed Hyprland's socket events before checking the
Tilelane model. Its 95th percentile was 48 ms for opening and 40 ms for closing.
The diagnostic process round trip was about 29 ms and is included in those results.
This measured model visibility, not the time when the display presented a frame.

## Panel lifecycle

Twenty Audio panel cycles opened, closed, and unloaded without failure.
The lazy loader waited 250 ms after close. No panel layer or extra child
remained. Shared-shell memory changed from 506376 KiB to 493828 KiB.

Current code keeps visual widget hosts loaded and unloads the five panel-only
controls. The older result does not prove that every hosted widget unloads.
Each native component can also have its own internal loaders and schedules.

## Displays and scaling

A temporary headless output exercised screen creation and removal.
The earlier test used output scales 1, 1.25, 1.5, and 2.
At the default UI scale, the bar stayed 44 logical pixels high.
Crops measured 44, 55, 66, and 88 physical pixels in height.

Removing the virtual output while Start was open left one bar and no stale
Start window. The model count and shell process count stayed at their expected values.
This covers virtual screen lifecycle. It does not cover physical cable events
or suspend/resume.

## Current work that can start a process

The [architecture inventory](architecture.md#processes-and-commands) is the
current source for process triggers. It includes app launch, hidden-entry scans,
terminal identity probes, shortcut lookup, and window actions.

Floating launch can poll new clients up to 40 times after a user request.
Terminal identification allows a bounded set of startup retries.
A new window without a PID can also request a batched native detail refresh.
These paths were added or changed after some early measurements.
The old claim that opening a window can never trigger a process is obsolete.

Tilelane does not run a recurring idle subprocess query. Short hover,
collapse, unload, and hint timers manage UI state. Hosted Omarchy widgets keep
their own refresh schedules. Count those separately when attributing work.

## Repeat the measurements

Record versions, active widgets, output scale, shell PID, and background activity.
Useful read-only commands include:

```sh
omarchy version
omarchy-shell shell ping
hyprctl monitors -j
pgrep -a -x quickshell
ps -eo pid,ppid,etimes,%cpu,rss,comm,args
```

Process output can contain private application arguments. Review it before sharing.

For a comparison, alternate stock-bar and Tilelane runs under the same conditions.
Measure each for ten minutes. Keep raw samples and report the median across runs.
Track both CPU ticks and direct children. State which process owns each timer or command.

Use controlled test windows for lifecycle and latency measurements.
Observe compositor events separately from process launch time.
Restore the prior bar, workspace, and test output state after a live experiment.

These measurements do not cover battery use, physical hot-plug, or suspend/resume.
