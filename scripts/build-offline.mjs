import { build } from 'esbuild';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as images from '../public/assets.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const publicDir = join(root, 'public');
const output = join(root, 'dist', 'Song-Nguyet-Web.html');
const [page, css] = await Promise.all([
  readFile(join(publicDir, 'index.html'), 'utf8'),
  readFile(join(publicDir, 'style.css'), 'utf8'),
]);

// Bundle all modules and images so the adventure can open from a file URL.
const imageExports = await Promise.all(Object.entries(images).map(async ([name, path]) => {
  const data = await readFile(join(publicDir, path));
  const mime = path.endsWith('.png') ? 'image/png' : 'image/webp';
  return `export const ${name} = 'data:${mime};base64,${data.toString('base64')}';`;
}));
const result = await build({
  entryPoints: [join(publicDir, 'game.js')],
  bundle: true,
  format: 'iife',
  write: false,
  plugins: [{
    name: 'offline-images',
    setup(builder) {
      builder.onLoad({ filter: /[/\\]assets\.js$/ }, () => ({
        contents: imageExports.join('\n'),
      }));
    },
  }],
});
const standaloneCSS = css.replace(`url('${images.panoramaUrl}')`, 'none');
const script = result.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const html = page
  .replace('<body>', '<body data-offline-only>')
  .replace('<link rel="stylesheet" href="./style.css">', () => '<style>' + standaloneCSS + '</style>')
  .replace(/<link rel="preload"[^>]*>/, '')
  .replace('<script type="module" src="./game.js"></script>', () => '<script>' + script + '</script>');
await mkdir(dirname(output), { recursive: true });
await writeFile(output, html);
console.log(output);
