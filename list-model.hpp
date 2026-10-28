#pragma once

#include <QAbstractListModel>
#include <QVariantMap>
#include <QVector>

// the read side shared by the song and card lists. Item needs role_names(),
// role_value(role) and to_qml(). no Q_OBJECT here, moc doesn't do templates.
template <typename Item>
class ListModel : public QAbstractListModel
{
  public:
    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex& parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : items.size();
    }

    QVariant data(const QModelIndex& index, int role) const override
    {
        return has_row(index.row()) ? items.at(index.row()).role_value(role) : QVariant();
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return Item::role_names();
    }

    const QVector<Item>& all() const
    {
        return items;
    }

  protected:
    bool has_row(int row) const
    {
        return row >= 0 && row < items.size();
    }

    QVariantMap qml_at(int row) const
    {
        return has_row(row) ? items.at(row).to_qml() : QVariantMap();
    }

    QVector<Item> items;
};
