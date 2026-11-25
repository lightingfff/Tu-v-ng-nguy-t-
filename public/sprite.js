// The hair and face take ten rows of the twenty-one-row figure.
const figure = [
  '       qqqq       ',
  '      qhhhlq      ',
  '     qhhhlmgq     ',
  '    qhhlhhggq     ',
  '    qhlhhaaaqq    ',
  '   qhhhaaaaaahq   ',
  '   qhhasssassaqq  ',
  '   qhaasfsfsahhq  ',
  '    qhaattahhqq   ',
  '     qqsshqqq     ',
  '     qlssglqq     ',
  '    qlrcgcrlqq    ',
  '   qlcrcgmcrcqq   ',
  '   qlrrcccrrrqq   ',
  '   qsscmgcrrssq   ',
  '   qqccggrrcqqq   ',
  '    qcrrrrrcrq    ',
  '    qlcrcrclrq    ',
  '   qlccrrrcrrqq   ',
  '    qqqqrqqqqq    ',
  '     qzdqdzq      ',
];
const outfits = {
  teal: ['#317b87', '#40979c', '#8bd4ca'],
  tealMoon: ['#2b6874', '#429a9b', '#e9c181'],
  violet: ['#5a4088', '#8962a5', '#c7b9e2'],
  rose: ['#803e62', '#b56382', '#efb3c4'],
  amber: ['#83523f', '#b37d4f', '#f7c67c'],
};

function makeTexture([main, fold, trim]) {
  const canvas = document.createElement('canvas');
  canvas.width = 19;
  canvas.height = figure.length;
  const paint = canvas.getContext('2d');
  const ink = {
    q: '#17213b', h: '#24304d', l: trim, m: '#efc285',
    g: '#d08d57', a: '#b98179', s: '#f4c297', f: '#201f37', t: '#d68683',
    c: fold, r: main, d: '#332b43', z: '#604353',
  };
  figure.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) {
      if (row[x] === ' ') continue;
      paint.fillStyle = ink[row[x]];
      paint.fillRect(x, y, 1, 1);
    }
  });
  return canvas;
}

const textures = Object.fromEntries(Object.keys(outfits).map((color) => [color, makeTexture(outfits[color])]));

export function actorSize(y, isPortrait) {
  return isPortrait ? 4.9 : Math.max(3.2, Math.min(4.2, 3.2 + (y - 605) / 235));
}

export function drawSprite(ctx, actor, x, y, size, time) {
  const step = actor.moving ? Math.floor(time * 8) % 4 : 0;
  const lift = step % 2 ? Math.round(size * 0.45) : 0;
  const texture = textures[actor.color] ?? textures.teal;
  const shadow = ctx.createRadialGradient(x + 4, y + 2, 0, x + 4, y + 2, 26);
  shadow.addColorStop(0, '#070918b8');
  shadow.addColorStop(0.52, '#0709186e');
  shadow.addColorStop(1, 'transparent');
  ctx.save();
  ctx.translate(x, y);
  ctx.transform(1, 0.06, -0.64, 0.33, 0, 0);
  ctx.translate(-x, -y);
  ctx.fillStyle = shadow;
  ctx.fillRect(x - 30, y - 30, 68, 65);
  ctx.restore();

  ctx.fillStyle = '#1114248c';
  ctx.beginPath();
  ctx.ellipse(x - 3, y + 1, 14, 3.1, -0.07, 0, Math.PI * 2);
  ctx.fill();

  ctx.save();
  ctx.translate(x, y - lift);
  ctx.scale(actor.face, 1);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(texture, Math.round(-texture.width * size * 0.5), Math.round(-texture.height * size),
    Math.round(texture.width * size), Math.round(texture.height * size));
  ctx.restore();
}
