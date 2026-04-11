require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @invoice = invoices(:one)
  end

  test "should get index" do
    get invoices_url
    assert_response :success
  end

  test "should get new" do
    get new_invoice_url
    assert_response :success
  end

  test "should create invoice" do
    assert_difference("Invoice.count") do
      post invoices_url, params: { invoice: { amount: @invoice.amount, customer_name: @invoice.customer_name, delivery_date: @invoice.delivery_date, invoice_date: @invoice.invoice_date, invoice_number: @invoice.invoice_number, load_number: @invoice.load_number, notes: @invoice.notes, piece_count: @invoice.piece_count, product_description: @invoice.product_description, rate_per_piece: @invoice.rate_per_piece, status: @invoice.status, truck_id: @invoice.truck_id } }
    end

    assert_redirected_to invoice_url(Invoice.last)
  end

  test "should show invoice" do
    get invoice_url(@invoice)
    assert_response :success
  end

  test "should get edit" do
    get edit_invoice_url(@invoice)
    assert_response :success
  end

  test "should update invoice" do
    patch invoice_url(@invoice), params: { invoice: { amount: @invoice.amount, customer_name: @invoice.customer_name, delivery_date: @invoice.delivery_date, invoice_date: @invoice.invoice_date, invoice_number: @invoice.invoice_number, load_number: @invoice.load_number, notes: @invoice.notes, piece_count: @invoice.piece_count, product_description: @invoice.product_description, rate_per_piece: @invoice.rate_per_piece, status: @invoice.status, truck_id: @invoice.truck_id } }
    assert_redirected_to invoice_url(@invoice)
  end

  test "should destroy invoice" do
    assert_difference("Invoice.count", -1) do
      delete invoice_url(@invoice)
    end

    assert_redirected_to invoices_url
  end
end
