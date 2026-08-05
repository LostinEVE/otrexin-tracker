# A lease term can be superseded — a trailer swap changes the weekly amounts.
# effective_from lets the audit judge each settlement against the terms in
# force on its date; NULL means "since the beginning".
class AddEffectiveFromToLeaseTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :lease_terms, :effective_from, :date
  end
end
