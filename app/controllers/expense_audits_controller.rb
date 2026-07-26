class ExpenseAuditsController < ApplicationController
  def show
    @audit = ExpenseAudit.new(user: current_user)
    @grouped = @audit.grouped
    @trucks = current_trucks
  end

  # Applies only the rows the driver ticked. Nothing is inferred beyond what was
  # shown on the review screen.
  def update
    recategorized = apply_recategorizations
    reassigned = apply_truck_move
    deleted = apply_deletions

    if (recategorized + reassigned + deleted).zero?
      redirect_to expense_audit_path, alert: "Nothing was selected, so nothing changed."
    else
      redirect_to expense_audit_path, notice: changes_notice(recategorized, reassigned, deleted)
    end
  end

  private

  def apply_recategorizations
    rows = params[:recategorize]
    return 0 unless rows.respond_to?(:keys)

    rows.keys.count do |expense_id|
      row = rows[expense_id]
      next false unless row.respond_to?(:[])
      next false unless ActiveModel::Type::Boolean.new.cast(row[:apply])

      category = row[:category].to_s
      next false unless Expense::CATEGORIES.key?(category)

      # Scoped to the signed-in user, so an id from someone else's books finds
      # nothing rather than being edited.
      expense = current_user.expenses.find_by(id: expense_id)
      next false if expense.blank? || expense.category == category

      expense.update(category: category)
    end
  end

  def apply_deletions
    ids = Array(params[:delete_ids]).compact_blank

    current_user.expenses.where(id: ids).destroy_all.size
  end

  def apply_truck_move
    from_id = params[:move_from_truck_id]
    to_id = params[:move_to_truck_id]
    return 0 if from_id.blank? || to_id.blank? || from_id == to_id

    from = current_user.trucks.find_by(id: from_id)
    to = current_user.trucks.find_by(id: to_id)
    return 0 if from.blank? || to.blank?

    current_user.expenses.where(truck: from).update_all(truck_id: to.id)
  end

  def changes_notice(recategorized, reassigned, deleted)
    parts = []
    parts << "recategorized #{helpers.pluralize(recategorized, 'expense')}" if recategorized.positive?
    parts << "moved #{helpers.pluralize(reassigned, 'expense')} to another truck" if reassigned.positive?
    parts << "deleted #{helpers.pluralize(deleted, 'expense')}" if deleted.positive?

    "Done — #{parts.to_sentence}."
  end
end
