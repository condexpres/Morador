"""Recorta a mão da logo original e amplia mantendo as bordas limpas."""
import sys
import numpy as np
from PIL import Image

original, saida = sys.argv[1], sys.argv[2]
X0, Y0, X1, Y1 = 64, 204, 227, 278          # região da mão na imagem original (500x500)
im = Image.open(original).convert('RGBA').crop((X0, Y0, X1, Y1))

# 1) Amplia 8x com suavização (as curvas ficam redondas, não serrilhadas)
grande = im.resize((im.width * 8, im.height * 8), Image.BICUBIC)
a = np.asarray(grande).astype(np.float32)
r, g, b, alfa = a[..., 0], a[..., 1], a[..., 2], a[..., 3]

# 2) Mantém só os pixels verde-água (a mão); fundo e caixa ficam transparentes
mao = (g - r > 45) & (b - r > 45) & (alfa > 110)

# 3) Duas cores chapadas, como na logo: contorno escuro e preenchimento claro
escuro = np.array([0, 132, 132], np.float32)     # #008484
claro = np.array([102, 198, 194], np.float32)    # #66C6C2
usa_claro = g > 165
cor = np.where(usa_claro[..., None], claro, escuro)
saida_px = np.zeros_like(a)
saida_px[..., :3] = cor
saida_px[..., 3] = np.where(mao, 255, 0)

# 4) Reduz 2x para suavizar a borda (fica 4x o tamanho original)
img = Image.fromarray(saida_px.astype(np.uint8), 'RGBA')
img = img.resize((im.width * 4, im.height * 4), Image.LANCZOS)
img.save(saida)
print('mão recortada:', img.size, 'origem', (X0, Y0, X1, Y1))
