// english defaults for the config's [music.words]; the config overrides any of them

.pragma library

const defaults = {
    window_title: "Bandstand",
    search_placeholder: "",

    display_idle: "",
    display_loading: "Loading…",
    status_loading: "Loading…",
    status_radio: "Starting radio…",
    loading: "Loading…",
    searching: "Searching…",

    tab_songs: "Songs",
    tab_albums: "Albums",
    tab_artists: "Artists",
    tab_playlists: "Playlists",

    column_title: "Title",
    column_time: "Time",
    column_artist: "Artist",
    column_album: "Album",

    sidebar_music: "Music",
    sidebar_library: "Library",
    sidebar_playlists: "Playlists",

    page_search: "Search",
    page_home: "Home",
    page_liked: "Liked Songs",
    page_history: "History",
    page_albums: "Albums",
    page_artists: "Artists",
    section_top_songs: "Top Songs",
    section_albums: "Albums",
    section_singles: "Singles",

    empty: "",
    empty_liked: "",
    empty_history: "",
    empty_playlist: "",
    empty_albums: "",
    empty_artists: "",
    empty_remote: "",
    nothing_found: "Nothing found for “%1”.",

    queue_title: "Up Next",
    queue_clear: "Clear",
    queue_empty: "",

    action_play: "Play",
    action_shuffle: "Shuffle",
    action_rename: "Rename",
    action_delete: "Delete",
    action_cancel: "Cancel",
    action_clear_history: "Clear History",
    action_save_album: "Add to Library",
    action_unsave_album: "Remove from Library",
    action_save_artist: "Add to Library",
    action_unsave_artist: "Remove from Library",
    action_save_playlist: "Save as Playlist",

    menu_play: "Play",
    menu_play_next: "Play Next",
    menu_add_to_queue: "Add to Up Next",
    menu_like: "Add to Liked Songs",
    menu_unlike: "Remove from Liked Songs",
    menu_add_to_playlist: "Add to Playlist",
    menu_new_playlist: "New Playlist…",
    menu_start_radio: "Start Radio",
    menu_remove_playlist: "Remove from Playlist",
    menu_remove_history: "Remove from History",
    menu_open: "Open",
    menu_save: "Add to Library",
    menu_unsave: "Remove from Library",

    new_playlist_name: "New Playlist",
    notice_added: "Added to “%1”",
    notice_already: "“%1” has this song already",
    notice_liked: "Added to Liked Songs",
    notice_already_liked: "This song is in Liked Songs already",
    confirm_delete_playlist: "Delete the playlist “%1”?",
    confirm_clear_history: "Clear the history of what was played?",

    song_one: "1 song",
    songs_many: "%1 songs",
    duration_minutes: "%1 min",
    duration_hours: "%1 h %2 min"
}

function withDefaults(words) {
    return Object.assign({}, defaults, words ?? {})
}
