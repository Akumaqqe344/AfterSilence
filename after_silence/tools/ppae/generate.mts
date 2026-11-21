import { deflateSync, crc32 } from 'node:zlib';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { PNG } from 'pngjs';

const project = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const engine = resolve(process.argv[2] || resolve(project, 'work/ppae-engine'));
const revision = 'ed98da220d9ac30e35b23da555d60f5a0ec84a51';
const actualRevision = execFileSync('git', ['-C', engine, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
if (actualRevision !== revision) throw new Error('Expected PPAE revision ' + revision + ', found ' + actualRevision);
const p = await import(pathToFileURL(resolve(engine, 'dist/library/index.js')).href);
const output = resolve(process.argv[3] || resolve(project, 'after_silence/assets/ppae0300'));
mkdirSync(output, { recursive: true });

type Color = { r: number; g: number; b: number; a: number };
type Pixels = {
  width: number; height: number; data: Uint8ClampedArray;
  getPixel(x: number, y: number): Color;
  setPixel(x: number, y: number, c: Color): void;
  fillRect(x: number, y: number, w: number, h: number, c: Color): void;
};
type Rect = [number, number, number, number];
type Paint = { buffer: Pixels; pivotTexel: readonly [number, number] };

const seed = 304211;
const tile = { ...p.DEFAULT_STYLE_PROFILES['classic-8x8'], canonicalTileTexels: 16 };
const actors = p.DEFAULT_STYLE_PROFILES['classic-8x8'];
const nature = new p.NatureGenerator();
const textures = new p.TerrainAutotiler();
const roads = new p.DirectionalRoadRenderer();
const water = new p.LiquidTileGenerator();
const structures = new p.StructureGenerator();
const rooms = new p.InteriorGenerator();
const lighting = new p.PixelPerfectLightingEngine();
const wind = new p.WeatherAndWindSystem();
const compiler = new p.SpritesheetCompiler();
const hud = new p.PixelNineSliceLibrary();
const rgba = (hex: string, a = 255): Color => ({ ...p.hexToRgba('#' + hex), a });
const data: Record<string, unknown> = { revision, seed, tile: 16, directions: p.ALL_DIRECTIONS_8 };
const profiles = JSON.parse(readFileSync(new URL('./profiles.json', import.meta.url), 'utf8'));

function chunk(type: string, body: Buffer): Buffer {
  const name = Buffer.from(type);
  const header = Buffer.alloc(8);
  header.writeUInt32BE(body.length);
  name.copy(header, 4);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([name, body])));
  return Buffer.concat([header, body, checksum]);
}

function png(name: string, pixels: Pixels): void {
  const { width, height } = pixels;
  if (width < 1 || height < 1 || pixels.data.length !== width * height * 4) throw new Error('Invalid PNG: ' + name);
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 6;
  const raw = Buffer.alloc(height * (width * 4 + 1));
  for (let y = 0; y < height; y++) {
    raw.set(pixels.data.subarray(y * width * 4, (y + 1) * width * 4), y * (width * 4 + 1) + 1);
  }
  writeFileSync(resolve(output, name + '.png'), Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]));
}

function blit(source: Pixels, destination: Pixels, x: number, y: number, rect: Rect = [0, 0, source.width, source.height]): void {
  const [sx, sy, w, h] = rect;
  for (let iy = 0; iy < h; iy++) for (let ix = 0; ix < w; ix++) {
    const c = source.getPixel(sx + ix, sy + iy);
    if (c.a) destination.setPixel(x + ix, y + iy, c);
  }
}

function colorGrade(source: Pixels, from: Color[], to: Color[]): Pixels {
  const shades = new Map<number, Color>();
  const result: Pixels = new p.PixelBuffer(source.width, source.height);
  for (let y = 0; y < source.height; y++) for (let x = 0; x < source.width; x++) {
    const c = source.getPixel(x, y);
    if (!c.a) continue;
    const key = (c.r << 16) | (c.g << 8) | c.b;
    let shade = shades.get(key);
    if (!shade) {
      let distance = Infinity;
      for (let i = 0; i < from.length; i++) {
        const ref = from[i];
        const d = (ref.r - c.r) ** 2 + (ref.g - c.g) ** 2 + (ref.b - c.b) ** 2;
        if (d < distance) {
          distance = d;
          shade = to[i];
        }
      }
      shades.set(key, shade!);
    }
    result.setPixel(x, y, { ...shade!, a: c.a });
  }
  return result;
}

