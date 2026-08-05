namespace :escrow do
  desc "Move legacy escrow-category expenses into the escrow ledger (dry run unless APPLY=1)"
  task migrate_expenses: :environment do
    report = EscrowExpenseMigrator.call(apply: ENV["APPLY"] == "1")

    puts "#{report.rows} escrow expense rows, #{ActiveSupport::NumberHelper.number_to_currency(report.total)} total."
    puts report.applied ? "Moved into the escrow ledger." : "Dry run only — nothing moved. Re-run with APPLY=1 to move them."
  end
end
