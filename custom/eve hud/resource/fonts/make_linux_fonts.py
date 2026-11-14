#!/usr/bin/env python3
"""Build renamed copies of the Microsoft core fonts for TF2 on Linux.

Linux TF2 never draws a scheme font named "Verdana", "Tahoma", "Arial" or
"Trebuchet MS": the engine swaps those names for its own fallbacks
(Liberation Sans / DejaVu Sans / Fira Sans) before it ever looks for a file,
so installing or bundling the real fonts does nothing. A font registered
under any other family name *is* used (same mechanism as the crosshair font),
so this script writes copies with the family renamed to "EveVerdana",
"EveTahoma" and "EveTrebuchet". clientscheme.res / chatscheme.res pick those
names under [$POSIX] and keep the real names for Windows.

The .ttf outputs are generated (and ignored by git) because the Microsoft
fonts may not be redistributed. Re-run after a fresh clone:

    python3 make_linux_fonts.py            # needs: pip install fonttools
    python3 make_linux_fonts.py /path/to/msfonts

The pixel fonts (evechat*.ttf) also need: pip install freetype-py

Source fonts come from the ttf-ms-fonts / corefonts package
(/usr/share/fonts/TTF by default).
"""
import os
import sys

from fontTools.ttLib import TTFont

# output file -> (new family, candidate source file names, case-insensitive)
FONTS = {
    "eveverdana.ttf":    ("EveVerdana",   ["verdana.ttf"]),
    "eveverdanab.ttf":   ("EveVerdana",   ["verdanab.ttf"]),
    "eveverdanai.ttf":   ("EveVerdana",   ["verdanai.ttf"]),
    "eveverdanaz.ttf":   ("EveVerdana",   ["verdanaz.ttf"]),
    "evetahoma.ttf":     ("EveTahoma",    ["tahoma.ttf"]),
    "evetahomabd.ttf":   ("EveTahoma",    ["tahomabd.ttf"]),
    "evetrebuc.ttf":     ("EveTrebuchet", ["trebuc.ttf"]),
    "evetrebucbd.ttf":   ("EveTrebuchet", ["trebucbd.ttf"]),
    "evetrebucit.ttf":   ("EveTrebuchet", ["trebucit.ttf"]),
    "evetrebucbi.ttf":   ("EveTrebuchet", ["trebucbi.ttf"]),
}


def find(src_dir, names):
    files = {f.lower(): f for f in os.listdir(src_dir)}
    for n in names:
        if n in files:
            return os.path.join(src_dir, files[n])
    return None


def rename(src, dst, family):
    font = TTFont(src)
    names = font["name"]
    style = names.getDebugName(2) or "Regular"
    full = family if style == "Regular" else f"{family} {style}"
    ps = f"{family}-{style.replace(' ', '')}"
    for rec in list(names.names):
        if rec.nameID in (1, 16):
            names.setName(family, rec.nameID, rec.platformID, rec.platEncID, rec.langID)
        elif rec.nameID in (3, 4):
            names.setName(full, rec.nameID, rec.platformID, rec.platEncID, rec.langID)
        elif rec.nameID == 6:
            names.setName(ps, rec.nameID, rec.platformID, rec.platEncID, rec.langID)
    font.save(dst)
    return style


# ---------------------------------------------------------------------------
# Pixel fonts: Windows draws fonts without "antialias 1" (e.g. the chat font)
# as hard black-and-white pixels with GDI's hinted spacing. Linux TF2 always
# antialiases, so these fonts store that black-and-white rendering as square
# outlines, one 64-unit square per pixel. Drawn at exactly PPEM pixels they
# land on the pixel grid and stay crisp, i.e. they look like Windows.
# output file -> (family, source candidates, ppem, OS/2 weight)
PIXEL_FONTS = {
    "evechat14.ttf": ("EveVerdanaChat14", ["verdanab.ttf"], 14, 700),
}
UNIT = 64  # font units per pixel


