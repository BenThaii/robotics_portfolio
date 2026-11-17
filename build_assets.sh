#!/usr/bin/env bash
# build_assets.sh — prepare web-optimized media for the portfolio site from the
# motion-retargeting repo outputs. Idempotent: skips clip outputs that already
# exist; the reel is always refreshed because the reel is rebuilt in place.
#   videos : 1600px wide, crf 24, faststart, no audio  -> assets/video/
#   posters: representative JPEG frame per clip        -> assets/poster/
#   plots  : per-clip tracking-error PNG, copied       -> assets/plots/
#
# Both stages are handled: <clip>.mp4 (Stage 1 IK) and <clip>_gmr.mp4 (Stage 2),
# plus the Stage 3 physics-tracking assets from projects/g1-physics-tracking,
# the two sim-demo captures, and three clean Figure-style hero loops derived
# from those assets (title/footer cards cut so the first frame is footage).
set -euo pipefail

SRC="$(cd "$HOME/ben_robotics/projects/humanoid-motion-retargeting/output" && pwd)"
SRC2="$(cd "$HOME/ben_robotics/projects/g1-physics-tracking/output" && pwd)"
SITE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
A="$SITE/assets"
mkdir -p "$A/video" "$A/poster" "$A/plots"

encode() { # encode <input mp4> <asset basename> <poster fraction>
  local in="$1" base="$2" ss="$3" dur
  [ -s "$in" ] || { echo "MISSING $in" >&2; exit 1; }
  if [ ! -s "$A/video/$base.mp4" ]; then
    ffmpeg -y -v error -nostdin -i "$in" -vf "scale=1600:-2" \
      -c:v libx264 -preset medium -crf 24 -an -movflags +faststart \
      "$A/video/$base.mp4"
    echo "video: $base ($(du -h "$A/video/$base.mp4" | cut -f1))"
  fi
  if [ ! -s "$A/poster/$base.jpg" ]; then
    dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
    ffmpeg -y -v error -nostdin -ss "$(python3 -c "print(round(float('$dur')*float('$ss'),2))")" \
      -i "$in" -frames:v 1 -q:v 4 "$A/poster/$base.jpg"
    echo "poster: $base"
  fi
}

# clip | poster fraction (same frame of the motion used for both stages)
while read -r clip ss; do
  [ -z "$clip" ] && continue
  encode "$SRC/$clip/${clip}_retargeted.mp4" "$clip" "$ss"
  encode "$SRC/gmr/$clip/${clip}_gmr.mp4" "${clip}_gmr" "$ss"
  [ -s "$SRC/$clip/${clip}_tracking_error.png" ] && \
    cp -f "$SRC/$clip/${clip}_tracking_error.png" "$A/plots/$clip.png"
done <<'CLIPS'
walk 0.5
walk_multi 0.62
dance 0.5
box 0.45
kick 0.86
jump 0.42
CLIPS

# reel — always refresh (the split reel replaced the stage-1-only one)
cp -f "$SRC/demo_reel.mp4" "$A/video/reel.mp4"
ffmpeg -y -v error -nostdin -ss 10 -i "$SRC/demo_reel.mp4" -frames:v 1 -q:v 4 "$A/poster/reel.jpg"
echo "reel: refreshed ($(du -h "$A/video/reel.mp4" | cut -f1)) + poster"

# --- Stage 3: physics tracking (projects/g1-physics-tracking) ----------------
# Two-pane renders get a caption burned into each pane (top-left) so the
# viewer always knows which side is which. Labels live HERE, not in the repo
# outputs — the raw artifacts stay unannotated.
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf

# encode_sbs <in> <base> <poster-frac> <left-label> <right-label>
encode_sbs() { # 1600x450 two-pane video -> caption per pane + encode + poster
  local in="$1" base="$2" ss="$3" lt="$4" rt="$5"
  [ -s "$in" ] || { echo "MISSING $in" >&2; exit 1; }
  if [ ! -s "$A/video/$base.mp4" ]; then
    ffmpeg -y -v error -nostdin -i "$in" -vf "scale=1600:-2,\
drawtext=fontfile=$FONT:text='$lt':fontsize=26:fontcolor=white:box=1:boxcolor=0x1c1b19@0.62:boxborderw=10:x=24:y=20,\
drawtext=fontfile=$FONT:text='$rt':fontsize=26:fontcolor=white:box=1:boxcolor=0x1c1b19@0.62:boxborderw=10:x=824:y=20" \
      -c:v libx264 -preset medium -crf 24 -an -movflags +faststart \
      "$A/video/$base.mp4"
    echo "video: $base ($(du -h "$A/video/$base.mp4" | cut -f1))"
  fi
  if [ ! -s "$A/poster/$base.jpg" ]; then
    ffmpeg -y -v error -nostdin -ss "$ss" -i "$A/video/$base.mp4" \
      -frames:v 1 -q:v 4 "$A/poster/$base.jpg"
    echo "poster: $base"
  fi
}