function terrainColors(material: string): Color[] {
  const m = p.TERRAIN_MATERIALS[material];
  return [m.baseColorHex, m.shadowColorHex, m.highlightColorHex, m.accentColorHex, m.transitionBorderHex].map(p.hexToRgba);
}

function materialAtlas(name: string, material: string, palette: string[], makeTile: (index: number) => Pixels, grid = 20): void {
  const atlas: Pixels = new p.PixelBuffer(grid * 16, grid * 16);
  const variants = Array.from({ length: 16 }, (_, i) => colorGrade(makeTile(i), terrainColors(material), palette.map(x => rgba(x))));
  for (let y = 0; y < grid; y++) for (let x = 0; x < grid; x++) {
    const index = Math.trunc(Math.abs(Math.imul(x + 37, 73856093) ^ Math.imul(y + seed, 19349663))) % 16;
    blit(variants[index], atlas, x * 16, y * 16);
  }
  png(name, atlas);
}

for (const [zone, config] of Object.entries(profiles.ground) as [string, {material: string; colors: string[]}][]) {
  const template = new p.DeterministicWorldField(seed + zone.length * 31);
  const sample = template.sampleWorldTile.bind(template);
  // An isolated material bank supplies Godot's existing TileMapLayer. PPAE's
  // chunk samples may tint and vary tiles, but cannot spawn anything into the map.
  template.sampleWorldTile = (x: number, y: number) => ({
    ...sample(x,y), material: config.material, autotileMask: 255,
    transitionNeighborMaterial: undefined, propSpawn: undefined,
  });
  const chunk = new p.ChunkWorldRenderer(template).renderChunk(0,0,tile,0,8,20);
  png('grass_' + zone, colorGrade(chunk.terrainBuffer,terrainColors(config.material),config.colors.map(x=>rgba(x))));
}
materialAtlas('dirt', 'dirt_soil', profiles.road, i => textures.generateSeamlessBaseTile('dirt_soil', tile, i));
materialAtlas('gravel', 'dirt_soil', profiles.road, i => roads.renderRoadTile(
  'dirt_soil', 17, tile, textures.generateSeamlessBaseTile('dirt_soil', tile, i), i).buffer, 6);
const sand = textures.composeAutotiledSurface('sand_beach', 255, tile, 'meadow_grass', 7);
png('sand', colorGrade(sand, terrainColors('sand_beach'), profiles.shore.map((x: string) => rgba(x))));

const stones = colorGrade(textures.generateSeamlessBaseTile('rock_cliff',tile,9),terrainColors('rock_cliff'),
  ['ada086','8c806d','baad94','b2a387','797366'].map(x=>rgba(x)));
const plaza: Pixels = new p.PixelBuffer(64,48);
for (let y=0;y<48;y++) for (let x=0;x<64;x++) {
  const row=Math.floor(y/8), shifted=x+row*8, column=Math.floor(shifted/16);
  const s=stones.getPixel((shifted+row*3)%16,(y+column*5)%16);
  const lx=shifted%16, ly=y%8;
  const bevel=lx===1 || ly===1 ? 13 : lx===15 || ly===7 ? -13 : 0;
  const shade=((row*13+column*19)%5-2)*2+bevel;
  plaza.setPixel(x,y,lx===0 || ly===0 || lx===1 && ly===7 ? rgba('817966') : {r:s.r+shade,g:s.g+shade,b:s.b+shade,a:255});
}
png('plaza',plaza);

