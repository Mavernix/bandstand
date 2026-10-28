#include "playlist-list.hpp"

PlaylistList::PlaylistList(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PlaylistList::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : entries.size();
}

QVariant PlaylistList::data(const QModelIndex& index, int role) const
{
    if (index.row() < 0 || index.row() >= entries.size())
    {
        return {};
    }

    const Entry& entry = entries.at(index.row());
    switch (role)
    {
    case IdRole: return entry.id;
    case NameRole: return entry.name;
    case CountRole: return entry.tracks->rowCount();
    default: return {};
    }
}

QHash<int, QByteArray> PlaylistList::roleNames() const
{
    return {
        {IdRole, "id"},
        {NameRole, "name"},
        {CountRole, "count"},
    };
}

TrackModel *PlaylistList::add(const QString& id, const QString& name)
{
    auto *tracks = new TrackModel(this);

    beginInsertRows(QModelIndex(), entries.size(), entries.size());
    entries.append({id, name, tracks});
    endInsertRows();

    // look the row up each time, earlier playlists may have been removed since
    connect(tracks, &TrackModel::countChanged, this, [this, id]
    {
        const int row = row_of(id);
        if (row >= 0)
        {
            emit dataChanged(index(row), index(row), {CountRole});
        }
    });
    connect(tracks, &TrackModel::changed, this, [this, id] { emit playlistChanged(id); });

    emit countChanged();
    emit playlistChanged(id);
    return tracks;
}

bool PlaylistList::rename(const QString& id, const QString& name)
{
    const int row = row_of(id);
    if (row < 0)
    {
        return false;
    }

    entries[row].name = name;
    emit dataChanged(index(row), index(row), {NameRole});
    emit playlistChanged(id);
    return true;
}

bool PlaylistList::remove(const QString& id)
{
    const int row = row_of(id);
    if (row < 0)
    {
        return false;
    }

    TrackModel *tracks = entries.at(row).tracks;
    beginRemoveRows(QModelIndex(), row, row);
    entries.remove(row);
    endRemoveRows();

    // disconnect first so nothing marks the deleted playlist dirty again
    tracks->disconnect(this);
    tracks->deleteLater();
    emit countChanged();
    emit playlistRemoved(id);
    return true;
}

bool PlaylistList::contains(const QString& id) const
{
    return row_of(id) >= 0;
}

TrackModel *PlaylistList::tracks_of(const QString& id) const
{
    const int row = row_of(id);
    return row < 0 ? nullptr : entries.at(row).tracks;
}

QString PlaylistList::name_of(const QString& id) const
{
    const int row = row_of(id);
    return row < 0 ? QString() : entries.at(row).name;
}

QString PlaylistList::idAt(int row) const
{
    return row < 0 || row >= entries.size() ? QString() : entries.at(row).id;
}

int PlaylistList::row_of(const QString& id) const
{
    for (int row = 0; row < entries.size(); ++row)
    {
        if (entries.at(row).id == id)
        {
            return row;
        }
    }
    return -1;
}
