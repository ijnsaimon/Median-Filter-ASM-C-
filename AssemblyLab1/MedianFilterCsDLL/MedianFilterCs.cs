using System.Security.Cryptography;
using System.Security.Principal;

namespace MedianFilterCsDLL
{
    public static class MedianFilterCs
    {
        public static unsafe void medianFilter(IntPtr srcPtr, IntPtr outPtr, int width, int height, int stride, int startY, int endY)
        {
            byte* src = (byte*)srcPtr;
            byte* outp = (byte*)outPtr;
            byte* chanR = stackalloc byte[9];
            byte* chanG = stackalloc byte[9];
            byte* chanB = stackalloc byte[9];
      //      for (int y = Math.Max(1, startY); y < Math.Min(height - 1, endY); y++)
            for (int y = startY; y < endY; y++)
            {
                for (int x = 1; x < width; x++)
                {
                    int k = 0;
                    for (int dy = -1; dy <= 1; dy++)
                    {
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            byte* px = src + (y + dy) * stride + (x + dx) * 3;
                            chanB[k] = px[0];
                            chanG[k] = px[1];
                            chanR[k] = px[2];
                            k++;
                        }
                    }
                    for (int i = 0; i < 9; i++)
                    {
                        for (int j = 0; j < 9; j++)
                        {
                            if (chanR[j] < chanR[i])
                            {
                                byte t = chanR[i];
                                chanR[i] = chanR[j];
                                chanR[j] = t;
                            }
                            if (chanG[j] < chanG[i])
                            {
                                byte t = chanG[i];
                                chanG[i] = chanG[j];
                                chanG[j] = t;
                            }
                            if (chanB[j] < chanB[i])
                            {
                                byte t = chanB[i];
                                chanB[i] = chanB[j];
                                chanB[j] = t;
                            }
                        }
                    }
                    byte* output = outp + y * stride + x * 3;
                    output[0] = chanB[4];
                    output[1] = chanG[4];
                    output[2] = chanR[4];
                }
            }
        }
    }
}

