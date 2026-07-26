require "test_helper"

class SettlementImportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  def upload(name = "settlement_statement")
    Rack::Test::UploadedFile.new(file_fixture("#{name}.txt"), "application/pdf")
  end

  def empty_upload(filename = "cloud_only.pdf")
    file = Tempfile.new([ "empty", ".pdf" ])
    Rack::Test::UploadedFile.new(file.path, "application/pdf", original_filename: filename)
  end

  test "the upload form renders and accepts many files at once" do
    get new_settlement_import_url

    assert_response :success
    assert_select "form[enctype=?]", "multipart/form-data"
    assert_select "input[type=file][name=?][multiple]", "statements[]"
  end

  # This action answers with a report instead of redirecting, and Turbo throws
  # away a 200 OK HTML response to a form submission. Without opting out the
  # upload silently does nothing: the import runs, the response is discarded,
  # and the page never changes.
  test "the upload form opts out of turbo because it renders its result" do
    get new_settlement_import_url

    assert_select "form[data-turbo=?]", "false"
  end

  # The regression that made every upload fail: PDF::Reader takes a path or a
  # real IO, and an uploaded file is neither. Handing the wrapper straight over
  # raises ArgumentError, which surfaced as "this statement could not be read"
  # for a perfectly good PDF. The earlier tests stubbed extraction and so drove
  # straight past the broken line; this one checks what extraction is handed.
  test "extraction is handed a real IO rather than the upload wrapper" do
    seen = {}
    original = SettlementStatementParser.method(:extract)
    text = file_fixture("settlement_statement.txt").read
    # Inspected inside the call: the tempfile is closed once the request ends.
    SettlementStatementParser.define_singleton_method(:extract) do |source|
      seen = {
        wrapper: source.is_a?(ActionDispatch::Http::UploadedFile),
        seekable: source.respond_to?(:seek),
        pos: (source.pos if source.respond_to?(:pos))
      }
      text
    end

    begin
      post settlement_import_url, params: { statements: [ upload ] }
    ensure
      SettlementStatementParser.singleton_class.undef_method(:extract)
      SettlementStatementParser.define_singleton_method(:extract, original)
    end

    assert_not seen[:wrapper], "the upload wrapper must be unwrapped before parsing"
    assert seen[:seekable], "PDF::Reader needs a seekable IO"
    assert_equal 0, seen[:pos], "the IO must be rewound before it is read"
  end

  test "the create action answers with a rendered report" do
    post settlement_import_url, params: { statements: [ upload ] }

    assert_response :ok
    assert_select "h1", "Import Results"
  end

  # Turning a PDF into text is a thin call into the gem, verified separately
  # against real statements. Stubbing it here keeps these tests on the part this
  # controller is responsible for: which files it accepts and where they land.
  def with_statement_text(name = "settlement_statement")
    text = file_fixture("#{name}.txt").read
    original = SettlementStatementParser.method(:extract)
    SettlementStatementParser.define_singleton_method(:extract) { |_source| text }
    yield
  ensure
    SettlementStatementParser.singleton_class.undef_method(:extract)
    SettlementStatementParser.define_singleton_method(:extract, original)
  end

  test "several statements are read in one submission" do
    post settlement_import_url, params: { statements: [ upload, upload("settlement_with_trip_permit") ] }

    assert_response :success
    assert_equal 2, @controller.view_assigns["outcomes"].size
  end

  test "a readable statement is imported" do
    with_statement_text do
      assert_difference "Settlement.count", 1 do
        post settlement_import_url, params: { statements: [ upload ] }
      end
    end

    assert_response :success
    assert @controller.view_assigns["outcomes"].first.imported?
  end

  test "the same statement uploaded twice is imported once" do
    with_statement_text do
      assert_difference "Settlement.count", 1 do
        post settlement_import_url, params: { statements: [ upload, upload ] }
      end
    end

    outcomes = @controller.view_assigns["outcomes"]
    assert_equal 1, outcomes.count(&:imported?)
    assert_equal 1, outcomes.count(&:skipped?)
  end

  test "submitting nothing explains what to do rather than assuming none were picked" do
    post settlement_import_url, params: { statements: [ "" ] }

    assert_redirected_to new_settlement_import_path
    assert_match(/No files reached the server/, flash[:alert])
    assert_match(/OneDrive/, flash[:alert])
  end

  # A cloud-only file submits with a name but no bytes, which previously read as
  # "you did not choose a file" even though the driver plainly had.
  test "a zero byte upload is named rather than dismissed" do
    post settlement_import_url, params: { statements: [ empty_upload("Settlement 07-14.pdf") ] }

    assert_redirected_to new_settlement_import_path
    assert_match(/arrived empty/, flash[:alert])
    assert_match(/Settlement 07-14\.pdf/, flash[:alert])
  end

  test "empty files are skipped but the good ones still import" do
    post settlement_import_url, params: { statements: [ empty_upload, upload ] }

    assert_response :success
    assert_equal 1, @controller.view_assigns["outcomes"].size
    assert_equal 1, @controller.view_assigns["skipped_empty"].size
  end

  test "too many files at once is refused" do
    post settlement_import_url, params: { statements: Array.new(61) { upload } }

    assert_redirected_to new_settlement_import_path
    assert_match(/at most/, flash[:alert])
  end

  test "statements import against the chosen truck" do
    with_statement_text do
      post settlement_import_url, params: { statements: [ upload ], truck_id: trucks(:two).id }
    end

    assert_response :success
    assert_equal trucks(:two), Settlement.order(:created_at).last.truck
  end

  test "another user's truck cannot be the import target" do
    with_statement_text do
      post settlement_import_url, params: { statements: [ upload ], truck_id: trucks(:three).id }
    end

    assert_response :success
    settlement = Settlement.order(:created_at).last
    assert_equal users(:one), settlement.user
    assert_not_equal trucks(:three), settlement.truck
  end
end
