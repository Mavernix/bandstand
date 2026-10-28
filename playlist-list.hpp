#pragma once

#include <QAbstractListModel>
#include <QVector>

#include "track-model.hpp"

// the user's playlists for the sidebar. owns each playlist's songs; saving is library.cpp's job
class PlaylistList : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

  public:
    enum Role
    {
        IdRole = Qt::UserRole + 1,
        NameRole,
        CountRole,
    };

    explicit PlaylistList(QObject *parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // appends an empty playlist and returns its songs
    TrackModel *add(const QString& id, const QString& name);
    bool rename(const QString& id, const QString& name);
    bool remove(const QString& id);

    bool contains(const QString& id) const;
    TrackModel *tracks_of(const QString& id) const;
    QString name_of(const QString& id) const;

    Q_INVOKABLE QString idAt(int row) const;

  signals:
    void countChanged();
    // added, renamed or its songs edited
    void playlistChanged(const QString& id);
    void playlistRemoved(const QString& id);

  private:
    struct Entry
    {
        QString id;
        QString name;
        TrackModel *tracks = nullptr;
    };

    int row_of(const QString& id) const;

    QVector<Entry> entries;
};
