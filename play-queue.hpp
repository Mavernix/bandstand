#pragma once

#include <QVariantList>
#include <QVariantMap>

#include "list-model.hpp"
#include "track-model.hpp"
#include "track.hpp"

// the up next queue. songs before `current` were played, songs after it come next.
// stepping only moves `current`, so going back replays. actual playback lives in qml/Main.qml.
class PlayQueue : public ListModel<Track>
{
    Q_OBJECT
    // all of these move together, so one signal covers them
    Q_PROPERTY(int count READ rowCount NOTIFY placeChanged)
    Q_PROPERTY(int current READ current NOTIFY placeChanged)
    Q_PROPERTY(bool hasPrevious READ has_previous NOTIFY placeChanged)
    Q_PROPERTY(bool hasNext READ has_next NOTIFY placeChanged)
    Q_PROPERTY(int upNextCount READ up_next_count NOTIFY placeChanged)

  public:
    using ListModel::ListModel;

    // -1 when empty
    int current() const;
    bool has_previous() const;
    bool has_next() const;
    int up_next_count() const;

    Q_INVOKABLE void playFrom(TrackModel *songs, int row);
    // a one-off shuffle, not a mode
    Q_INVOKABLE void playShuffled(TrackModel *songs);
    // for songs that aren't in a model, e.g. a home page shelf
    Q_INVOKABLE void playList(const QVariantList& songs, int row);
    Q_INVOKABLE void playNext(const QVariantMap& song);
    Q_INVOKABLE void addToEnd(const QVariantMap& song);
    // the current song can't be removed, it's playing
    Q_INVOKABLE void removeAt(int row);
    Q_INVOKABLE void clearUpNext();
    Q_INVOKABLE bool step(int by);
    Q_INVOKABLE bool jumpTo(int row);

    Q_INVOKABLE QVariantMap trackAt(int row) const;
    Q_INVOKABLE QVariantMap currentTrack() const;

  signals:
    void placeChanged();

  private:
    void replace(const QVector<Track>& tracks, int new_current);
    void insert_at(int row, const QVariantMap& song);

    int current_row = -1;
};
