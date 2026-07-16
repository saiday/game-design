# Decision: starting values not pinned by the design

The corpus pins start population (12) but not start treasury, happiness, culture, or tech.
Driver decisions (v1 baselines, calibration knobs like everything else):

| Field | Start | Reasoning |
|---|---|---|
| treasury | 30 | Buys one region (20×1) + one cheap building in the tribal era without going into debt on generation 1; forces a real choice by generation 2–3. |
| happiness | 70 | Exactly at the ≥70 good-draw threshold: the player starts with the perk and loses it on the first neglect, teaching the 幸福 downstreams early. |
| culture | 0 | Both accumulate purely from buildings/policies; no reason for a head start. |
| tech | 0 | Same. |

If playtest shows generation-1 deadlock or a too-comfortable opening, tune treasury first
(it's the least entangled knob).
