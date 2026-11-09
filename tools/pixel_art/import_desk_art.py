"""Arte de produção do balcão, um estilo por vez ou todos.

Cada estilo converte os assets pintados de art/concepts/desk/<estilo>/ em
sprites na grade de 640x360 (escala inteira, ver AtelierPixelFrame) em
art/desk/<estilo>/. O jogo escolhe o estilo em data/desk_styles/ (tela de
título); os tamanhos dos papéis e das peças são os mesmos em todos.

Requer: pillow, numpy, opencv-python.
Rodar: python tools/pixel_art/import_desk_art.py [arcane|apothecary]
"""
import sys

import desk_apothecary
import desk_arcane

STYLES = {"arcane": desk_arcane.build, "apothecary": desk_apothecary.build}


if __name__ == "__main__":
    for style in sys.argv[1:] or list(STYLES):
        STYLES[style]()
        print("desk style", style, "written to art/desk/" + style)
