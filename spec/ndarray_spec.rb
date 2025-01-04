# frozen_string_literal: true

RSpec.describe NDArray do
  it "has a version number" do
    expect(NDArray::VERSION).not_to be nil
  end

  describe "#from_array([[1.0, 2.0], [3.0, 4.0]])" do
    let(:rb_array) { [[1.0, 2.0], [3.0, 4.0]] }

    it { expect(described_class.from_array(rb_array)).to be_a(NDArray) }

    describe "can be converted back to Ruby array with #to_a" do
      it { expect(described_class.from_array(rb_array).to_a).to eq(rb_array) }
    end
  end
end