const shallowFrames = new p.PixelBuffer(8 * 16, 32);
for (const [row, name] of ['shallow_water', 'deep_water'].entries()) {
  for (let n = 0; n < 8; n++) {
    const frame = water.generateAnimatedFrame(name, n, 8, 255, tile);
    blit(colorGrade(frame, terrainColors(name), profiles.liquid[row].map((x: string) => rgba(x))), shallowFrames, n * 16, row * 16);
  }
}
png('liquid', shallowFrames);
const stillWater = new p.PixelBuffer(80, 80);
for (let x = 0; x < 80; x += 16) for (let y = 0; y < 80; y += 16) blit(shallowFrames, stillWater, x, y, [0, 16, 16, 16]);
png('water', stillWater);

for (const [zone, colors] of Object.entries(profiles.floor) as [string, string[]][]) {
  const floorProfile = { ...tile, canonicalTileTexels: 64, moduleSize: 16 };
  const from = rooms.renderInterior({
    ...p.DEFAULT_COTTAGE_INTERIOR, widthInTiles: 7, heightInTiles: 7, furniture: [],
    floorMaterialHex: '#' + colors[0], floorAccentHex: '#' + colors[1],
  }, floorProfile);
  const floor = new p.PixelBuffer(320, 320);
  blit(from.roomBuffer, floor, 0, 0, [64, 64, 320, 320]);
  for (let y = 0; y < 320; y++) for (let x = 0; x < 320; x++) {
    const c = floor.getPixel(x, y);
    const grain = ((x * 89 ^ (y >> 1) * 67 ^ seed) & 23) < 3;
    if (grain && c.r === parseInt(colors[0].slice(0, 2), 16)) floor.setPixel(x, y, rgba(colors[2]));
  }
  png('floor_' + zone, floor);
}

const groundPivot: Record<string, number[]> = {};
function boundsOf(paint: Paint): Rect {
  const {buffer, pivotTexel: [px, py]} = paint;
  let left = buffer.width, right = 0, top = buffer.height, bottom = 0;
  for (let y = 0; y < buffer.height; y++) for (let x = 0; x < buffer.width; x++) {
    if (!buffer.getPixel(x, y).a) continue;
    left = Math.min(left, x); right = Math.max(right, x);
    top = Math.min(top, y); bottom = Math.max(bottom, y);
  }
  return [left - px, top - py, right - px, bottom - py];
}
function naturalSprite(name: string, paint: Paint, width: number, height: number, bounds = boundsOf(paint)): void {
  const canvas: Pixels = new p.PixelBuffer(width, height);
  const pivot = [Math.floor(width / 2), height - 4];
  const scale = Math.min((width / 2 - 2) / Math.max(-bounds[0], bounds[2], 1), (height - 6) / Math.max(-bounds[1], 1));
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const srcX = Math.round((x - pivot[0]) / scale + paint.pivotTexel[0]);
    const srcY = Math.round((y - pivot[1]) / scale + paint.pivotTexel[1]);
    const c = paint.buffer.getPixel(srcX, srcY);
    if (!c.a) continue;
    const foliage = c.g > c.r * 1.12 && c.g >= c.b * .84;
    let painted=c;
    if (foliage && name.startsWith('tree_1_')) {
      const lum=Math.max(0,c.g-26);
      painted={r:35+lum*.72,g:48+lum*.82,b:39+lum*.48,a:c.a};
    } else if (foliage && name.startsWith('tree_')) {
      painted={r:c.r*.91+18,g:c.g*.83+18,b:c.b*.81+12,a:c.a};
    } else if (name.startsWith('tree_') && c.r>c.g) {
      painted={r:c.r*.83+8,g:c.g*.89+8,b:c.b*.92+9,a:c.a};
    }
    canvas.setPixel(x, y, painted);
  }
  png(name, canvas);
  groundPivot[name] = pivot;
}
for (const [index, species] of ['oak', 'pine', 'fruit_tree'].entries()) {
  for (let variant = 0; variant < 3; variant++) {
    const stage = variant === 2 && species !== 'pine' ? 'ancient' : 'mature';
    const archetypeId = species === 'pine' ? (variant===2 ? 'pine_windswept_crag' : 'pine_alpine_spire') : undefined;
    let selected = seed + index * 3407 + variant * 211;
    let fullness = 0;
    for (let candidate = 0; candidate < 8; candidate++) {
      const s = seed + index * 3407 + variant * 211 + candidate * 73;
      const tree = nature.generateTreeStage(species, stage, actors, s, {archetypeId});
      const [x0, y0, x1, y1] = boundsOf(tree);
      let leaves = 0;
      for (let k = 0; k < tree.buffer.data.length; k += 4) {
        const [r, g, b, a] = tree.buffer.data.subarray(k, k + 4);
        if (a && g > r * 1.12 && g > b * 1.12) leaves++;
      }
      const density = leaves / Math.max(1, (x1 - x0) * (y1 - y0));
      if (density > fullness) { fullness = density; selected = s; }
    }
    const rest = nature.generateTreeStage(species, stage, actors, selected, {archetypeId});
    const [x0, y0, x1, y1] = boundsOf(rest);
    for (let sway = -1; sway <= 1; sway++) {
      const tree = nature.generateTreeStage(species, stage, actors, selected, {archetypeId,windShiftTexels: sway});
      naturalSprite('tree_' + index + '_' + variant + '_' + (sway + 1), tree, 64, 68, [x0 - 3, y0 - 2, x1 + 3, y1]);
    }
  }
}
for (const [i, name] of ['flower_cluster', 'wild_flower', 'fern', 'low_shrub', 'short_grass', 'water_reed', 'mushroom_cluster'].entries()) {
  for (let v = 0; v < 3; v++) {
    naturalSprite(name + '_' + v, nature.generateSecondaryFlora(name, actors, seed + i * 137 + v * 5), 40, 48);
  }
}
for (const [i, name] of ['rounded_riverstone', 'mossy_boulder', 'surface_pebbles'].entries()) {
  naturalSprite(name, nature.generateGeologicalResource(name, actors, seed + i * 753), 64, 48);
}
data.groundPivot = groundPivot;

