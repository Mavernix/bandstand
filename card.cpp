#include "card.hpp"

namespace
{
struct Keys
{
    QString kind;
    QString browse_id;
    QString title;
    QString subtitle;
    QString thumbnail_url;
};

const Keys helper_keys{"kind", "browse_id", "title", "subtitle", "thumbnail_url"};
const Keys qml_keys{"kind", "browseId", "title", "subtitle", "thumbnailUrl"};

Card read(const QVariantMap& map, const Keys& keys)
{
    Card card;
    card.kind = map.value(keys.kind).toString();
    card.browse_id = map.value(keys.browse_id).toString();
    card.title = map.value(keys.title).toString();
    card.subtitle = map.value(keys.subtitle).toString();
    card.thumbnail_url = map.value(keys.thumbnail_url).toString();
    return card;
}
} // namespace

Card Card::from_helper(const QVariantMap& map)
{
    return read(map, helper_keys);
}

Card Card::from_qml(const QVariantMap& map)
{
    return read(map, qml_keys);
}

QVariantMap Card::to_helper() const
{
    return {
        {helper_keys.kind, kind},
        {helper_keys.browse_id, browse_id},
        {helper_keys.title, title},
        {helper_keys.subtitle, subtitle},
        {helper_keys.thumbnail_url, thumbnail_url},
    };
}

QVariantMap Card::to_qml() const
{
    return {
        {qml_keys.kind, kind},
        {qml_keys.browse_id, browse_id},
        {qml_keys.title, title},
        {qml_keys.subtitle, subtitle},
        {qml_keys.thumbnail_url, thumbnail_url},
    };
}

QHash<int, QByteArray> Card::role_names()
{
    return {
        {KindRole, qml_keys.kind.toLatin1()},
        {BrowseIdRole, qml_keys.browse_id.toLatin1()},
        {TitleRole, qml_keys.title.toLatin1()},
        {SubtitleRole, qml_keys.subtitle.toLatin1()},
        {ThumbnailUrlRole, qml_keys.thumbnail_url.toLatin1()},
    };
}

QVariant Card::role_value(int role) const
{
    switch (role)
    {
    case KindRole: return kind;
    case BrowseIdRole: return browse_id;
    case TitleRole: return title;
    case SubtitleRole: return subtitle;
    case ThumbnailUrlRole: return thumbnail_url;
    default: return {};
    }
}

bool Card::is_valid() const
{
    return !browse_id.isEmpty();
}
