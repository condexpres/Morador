"""Gera a logo do Condexpress em SVG (com as fontes embutidas)."""
import base64, os, sys
D = os.path.dirname(os.path.abspath(__file__))
b64 = lambda f: base64.b64encode(open(os.path.join(D, f), 'rb').read()).decode()

CORES = {
  'claro':  dict(teal='#008484', mao='#66C6C2', laranja='#CC4818', amarelo='#E8A632', slogan='#008484'),
  'escuro': dict(teal='#34BDB4', mao='#66C6C2', laranja='#F0703F', amarelo='#F2B544', slogan='#8ED9D3'),
}

def simbolo(c, contorno='#008484'):
    # viewBox 0 0 200 140 — caixa, linhas de velocidade e mão
    return f'''
  <g stroke-linecap="round" stroke-linejoin="round">
    <line x1="18" y1="40" x2="46" y2="40" stroke="{c['amarelo']}" stroke-width="10"/>
    <line x1="8" y1="62" x2="42" y2="62" stroke="{c['amarelo']}" stroke-width="10"/>
    <rect x="62" y="10" width="96" height="86" rx="9" fill="{c['amarelo']}" stroke="{c['laranja']}" stroke-width="8"/>
    <path d="M100 10 V34 H120 V10" fill="none" stroke="{c['laranja']}" stroke-width="7"/>
    <image href="data:image/png;base64,{b64('saida/mao.png')}" x="10.25" y="56.9" width="172.9" height="78.5"/>
  </g>'''

def fontes():
    return f'''<style>
    @font-face {{ font-family: 'Oswald'; font-weight: 200 700; src: url(data:font/ttf;base64,{b64('Oswald.ttf')}) format('truetype'); }}
    @font-face {{ font-family: 'Nunito'; font-weight: 200 1000; src: url(data:font/ttf;base64,{b64('Nunito.ttf')}) format('truetype'); }}
  </style>'''

def logo(tema):
    """Logo completa nas coordenadas da logo original (500x500): símbolo + letras originais."""
    c = CORES[tema]
    contorno = '#008484' if tema == 'claro' else '#0B6F6B'
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="46 146 450 206" width="900" height="412">
  <title>Condexpress – Envio de mercadorias para condomínio</title>
  <g transform="translate(54.33 150.35) scale(0.9425)">{simbolo(c, contorno)}</g>
  <image href="data:image/png;base64,{b64(f'saida/nome_{tema}.png')}" x="220" y="146" width="272" height="204"/>
  <image href="data:image/png;base64,{b64(f'saida/slogan_{tema}.png')}" x="40" y="146" width="452" height="204"/>
</svg>'''

def simbolo_svg(fundo=None, tamanho=512, margem=0.14):
    c = CORES['claro']
    lado = 200 * (1 + 2 * margem)
    caixa = f'<rect width="{lado}" height="{lado}" fill="{fundo}"/>' if fundo else ''
    dy = (lado - 140) / 2
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {lado} {lado}" width="{tamanho}" height="{tamanho}">
  {caixa}<g transform="translate({200*margem} {dy})">{simbolo(c)}</g></svg>'''

if __name__ == '__main__':
    saida = sys.argv[1]
    os.makedirs(saida, exist_ok=True)
    open(os.path.join(saida, 'logo_condexpress.svg'), 'w').write(logo('claro'))
    open(os.path.join(saida, 'logo_condexpress_escuro.svg'), 'w').write(logo('escuro'))
    open(os.path.join(saida, 'simbolo.svg'), 'w').write(simbolo_svg())
    open(os.path.join(saida, 'icone.svg'), 'w').write(simbolo_svg(fundo='#FFFFFF', margem=0.07))
    open(os.path.join(saida, 'icone_maskable.svg'), 'w').write(simbolo_svg(fundo='#FFFFFF', margem=0.26))
    print('ok')
