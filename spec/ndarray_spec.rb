# frozen_string_literal: true

RSpec.describe NDArray do
  it "has a version number" do
    expect(NDArray::VERSION).not_to be nil
  end

  describe "Checking Rust <=> Ruby communication" do
    describe '#hello "João"' do
      it { expect(described_class.hello("João")).to eq("Hello from Rust, João!") }
    end
  end
end