for (const [id, spec] of Object.entries(profiles.buildings) as [string, any][]) {
  const { base, ...overrides } = spec;
  const artifact = structures.generateStructure({
    ...p.DEFAULT_STRUCTURE_CATALOG[base], ...overrides, structureId: id, doorTileOffsetX: 2,
  }, tile);
  const { baseAndWallsBuffer: wall, roofOverlayBuffer: roof } = artifact;
  const facade: Pixels = new p.PixelBuffer(wall.width, wall.height);
  blit(wall, facade, 0, 0);
  blit(roof, facade, 0, 0);
  if (id !== 'well') {
    const w = facade.width;
    const h = facade.height;
    const center = Math.floor(w / 2);
    const eave = Math.floor(h * .52);
    const facadeShade = rgba('4e403a');
    const fascia = rgba('ab8667');
    // Rebuild the silhouette around the generated masonry and panelling.
    // The centered door, foundation and original footprint stay in place.
    for (let y = 0; y < eave; y++) {
      const width = Math.floor(9 + (w / 2 - 10) * y / eave);
      for (let x = 0; x < w; x++) {
        if (Math.abs(x - center) > width) facade.setPixel(x, y, rgba('000000', 0));
        else if (Math.abs(x - center) >= width - 1) facade.setPixel(x, y, x < center ? fascia : facadeShade);
      }
    }
    facade.fillRect(3, eave - 1, w - 6, 2, fascia);
    facade.fillRect(2, eave + 1, w - 4, 3, facadeShade);
    facade.fillRect(6, eave + 4, w - 12, 1, rgba('6e5846'));
    for (const x of [4, w - 8]) {
      facade.fillRect(x, eave + 2, 4, h - eave - 7, facadeShade);
      facade.fillRect(x + 1, eave + 4, 1, h - eave - 12, fascia);
    }
    for (const x of [16, w - 24]) {
      facade.fillRect(x - 1, eave + 10, 10, 15, rgba('302c2b'));
      facade.fillRect(x, eave + 11, 8, 13, rgba('c58c54'));
      facade.fillRect(x + 1, eave + 13, 6, 5, rgba('ecc489'));
      facade.fillRect(x + 3, eave + 11, 1, 13, facadeShade);
      facade.fillRect(x, eave + 17, 8, 1, facadeShade);
      facade.fillRect(x - 2, eave + 24, 12, 2, fascia);
    }
    const steps = id === 'shop_front' ? rgba('958266') : rgba('867e72');
    facade.fillRect(center - 7, h - 4, 14, 2, fascia);
    facade.fillRect(center - 9, h - 2, 18, 2, steps);
    facade.fillRect(center + 3, h - 10, 1, 1, rgba('d6ac6d'));
  }
  const layoutFolder = ['shop_front','well'].includes(id) ? 'art120' : 'art100';
  const layoutName = id==='library' ? 'house-1' : id;
  const original = PNG.sync.read(readFileSync(resolve(project,'after_silence/assets',layoutFolder,layoutName+'.png')));
  const textured: Pixels = new p.PixelBuffer(original.width, original.height);
  const windows: Pixels = new p.PixelBuffer(original.width, original.height);
  for (let y=0;y<original.height;y++) for (let x=0;x<original.width;x++) {
    const offset=(y*original.width+x)*4;
    const [r,g,b,a]=original.data.subarray(offset,offset+4);
    if (!a) continue;
    const roofHeight=facade.height*.50;
    const roofPixel=y<original.height*.56 && b>r*.69 && (g>r*.78 || r<111);
    const lightPixel=r>141 && g>96 && b<g*.84 && r>g*1.04;
    const woodPixel=r>g*1.1 && g>b*1.08 && r>66;
    const edgePixel=(r+g+b)/3<53;
    const sampleX=(Math.floor(x*.82)+Math.floor(y*.2))%facade.width;
    const sampleY=roofPixel ? Math.min(facade.height-1,Math.floor(y*.85)%Math.floor(roofHeight)) : Math.min(facade.height-1,Math.floor(roofHeight+y*.6)%facade.height);
    const generated=facade.getPixel(sampleX,sampleY);
    const neighbor=facade.getPixel(sampleX,Math.max(0,sampleY-1));
    const groove=generated.a && neighbor.a ? Math.max(-18, Math.min(18, (generated.r-neighbor.r)*.50)):0;
    const mark = (x*173+y*131+seed)%97;
    const chip=mark===0 && y>original.height*.22 ? 11 : mark<3 ? -6 : 0;
    const detail=edgePixel || lightPixel ? 0 : groove*(roofPixel || woodPixel ? 1 : .5)+chip;
    const warm = woodPixel ? 2 : roofPixel ? -2 : 0;
    textured.setPixel(x,y,{r:r+detail+warm,g:g+detail,b:b+detail-warm,a});
    if (lightPixel && y<original.height*.84 && (g-b)>58) windows.setPixel(x,y,rgba('ffc87e',66));
  }
  png('structure_' + id, textured);
  if (id!=='well') png('windows_' + id, windows);
}

