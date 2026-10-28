const { app, BrowserWindow } = require('electron');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
app.setPath('userData', fs.mkdtempSync(path.join(os.tmpdir(), 'portfolio-writing-test-')));
app.whenReady().then(async () => {
  const win = new BrowserWindow({ show: false, width: 1280, height: 1000,
    webPreferences: { nodeIntegration: false, sandbox: true, contextIsolation: true } });
  let failed = false;
  try {
    await win.loadFile(path.resolve(__dirname, '../ecrits.html'));
    const info = await win.webContents.executeJavaScript(`(() => {
      const card=document.querySelector('.writing-card');
      return {title:card.querySelector('h3').textContent, blurb:card.querySelector('.writing-content p').textContent,
        expectedTitle:portfolioWritingData.title, expectedBlurb:portfolioWritingData.backCover,
        imageLoaded:card.querySelector('img').naturalWidth>0, pdf:card.querySelector('.pdf-action').href};
    })()`);
    assert.equal(info.title, info.expectedTitle);
    assert.equal(info.blurb, info.expectedBlurb);
    assert.equal(info.imageLoaded, true);
    assert.ok(info.pdf.includes('?v='));
    assert.ok(!info.title.includes("L'Astre Noir"));
    const output = path.resolve(__dirname, '../../Montage/controles-interface/publication-roman/site.png');
    fs.mkdirSync(path.dirname(output), { recursive: true });
    await new Promise(resolve => setTimeout(resolve, 400));
    fs.writeFileSync(output, (await win.webContents.capturePage()).toPNG());
    process.stdout.write('Titre, résumé, couverture et lien PDF versionné affichés correctement.\n');
  } catch (error) { failed = true; process.stderr.write(error.stack + '\n'); }
  finally { win.destroy(); app.exit(failed ? 1 : 0); }
});
