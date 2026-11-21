const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const output = path.resolve(__dirname, '../../assets/expeditions0330');
fs.mkdirSync(output, { recursive: true });

function color(hex) {
  return (hex.length === 6 ? hex + 'ff' : hex).match(/../g).map(x => parseInt(x, 16));
}

function surface(width, height) {
  const data = Buffer.alloc(width * height * 4);
  function rect(x, y, w, h, shade) {
    const rgba = color(shade);
    for (let j = Math.max(y, 0); j < Math.min(y+h, height); j++) {
      for (let i = Math.max(x, 0); i < Math.min(x+w, width); i++) data.set(rgba, (j*width+i)*4);
    }
  }
  function pixel(x, y, shade) { rect(x, y, 1, 1, shade); }
  function line(x, y, x1, y1, shade) {
    const dx = Math.abs(x1-x), dy = -Math.abs(y1-y);
    let error = dx+dy;
    while (true) {
      pixel(x,y,shade);
      if (x===x1 && y===y1) break;
      const next=2*error;
      if (next>=dy) { error+=dy; x+=Math.sign(x1-x); }
      if (next<=dx) { error+=dx; y+=Math.sign(y1-y); }
    }
  }
  function ellipse(x, y, rx, ry, shade) {
    for (let j=-ry;j<=ry;j++) {
      const span=Math.floor(rx*Math.sqrt(1-j*j/(ry*ry)));
      rect(x-span,y+j,span*2+1,1,shade);
    }
  }
  function save(file) {
    const chunk = (type, bytes) => {
      const key=Buffer.from(type);
      let crc=0xffffffff;
      for (const byte of Buffer.concat([key,bytes])) {
        crc^=byte;
        for (let bit=0;bit<8;bit++) crc=(crc>>>1)^((crc&1)?0xedb88320:0);
      }
      const length=Buffer.alloc(4), check=Buffer.alloc(4);
      length.writeUInt32BE(bytes.length);
      check.writeUInt32BE((crc^0xffffffff)>>>0);
      return Buffer.concat([length,key,bytes,check]);
    };
    const head=Buffer.alloc(13);
    head.writeUInt32BE(width); head.writeUInt32BE(height,4); head[8]=8;head[9]=6;
    const rows=[];
    for(let j=0;j<height;j++) rows.push(Buffer.alloc(1),data.subarray(j*width*4,(j+1)*width*4));
    fs.writeFileSync(path.join(output,file),Buffer.concat([
      Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',head),
      chunk('IDAT',zlib.deflateSync(Buffer.concat(rows))),chunk('IEND',Buffer.alloc(0))
    ]));
  }
  return {rect,pixel,line,ellipse,save};
}

