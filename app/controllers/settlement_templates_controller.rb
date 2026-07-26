class SettlementTemplatesController < ApplicationController
  before_action :ensure_trucks!
  before_action :set_template, only: %i[ edit update destroy apply run ]
  before_action :set_trucks, only: %i[ index new edit create update apply ]

  def index
    @settlement_templates = current_user.settlement_templates.includes(lines: :expenses).order(:name)
  end

  def new
    @settlement_template = current_user.settlement_templates.new(
      truck: selected_truck || current_user.default_truck
    )

    @settlement_template.lines = if params[:starter].present?
      SettlementTemplate.starter_lines
    else
      [ SettlementTemplateLine.new(position: 0) ]
    end
  end

  def create
    @settlement_template = current_user.settlement_templates.new(template_params)
    assign_owned_truck_if_present(@settlement_template)

    if @settlement_template.save
      redirect_to settlement_templates_path, notice: "Settlement template saved."
    else
      set_trucks
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @settlement_template.assign_attributes(template_params)
    assign_owned_truck_if_present(@settlement_template)

    if @settlement_template.save
      redirect_to settlement_templates_path, notice: "Settlement template updated.", status: :see_other
    else
      set_trucks
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @settlement_template.destroy!
    redirect_to settlement_templates_path, notice: "Settlement template deleted.", status: :see_other
  end

  # The form that turns one settlement statement into a week of expenses.
  def apply
    @expense_date = parse_date(params[:expense_date]) || Date.current
    @lines = @settlement_template.active_lines
  end

  def run
    expense_date = parse_date(params[:expense_date])
    return redirect_to apply_settlement_template_path(@settlement_template), alert: "Enter a valid date." if expense_date.blank?

    truck = @settlement_template.truck || current_user.default_truck
    return redirect_to apply_settlement_template_path(@settlement_template), alert: "Assign a truck to this template first." if truck.blank?

    created = build_expenses(expense_date, truck)

    if created.empty?
      redirect_to apply_settlement_template_path(@settlement_template, expense_date: expense_date),
                  alert: "Nothing to record — every line was zero or unchecked."
    elsif created.all?(&:persisted?)
      redirect_to expenses_path(start_date: expense_date, end_date: expense_date),
                  notice: "Recorded #{helpers.pluralize(created.size, 'expense')} for #{expense_date}."
    else
      @expense_date = expense_date
      @lines = @settlement_template.active_lines
      @failed = created.reject(&:persisted?)
      render :apply, status: :unprocessable_entity
    end
  end

  private

  def build_expenses(expense_date, truck)
    submitted = params[:lines] || {}

    @settlement_template.active_lines.filter_map do |line|
      row = submitted[line.id.to_s]
      next if row.blank?
      next unless ActiveModel::Type::Boolean.new.cast(row[:include])

      amount = row[:amount].to_d
      next unless amount.positive?

      current_user.expenses.create(
        truck: truck,
        settlement_template_line: line,
        expense_date: expense_date,
        category: line.category,
        vendor: @settlement_template.vendor.presence,
        amount: amount,
        notes: line.label
      )
    end
  end

  def set_template
    @settlement_template = current_user.settlement_templates.find(params.expect(:id))
  end

  def set_trucks
    @trucks = current_trucks
  end

  def assign_owned_truck_if_present(template)
    truck_id = params.dig(:settlement_template, :truck_id)
    template.truck = truck_id.present? ? current_user.trucks.find_by(id: truck_id) : nil
  end

  def template_params
    params.require(:settlement_template).permit(
      :name, :vendor, :notes,
      lines_attributes: [ :id, :label, :category, :amount, :balance_target, :position, :active, :_destroy ]
    )
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end
end
