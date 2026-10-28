#pragma once

#include <QVariantList>

#include "list-model.hpp"
#include "track.hpp"

// search results, album tracks, a playlist, the history...
class TrackModel : public ListModel<Track>
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    // NOTIFY changed, not countChanged: a remove plus an add keeps the count but not the total
    Q_PROPERTY(int totalSeconds READ total_seconds NOTIFY changed)

  public:
    using ListModel::ListModel;

    int total_seconds() const;

    // songs without a video id are dropped
    void set_tracks(const QVariantList& helper_tracks);
    void set_all(const QVector<Track>& tracks);

    void append(const Track& track);
    void insert(int row, const Track& track);
    void remove_at(int row);
    void move_row(int from, int to);
    void clear();

    Q_INVOKABLE void removeAt(int row);
    Q_INVOKABLE void moveRow(int from, int to);
    Q_INVOKABLE QVariantMap trackAt(int row) const;

  signals:
    void countChanged();
    // any edit at all; playlists get saved off this
    void changed();
};