# track_box_full : the FULL 46.6 s / 1399-frame box run, never falls (hero clip)
# track_box      : 20 s cut (t=13-33 s, deepest squat), left = Stage 1 IK ref
# track_box_gmr  : same clip + window, left = Stage 2 GMR ref instead
# track_walk     : 15 s walking incl. real footsteps (450/688 frames)
# track_terminal : real terminal capture of the live fresh-BVH retargeting
# bball_gmr      : the fresh CMU 13_29 basketball clip retargeted by the live run,
#                  rendered human | G1
while read -r in base ss; do
  [ -z "$in" ] && continue
  case "$base" in
    track_box_full|track_box|track_walk)
      encode_sbs "$SRC2/$in" "$base" "$ss" \
        "IK retargeted reference" "IK → MuJoCo physics · torque PD" ;;
    track_box_gmr)
      encode_sbs "$SRC2/$in" "$base" "$ss" \
        "GMR retargeted reference" "GMR → MuJoCo physics · torque PD" ;;
    bball_gmr)
      encode_sbs "$SRC2/$in" "$base" "$ss" \
        "CMU human (BVH)" "Unitree G1 · retargeted" ;;
    *) encode "$SRC2/$in" "$base" "$ss" ;;
  esac
done <<'PHYSICS'
box_full_sbs.mp4        track_box_full 0.45
box_20s_sbs.mp4         track_box      0.55
box_gmr_20s_sbs.mp4     track_box_gmr  0.55
walk_15s_sbs.mp4        track_walk     0.50
terminal_live.mp4       track_terminal 0.62
basketball_live_gmr.mp4 bball_gmr      0.30
PHYSICS

# --- Imitation-learning 3-pane (projects/g1-il-tracking) ---------------------
# The raw render is 2560x496 (three 853x480 panes + its own 16 px caption
# strip): crop the strip off, scale to 1600x300, burn the site's pane labels.
IL="$(cd "$HOME/ben_robotics/projects/g1-il-tracking/output" && pwd)"
encode_tri() { # <in> <base> <poster-ss>
  local in="$1" base="$2" ss="$3"
  [ -s "$in" ] || { echo "MISSING $in" >&2; return 0; }
  if [ ! -s "$A/video/$base.mp4" ]; then
    ffmpeg -y -v error -nostdin -i "$in" -vf "crop=2560:480:0:0,\
scale=1600:300:flags=lanczos,\
drawtext=fontfile=$FONT:text='GMR reference':fontsize=18:fontcolor=white:box=1:boxcolor=0x1c1b19@0.62:boxborderw=8:x=16:y=16,\
drawtext=fontfile=$FONT:text='teacher · 500 Hz PD':fontsize=18:fontcolor=white:box=1:boxcolor=0x1c1b19@0.62:boxborderw=8:x=549:y=16,\
drawtext=fontfile=$FONT:text='neural policy @ 50 Hz, dq=0':fontsize=18:fontcolor=white:box=1:boxcolor=0x1c1b19@0.62:boxborderw=8:x=1082:y=16" \
      -c:v libx264 -preset medium -crf 24 -an -movflags +faststart \
      "$A/video/$base.mp4"
    echo "video: $base ($(du -h "$A/video/$base.mp4" | cut -f1))"
  fi
  if [ ! -s "$A/poster/$base.jpg" ]; then
    ffmpeg -y -v error -nostdin -ss "$ss" -i "$A/video/$base.mp4" \
      -frames:v 1 -q:v 3 "$A/poster/$base.jpg"
    echo "poster: $base"
  fi
}
encode_tri "$IL/box_gmr_3pane.mp4" track_il_box 20

