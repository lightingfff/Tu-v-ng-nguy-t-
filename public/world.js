export const width = 1536;
export const height = 1024;
export const plaza = [
  [641, 475], [891, 475], [929, 519], [1034, 522],
  [1206, 605], [1320, 724], [1212, 913], [1075, 966],
  [413, 966], [235, 864], [175, 727], [411, 606], [580, 523],
];
export const guide = { x: 633, y: 621 };
export const altar = { x: 767, y: 483 };
export const fragments = [
  { x: 449, y: 710 },
  { x: 1060, y: 651 },
  { x: 975, y: 865 },
];
export const canWalk = (x, y) => {
  let inside = false;
  for (let i = 0, j = plaza.length - 1; i < plaza.length; j = i++) {
    const [ax, ay] = plaza[i];
    const [bx, by] = plaza[j];
    if ((ay > y) !== (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax) {
      inside = !inside;
    }
  }
  return inside;
};
export const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