const emptyRoom = { ...p.DEFAULT_COTTAGE_INTERIOR, widthInTiles: 8, heightInTiles: 8, furniture: [] };
const empty = rooms.renderInterior(emptyRoom, tile).roomBuffer;
for (const [id, w, h] of profiles.furniture as [string, number, number][]) {
  const placement = { id, kind: id, tileX: 2, tileY: 2, widthTiles: w, heightTiles: h, collidable: false };
  const placed = rooms.renderInterior({ ...emptyRoom, furniture: [placement] }, tile).roomBuffer;
  const art: Pixels = new p.PixelBuffer(w * 16, h * 16);
  for (let y = 0; y < art.height; y++) for (let x = 0; x < art.width; x++) {
    const pixel = placed.getPixel(x + 32, y + 32);
    const previous = empty.getPixel(x + 32, y + 32);
    if (pixel.r === previous.r && pixel.g === previous.g && pixel.b === previous.b) continue;
    const grain = ((x * 71) ^ (y * 29) ^ seed) % 11 === 0 ? 8 : 0;
    const level = (.3 * pixel.r + .59 * pixel.g + .11 * pixel.b) / 255;
    const original = pixel.r < 20 && pixel.g < 24 && pixel.b < 30 ? '342d2a' : null;
    const wood = { r: 62 + level * 129 + grain, g: 43 + level * 100 + grain, b: 36 + level * 74 + grain, a: 255 };
    art.setPixel(x, y, original ? rgba(original) : wood);
  }
  const l = art.width, t = art.height;
  if (id === 'bed') {
    art.fillRect(2, 3, l-4, 5, rgba('7b5d4e'));
    art.fillRect(5, 8, l-10, 9, rgba('d5bda0'));
    art.fillRect(7, 10, l-14, 5, rgba('e5d2b4'));
    for (let y = 18; y < t-3; y++) for (let x = 4; x < l-4; x++) {
      art.setPixel(x, y, rgba(['856865','9c7978','ad8880','96706c'][(Math.floor((x+y)/5) + Math.floor(y/6)) % 4]));
    }
    art.fillRect(4, 18, l-8, 3, rgba('c5a083'));
    art.fillRect(2, t-5, l-4, 3, rgba('745444'));
  } else if (id === 'woven_rug') {
    for (let y = 2; y < t-2; y++) for (let x = 2; x < l-2; x++) {
      const border = Math.min(x-2,y-2,l-x-3,t-y-3);
      const knot = Math.abs((x%16)-8) + Math.abs(y-t/2) * 1.5;
      art.setPixel(x,y,rgba(border===1 ? 'bc9b79' : border<=3 ? '684a4b' : knot < 6 ? 'ba9680' : (x+y)%5===0 ? '936d68' : '7f595d'));
    }
    for (let x = 4; x < l-3; x += 3) {
      art.fillRect(x,0,1,2,rgba('ac8f76')); art.fillRect(x,t-2,1,2,rgba('ac8f76'));
    }
  } else if (id === 'bookshelf') {
    const dyes=['a48168','738b7d','99757b','a79565','6f7c85'];
    art.fillRect(3,3,l-6,t-7,rgba('514036'));
    for (let y = 4; y < t-4; y += 13) {
      const bottom=Math.min(t-4,y+10);
      for (let x = 4, n = 0; x < l-4; x+=3+(n%3), n++) {
        const h=Math.min(bottom-y,5+(n*7+y)%5);
        art.fillRect(x,bottom-h,Math.min(2+n%2,l-4-x),h,rgba(dyes[n%dyes.length]));
        art.fillRect(x,bottom-2,1,1,rgba('c0a884'));
      }
      art.fillRect(3,bottom,l-6,2,rgba('977658'));
    }
  } else if (['dining_table','wooden_chair','storage_chest','alchemy_bench'].includes(id)) {
    art.fillRect(3,2,l-6,1,rgba('bc9874'));
    art.fillRect(3,t-5,l-6,1,rgba('987455'));
    for (let y = 5; y < t-6; y+=5) {
      art.fillRect(4,y,l-8,1,rgba(y%2 ? '8f6f57' : '624c40'));
      art.fillRect(6+(y*7)%(l-10),y+1,3,1,rgba('ab8566'));
    }
    if (id==='storage_chest') art.fillRect(l/2-2,t/2-2,4,4,rgba('bb9a6a'));
  } else if (id === 'potted_plant') {
    const plant=nature.generateSecondaryFlora('fern',actors,seed).buffer;
    for (let y=0;y<t-3;y++) for (let x=0;x<l;x++) {
      const leaf=plant.getPixel(Math.floor(x*plant.width/l),Math.floor(y*plant.height/(t-3)));
      if (leaf.a) art.setPixel(x,y,leaf);
      else if (y<t-7) art.setPixel(x,y,rgba('000000',0));
    }
  }
  png('interior_' + id, art);
}

