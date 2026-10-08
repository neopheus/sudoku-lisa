"""Reproduce a focused contrast audit from the current SwiftUI sRGB palette.
These are calculated ratios, not measurements of iPhone display output.
Sources: LisaTheme.swift, GameView.swift/SudokuCellContent, HintCoachView.swift.
"""
import json

def composite(fg, bg, alpha):
    return tuple(f * alpha + b * (1 - alpha) for f, b in zip(fg, bg))

def luminance(rgb):
    return sum((v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) * w
               for v, w in zip(rgb, (0.2126, 0.7152, 0.0722)))

def ratio(fg, bg):
    lo, hi = sorted((luminance(fg), luminance(bg)))
    return round((hi + 0.05) / (lo + 0.05), 4)

paper_light, paper_dark = (1, 0.985, 0.94), (0.20, 0.14, 0.29)
blue, coral = (0.18, 0.59, 0.94), (0.79, 0.07, 0.43)
cases = [
    ('light entered digit on selected cell', (0.13, 0.39, 0.72), composite(blue, paper_light, 0.26)),
    ('light entered digit on hint cell', (0.13, 0.39, 0.72), composite((1, 0.82, 0.28), paper_light, 0.72)),
    ('dark notes on selected cell', (0.82, 0.74, 0.89), composite(blue, paper_dark, 0.42)),
    ('dark coral text on paper', coral, paper_dark),
    ('dark eliminated candidate in hint', coral, composite(coral, paper_dark, 0.12)),
    ('light eliminated candidate in hint', coral, composite(coral, paper_light, 0.12)),
]
print(json.dumps([dict(state=name, ratio=ratio(fg, bg), foreground=fg, background=bg)
                  for name, fg, bg in cases], indent=2))
