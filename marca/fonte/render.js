// Converte os SVGs em PNG (fundo transparente) usando o Chromium
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const [dir, ...pedidos] = process.argv.slice(2); // pedidos: arquivo.svg:largura:saida.png[:fundo]
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  for (const ped of pedidos) {
    const [svg, largura, png, fundo] = ped.split(':');
    const conteudo = fs.readFileSync(path.join(dir, svg), 'utf8');
    await p.setContent(`<html><body style="margin:0;background:${fundo || 'transparent'}"><div id="a" style="width:${largura}px;line-height:0">${conteudo.replace('<svg ', '<svg style="width:100%;height:auto" ')}</div></body></html>`);
    await p.evaluate(() => document.fonts.ready);
    await p.waitForTimeout(150);
    await p.locator('#a').screenshot({ path: path.join(dir, png), omitBackground: !fundo });
  }
  await b.close();
})();