let seed=207;
function rand(n) { seed=(Math.imul(seed,1664525)+1013904223)>>>0; return Math.floor(seed/4294967296*n); }
function grain(s, x, y, w, h, palette, density) {
  for(let i=0;i<density;i++) s.rect(x+rand(w),y+rand(h),1+rand(4),1,palette[rand(palette.length)]);
}
function glow(s,x,y,tones) {
  for(let i=0;i<tones.length;i++) {
    const step=tones.length-i;
    s.ellipse(x,y,step*12+8,step*6+4,tones[i]);
  }
}
function floor(s,x,y,w,h,p,brick=false) {
  s.rect(x,y,w,h,p[0]);
  for(let row=y;row<y+h;row+=brick?10:8) {
    const deep=p[1+rand(2)];
    s.rect(x,row,w,1,deep);
    s.rect(x,row+1,w,1,p[3]);
    for(let offset=rand(22);offset<w-3;offset+=brick?24:37+rand(36)) {
      s.rect(x+offset,row+1,1,Math.min(brick?9:7,y+h-row-1),p[1]);
      s.pixel(x+offset+2,row+3,p[3]);
    }
  }
  grain(s,x,y,w,h,p.slice(1),Math.floor(w*h/36));
}
function casing(s,x,y,w,h,p) {
  s.ellipse(x+(w>>1),y+h-1,(w>>1)+7,5,'161d22');
  s.rect(x,y,w,h,p[0]);s.rect(x+2,y+2,w-4,h-4,p[1]);
  s.rect(x+3,y+2,w-6,2,p[2]); s.rect(x+3,y+h-5,w-6,2,p[0]);
  for(const cx of [x+4,x+w-5]) for(const cy of [y+5,y+h-7]) s.pixel(cx,cy,p[3]);
}
function shelf(s,x,y,w,h,p,items) {
  casing(s,x,y,w,h,p);
  for(let row=y+6;row<y+h-7;row+=10) {
    s.rect(x+4,row+7,w-8,1,p[2]);
    for(let col=x+6;col<x+w-9;col+=4+rand(3)) {
      const height=2+rand(6);
      const shade=items[rand(items.length)];
      s.rect(col,row+7-height,3,height,shade);
      if(height>4) s.pixel(col+1,row+5,p[2]);
    }
  }
}
function window(s,x,y,w,h,p) {
  s.rect(x-3,y-3,w+6,h+6,p[0]);s.rect(x-1,y-1,w+2,h+2,p[2]);
  s.rect(x,y,w,h,p[1]);s.rect(x+1,y+1,w-2,h-2,'405766');
  for(let dx=2;dx<w-1;dx+=2) s.rect(x+dx,y+2,1,h-3,dx%3?'58737b':'698a87');
  s.rect(x+(w>>1),y,2,h,p[2]);s.rect(x,y+(h>>1),w,2,p[2]);s.rect(x-3,y+h,w+6,2,p[3]);
}
function rug(s,x,y,w,h,p) {
  s.rect(x,y,w,h,p[0]);s.rect(x+2,y+2,w-4,h-4,p[1]);
  s.rect(x+4,y+4,w-8,h-8,p[2]);
  for(let yy=y+7;yy<y+h-6;yy+=7) for(let xx=x+7;xx<x+w-6;xx+=8) {
    s.pixel(xx,yy,p[3]);s.pixel(xx-1,yy+1,p[3]);s.pixel(xx+1,yy+1,p[3]);s.pixel(xx,yy+2,p[3]);
  }
}
const wood=['4a3b35','302b2c','59463b','685341'];
const stone=['3a4448','29343d','435058','526068'];
const violet=['434050','302f40','4d4a5e','5b5467'];
const trim=['28262f','494754','746474','a29187'];
const bronze=['27272d','55443b','987556','c29c68'];
const archive=['322a34','50333d','8b5760','bc9479'];
const books=['c08c64','788c86','a26067','928983','dab083','725379'];
const metal=['2b3039','374a53','62777b','abb0a0'];
const forest=['233c36','2e4940','365543','57725a'];

function roomShell(s,palette,wall) {
  s.rect(0,0,320,240,'171b25');
  floor(s,30,41,260,176,palette,palette===stone);
  floor(s,28,23,264,23,wall,true);
  s.rect(28,43,264,3,wall[3]);s.rect(29,45,3,172,wall[3]);s.rect(288,44,3,172,wall[3]);
  s.rect(30,211,115,5,wall[2]);s.rect(175,211,115,5,wall[2]);
  s.rect(145,211,30,7,wall[3]);s.rect(147,213,26,2,wall[1]);
  for(const x of [35,277]) casing(s,x,45,9,14,wall);
}
function tower(s,x,y,p) {
  s.ellipse(x,y,16,5,'172e2b');
  s.rect(x-2,y-26,5,26,'453c34');s.rect(x-1,y-20,1,17,'907356');
  s.ellipse(x-3,y-28,15,16,p[0]);s.ellipse(x+2,y-38,17,15,p[1]);
  s.ellipse(x-4,y-45,12,13,p[2]);s.ellipse(x-2,y-51,8,6,p[3]);
  grain(s,x-12,y-51,25,18,[p[2],p[3]],35);
}
function grass(s,x,y,p) {
  for(let i=0;i<6;i++) {
    const dx=rand(13)-6;
    s.line(x,y,x+dx,y-3-rand(8),p[1+rand(3)]);
  }
}
function paper(s,x,y,p) {
  s.rect(x-1,y+1,12,8,'24232a');s.rect(x,y,11,7,p[0]);
  s.pixel(x,y,p[1]);s.rect(x+2,y+2,6,1,p[2]);s.rect(x+3,y+4,5,1,p[2]);
}
function rope(s,x,y) {
  for(let i=0;i<4;i++) {
    s.ellipse(x,y-i,7-i,3,'a68663');s.ellipse(x,y-i,5-i,2,'584f47');
  }
}

