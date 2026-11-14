$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;using System.Drawing;using System.Drawing.Imaging;using System.Drawing.Drawing2D;
public static class VeraPack{
 public static void Pack(string input,string output){using(var src=new Bitmap(input))using(var dst=new Bitmap(128,192,PixelFormat.Format32bppArgb))using(var g=Graphics.FromImage(dst)){
 g.InterpolationMode=InterpolationMode.NearestNeighbor;g.PixelOffsetMode=PixelOffsetMode.Half;
 var bounds=new Rectangle[16];double scale=1;
 for(int row=0;row<4;row++)for(int col=0;col<4;col++){int l=src.Width,t=src.Height,r=-1,b=-1;for(int y=row*src.Height/4;y<(row+1)*src.Height/4;y++)for(int x=col*src.Width/4;x<(col+1)*src.Width/4;x++)if(src.GetPixel(x,y).A>200){l=Math.Min(l,x);t=Math.Min(t,y);r=Math.Max(r,x);b=Math.Max(b,y);}if(r<l)throw new Exception("Empty frame");bounds[row*4+col]=new Rectangle(l,t,r-l+1,b-t+1);scale=Math.Min(scale,Math.Min(28.0/(r-l+1),40.0/(b-t+1)));}
 for(int row=0;row<4;row++)for(int col=0;col<4;col++){var r=bounds[row*4+col];int w=(int)Math.Round(r.Width*scale),h=(int)Math.Round(r.Height*scale);g.DrawImage(src,new Rectangle(col*32+(32-w)/2,row*48+45-h,w,h),r,GraphicsUnit.Pixel);}
 for(int y=0;y<dst.Height;y++)for(int x=0;x<dst.Width;x++){var p=dst.GetPixel(x,y);dst.SetPixel(x,y,p.A<200?Color.Transparent:Color.FromArgb(255,p.R/8*8,p.G/8*8,p.B/8*8));}dst.Save(output,ImageFormat.Png);
 }}
}
'@
[VeraPack]::Pack((Join-Path $PSScriptRoot 'vera-source.png'),(Join-Path $PSScriptRoot 'vera.png'))
