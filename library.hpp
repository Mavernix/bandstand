#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QSet>
#include <QString>
#include <QTimer>
#include <QVariantMap>

#include "card-model.hpp"
#include "playlist-list.hpp"
#include "track-model.hpp"

// the user's local library, one json file per part so other tools can read it:
//   FOLDER/playlists/ID.json, liked.json, history.json, albums.json, artists.json
class Library : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel* playlists READ playlists CONSTANT)
    Q_PROPERTY(TrackModel* liked READ liked CONSTANT)
    Q_PROPERTY(TrackModel* history READ history CONSTANT)
    Q_PROPERTY(CardModel* albums READ albums CONSTANT)
    Q_PROPERTY(CardModel* artists READ artists CONSTANT)
    // bumped on every change; qml bindings that call isLiked()/isSaved() read these
    // so they get re-evaluated
    Q_PROPERTY(int likedVersion READ liked_version NOTIFY likedChanged)
    Q_PROPERTY(int savedVersion READ saved_version NOTIFY savedChanged)
    // last write error, empty once everything saved
    Q_PROPERTY(QString problem READ problem NOTIFY problemChanged)

  public:
    // the folder is only created on the first write
    explicit Library(const QString& folder, QObject *parent = nullptr);
    ~Library() override;

    QAbstractItemModel *playlists();
    TrackModel *liked();
    TrackModel *history();
    CardModel *albums();
    CardModel *artists();
    int liked_version() const;
    int saved_version() const;
    QString problem() const;

    Q_INVOKABLE QString createPlaylist(const QString& name);
    Q_INVOKABLE QString createPlaylistFrom(const QString& name, TrackModel *songs);
    Q_INVOKABLE void renamePlaylist(const QString& id, const QString& name);
    Q_INVOKABLE void deletePlaylist(const QString& id);
    Q_INVOKABLE TrackModel *playlistTracks(const QString& id) const;
    Q_INVOKABLE QString playlistName(const QString& id) const;
    // false if the playlist already has the song
    Q_INVOKABLE bool addToPlaylist(const QString& id, const QVariantMap& song);
    // returns how many were new
    Q_INVOKABLE int addAllToPlaylist(const QString& id, TrackModel *songs);
    Q_INVOKABLE bool playlistHas(const QString& id, const QString& video_id) const;

    Q_INVOKABLE bool isLiked(const QString& video_id) const;
    Q_INVOKABLE void setLiked(const QVariantMap& song, bool liked);

    // newest first, each song once, capped at HISTORY_LIMIT
    Q_INVOKABLE void recordPlayed(const QVariantMap& song);
    Q_INVOKABLE void clearHistory();

    Q_INVOKABLE bool isSaved(const QString& browse_id) const;
    // albums and artists only, other kinds are ignored
    Q_INVOKABLE void save(const QVariantMap& card);
    Q_INVOKABLE void unsave(const QString& browse_id);

    // writes pending changes now; files that fail stay pending and are retried
    void flush();

    static constexpr int HISTORY_LIMIT = 500;

  signals:
    void likedChanged();
    void savedChanged();
    void problemChanged();

  private:
    // `what` is "liked", "history", "albums", "artists" or "playlist:ID"
    void mark_dirty(const QString& what);
    QString path_of(const QString& what) const;
    bool write_file(const QString& what);
    void delete_playlist_file(const QString& id);
    void set_problem(const QString& text);

    void load();
    void load_playlists();
    QJsonObject read_object(const QString& path) const;
    void watch_for_changes();
    void rebuild_liked_ids();
    QString new_playlist_id() const;

    QString folder;
    PlaylistList playlist_list;
    TrackModel liked_songs;
    TrackModel history_songs;
    CardModel saved_albums;
    CardModel saved_artists;
    QSet<QString> liked_ids;
    int liked_counter = 0;
    int saved_counter = 0;
    QString problem_text;

    QSet<QString> dirty;
    QTimer write_timer;
};