const veraGuide = PNG.sync.read(readFileSync(resolve(project,'after_silence/assets/remaster0290/vera_idle.png')));
const originalRows = ['S','N','W','E','SW','SE','NW','NE'];
function drawVeraHead(atlas: Pixels, f: any): void {
  const row=originalRows.indexOf(f.direction);
  const blink=f.action==='idle' && f.frameIndex===2 ? 5 : 0;
  const center=f.atlasX+f.anchors.head_top.texelX+1;
  const top=f.atlasY+f.anchors.head_top.texelY+1;
  const x0=Math.max(f.innerX,center-15);
  const y0=Math.max(f.innerY,top-9);
  atlas.fillRect(f.atlasX,f.atlasY, f.width, Math.max(0,top+13-f.atlasY),rgba('000000',0));
  for (let y=0;y<29;y++) for (let x=0;x<31;x++) {
    const localX=Math.floor(5+x*54/31),localY=Math.floor(9+y*48/29);
    if (localY>49 && localX>=17 && localX<=46) continue;
    const src=((row*96+localY)*veraGuide.width+blink*64+localX)*4;
    const [r,g,b,a]=veraGuide.data.subarray(src,src+4);
    if (a && x0+x<f.innerX+f.innerWidth && y0+y<f.innerY+f.innerHeight) atlas.setPixel(x0+x,y0+y,{r,g,b,a});
  }
}

