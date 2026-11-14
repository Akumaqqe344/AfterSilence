$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;using System.Drawing;using System.Drawing.Imaging;using System.Drawing.Drawing2D;using System.IO;
public static class WorldPack {
static Rectangle Bounds(Bitmap src,int col,int row,int columns,int rows) {
 int l=src.Width,t=src.Height,r=-1,b=-1;
 for(int y=row*src.Height/rows;y<(row+1)*src.Height/rows;y++)for(int x=col*src.Width/columns;x<(col+1)*src.Width/columns;x++)
 if(src.GetPixel(x,y).A>200){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);b=Math.Max(b,y);}
 if(r<l)throw new Exception("Empty atlas cell");return new Rectangle(l,t,r-l+1,b-t+1);
}
static void Finish(Bitmap dst,string output) {
 for(int y=0;y<dst.Height;y++)for(int x=0;x<dst.Width;x++){var p=dst.GetPixel(x,y);dst.SetPixel(x,y,p.A<200?Color.Transparent:Color.FromArgb(255,p.R/8*8,p.G/8*8,p.B/8*8));}
 dst.Save(output,ImageFormat.Png);
}
static Graphics Canvas(Bitmap dst) {var g=Graphics.FromImage(dst);g.InterpolationMode=InterpolationMode.NearestNeighbor;g.PixelOffsetMode=PixelOffsetMode.Half;return g;}
public static void Pack(string folder) {
 using(var src=new Bitmap(Path.Combine(folder,"npc-source.png"))) {
 string[] names={"nadia","lev","mara","pavel","sonya"};
 double scale=1;var cells=new Rectangle[20];
 for(int row=0;row<4;row++)for(int col=0;col<5;col++){var r=Bounds(src,col,row,5,4);cells[row*5+col]=r;scale=Math.Min(scale,Math.Min(28.0/r.Width,40.0/r.Height));}
 for(int col=0;col<5;col++)using(var dst=new Bitmap(128,48,PixelFormat.Format32bppArgb)){
 using(var g=Canvas(dst))for(int row=0;row<4;row++){var r=cells[row*5+col];int w=(int)Math.Round(r.Width*scale),h=(int)Math.Round(r.Height*scale);g.DrawImage(src,new Rectangle(row*32+(32-w)/2,45-h,w,h),r,GraphicsUnit.Pixel);}
 Finish(dst,Path.Combine(folder,names[col]+".png"));}
 }
 using(var src=new Bitmap(Path.Combine(folder,"environment-source.png"))) {
 string[] names={"cottage","townhouse","library","well","oak","fir","flowers","rock"};
 int[] widths={176,176,176,64,80,64,48,56},heights={160,160,160,72,104,104,32,48};
 for(int index=0;index<8;index++){var r=Bounds(src,index%4,index/4,4,2);double scale=Math.Min((double)widths[index]/r.Width,(double)heights[index]/r.Height);int w=(int)Math.Round(r.Width*scale),h=(int)Math.Round(r.Height*scale);
 using(var dst=new Bitmap(widths[index],heights[index],PixelFormat.Format32bppArgb)){
 using(var g=Canvas(dst))g.DrawImage(src,new Rectangle((dst.Width-w)/2,dst.Height-h,w,h),r,GraphicsUnit.Pixel);
 Finish(dst,Path.Combine(folder,names[index]+".png"));}}
 }
}
}
'@
[WorldPack]::Pack($PSScriptRoot)
