#include "content-page.hpp"

ContentPage::ContentPage(const QString& kind, const QString& browse_id, QObject *parent)
    : QObject(parent)
    , page_kind(kind)
    , page_browse_id(browse_id)
{
}

QString ContentPage::kind() const
{
    return page_kind;
}

QString ContentPage::browse_id() const
{
    return page_browse_id;
}

QString ContentPage::title() const
{
    return page_title;
}

QString ContentPage::subtitle() const
{
    return page_subtitle;
}

QString ContentPage::description() const
{
    return page_description;
}

QString ContentPage::thumbnail_url() const
{
    return page_thumbnail_url;
}

TrackModel *ContentPage::tracks()
{
    return &page_tracks;
}

CardModel *ContentPage::albums()
{
    return &page_albums;
}

CardModel *ContentPage::singles()
{
    return &page_singles;
}

QVariantList ContentPage::shelves() const
{
    return page_shelves;
}

bool ContentPage::loading() const
{
    return is_loading;
}

QString ContentPage::problem() const
{
    return problem_text;
}

void ContentPage::start_loading()
{
    set_loading(true);
}

void ContentPage::fill(const QVariantMap& answer)
{
    auto text = [&answer](const char *key) { return answer.value(QLatin1String(key)).toString(); };
    auto list = [&answer](const char *key) { return answer.value(QLatin1String(key)).toList(); };

    if (page_kind == QLatin1String("album"))
    {
        page_title = text("title");
        const QString artist = text("artist");
        const QString year = text("year");
        page_subtitle = artist.isEmpty() || year.isEmpty() ? artist + year : artist + QStringLiteral(" · ") + year;
        page_thumbnail_url = text("thumbnail_url");
        page_tracks.set_tracks(list("tracks"));
    }
    else if (page_kind == QLatin1String("playlist"))
    {
        page_title = text("title");
        page_subtitle = text("author");
        page_thumbnail_url = text("thumbnail_url");
        page_tracks.set_tracks(list("tracks"));
    }
    else if (page_kind == QLatin1String("artist"))
    {
        page_title = text("name");
        page_description = text("description");
        page_thumbnail_url = text("thumbnail_url");
        page_tracks.set_tracks(list("songs"));
        page_albums.set_cards(list("albums"));
        page_singles.set_cards(list("singles"));
    }
    else if (page_kind == QLatin1String("home"))
    {
        page_shelves = shelves_from_helper(list("shelves"));
    }

    filled_at = QDateTime::currentDateTime();
    emit contentChanged();
    set_problem({});
    set_loading(false);
}

void ContentPage::fail(const QString& message)
{
    set_problem(message);
    set_loading(false);
}

bool ContentPage::is_stale() const
{
    return !filled_at.isValid() || filled_at.secsTo(QDateTime::currentDateTime()) > STALE_AFTER_SECONDS;
}

void ContentPage::set_loading(bool value)
{
    if (is_loading != value)
    {
        is_loading = value;
        emit loadingChanged();
    }
}

void ContentPage::set_problem(const QString& text)
{
    if (problem_text != text)
    {
        problem_text = text;
        emit problemChanged();
    }
}

QVariantList ContentPage::shelves_from_helper(const QVariantList& shelves)
{
    QVariantList result;
    for (const QVariant& entry : shelves)
    {
        const QVariantMap shelf = entry.toMap();

        QVariantList items;
        for (const QVariant& item_entry : shelf.value(QStringLiteral("items")).toList())
        {
            const QVariantMap item = item_entry.toMap();
            QVariantMap shown;
            // only tracks carry a video_id
            if (item.contains(QStringLiteral("video_id")))
            {
                shown = Track::from_helper(item).to_qml();
                shown.insert(QStringLiteral("type"), QStringLiteral("track"));
            }
            else
            {
                shown = Card::from_helper(item).to_qml();
                shown.insert(QStringLiteral("type"), QStringLiteral("card"));
            }
            items.append(shown);
        }

        result.append(QVariantMap{
            {QStringLiteral("title"), shelf.value(QStringLiteral("title"))},
            {QStringLiteral("items"), items},
        });
    }
    return result;
}
