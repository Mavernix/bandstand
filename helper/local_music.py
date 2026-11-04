# the songs in the user's music folders, for the "local" command.
#
# a local song's video_id is its file:// url, so the app plays it straight from disk and
# likes, history and playlists keep it like any other song. tags are read with mutagen.
#
# what was read is kept in DIR/index.json, by path with the file's size and mtime, so a
# scan only reads files that are new or changed. covers come from a cover.jpg (folder.jpg,
# front.png, ...) next to the songs, or else the first picture embedded in a song of that
# folder, written to DIR/covers/.

import base64
import hashlib
import json
import os
import pathlib
import sys
import threading

from youtube_music import HelperError

AUDIO_SUFFIXES = {".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".aac", ".wav", ".aif", ".aiff", ".wv"}

COVER_NAMES = ("cover", "folder", "front", "album")
COVER_SUFFIXES = (".jpg", ".jpeg", ".png")
PICTURE_SUFFIXES = {"image/png": ".png"}

INDEX_VERSION = 1
# a first scan of a big library takes a while; this much reading is kept even if it stops
SAVE_EVERY_FILES = 500


def log(format, *args):
    # stdout is reserved for the json protocol
    sys.stderr.write("local music: " + (format % args) + "\n")


def _first(tags, *names):
    for name in names:
        values = tags.get(name) if tags is not None else None
        if values:
            text = str(values[0]).strip()
            if text:
                return text
    return ""


def _number(text):
    # "3/12" -> 3
    try:
        return int(text.split("/")[0])
    except ValueError:
        return 0


def _mutagen():
    try:
        import mutagen
    except ImportError:
        raise HelperError("Reading your music files needs mutagen (python-mutagen), which isn't installed.") from None
    return mutagen


def read_tags(path):
    """{title, artist, album_artist, album, track, disc, duration_seconds}, empty strings
    for missing tags. None for a file mutagen can't read."""
    mutagen = _mutagen()
    try:
        audio = mutagen.File(path, easy=True)
    except Exception as error:  # noqa: BLE001 - a broken file must not stop the scan
        log("could not read %s: %s", path, error)
        return None
    if audio is None:
        return None

    tags = audio.tags
    length = getattr(audio.info, "length", 0) or 0
    return {
        "title": _first(tags, "title"),
        "artist": _first(tags, "artist", "albumartist"),
        "album_artist": _first(tags, "albumartist", "artist"),
        "album": _first(tags, "album"),
        "track": _number(_first(tags, "tracknumber")),
        "disc": _number(_first(tags, "discnumber")),
        "duration_seconds": int(round(length)),
    }


def read_picture(path):
    """(bytes, mime) of the first picture embedded in the file, or None."""
    mutagen = _mutagen()
    try:
        audio = mutagen.File(path)
    except Exception:  # noqa: BLE001
        return None
    if audio is None:
        return None

    pictures = getattr(audio, "pictures", None)  # flac
    if pictures:
        return pictures[0].data, pictures[0].mime
    tags = audio.tags
    if tags is None:
        return None
    if hasattr(tags, "getall"):  # id3
        frames = tags.getall("APIC")
        if frames:
            return frames[0].data, frames[0].mime
        return None
    covers = tags.get("covr") if hasattr(tags, "get") else None  # mp4
    if covers:
        mime = "image/png" if getattr(covers[0], "imageformat", 0) == 14 else "image/jpeg"
        return bytes(covers[0]), mime
    blocks = tags.get("metadata_block_picture") if hasattr(tags, "get") else None  # ogg
    if blocks:
        from mutagen.flac import Picture

        try:
            picture = Picture(base64.b64decode(blocks[0]))
        except Exception:  # noqa: BLE001
            return None
        return picture.data, picture.mime
    return None


def display_path(path):
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path == home or path.startswith(home + os.sep) else path


def _write_atomically(path, data):
    part = path + ".part"
    with open(part, "wb") as file:
        file.write(data)
    os.replace(part, path)


class LocalMusic:
    def __init__(self, folders, cache_dir, read_tags=read_tags, read_picture=read_picture):
        self._folders = [os.path.abspath(os.path.expanduser(folder)) for folder in folders]
        self._cache_dir = cache_dir
        self._covers_dir = os.path.join(cache_dir, "covers")
        self._index_path = os.path.join(cache_dir, "index.json")
        self._read_tags = read_tags
        self._read_picture = read_picture
        # a second scan waits for the first, then finds everything in the index
        self._lock = threading.Lock()

    def songs(self):
        """{folders, tracks}, tracks in the shape of youtube_music.py, by artist and album."""
        folders = [folder for folder in self._folders if os.path.isdir(folder)]
        if not folders:
            if not self._folders:
                raise HelperError("No music folders are set. Add local_folders to the config's [music] table.")
            raise HelperError("%s isn't there. Set local_folders in the config's [music] table to where your "
                              "music is." % " or ".join(display_path(folder) for folder in self._folders))

        with self._lock:
            songs = self._scan(folders)

        songs.sort(key=lambda song: (song["album_artist"].casefold(), song["album"].casefold(),
                                     song["disc"], song["track"], song["path"]))
        return {
            "folders": [display_path(folder) for folder in folders],
            "tracks": [self._track(song) for song in songs],
        }

    def _scan(self, folders):
        old = self._load_index()
        index = {}
        fresh_in = {}  # folder -> paths read this time
        unsaved = 0

        for root, path in self._audio_files(folders):
            try:
                stat = os.stat(path)
            except OSError:
                continue
            entry = old.get(path)
            if entry is None or entry.get("size") != stat.st_size or entry.get("mtime") != stat.st_mtime:
                tags = self._read_tags(path)
                if tags is None:
                    continue
                entry = dict(tags, size=stat.st_size, mtime=stat.st_mtime)
                fresh_in.setdefault(os.path.dirname(path), []).append(path)
                unsaved += 1
            index[path] = dict(entry, root=root)
            if unsaved >= SAVE_EVERY_FILES:
                self._save_index({**old, **index})
                unsaved = 0

        if index != old:
            self._save_index(index)

        covers = {}
        songs = []
        for path, entry in index.items():
            folder = os.path.dirname(path)
            if folder not in covers:
                covers[folder] = self._cover(folder, fresh_in.get(folder, []))
            songs.append(dict(entry, path=path, cover=covers[folder]))
        return songs

    def _audio_files(self, folders):
        seen = set()
        for root in folders:
            for directory, subdirectories, names in os.walk(root):
                subdirectories[:] = sorted(name for name in subdirectories if not name.startswith("."))
                for name in sorted(names):
                    path = os.path.join(directory, name)
                    # a folder inside another listed folder
                    if path in seen or name.startswith(".") or os.path.splitext(name)[1].lower() not in AUDIO_SUFFIXES:
                        continue
                    # a name that isn't utf-8 can't go into the json the app reads
                    try:
                        path.encode("utf-8")
                    except UnicodeEncodeError:
                        log("skipped %r, its name isn't utf-8", path)
                        continue
                    seen.add(path)
                    yield root, path

    def _cover(self, folder, fresh_paths):
        """A file:// url, or "". Embedded pictures are only looked for in songs read this
        scan, so a folder without any costs nothing the next time."""
        try:
            names = {name.lower(): name for name in os.listdir(folder)}
        except OSError:
            names = {}
        for stem in COVER_NAMES:
            for suffix in COVER_SUFFIXES:
                name = names.get(stem + suffix)
                if name is not None:
                    return pathlib.Path(folder, name).as_uri()

        stem = os.path.join(self._covers_dir, hashlib.sha1(folder.encode("utf-8", "surrogateescape")).hexdigest())
        for suffix in (".jpg", ".png"):
            if os.path.exists(stem + suffix) and not fresh_paths:
                return pathlib.Path(stem + suffix).as_uri()

        for path in fresh_paths:
            picture = self._read_picture(path)
            if picture is None:
                continue
            data, mime = picture
            target = stem + PICTURE_SUFFIXES.get(mime, ".jpg")
            try:
                os.makedirs(self._covers_dir, exist_ok=True)
                _write_atomically(target, data)
            except OSError as error:
                log("could not keep the cover of %s: %s", folder, error)
                return ""
            return pathlib.Path(target).as_uri()

        for suffix in (".jpg", ".png"):
            if os.path.exists(stem + suffix):
                return pathlib.Path(stem + suffix).as_uri()
        return ""

    @staticmethod
    def _track(song):
        path = song["path"]
        folder = os.path.dirname(path)
        # loose files right in a music folder have no album to fall back to
        album = song["album"] or ("" if folder == song["root"] else os.path.basename(folder))
        return {
            "video_id": pathlib.Path(path).as_uri(),
            "title": song["title"] or os.path.splitext(os.path.basename(path))[0],
            "artist": song["artist"],
            "album": album,
            "duration_seconds": song["duration_seconds"],
            "thumbnail_url": song["cover"],
        }

    def _load_index(self):
        try:
            with open(self._index_path, encoding="utf-8") as file:
                data = json.load(file)
        except (OSError, ValueError):
            return {}
        if not isinstance(data, dict) or data.get("version") != INDEX_VERSION or not isinstance(data.get("files"), dict):
            return {}
        return data["files"]

    def _save_index(self, files):
        data = json.dumps({"version": INDEX_VERSION, "files": files}, ensure_ascii=False)
        try:
            os.makedirs(self._cache_dir, exist_ok=True)
            _write_atomically(self._index_path, data.encode("utf-8"))
        except OSError as error:
            log("could not save the index: %s", error)
