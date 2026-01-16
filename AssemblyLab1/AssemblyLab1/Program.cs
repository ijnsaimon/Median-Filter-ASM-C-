using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Data.SqlTypes;
using MedianFilterCsDLL;

namespace AssemblyLab1
{
    class Program
    {
        [DllImport("JA1.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void MedianFilter(IntPtr data, IntPtr outData, int width, int height, int stride, int startY, int endY);

        [DllImport("MedianFilterC++.dll", CallingConvention = CallingConvention.Cdecl)]

        public static extern void MedianFilterCpp(IntPtr data, IntPtr outData, int width, int height, int stride, int startY, int endY);

        static void Main(string[] args)
        {
            string bmpPath = args[0];
            Console.WriteLine($"Bitmap path={bmpPath}");
            using (var bmp = new Bitmap(bmpPath))
            {
                Rectangle r = new Rectangle(0, 0, bmp.Width, bmp.Height);
                String num = Console.ReadLine();
                BitmapData bmpData = bmp.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
                IntPtr bmpPtr = bmpData.Scan0;
                int stride = bmpData.Stride;
                int width = bmpData.Width;
                int height = bmpData.Height;
                int threadsNum = Math.Min(Environment.ProcessorCount, height);
                int chunkHeight = height / threadsNum;
                int extra = height % threadsNum;
                var output = new Bitmap(width, height);
                var outp = output.LockBits(r, ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
                var outPtr = outp.Scan0;
                if (num == "0")
                {
                    Stopwatch sw = Stopwatch.StartNew();
                    Parallel.For(0, threadsNum, i =>
                    {
                        int startY = i * chunkHeight + Math.Min(i, extra);
                        int endY = startY + chunkHeight + (i < extra ? 1 : 0);
                        startY = Math.Max(1, startY);
                        endY = Math.Min(height - 1, endY);
                 //       MedianFilterCs.medianFilter(bmpPtr, outPtr, width, height, stride, startY, endY);
                        MedianFilterCpp(bmpPtr, outPtr, width, height, stride, startY, endY);
                        Console.WriteLine("Thread finished cpp");
                    });
                    sw.Stop();
                    Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
                    bmp.UnlockBits(bmpData);
                    output.UnlockBits(outp);
                    output.Save("result.bmp");
                }
                else
                {

                    Stopwatch sw = Stopwatch.StartNew();
                    Parallel.For(0, threadsNum, i =>
                    {
                        int startY = i * chunkHeight + Math.Min(i, extra);
                        int endY = startY + chunkHeight + (i < extra ? 1 : 0);
                        startY = Math.Max(1, startY);
                        endY = Math.Min(height - 1, endY);
                        MedianFilter(bmpPtr, outPtr, width, height, stride, startY, endY);
                        Console.WriteLine("Thread finished asm");
                    });
                    sw.Stop();
                    Console.WriteLine($"Time: {sw.ElapsedMilliseconds} ms");
                    bmp.UnlockBits(bmpData);
                    output.UnlockBits(outp);
                    output.Save("result.bmp");
                }
            }
            Console.WriteLine("End");
        }
    }
}
