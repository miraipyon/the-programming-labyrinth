from PIL import Image
import numpy as np

img_small = Image.open('assets_3/wallBreakable_small.png').convert('RGBA')
img_norm = Image.open('assets_3/wallBreakable.png').convert('RGBA')

# Create a canvas 64x128
canvas = Image.new('RGBA', (64, 128), (0,0,0,0))

# Simulate y=0 (small) and y=1 (small)
# Tile y=0 drawn at 0
canvas.alpha_composite(img_small.crop((0,0,64,66)), (0,0))
# Tile y=1 drawn at 64
canvas.alpha_composite(img_small.crop((0,0,64,66)), (0,64))
canvas.save('sim_small_small.png')

canvas2 = Image.new('RGBA', (64, 128), (0,0,0,0))
canvas2.alpha_composite(img_norm.crop((0,0,64,98)), (0,0))
canvas2.alpha_composite(img_norm.crop((0,0,64,98)), (0,64))
canvas2.save('sim_norm_norm.png')
