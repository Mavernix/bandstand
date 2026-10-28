#include "track-model.hpp"

int TrackModel::total_seconds() const
{
    int total = 0;
    for (const Track& track : items)
    {
        total += track.duration_seconds;
    }
    return total;
}

void TrackModel::set_tracks(const QVariantList& helper_tracks)
{
    QVector<Track> parsed;
    for (const QVariant& entry : helper_tracks)
    {
        parsed.append(Track::from_helper(entry.toMap()));
    }
    set_all(parsed);
}

void TrackModel::set_all(const QVector<Track>& tracks)
{
    const int old_count = items.size();

    beginResetModel();
    items.clear();
    for (const Track& track : tracks)
    {
        if (track.is_valid())
        {
            items.append(track);
        }
    }
    endResetModel();

    if (items.size() != old_count)
    {
        emit countChanged();
    }
    emit changed();
}

void TrackModel::append(const Track& track)
{
    insert(items.size(), track);
}

void TrackModel::insert(int row, const Track& track)
{
    if (!track.is_valid() || row < 0 || row > items.size())
    {
        return;
    }

    beginInsertRows(QModelIndex(), row, row);
    items.insert(row, track);
    endInsertRows();
    emit countChanged();
    emit changed();
}

void TrackModel::remove_at(int row)
{
    if (!has_row(row))
    {
        return;
    }

    beginRemoveRows(QModelIndex(), row, row);
    items.remove(row);
    endRemoveRows();
    emit countChanged();
    emit changed();
}

void TrackModel::move_row(int from, int to)
{
    if (!has_row(from) || !has_row(to) || from == to)
    {
        return;
    }

    // qt wants the row it lands before, which is one further when moving down
    const int destination = to > from ? to + 1 : to;
    beginMoveRows(QModelIndex(), from, from, QModelIndex(), destination);
    items.move(from, to);
    endMoveRows();
    emit changed();
}

void TrackModel::clear()
{
    if (items.isEmpty())
    {
        return;
    }

    beginResetModel();
    items.clear();
    endResetModel();
    emit countChanged();
    emit changed();
}

void TrackModel::removeAt(int row)
{
    remove_at(row);
}

void TrackModel::moveRow(int from, int to)
{
    move_row(from, to);
}

QVariantMap TrackModel::trackAt(int row) const
{
    return qml_at(row);
}