const post=surface(320,240);
roomShell(post,wood,bronze);
window(post,57,30,26,18,bronze);window(post,236,30,27,18,bronze);
shelf(post,55,55,51,30,bronze,books);shelf(post,211,56,57,33,bronze,books);
glow(post,161,87,['534137','604834','725339']);
rug(post,119,160,76,39,['3b3035','816755','554149','866762']);
casing(post,121,105,78,23,bronze);
for(let x=127;x<190;x+=16) paper(post,x,109,['a78868','c2a77e','735a4e']);
casing(post,47,127,37,23,bronze);casing(post,232,131,35,22,bronze);
for(const x of [52,58,236,242,249]) paper(post,x,134,['c3a580','e0c59c','836950']);
window(post,234,172,20,15,bronze);
post.save('closed_post.png');

const cellar=surface(320,240);
roomShell(cellar,stone,metal);
casing(cellar,54,57,49,38,metal);casing(cellar,219,57,48,39,metal);
for(let x=59;x<261;x+=22) {
  cellar.rect(x,37,14,1,'a48054');cellar.rect(x+3,39,12,3,'45494a');
}
for(const x of [45,272]) {
  cellar.rect(x,53,9,95,'4e6468');cellar.rect(x+2,56,2,90,'849087');
  for(let y=64;y<144;y+=24) cellar.rect(x-1,y,11,3,'988268');
}
glow(cellar,160,108,['3c4b4d','435447','51604b']);
casing(cellar,114,80,91,38,metal);
for(let x=121;x<199;x+=9) { cellar.rect(x,85,4,21,'202d38');cellar.pixel(x+1,89,'95a76f'); }
casing(cellar,91,152,40,25,metal);casing(cellar,183,152,40,25,metal);
for(const x of [105,209]) rope(cellar,x,161);
cellar.line(62,180,245,180,'a18a64');cellar.line(62,182,245,182,'5d6256');
cellar.save('signal_cellar.png');

const archiveRoom=surface(320,240);
roomShell(archiveRoom,violet,archive);
window(archiveRoom,146,29,28,20,archive);
shelf(archiveRoom,48,52,58,32,archive,books);shelf(archiveRoom,214,52,57,32,archive,books);
shelf(archiveRoom,48,132,44,19,archive,books);shelf(archiveRoom,229,132,43,19,archive,books);
rug(archiveRoom,115,155,89,42,['2b2637','9c6769','694a5f','987171']);
glow(archiveRoom,159,87,['4e4153','5d4a56','73545f']);
casing(archiveRoom,123,101,73,26,archive);
for(let x=131;x<189;x+=17) paper(archiveRoom,x,107,['cbae92','f0d6ac','8c6571']);
for(const x of [58,251]) { archiveRoom.rect(x,161,7,16,'665565');archiveRoom.rect(x+2,160,3,5,'e0b279'); }
archiveRoom.save('listening_archive.png');

const tide=surface(320,240);
tide.rect(0,0,320,240,'182a39');
const water=['203b4b','2a4e5d','355968','396773'];
for(let y=9;y<226;y+=5) {
  const tone=water[rand(water.length)];
  for(let x=rand(20);x<316;x+=10+rand(16)) tide.rect(x,y+rand(3),4+rand(18),1,tone);
}
for(const [x,y] of [[37,72],[51,126],[269,76],[278,133],[82,52],[238,47]]) {
  tide.ellipse(x,y+5,10,3,'355b65');tide.rect(x-3,y-9,6,14,'473c3c');tide.rect(x-2,y-8,3,13,'8d735f');
}
floor(tide,130,45,60,51,wood);floor(tide,140,84,40,43,wood);
floor(tide,49,126,222,84,wood);
for(const x of [50,265]) {
  tide.rect(x,129,3,76,'856c59');
  for(let y=135;y<196;y+=17) casing(tide,x-2,y,7,7,bronze);
}
casing(tide,63,55,49,34,bronze);casing(tide,207,53,50,35,bronze);
casing(tide,54,135,36,24,bronze);casing(tide,232,130,31,24,bronze);
rope(tide,108,148);rope(tide,206,168);rope(tide,108,187);
for(const x of [133,185]) {
  tide.rect(x,51,3,41,'6d5e54');tide.rect(x+1,51,1,41,'a38b70');
}
rug(tide,145,193,30,16,['3e342f','8a7960','66564a','8a7960']);
tide.rect(104,208,112,12,'3a3937');tide.rect(103,219,114,4,'685647');
tide.save('tide_station.png');

