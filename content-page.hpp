#pragma once

#include <QDateTime>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "card-model.hpp"
#include "track-model.hpp"

// an album, artist, playlist or home page. handed to qml empty and loading, filled
// when the helper answers. which fields get set depends on the kind, see fill() and
// the answers in helper/youtube_music.py.
class ContentPage : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString kind READ kind CONSTANT)
    Q_PROPERTY(QString browseId READ browse_id CONSTANT)
    Q_PROPERTY(QString title READ title NOTIFY contentChanged)
    Q_PROPERTY(QString subtitle READ subtitle NOTIFY contentChanged)
    Q_PROPERTY(QString description READ description NOTIFY contentChanged)
    Q_PROPERTY(QString thumbnailUrl READ thumbnail_url NOTIFY contentChanged)
    Q_PROPERTY(TrackModel* tracks READ tracks CONSTANT)
    Q_PROPERTY(CardModel* albums READ albums CONSTANT)
    Q_PROPERTY(CardModel* singles READ singles CONSTANT)
    // home only: [{title, items}], each item a track or card map with "type" set to which
    Q_PROPERTY(QVariantList shelves READ shelves NOTIFY contentChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString problem READ problem NOTIFY problemChanged)

  public:
    ContentPage(const QString& kind, const QString& browse_id, QObject *parent = nullptr);

    QString kind() const;
    QString browse_id() const;
    QString title() const;
    QString subtitle() const;
    QString description() const;
    QString thumbnail_url() const;
    TrackModel *tracks();
    CardModel *albums();
    CardModel *singles();
    QVariantList shelves() const;
    bool loading() const;
    QString problem() const;

    void start_loading();
    void fill(const QVariantMap& answer);
    void fail(const QString& message);

    bool is_stale() const;

    static constexpr int STALE_AFTER_SECONDS = 600;

  signals:
    void contentChanged();
    void loadingChanged();
    void problemChanged();

  private:
    void set_loading(bool value);
    void set_problem(const QString& text);
    static QVariantList shelves_from_helper(const QVariantList& shelves);

    QString page_kind;
    QString page_browse_id;
    QString page_title;
    QString page_subtitle;
    QString page_description;
    QString page_thumbnail_url;
    TrackModel page_tracks;
    CardModel page_albums;
    CardModel page_singles;
    QVariantList page_shelves;
    bool is_loading = false;
    QString problem_text;
    QDateTime filled_at;
};
