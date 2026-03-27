class CustomersController < ApplicationController
  def index
    all_invoices = current_user.invoices

    grouped = all_invoices.group_by(&:customer_name)

    @customers = grouped.map do |name, invoices|
      total_revenue = invoices.sum { |i| i.amount.to_f }
      paid_count    = invoices.count { |i| i.status == 'paid' }
      invoice_count = invoices.size
      avg_invoice   = invoice_count > 0 ? (total_revenue / invoice_count).round(2) : 0

      {
        name:          name,
        invoice_count: invoice_count,
        total_revenue: total_revenue.round(2),
        paid_count:    paid_count,
        unpaid_count:  invoice_count - paid_count,
        avg_invoice:   avg_invoice,
        payment_rate:  invoice_count > 0 ? ((paid_count.to_f / invoice_count) * 100).round(0) : 0
      }
    end.sort_by { |c| -c[:total_revenue] }

    total_revenue = @customers.sum { |c| c[:total_revenue] }
    @avg_customer_value = @customers.size > 0 ? (total_revenue / @customers.size).round(2) : 0
    @top_customer = @customers.first
  end
end
