#include "play-queue.hpp"

#include <QRandomGenerator>

#include <algorithm>

int PlayQueue::current() const
{
    return current_row;
}

bool PlayQueue::has_previous() const
{
    return current_row > 0;
}

bool PlayQueue::has_next() const
{
    return current_row >= 0 && current_row < items.size() - 1;
}

int PlayQueue::up_next_count() const
{
    return current_row < 0 ? 0 : items.size() - 1 - current_row;
}

void PlayQueue::playFrom(TrackModel *songs, int row)
{
    if (songs == nullptr || row < 0 || row >= songs->all().size())
    {
        return;
    }
    replace(songs->all(), row);
}

void PlayQueue::playShuffled(TrackModel *songs)
{
    if (songs == nullptr || songs->all().isEmpty())
    {
        return;
    }

    QVector<Track> shuffled = songs->all();
    std::shuffle(shuffled.begin(), shuffled.end(), *QRandomGenerator::global());
    replace(shuffled, 0);
}

void PlayQueue::playList(const QVariantList& songs, int row)
{
    QVector<Track> tracks;
    int new_current = -1;
    for (int index = 0; index < songs.size(); ++index)
    {
        const Track track = Track::from_qml(songs.at(index).toMap());
        if (!track.is_valid())
        {
            continue;
        }
        // row counts the unplayable songs too, so map it while skipping them
        if (index == row)
        {
            new_current = tracks.size();
        }
        tracks.append(track);
    }

    if (new_current >= 0)
    {
        replace(tracks, new_current);
    }
}

void PlayQueue::playNext(const QVariantMap& song)
{
    // current_row + 1 is also 0 for an empty queue
    insert_at(current_row + 1, song);
}

void PlayQueue::addToEnd(const QVariantMap& song)
{
    insert_at(items.size(), song);
}

void PlayQueue::removeAt(int row)
{
    if (!has_row(row) || row == current_row)
    {
        return;
    }

    beginRemoveRows(QModelIndex(), row, row);
    items.remove(row);
    if (row < current_row)
    {
        --current_row;
    }
    endRemoveRows();
    emit placeChanged();
}

void PlayQueue::clearUpNext()
{
    if (!has_next())
    {
        return;
    }

    const int first = current_row + 1;
    beginRemoveRows(QModelIndex(), first, items.size() - 1);
    items.remove(first, items.size() - first);
    endRemoveRows();
    emit placeChanged();
}

bool PlayQueue::step(int by)
{
    return jumpTo(current_row + by);
}

bool PlayQueue::jumpTo(int row)
{
    if (!has_row(row))
    {
        return false;
    }

    if (row != current_row)
    {
        current_row = row;
        emit placeChanged();
    }
    return true;
}

QVariantMap PlayQueue::trackAt(int row) const
{
    return qml_at(row);
}

QVariantMap PlayQueue::currentTrack() const
{
    return qml_at(current_row);
}

void PlayQueue::replace(const QVector<Track>& tracks, int new_current)
{
    beginResetModel();
    items = tracks;
    current_row = new_current;
    endResetModel();
    emit placeChanged();
}

void PlayQueue::insert_at(int row, const QVariantMap& song)
{
    const Track track = Track::from_qml(song);
    if (!track.is_valid())
    {
        return;
    }

    beginInsertRows(QModelIndex(), row, row);
    items.insert(row, track);
    if (current_row < 0)
    {
        current_row = 0;
    }
    endInsertRows();
    emit placeChanged();
}
