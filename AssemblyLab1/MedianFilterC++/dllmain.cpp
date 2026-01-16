// dllmain.cpp : Definiuje punkt wejścia dla aplikacji DLL.
#include "pch.h"
#include <iostream>
#include <algorithm>
#include <cstdint>
#include <vector>
#include <cmath>

#define EXPORTED_METHOD extern "C" __declspec(dllexport)

EXPORTED_METHOD

void MedianFilterCpp(uint8_t* src, uint8_t* out, int width, int height, int stride, int startY, int endY){
	// Channels for 3x3 neighborhood
    uint8_t chanR[9];
    uint8_t chanG[9];
    uint8_t chanB[9];
	// Loop Y: from startY to endY
    for (int y = startY; y < endY; y++) {
		// Loop X: from 1 to width-1 (to avoid borders)
        for (int x = 1; x < width - 1; x++) {
			int k = 0; // Index for channel arrays

			// Loop DY from 1 to -1 (y = 3 for 3x3 neighborhood)
            for (int dy = -1; dy <= 1; dy++) {
				// Loop DX from 1 to -1 (x = 3 for 3x3 neighborhood)
                for (int dx = -1; dx <= 1; dx++) {
					// Calculate pixel position
                    uint8_t* px = src + (y + dy) * stride + (x + dx) * 3;
					// Store color channels in separate arrays
                    chanB[k] = px[0];
                    chanG[k] = px[1];
                    chanR[k] = px[2];
                    k++;
                }
            }

            // Median search (middle element after sorting the arrays)
			// std::nth_element is faster than full sort, as we need only the fourth element of the array in the correct position
            std::nth_element(chanR, chanR + 4, chanR + 9);
            std::nth_element(chanG, chanG + 4, chanG + 9);
            std::nth_element(chanB, chanB + 4, chanB + 9);
            // Saving to output buffer
            uint8_t* output = out + y * stride + x * 3;
            output[0] = chanB[4];
            output[1] = chanG[4];
            output[2] = chanR[4];
        }
    }
}
// Whatever this is needed for DLLs.
BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}

