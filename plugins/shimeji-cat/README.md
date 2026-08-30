# Shimeji Cat

A shimeji-style desktop pet for Caelestia. A small cat lives on your desktop,
wanders around, sits on the taskbar, and can be picked up and tossed with the
mouse.

Ported from the shimeji module in
[ladybug-me/caelestia-dots-kde](https://github.com/ladybug-me/caelestia-dots-kde).

## Requirements

- Caelestia shell 2.3 or newer.
- A set of shimeji sprite frames (see Sprites below).

## Sprites

This plugin ships no artwork. It loads sprite frames from a directory you
provide. The default path is `root:/assets/shimeji/pusheen/`, the same place
the original shell module read its sprites, so existing Caelestia installs work
out of the box.

The expected frames are the classic shimeji set, named `shime1.png` through
`shime33.png` (128x128 px). To use a different set, edit `spritePath` in
`ShimejiCat.qml`:

- An absolute path like `/home/you/sprites/`.
- A home-relative path like `~/sprites/`.
- A shell-root-relative path like `root:/assets/shimeji/pusheen/`.

## Configuration

Edit the constants at the top of `ShimejiCat.qml`:

- `spritePath` - directory containing the sprite frames.
- `petCount` - number of cats per screen (default 1).

## License

GPL-3.0-or-later. See `LICENSE`. Original code by the Caelestia contributors.