# --- Sim-demo captures (experiments/captures-2026-11-15) ---------------------
# Produced clips already carry title/verdict cards + 1.5x speed, so these are
# straight transcodes; never upscale (native width kept), crf 24, faststart.
#   ur5e_pick_place : MoveIt 2 UR5e pick-and-place, Gazebo GUI, VERDICT: PASS
#   nav2_waypoints  : TurtleBot3 Nav2 5-waypoint mission, RViz, 5/5 reached
CAPS="$(cd "$HOME/ben_robotics/experiments/captures-2026-11-15" && pwd)"
while read -r in base ss; do
  [ -z "$in" ] && continue
  if [ ! -s "$A/video/$base.mp4" ]; then
    ffmpeg -y -v error -nostdin -i "$CAPS/$in" -vf "scale='min(1600\,iw)':-2" \
      -c:v libx264 -preset medium -crf 24 -an -movflags +faststart \
      "$A/video/$base.mp4"
    echo "video: $base ($(du -h "$A/video/$base.mp4" | cut -f1))"
  fi
  if [ ! -s "$A/poster/$base.jpg" ]; then
    ffmpeg -y -v error -nostdin -ss "$ss" -i "$CAPS/$in" -frames:v 1 -q:v 4 "$A/poster/$base.jpg"
    echo "poster: $base"
  fi
done <<'SIMDEMOS'
ur5e_moveit_pick_place_sim.mp4 ur5e_pick_place 0.45
turtlebot3_nav2_waypoints_sim.mp4 nav2_waypoints 0.50
SIMDEMOS

# --- Figure-style hero loops (clean, title-card-free) ------------------------
# Short muted loops for the opening hero and the project hero sections. Each is
# cut from an asset already produced above (or from the P0.8 showcase capture)
# so the burned-in title / footer cards never appear on screen.
hero() { # hero <in> <base> <start> <dur> <poster-t> [vf] [crf]
  local in="$1" base="$2" ss="$3" dur="$4" pt="$5" vf="${6:-}" crf="${7:-24}"
  [ -s "$in" ] || { echo "MISSING hero source $in" >&2; return 0; }
  if [ ! -s "$A/video/$base.mp4" ]; then
    if [ -n "$vf" ]; then
      ffmpeg -y -v error -nostdin -ss "$ss" -t "$dur" -i "$in" -vf "$vf" \
        -c:v libx264 -preset medium -crf "$crf" -an -movflags +faststart \
        "$A/video/$base.mp4"
    else
      ffmpeg -y -v error -nostdin -ss "$ss" -t "$dur" -i "$in" \
        -c:v libx264 -preset medium -crf "$crf" -an -movflags +faststart \
        "$A/video/$base.mp4"
    fi
    echo "hero video: $base ($(du -h "$A/video/$base.mp4" | cut -f1))"
  fi
  if [ ! -s "$A/poster/$base.jpg" ]; then
    ffmpeg -y -v error -nostdin -ss "$pt" -i "$A/video/$base.mp4" \
      -frames:v 1 -q:v 3 "$A/poster/$base.jpg"
    echo "hero poster: $base"
  fi
}

P08="$(cd "$HOME/ben_robotics/model-validation/turtlebot3-p02/video" 2>/dev/null && pwd || true)"
if [ -n "$P08" ] && [ -s "$P08/p08_slam_showcase.mp4" ] && \
   [ ! -s "$A/video/p08_slam_showcase.mp4" ]; then
  cp -f "$P08/p08_slam_showcase.mp4" "$A/video/p08_slam_showcase.mp4"
fi
# P0.8 showcase carries a title card and a persistent footer caption: crop the
# middle 560 px band and pad it back to 1280x720 so only the cloud shows.
hero "$A/video/p08_slam_showcase.mp4" hero_cloud 10 16 5 \
  "crop=1280:560:0:88,pad=1280:720:0:88:black" 27
# Longer clean cut for the mobile-robot detail page (same crop, no title cards).
hero "$A/video/p08_slam_showcase.mp4" cloud_full 10 25 8 \
  "crop=1280:560:0:88,pad=1280:720:0:88:black" 24
# Split IK-vs-GMR reel: skip the 4 s title card, keep the comparison footage.
hero "$A/video/reel.mp4" hero_retarget 4 40 6
# UR5e capstone: skip the 4 s title card, keep the sense-plan-grasp-place run.
hero "$A/video/ur5e_pick_place.mp4" hero_arm 4 60 20

echo "--- totals ---"
du -sh "$A/video" "$A/poster" "$A/plots"
