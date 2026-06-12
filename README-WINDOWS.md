# Ghostty for Windows (fork)

This branch (`win32-improvements`) builds a native Windows Ghostty on
top of [mattn's `win32-apprt`](https://github.com/mattn/ghostty/tree/win32-apprt)
work. It is unofficial and experimental; see
[ghostty-org/ghostty#2563](https://github.com/ghostty-org/ghostty/discussions/2563)
for the upstream Windows effort.

## Building

Requires [Zig 0.15.2](https://ziglang.org/download/) on Windows 10/11.

```powershell
zig build -Dtarget=native-native-gnu
.\zig-out\bin\ghostty.exe
```

To use the experimental Direct3D 11 renderer instead of OpenGL/WGL:

```powershell
zig build -Dtarget=native-native-gnu -Drenderer=d3d11
```

## What works

Everything from mattn's branch: Win32 window, tabs, splits with
draggable dividers, ConPTY, keyboard (incl. dead keys), mouse,
clipboard, IME, per-monitor DPI, fullscreen, quick terminal, command
palette, search, light/dark theme detection, config loading and hot
reload, desktop notifications, taskbar progress.

Added on this branch:

- Right-click context menu (Copy/Paste/Clear/Reset/Split/Change
  Title/Command Palette), following `right-click-action`.
- Link URL overlay at the bottom-left on Ctrl+hover (`mouse_over_link`).
- Real split zoom for `toggle_split_zoom` (Ctrl+Shift+Enter).
- Inline IME preedit rendered in the terminal at the cursor.
- `initial_size` action support.
- Tab overview popup (`toggle_tab_overview`).
- Native scrollbar wired to the terminal scrollback.
- DirectWrite font discovery (`dwrite_freetype` backend, the new
  default): proper family/style matching through the system font
  collection, working `+list-fonts`, and codepoint-filtered fallback.
- Experimental Direct3D 11 renderer (`-Drenderer=d3d11`): flip-model
  DXGI swapchain, HLSL cell shaders compiled at startup via
  d3dcompiler_47, no C++.

## Known gaps

- D3D11: custom (post-process) shaders and background images are not
  drawn yet; OpenGL remains the default renderer.
- Font rasterization is FreeType (DirectWrite is discovery-only).
- IME preedit is smoke-tested only; real CJK IME feedback welcome.
- No shell integration scripts, no accessibility support.

## Testing

```powershell
zig build -Dapp-runtime=none test
```
