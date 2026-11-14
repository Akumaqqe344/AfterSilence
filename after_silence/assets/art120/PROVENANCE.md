# After Silence 0.12 art

Generated with the built-in image_gen tool on 2026-11-15. References: the existing
`art100/house-0.png`, `tree-0.png`, `well.png`. Transparent atlas source retained
as `source.png`. `tools/prepare_art120.gd` extracts four quadrants, thresholds
alpha, crops and resizes with nearest-neighbor to native game resolutions.

Final assets: shop_front (88x80), well (40x44), gazebo (64x60), village_board
(32x34), displayed at integer 2x size. No third-party demo art was added.

Prompt:

Use case: stylized-concept. Asset type: transparent pixel-art game sprite atlas
for After Silence. Reference images are the existing house, tree and well:
match their EXACT low-resolution top-down 3/4 RPG pixel style, dark charcoal
outlines, clustered pixels, muted moss greens, honey-brown timber, blue-gray
slate, warm window light. Create a 2 by 2 evenly spaced atlas with four separate
isolated sprites, each entirely contained in its quadrant with wide transparent
margins. Top left: small cozy village shop in the same architecture as reference
house, south-facing entrance centered at bottom, slate roof, timber beams, small
green awning, crates next to door, no words or letters. Top right:
well-proportioned village well, stone round rim with visible dark water, two
timber posts, pitched slate roof, rope and bucket, south-facing access, no giant
handle or tall tower. Bottom left: open wooden riverside gazebo with slate
pitched roof and two benches, south-facing steps. Bottom right: modest covered
wooden noticeboard with slate roof, paper pinned under roof, no legible writing.
No floor, terrain, sky, characters, shadows outside each sprite, text, labels or
frame. Hard crisp pixel edges, no smooth gradients, no antialiasing, no
illustration brush strokes. All four use same game perspective as references.
Actual transparent background.
