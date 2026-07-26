class SettlementImportsController < ApplicationController
  before_action :ensure_trucks!

  MAX_FILES = 60
  MAX_BYTES = 10.megabytes

  def new
    @trucks = current_trucks
  end

  def create
    uploads = Array(params[:statements]).select { |file| file.respond_to?(:original_filename) }
    empty, files = uploads.partition { |file| file.size.to_i.zero? }

    return redirect_to new_settlement_import_path, alert: nothing_usable_message(uploads, empty) if files.empty?

    if files.size > MAX_FILES
      return redirect_to new_settlement_import_path, alert: "Import at most #{MAX_FILES} statements at a time."
    end

    oversized = files.find { |file| file.size.to_i > MAX_BYTES }
    if oversized
      return redirect_to new_settlement_import_path,
                         alert: "#{oversized.original_filename} is larger than #{MAX_BYTES / 1.megabyte} MB."
    end

    truck = current_user.trucks.find_by(id: params[:truck_id]) || current_user.default_truck
    @on_conflict = params[:on_conflict].presence&.to_sym || :hold

    @outcomes = SettlementImporter.new(user: current_user, truck: truck)
      .import_all(files, on_conflict: @on_conflict)
    @skipped_empty = empty.map(&:original_filename)
    @trucks = current_trucks
    @overlapping_invoices = overlapping_invoices

    render :create
  end

  # Revenue is the sum of settlements and paid invoices. A driver who was
  # recording these loads as invoices before will now have both, so the overlap
  # is reported rather than left to be discovered on a tax return.
  def overlapping_invoices
    dates = @outcomes.filter_map { |outcome| outcome.settlement&.statement_date }
    return Invoice.none if dates.empty?

    current_user.invoices.where(status: "paid", invoice_date: dates.min - 7..dates.max + 7)
  end

  private

  # Says what actually arrived rather than assuming nothing was picked. A file
  # stored in OneDrive or iCloud can be a cloud-only placeholder, which the
  # browser submits as zero bytes, and "choose a file" is misleading when the
  # driver plainly did.
  def nothing_usable_message(uploads, empty)
    if uploads.empty?
      "No files reached the server. Pick the PDFs again — and if they live in OneDrive or iCloud, " \
        "make them available offline first (right-click the folder, \"Always keep on this device\"), " \
        "because cloud-only files upload as nothing."
    else
      "#{helpers.pluralize(empty.size, 'file')} arrived empty: #{empty.map(&:original_filename).to_sentence}. " \
        "That usually means the file is stored in the cloud rather than on this device. Make the folder " \
        "available offline and try again."
    end
  end
end
