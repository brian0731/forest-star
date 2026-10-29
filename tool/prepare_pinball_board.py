"""Fit the entire illustrated frame to the board without cropping its ends.

Resize the nine regions separately so the empty centre absorbs the aspect
ratio change and the wood rails keep the same thickness on all four sides.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
source = Image.open(ROOT / 'output/imagegen/storybook-v2/pinball.png').convert('RGB')
frame = source.crop((90, 155, 934, 1375))
width, height = frame.size
src_x, src_y = (0, 100, width-100, width), (0, 110, height-110, height)
dst_x, dst_y = (0, 32, 872-32, 872), (0, 36, 908-36, 908)
board = Image.new('RGB', (872, 908))
for row in range(3):
    # Protect the central brass stud as well as the corner decorations.
    # Only the plain wood spans stretch horizontally on the top/bottom rails.
    row_src_x = src_x if row == 1 else (0, 100, width//2-40, width//2+40, width-100, width)
    row_dst_x = dst_x if row == 1 else (0, 32, 872//2-13, 872//2+13, 872-32, 872)
    for column in range(len(row_src_x)-1):
        tile = frame.crop((row_src_x[column], src_y[row], row_src_x[column+1], src_y[row+1]))
        tile = tile.resize((row_dst_x[column+1]-row_dst_x[column], dst_y[row+1]-dst_y[row]),
                           Image.Resampling.LANCZOS)
        board.paste(tile, (row_dst_x[column], dst_y[row]))
target = ROOT / 'assets/storybook/pinball-board-v2.webp'
board.save(target, quality=95)
print(target, board.size)
