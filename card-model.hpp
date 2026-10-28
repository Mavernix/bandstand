#pragma once

#include <QVariantList>

#include "card.hpp"
#include "list-model.hpp"

class CardModel : public ListModel<Card>
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

  public:
    using ListModel::ListModel;

    // cards without a browse id are dropped
    void set_cards(const QVariantList& helper_cards);
    void set_all(const QVector<Card>& cards);

    // moves an existing card with the same id to the front instead of duplicating it
    void add_first(const Card& card);
    bool remove_id(const QString& browse_id);
    bool contains(const QString& browse_id) const;

    Q_INVOKABLE QVariantMap cardAt(int row) const;

  signals:
    void countChanged();
    // any edit at all; the library saves off this
    void changed();

  private:
    int row_of(const QString& browse_id) const;
};
