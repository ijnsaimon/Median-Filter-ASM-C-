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
    // Bufory na kanały kolorów (odpowiednik stackalloc)
    uint8_t chanR[9];
    uint8_t chanG[9];
    uint8_t chanB[9];

    // Zabezpieczenie pętli Y, aby nie wyjść poza zakres (margines 1 piksela)
    int validStartY = max(1, startY);
    int validEndY = min(height - 1, endY);

    for (int y = validStartY; y < validEndY; y++) {
        // Pętla X: od 1 do width - 1 (w oryginale było < width, co mogło powodować błąd przy x+1)
        for (int x = 1; x < width - 1; x++) {
            int k = 0;

            // Pobieranie otoczenia 3x3
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    // Obliczanie wskaźnika: przesunięcie wiersza + przesunięcie piksela
                    // stride to szerokość wiersza w bajtach (wliczając padding)
                    uint8_t* px = src + (y + dy) * stride + (x + dx) * 3;

                    chanB[k] = px[0];
                    chanG[k] = px[1];
                    chanR[k] = px[2];
                    k++;
                }
            }

            // Znajdowanie mediany (elementu środkowego po posortowaniu).
            // std::nth_element jest szybsze niż pełne sortowanie, bo ustawia
            // tylko element na pozycji 4 na właściwym miejscu.
            std::nth_element(chanR, chanR + 4, chanR + 9);
            std::nth_element(chanG, chanG + 4, chanG + 9);
            std::nth_element(chanB, chanB + 4, chanB + 9);

            // Jeśli wolisz pełne sortowanie (jak w oryginale), użyj:
            // std::sort(chanR, chanR + 9);
            // std::sort(chanG, chanG + 9);
            // std::sort(chanB, chanB + 9);

            // Zapis do bufora wyjściowego
            uint8_t* output = out + y * stride + x * 3;
            output[0] = chanB[4];
            output[1] = chanG[4];
            output[2] = chanR[4];
        }
    }
}
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