const sprites: Record<string, unknown> = {};
for (const [index, [id, style]] of Object.entries(profiles.people).entries()) {
  const { armor, coat, trim, hood, ...look } = style as any;
  const appearance = {
    ...p.DEFAULT_HERO_APPEARANCE, ...look, entityId: id, seed: seed + index * 371,
    beardStyle: look.beardStyle || 'none', hasFacialScar: false,
  };
  const equipment = {
    ...p.DEFAULT_HERO_EQUIPMENT, armor, armorPrimaryHex: coat, armorSecondaryHex: trim,
    mainHand: 'none', offHand: 'none', hasCape: false, backpack: 'none',
    helmet: hood ? 'ranger_hood' : 'none', helmetPrimaryHex: coat,
    bootsColorHex: '#3e352f', glovesColorHex: '#69524a',
  };
  const moves = id === 'vera' ? ['idle', 'walk', 'run', 'dodge', 'use_tool', 'attack', 'hurt'] : ['watcher','guardian'].includes(id) ? ['idle','walk','attack','hurt'] : ['idle', 'walk', 'use_tool'];
  const baked = compiler.compileCharacterSheet(appearance, equipment, actors, moves, p.ALL_DIRECTIONS_8);
  if (id==='vera') for (const f of Object.values(baked.metadata.frames)) drawVeraHead(baked.atlasBuffer,f);
  png('actor_' + id, baked.atlasBuffer);
  const sequences: Record<string, unknown> = {};
  for (const [key, ids] of Object.entries(baked.metadata.sequenceOrder) as [string, string[]][]) {
    sequences[key] = ids.map(frameId => {
      const f = baked.metadata.frames[frameId];
      return {
        rect: [f.innerX, f.innerY, f.innerWidth, f.innerHeight],
        pivot: f.pivotTexel.map((v: number) => v - baked.metadata.paddingPx),
        duration: f.durationMs, anchors: f.anchors, hitbox: f.hitbox, events: f.events,
      };
    });
  }
  sprites[id] = sequences;
}
writeFileSync(resolve(output, 'actors.json'), JSON.stringify(sprites));

for (const [id, [bg, edge, alpha]] of Object.entries(profiles.ui) as [string, [string, string, number]][]) {
  const colors = [rgba(bg, alpha), rgba(edge)];
  const skin: Pixels = hud.renderNineSlicePanel(p.DEFAULT_HUD_PANEL_CONFIG, 24, 24, ...colors);
  // Fill the sides inside the border and leave one transparent pixel at the corners.
  skin.fillRect(2, 6, 4, 12, colors[0]);
  skin.fillRect(18, 6, 4, 12, colors[0]);
  skin.fillRect(6, 2, 12, 4, colors[0]);
  skin.fillRect(6, 18, 12, 4, colors[0]);
  for (const [x, y] of [[0, 0], [23, 0], [0, 23], [23, 23]]) skin.setPixel(x, y, rgba('000000', 0));
  png('ui_' + id, skin);
}

