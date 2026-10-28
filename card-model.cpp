#include "card-model.hpp"

void CardModel::set_cards(const QVariantList& helper_cards)
{
    QVector<Card> parsed;
    for (const QVariant& entry : helper_cards)
    {
        parsed.append(Card::from_helper(entry.toMap()));
    }
    set_all(parsed);
}

void CardModel::set_all(const QVector<Card>& cards)
{
    const int old_count = items.size();

    beginResetModel();
    items.clear();
    for (const Card& card : cards)
    {
        if (card.is_valid())
        {
            items.append(card);
        }
    }
    endResetModel();

    if (items.size() != old_count)
    {
        emit countChanged();
    }
    emit changed();
}

void CardModel::add_first(const Card& card)
{
    if (!card.is_valid())
    {
        return;
    }

    remove_id(card.browse_id);
    beginInsertRows(QModelIndex(), 0, 0);
    items.prepend(card);
    endInsertRows();
    emit countChanged();
    emit changed();
}

bool CardModel::remove_id(const QString& browse_id)
{
    const int row = row_of(browse_id);
    if (row < 0)
    {
        return false;
    }

    beginRemoveRows(QModelIndex(), row, row);
    items.remove(row);
    endRemoveRows();
    emit countChanged();
    emit changed();
    return true;
}

bool CardModel::contains(const QString& browse_id) const
{
    return row_of(browse_id) >= 0;
}

QVariantMap CardModel::cardAt(int row) const
{
    return qml_at(row);
}

int CardModel::row_of(const QString& browse_id) const
{
    for (int row = 0; row < items.size(); ++row)
    {
        if (items.at(row).browse_id == browse_id)
        {
            return row;
        }
    }
    return -1;
}
