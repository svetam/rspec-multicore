# frozen_string_literal: true

RSpec.describe "first FactoryBot group" do
  it "creates and rolls back a worker-owned record" do
    widget = create(:compatibility_widget)
    expect(CompatibilityWidget.where(id: widget.id)).to exist
    record_database_evidence(widget)
  end
end

RSpec.describe "second FactoryBot group" do
  it "creates and rolls back another worker-owned record" do
    widget = create(:compatibility_widget)
    expect(CompatibilityWidget.where(id: widget.id)).to exist
    record_database_evidence(widget)
  end
end

def record_database_evidence(widget)
  CompatibilityEvidence.record(
    slot: ENV.fetch("RSPEC_MULTICORE_WORKER", "serial"),
    database: ActiveRecord::Base.connection_db_config.database,
    widget: widget.name
  )
end