const airFrames: Record<string, number[]> = {};
for (const [id, preset, count] of [
  ['step', 'wood_chop_chips', 4], ['land', 'wood_chop_chips', 8],
  ['spark', 'combat_hit_sparks', 8], ['mote', 'forest_fireflies', 8],
  ['ember', 'torch_dancing_embers', 6], ['smoke', 'ember_smoke', 6],
] as [string, string, number][]) {
  const particle = new p.PixelParticleEngine(64);
  particle.emitBurst(preset, 24, 30, seed, count);
  const strip: Pixels = new p.PixelBuffer(48 * 8, 48);
  for (let i = 0; i < 8; i++) {
    const frame: Pixels = new p.PixelBuffer(48, 48);
    particle.update(48, wind.sampleWindField(0, 0, i / 20));
    particle.renderParticles(frame, tile);
    blit(frame, strip, i * 48, 0);
  }
  png('fx_' + id, strip);
  airFrames[id] = [48, 48, 8, 24, 30];
}
data.fx = airFrames;
for (const [id, condition] of [['forest', 'drizzle'], ['echo', 'dense_fog']]) {
  wind.setWeatherState({
    ...p.DEFAULT_WEATHER_STATES[condition], intensity: id === 'forest' ? .28 : .12,
    fogDensity: id === 'forest' ? .05 : .20,
  });
  const strip: Pixels = new p.PixelBuffer(320 * 4, 180);
  for (let i = 0; i < 4; i++) {
    const effect = wind.renderWeatherOverlay(320, 180, { x: 0, y: 0, width: 320, height: 180 }, tile, i / 10, [], false, seed);
    blit(effect.overlayBuffer, strip, i * 320, 0);
  }
  png('weather_' + id, strip);
}
data.daylight = Array.from({length: 24}, (_, hour) => ({
  ambient: lighting.resolveAmbientProfileFromHour(hour),
  shadow: lighting.resolveSolarShadowVector(hour),
}));
wind.setWeatherState({...p.DEFAULT_WEATHER_STATES.clear,windSpeed:.62,windAngleRad:.3});
data.breeze = Array.from({length: 64}, (_, sample) => {
  const gust=wind.sampleWindField(690,444,sample/8);
  return Math.round(Math.sin(sample*Math.PI/16)*gust.strength*2);
});
const white: Pixels = new p.PixelBuffer(64, 64);
white.fillRect(0, 0, 64, 64, rgba('ffffff'));
const ambient = { ...lighting.resolveAmbientProfileFromHour(22), ambientColorHex: '#ffffff', ambientIntensity: .08 };
lighting.registerLight({
  schemaVersion: p.PPAE_SCHEMA_VERSION, lightId: 'window', kind: 'window_interior', worldX: 32, worldY: 32,
  radiusLogical: 30, colorHex: '#ffffff', intensity: .92, priority: 1,
  flickerSpeed: 0, flickerAmplitude: 0, castsShadows: false, enabled: true,
});
const lightMap = lighting.applyLightingToScene(white, {x: 0, y: 0, width: 64, height: 64}, ambient, tile).lightmapBuffer;
const glow: Pixels = new p.PixelBuffer(64, 64);
for (let y = 0; y < 64; y++) for (let x = 0; x < 64; x++) {
  const level = lightMap.getPixel(x, y).r;
  glow.setPixel(x, y, rgba('ffffff', Math.max(0, level - 26)));
}
png('light_window', glow);
writeFileSync(resolve(output, 'manifest.json'), JSON.stringify(data, null, 2) + '\n');
console.log('Generated After Silence visual resources from PPAE ' + revision.slice(0, 8) + ' -> ' + output);
