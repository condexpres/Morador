"""Monta o texto da logo com as letras desenhadas da logo original:
- "EXPRES" vira "EXPRESS" (o último S é copiado e repetido);
- o acento de "ENVÍO" sai e vai para o I de "CONDOMÍNIO".
Gera as versões clara e escura com bordas limpas (ampliação 4x)."""
import sys
import numpy as np
from PIL import Image

original, pasta = sys.argv[1], sys.argv[2]
a = np.asarray(Image.open(original).convert('RGBA')).astype(np.float32)
r, g, b, alfa = a[..., 0], a[..., 1], a[..., 2], a[..., 3] / 255

# "Quanto" cada pixel é verde-água ou laranja (0 a 1), preservando a suavização das bordas
verde = np.clip((np.minimum(g, b) - r - 25) / 60, 0, 1) * alfa
laranja = np.clip((r - np.maximum(g, b) - 40) / 60, 0, 1) * alfa

def so(m, x0, y0, x1, y1):
    saida = np.zeros_like(m)
    saida[y0:y1 + 1, x0:x1 + 1] = m[y0:y1 + 1, x0:x1 + 1]
    return saida

nome_verde = so(verde, 226, 150, 480, 216)        # COND
nome_laranja = so(laranja, 226, 218, 480, 280)    # EXPRES
slogan = so(verde, 40, 284, 480, 346)             # ENVÍO DE MERCADORIAS / PARA CONDOMINIO

# EXPRES → EXPRESS: repete o S (colunas 413–446) com o mesmo espaço entre letras
S = nome_laranja[218:281, 413:447].copy()
nome_laranja[218:281, 451:485] = np.maximum(nome_laranja[218:281, 451:485], S)

# Acento: tira de ENVÍO (sobre o I em x 129–133) e coloca no I de CONDOMÍNIO (x 332–335)
acento = slogan[284:292, 128:136].copy()
slogan[284:292, 128:136] = 0
dx, dy = 332 - 129, 323 - 292                     # mesma posição relativa ao I e ao topo da linha
slogan[284 + dy:292 + dy, 128 + dx:136 + dx] = np.maximum(slogan[284 + dy:292 + dy, 128 + dx:136 + dx], acento)

# Região final do texto (coordenadas da logo original)
X0, Y0, X1, Y1 = 220, 146, 492, 350
def limpar(m, fator=4):
    """Amplia com suavização e corta em 50%: letras chapadas com curvas lisas."""
    corte = Image.fromarray((m[Y0:Y1, X0:X1] * 255).astype(np.uint8), 'L')
    grande = corte.resize((corte.width * fator * 2, corte.height * fator * 2), Image.BICUBIC)
    nitido = grande.point(lambda v: 255 if v >= 128 else 0)
    return nitido.resize((corte.width * fator, corte.height * fator), Image.LANCZOS)

def montar(cores, nome):
    camadas = [(limpar(nome_verde), cores[0]), (limpar(nome_laranja), cores[1])]
    tamanho = camadas[0][0].size
    img = Image.new('RGBA', tamanho, (0, 0, 0, 0))
    for mascara, cor in camadas:
        img.paste(Image.new('RGBA', tamanho, cor), (0, 0), mascara)
    img.save(f'{pasta}/{nome}')

def montar_slogan(cor, nome):
    # O slogan começa em x=40 (mais à esquerda que o nome), então tem recorte próprio
    global X0
    antigo, X0 = X0, 40
    m = limpar(slogan)
    X0 = antigo
    img = Image.new('RGBA', m.size, (0, 0, 0, 0))
    img.paste(Image.new('RGBA', m.size, cor), (0, 0), m)
    img.save(f'{pasta}/{nome}')

montar(('#008484', '#CC4818'), 'nome_claro.png')
montar(('#34BDB4', '#F0703F'), 'nome_escuro.png')
montar_slogan('#008484', 'slogan_claro.png')
montar_slogan('#8ED9D3', 'slogan_escuro.png')
print('nome: x', X0, '→', X1, ' y', Y0, '→', Y1, '| slogan: x 40 →', X1)