const glade=surface(320,240);
glade.rect(0,0,320,240,'162b2a');
glade.ellipse(160,130,137,103,'243c34');
glade.ellipse(160,134,114,85,'30483b');
glade.ellipse(163,137,90,69,'3d5141');
glade.ellipse(163,144,58,61,'455647');
grain(glade,41,52,237,154,['33493c','4d604b','50634c','293f36','798267'],950);
for(const [x,y] of [[51,75],[74,73],[111,72],[134,68],[187,68],[214,68],[250,74],[273,82],[42,127],[276,125],[47,178],[278,176],[58,211],[266,211],[109,219],[224,218]]) tower(glade,x,y,forest);
for(let i=0;i<75;i++) {
  const x=38+rand(244),y=80+rand(127);
  if(x<115||x>200||y<98) grass(glade,x,y,forest);
}
glade.ellipse(158,117,55,12,'172f2c');
glade.ellipse(167,117,43,8,'4a5749');
glade.rect(130,111,57,5,'645542');glade.rect(143,109,38,2,'918363');
glade.ellipse(188,114,5,5,'a79975');glade.ellipse(188,114,3,3,'6b614e');
for(const [x,y] of [[83,143],[228,154],[143,91],[187,84],[105,177]]) {
  glade.ellipse(x,y+2,8,5,'263834');glade.ellipse(x,y,6,4,'617364');glade.rect(x-3,y-2,5,1,'8c9374');
}
glade.save('bracken_clearing.png');

const sheet=surface(448,80);
for(let f=0;f<4;f++) {
  const x=f*112;
  casing(sheet,x+3,4,106,32,bronze);
  for(let dial=0;dial<3;dial++) {
    const dx=x+25+dial*31,dy=20;
    sheet.ellipse(dx,dy,10,10,'26282d');sheet.ellipse(dx,dy,8,8,'a98a66');sheet.ellipse(dx,dy,6,6,'5c4f46');
    sheet.line(dx,dy,dx+(f%3-1)*4,dy-4,'dfc398');
    sheet.pixel(dx-7,dy-6,'e0b889');
    sheet.rect(dx-3,dy+11,7,1,f===3?'a5c886':'8c6854');
  }
  casing(sheet,x+3,44,106,32,metal);
  for(let dial=0;dial<2;dial++) {
    const dx=x+32+dial*48,dy=60;
    sheet.ellipse(dx,dy,12,12,'25343c');sheet.ellipse(dx,dy,9,9,'6e8886');
    sheet.ellipse(dx,dy,6,6,'363d42');
    sheet.line(dx-4,dy-4,dx+f-1,dy+5,'caa176');
    sheet.line(dx+4,dy-4,dx-(f-1),dy+5,'b5956c');
  }
  sheet.rect(x+27,55-f,58,2,'b6986c');
  sheet.rect(x+21,69,72,1,f===3?'aac886':'768580');
}
sheet.save('mechanisms.png');