def build_pixel_font(src, dst, family, ppem, weight):
    import freetype  # pip install freetype-py
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.ttLib import newTable
    from fontTools.ttLib.tables import ttProgram

    srcfont = TTFont(src)
    cmap = srcfont.getBestCmap()
    hdmx = srcfont["hdmx"].hdmx.get(ppem) if "hdmx" in srcfont else None
    os2 = srcfont["OS/2"]
    upem_src = srcfont["head"].unitsPerEm
    face = freetype.Face(src)
    face.set_pixel_sizes(0, ppem)
    flags = freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO

    glyphs, metrics, outmap = {".notdef": None}, {".notdef": (ppem // 2 * UNIT, 0)}, {}
    order = [".notdef"]
    for cp, gname in sorted(cmap.items()):
        if gname in glyphs:
            outmap[cp] = gname
            continue
        face.load_glyph(srcfont.getGlyphID(gname), flags)
        g = face.glyph
        bm = g.bitmap
        adv = hdmx[gname] if hdmx and gname in hdmx else (g.advance.x + 32) >> 6
        pen = TTGlyphPen(None)
        for row in range(bm.rows):
            line = bm.buffer[row * bm.pitch:(row + 1) * bm.pitch]
            bits = [(line[x >> 3] >> (7 - (x & 7))) & 1 for x in range(bm.width)]
            x = 0
            while x < bm.width:
                if not bits[x]:
                    x += 1
                    continue
                x0 = x
                while x < bm.width and bits[x]:
                    x += 1
                left, right = (g.bitmap_left + x0) * UNIT, (g.bitmap_left + x) * UNIT
                top = (g.bitmap_top - row) * UNIT
                bottom = top - UNIT
                pen.moveTo((left, bottom))   # clockwise = filled in TrueType
                pen.lineTo((left, top))
                pen.lineTo((right, top))
                pen.lineTo((right, bottom))
                pen.closePath()
        glyphs[gname] = pen.glyph()
        metrics[gname] = (adv * UNIT, glyphs[gname].xMin if hasattr(glyphs[gname], "xMin") else 0)
        outmap[cp] = gname
        order.append(gname)
    glyphs[".notdef"] = TTGlyphPen(None).glyph()

    # Windows (GDI) cell: ascent/descent from usWinAscent/usWinDescent,
    # rounded like GDI (Verdana at 14px: 14 + 3 = the 17px cell of "tall 17")
    asc = round(os2.usWinAscent * ppem / upem_src)
    desc = round(os2.usWinDescent * ppem / upem_src)
    fb = FontBuilder(ppem * UNIT, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(outmap)
    fb.setupGlyf(glyphs)
    for n in order:
        glyphs[n].recalcBounds(fb.font["glyf"])
    fb.setupHorizontalMetrics({n: (metrics[n][0], getattr(glyphs[n], "xMin", 0)) for n in order})
    fb.setupHorizontalHeader(ascent=asc * UNIT, descent=-desc * UNIT)
    fb.setupOS2(usWeightClass=weight, fsSelection=0x20 if weight >= 600 else 0x40,
                sTypoAscender=asc * UNIT, sTypoDescender=-desc * UNIT, sTypoLineGap=0,
                usWinAscent=asc * UNIT, usWinDescent=desc * UNIT)
    style = "Bold" if weight >= 600 else "Regular"
    fb.setupNameTable({"familyName": family, "styleName": style,
                       "uniqueFontIdentifier": f"{family}-{style}",
                       "fullName": f"{family} {style}", "psName": f"{family}-{style}"})
    fb.setupPost()
    fb.setupHead(unitsPerEm=ppem * UNIT, macStyle=1 if weight >= 600 else 0)
    # A font without any hinting program gets FreeType's auto-hinter, which
    # would move the pixel edges. A no-op 'prep' keeps the native (no-op) path.
    prep = newTable("prep")
    prep.program = ttProgram.Program()
    prep.program.fromAssembly(["SVTCA[0]"])
    fb.font["prep"] = prep
    fb.font["maxp"].maxSizeOfInstructions = 1
    fb.font.save(dst)
    return len(order)


# ---------------------------------------------------------------------------
# Outline fonts: the Linux engine copies each glyph into its texture at
# column 0 (CLinuxFont::GetCharRGBA ignores the outline size), while the
# glyph width reserves 1px of outline on both sides. Result: the left
# outline is clipped and the glyph sits 1px too far left. These copies add an
# invisible zero-area point 1px left of every glyph (FreeType sizes the bitmap
# from the outline's bounding box, so the bitmap gains an empty first column
# for the outline) and move the ink 1px right at SHIFT_PPEM to cancel the
# offset. Hinting is stripped because the extra point would break the
# glyph instructions; a no-op 'prep' keeps FreeType's auto-hinter away.
# output file -> (family, source candidates, ppem the 1px shift is exact for)
OUTLINE_FONTS = {
    "eveverdanaol.ttf": ("EveVerdanaOL", ["verdana.ttf"], 17),
}


def build_outline_font(src, dst, family, shift_ppem):
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import newTable
    from fontTools.ttLib.tables import ttProgram

    font = TTFont(src)
    upem = font["head"].unitsPerEm
    px = upem / shift_ppem              # one pixel at shift_ppem, in font units
    gs = font.getGlyphSet()
    glyf, hmtx = font["glyf"], font["hmtx"]
    new = {}
    for name in font.getGlyphOrder():
        adv, _ = hmtx[name]
        pen = TTGlyphPen(gs)
        gs[name].draw(TransformPen(pen, (1, 0, 0, 1, round(px), 0)))
        g = pen.glyph()
        g.recalcBounds(glyf)
        if g.numberOfContours:
            x = int(g.xMin - round(px))
            pen = TTGlyphPen(gs)
            gs[name].draw(TransformPen(pen, (1, 0, 0, 1, round(px), 0)))
            pen.moveTo((x, g.yMin))          # zero-area padding contour
            pen.lineTo((x, g.yMin + 1))
            pen.closePath()
            g = pen.glyph()
            g.recalcBounds(glyf)
        new[name] = (g, adv)
    for name, (g, adv) in new.items():
        glyf[name] = g
        hmtx[name] = (adv, getattr(g, "xMin", 0))
    for tag in ("fpgm", "cvt ", "hdmx", "LTSH", "VDMX", "DSIG"):
        if tag in font:
            del font[tag]
    prep = newTable("prep")
    prep.program = ttProgram.Program()
    prep.program.fromAssembly(["SVTCA[0]"])
    font["prep"] = prep
    maxp = font["maxp"]
    maxp.maxSizeOfInstructions = 1
    maxp.maxFunctionDefs = maxp.maxInstructionDefs = maxp.maxStackElements = 0
    maxp.maxTwilightPoints = maxp.maxStorage = 0
    maxp.maxZones = 1
    names = font["name"]
    style = names.getDebugName(2) or "Regular"
    for rec in list(names.names):
        if rec.nameID in (1, 16):
            names.setName(family, rec.nameID, rec.platformID, rec.platEncID, rec.langID)
        elif rec.nameID in (3, 4):
            names.setName(f"{family} {style}" if style != "Regular" else family,
                          rec.nameID, rec.platformID, rec.platEncID, rec.langID)
        elif rec.nameID == 6:
            names.setName(f"{family}-{style.replace(' ', '')}", rec.nameID,
                          rec.platformID, rec.platEncID, rec.langID)
    font["head"].flags &= ~(1 << 3)     # no "instructions may alter advance"
    font.save(dst)
    return len(new)


def main():
    src_dir = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/TTF"
    out_dir = os.path.dirname(os.path.abspath(__file__))
    missing = 0
    for out, (family, cands) in FONTS.items():
        src = find(src_dir, cands)
        if not src:
            print(f"MISSING {cands[0]} in {src_dir}")
            missing += 1
            continue
        style = rename(src, os.path.join(out_dir, out), family)
        print(f"{out:18} <- {os.path.basename(src):14} ({family} {style})")
    for out, (family, cands, ppem) in OUTLINE_FONTS.items():
        src = find(src_dir, cands)
        if not src:
            print(f"MISSING {cands[0]} in {src_dir}")
            missing += 1
            continue
        n = build_outline_font(src, os.path.join(out_dir, out), family, ppem)
        print(f"{out:18} <- {os.path.basename(src):14} ({family}, outline-padded, {n} glyphs)")
    for out, (family, cands, ppem, weight) in PIXEL_FONTS.items():
        src = find(src_dir, cands)
        if not src:
            print(f"MISSING {cands[0]} in {src_dir}")
            missing += 1
            continue
        n = build_pixel_font(src, os.path.join(out_dir, out), family, ppem, weight)
        print(f"{out:18} <- {os.path.basename(src):14} ({family}, {ppem}px pixel font, {n} glyphs)")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
