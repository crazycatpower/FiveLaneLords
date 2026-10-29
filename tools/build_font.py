"""Build assets/fonts/ManuscriptSerif-subset.ttf from Noto Serif TC (SIL OFL 1.1).

Only the characters the game actually uses are kept, so the font ships small and the
game looks the same on machines without Noto Serif TC. Re-run after adding new text:
    python tools/build_font.py [path/to/NotoSerifTC-VF.ttf]
"""
import pathlib, sys
from fontTools import subset
from fontTools.ttLib import TTFont

root = pathlib.Path(__file__).resolve().parent.parent
source = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "C:/Windows/Fonts/NotoSerifTC-VF.ttf")
chars = set(chr(c) for c in range(32, 127)) | set("·—–×→↑↓…「」『』（）、，。：；！？％／＋−Ⅱ▶■◆★♛")
for f in list(root.glob("*.gd")) + list(root.glob("tools/*.gd")):
    chars |= set(f.read_text(encoding="utf-8"))
chars = {c for c in chars if c.isprintable() and c not in "\t\r\n"}
font = TTFont(source)
# Pin the variable font to its Regular weight: Godot then renders exactly one style.
if "fvar" in font:
    from fontTools.varLib import instancer
    font = instancer.instantiateVariableFont(font, {"wght": 500})
options = subset.Options()
options.layout_features = ["*"]
options.name_IDs = ["*"]
sub = subset.Subsetter(options)
sub.populate(text="".join(sorted(chars)))
sub.subset(font)
out = root / "assets" / "fonts" / "ManuscriptSerif-subset.ttf"
out.parent.mkdir(parents=True, exist_ok=True)
font.save(out)
print(f"{len(chars)} characters -> {out} ({out.stat().st_size // 1024} KB)")