const motion=surface(384,160);
for(let f=0;f<6;f++) {
  const x=f*64;
  for(let i=0;i<11;i++) {
    const wave=(i*13+f*2)%52;
    motion.rect(x+wave,7+(i*5)%24,5+i%4,1,i%3?'6a9ba99e':'b5cbba9b');
  }
  for(let i=0;i<7;i++) {
    const sway=Math.round(Math.sin(f*Math.PI/3)*4);
    motion.line(x+32,60,x+10+i*6+sway,41+(i%3)*5,'66835f');
    motion.ellipse(x+10+i*6+sway,42+(i%3)*5,3,2,i%2?'798d5d':'9a9f65');
  }
  for(let i=0;i<2;i++) {
    const dx=x+19+i*25;
    motion.ellipse(dx,80,12,12,'252930');motion.ellipse(dx,80,10,10,'807677');
    motion.ellipse(dx,80,8,8,'504658');
    for(let spoke=0;spoke<3;spoke++) {
      const angle=(2*spoke+f)*Math.PI/3;
      motion.line(dx,80,dx+Math.round(8*Math.cos(angle)),80+Math.round(8*Math.sin(angle)),'c3a68e');
    }
  }
  motion.ellipse(x+32,112,7,5,'7a6340');
  motion.ellipse(x+32,112,4+(f%3),3,'b9904d');motion.ellipse(x+32,112,2,2,'edc681');
  for(let i=0;i<7;i++) {
    const px=x+(17+i*7+f*3)%59+2, py=134+(i*3+f*2)%20;
    motion.pixel(px,py,i%2?'e8c694':'98877e');
    if(i%3===0) motion.pixel(px+1,py,'e8c694');
  }
}
motion.save('motion.png');

const icons=surface(144,24);
for(let i=0;i<6;i++) icons.ellipse(i*24+12,21,8,2,'25212a99');
casing(icons,3,7,18,13,bronze);icons.rect(6,11,12,4,'2b3640');icons.rect(11,11,3,4,'a1a97f');
casing(icons,25,7,20,13,metal);icons.ellipse(31,12,4,4,'af937e');icons.ellipse(39,12,4,4,'af937e');
icons.pixel(31,12,'343340');icons.pixel(39,12,'343340');icons.rect(31,15,9,1,'d0b197');
paper(icons,54,10,['cba77d','e7c89c','a27865']);paper(icons,57,12,['e0c398','f5d8ae','8b6460']);
icons.rect(61,16,3,3,'a95559');icons.pixel(62,17,'e48766');
icons.ellipse(84,12,6,6,'b08b55');icons.ellipse(84,10,5,4,'e0af61');icons.rect(77,15,14,2,'e0b571');icons.pixel(84,18,'aa7c56');
casing(icons,99,10,18,10,metal);icons.ellipse(108,10,5,5,'aa8053');icons.ellipse(108,10,3,3,'58495a');
icons.line(111,9,116,5,'cfa876');icons.pixel(117,5,'e8bf87');
casing(icons,125,7,14,13,bronze);icons.rect(129,9,5,8,'a2a46e');icons.pixel(132,13,'ffdc8b');
icons.save('props.png');

// Rows are labeled in the same order as TrialStageArt.MODES. Each row
// contains six frames with a constant origin. The last frame is transparent.
const reactions=surface(144,12*24);
const cueColors=['d9b589','b8c2a1','b4bedc','a1cad0','d7ba81','daa2ac','aacb87','f4c987','afa582','dec297','bdafdc','b2c198'];
for(let row=0;row<cueColors.length;row++) {
  const tone=cueColors[row];
  for(let frame=0;frame<5;frame++) {
    const x=frame*24+12, y=row*24+12;
    for(let j=0;j<5;j++) {
      const angle=(j/5+row/24)*Math.PI*2;
      const radius=2+frame*2+(j%2);
      const xx=x+Math.round(Math.cos(angle)*radius), yy=y+Math.round(Math.sin(angle)*radius);
      if(row===0||row===5||row===11) {
        reactions.rect(xx,yy,frame<2?3:2,2,tone);
      } else if(row===3||row===6) {
        reactions.rect(xx,yy-1,1,3,tone);reactions.pixel(xx+1,yy+1,tone);
      } else if(row===4||row===8||row===1) {
        reactions.rect(xx,yy,2,2,tone);reactions.pixel(xx+2,yy,tone);
      } else {
        reactions.rect(xx-1,yy,3,1,tone);reactions.rect(xx,yy-1,1,3,tone);
      }
    }
  }
}
reactions.save('trial_reactions.png');
