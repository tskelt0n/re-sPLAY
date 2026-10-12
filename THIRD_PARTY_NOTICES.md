# Brightness implementation references

re-sPLAY’s brightness backend is implemented in Swift. The DDC/CI packet format, IOAVService API signatures and transport conventions were checked against m1ddc by Istvan Toth: https://github.com/waydabber/m1ddc . The m1ddc executable is not bundled. Its license is retained below for attribution to these implementation references.

Apple DisplayServices API signatures were checked against https://github.com/nriley/brightness/blob/master/brightness.c . Ambient-light compensation function declarations were checked against https://github.com/alin23/Lunar/blob/master/Lunar/DDC/Lunar-Bridging-Header.h and the local macOS SDK exports. The control implementation is original; no Lunar implementation code or assets are included.

Native capability selection was checked against DisplayServicesCanChangeBrightness declarations and usage in https://github.com/taketaku/MacBrightnessKit and the local framework. HDR detection uses the runtime-resolved CoreDisplay_Display_IsHDRModeEnabled Boolean API; the CoreDisplay/SkyLight relationship and Boolean signature were checked against https://github.com/fastfetch-cli/fastfetch/blob/dev/src/detection/displayserver/displayserver_apple.c . These are API references, not bundled implementations.

## m1ddc — MIT license

MIT License

Copyright (c) 2021 waydabber

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
