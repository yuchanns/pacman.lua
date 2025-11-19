# pacman.lua

A Pacman clone made by soluna for Windows, macOS, Linux and WASM.

> Be aware that I will occasionally force-push my local repository to GitHub to rewrite history for educational purposes.

## Play Online (Recommended)

You can play the game online at: [https://yuchanns.github.io/pacman.lua](https://yuchanns.github.io/pacman.lua).

## Play Locally

1. Generate sprites, tiles and fonts:

```bash
python3 .github/scripts/gen_sprites.py
python3 .github/scripts/gen_fonts.py
```

2. Build the game engine:

```bash
cd soluna

luamake
```

3. Run the game:

```bash
.\soluna\bin\msvc\release\soluna # on Windows
./soluna/bin/macos/release/soluna # on macOS
./soluna/bin/linux/release/soluna # on Linux
```

## License

This project is distributed under the terms of **GPL-3.0**. While the original [pacman.c](https://github.com/floooh/pacman.c) reference implementation is MIT-licensed,
this repository relys on snippets of GPL-licensed projects, so the whole codebase must adopt GPL accordingly. WE HOPE FOR YOUR UNDERSTANDING.
