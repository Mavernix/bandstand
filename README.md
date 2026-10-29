# Bandstand

A music player for [Mavernix](https://github.com/Mavernix/mavernix). Search YouTube Music, play songs, keep playlists and liked songs. No account needed.

It takes its look from whatever Mavernix theme you're running.

![Bandstand](docs/screenshot.png)

## Install

Open the App Store in Mavernix and get Bandstand. It comes with everything it needs.

## Build

You need Qt 6 (with Qt Multimedia), meson, python, `python-ytmusicapi`, `yt-dlp` and `deno`.

```sh
meson setup build
meson compile -C build
```

Start `build/bandstand` from a Mavernix session.

Your library lives in `~/.local/share/bandstand` as plain JSON files.

## Release

Push a version tag, such as `v0.2.0`, with the release notes as the tag's message. `.github/workflows/release.yml` then builds the bundle the App Store installs (`packaging/make-bundle`) and publishes the release. `mavernix-app.toml` is what the store shows; how that works is in Mavernix's [docs/app-store.md](https://github.com/Mavernix/mavernix/blob/main/docs/app-store.md).

When songs stop playing because YouTube changed something, update yt-dlp in `packaging/bundle-requirements.txt` and make a new release.

## License

GPLv3
