#pragma once

#include <QByteArray>
#include <QHash>
#include <QString>
#include <QVariant>
#include <QVariantMap>

// an album, artist or playlist tile. helper shape: helper/youtube_music.py
struct Card
{
    enum Role
    {
        KindRole = Qt::UserRole + 1,
        BrowseIdRole,
        TitleRole,
        SubtitleRole,
        ThumbnailUrlRole,
    };

    // "album", "artist" or "playlist"
    QString kind;
    QString browse_id;
    QString title;
    QString subtitle;
    QString thumbnail_url;

    static Card from_helper(const QVariantMap& map);
    static Card from_qml(const QVariantMap& map);
    QVariantMap to_helper() const;
    QVariantMap to_qml() const;

    static QHash<int, QByteArray> role_names();
    QVariant role_value(int role) const;

    bool is_valid() const;
};
