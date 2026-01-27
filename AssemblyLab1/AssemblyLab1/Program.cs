using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime;
using System.Text;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Data.SqlTypes;
using MedianFilterCsDLL;
using System.Numerics;

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
            long totalTime = 0;
            int iterations = 10;
            string outputPath = args[1];
            Console.WriteLine($"Output path={outputPath}");
            int threadsNum = Convert.ToInt32(args[2]);
            Console.WriteLine($"Threads number={threadsNum}");
            String num = Console.ReadLine();
            for (int k = 0; k < iterations; k++) {
            {
                    using (var bmp = new Bitmap(bmpPath))
                    {
                        Rectangle r = new Rectangle(0, 0, bmp.Width, bmp.Height);
                        BitmapData bmpData = bmp.LockBits(r, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
                        IntPtr bmpPtr = bmpData.Scan0;
                        int stride = bmpData.Stride;
                        int width = bmpData.Width;
                        int height = bmpData.Height;
                        int chunkHeight = height / threadsNum;
                        int extra = height % threadsNum;
                        var output = new Bitmap(width, height);
                        var outp = output.LockBits(r, ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
                        var outPtr = outp.Scan0;
                        {
                            Stopwatch sw = Stopwatch.StartNew();
                            Parallel.For(0, threadsNum, i =>
                            {
                                int startY = i * chunkHeight + Math.Min(i, extra);
                                int endY = startY + chunkHeight + (i < extra ? 1 : 0);
                                startY = Math.Max(1, startY);
                                endY = Math.Min(height - 1, endY);
                                if (num == "0")
                                {
                                    MedianFilterCpp(bmpPtr, outPtr, width, height, stride, startY, endY);
                                }
                                else
                                {
                                    MedianFilter(bmpPtr, outPtr, width, height, stride, startY, endY);
                                }
                            });
                            sw.Stop();
                            long runTime = sw.ElapsedMilliseconds;
                            totalTime += runTime;
                            Console.WriteLine($"Iteration {k + 1}: {runTime} ms");
                        }
                        bmp.UnlockBits(bmpData);
                        output.UnlockBits(outp);
                        output.Save(outputPath);
                    }

                }
            }
            Console.WriteLine("End");
            double averageTime = (double)totalTime / iterations;
            Console.WriteLine("--------------------------------------------------");
            Console.WriteLine($"Avg time of ({iterations} iterations): {averageTime:F2} ms");
        }
    }
}
