# Adventure lord art

Generated using built-in image_gen. Prompts: ../adventure-prompts.json.
The screenshot supplied by the user was a pose reference only.

- ../adventure-lord.png: full-resolution two-handed high-guard portrait.
- ../village.png: transparent village cluster, complete cottages and granary.
- ../adventure-lord-attack-source.png: original six-pose atlas.
- frame-0.png through frame-5.png: aligned 640 x 576 RGBA animation frames.
- ../adventure-lord-attack.tres: Godot SpriteFrames, idle and non-looping attack.
- ../../../docs/adventure-art-preview/attack.gif: looping review preview.

Facing: right. Suggested foot anchor: (320, 550). For AnimatedSprite2D with
centered=false, offset=(-320, -550) places this anchor at the node origin.
Attack phases: guard, anticipation, downswing, impact, recovery, guard.
Durations: 0.32, 0.16, 0.06, 0.12, 0.14, 0.28 seconds; total 1.08 seconds.
Retiming in gameplay should match the actual attack event; this asset contains
no gameplay damage calls and is not yet connected to the live battle renderer.

Rebuild extracted frames and preview with tools/build_adventure_animation.ps1
from the project root (requires FFmpeg). Extraction retains the source art;
non-uniform source regions and corner masks exclude adjacent atlas poses.

Validation: inspect opaque parchment proofs to judge alpha correctly. Some
image viewers display RGB hidden beneath alpha=0 as a coloured haze; these
pixels do not appear in normal alpha compositing. GIF is a preview only;
use RGBA PNG frames for the game to retain antialiased transparent edges.
