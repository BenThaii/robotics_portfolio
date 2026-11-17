# Robotics Portfolio

A static portfolio site presenting five robotics builds, with recorded video
evidence for every reported result.

## What's here

| Path | What it shows |
|---|---|
| `motion-retargeting/` | Human mocap → Unitree G1 via per-frame IK and GMR-based retargeting, compared clip by clip |
| `motion-physics/` | Those trajectories executed on a 29-DoF G1 in MuJoCo under explicit torque PD |
| `mobile-robot/` | RTAB-Map RGB-D SLAM and Nav2 navigation on a real mobile base |
| `robot-arm/` | A MoveIt 2 pick-and-place stack in simulation |
| `imitation-learning/` | A 50 Hz neural policy distilled from the 500 Hz tracking teacher, with the full BC/PPO ledger |

`assets/` holds the web-encoded videos, poster frames, plots and figures.
`build_assets.sh` rebuilds them from the project outputs.

All numbers on the site were measured from the builds themselves. Each page
carries an honest-scope note describing what the demos do and do not show.

## Running locally

All asset paths are relative, so the site works from any static file server:

```
python3 -m http.server 8899
```

Then open `http://localhost:8899/`.

## Publishing

The site is served by GitHub Pages from the repository root. `.nojekyll` keeps
Pages from running the Jekyll build step over the static files.

## Attribution

Motion data: CMU Graphics Lab motion capture database. Robot model: Unitree G1.

GMR is external open-source work — *Retargeting Matters: General Motion
Retargeting for Humanoid Motion Tracking* (Araújo, Ze, Xu, Wu, Liu; Stanford
University; ICRA 2026; MIT licence) — and is not a group algorithm.
