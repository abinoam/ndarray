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

  describe "#dot" do
    describe "[[1.0, 2.0], [3.0, 4.0]] dot [[5.0, 6.0], [7.0, 8.0]]" do
      let(:rb_array1) { [[1.0, 2.0], [3.0, 4.0]] }
      let(:rb_array2) { [[5.0, 6.0], [7.0, 8.0]] }

      let(:ndarray1) { described_class.from_array(rb_array1) }
      let(:ndarray2) { described_class.from_array(rb_array2) }

      describe "returns a new NDArray" do
        it { expect(ndarray1.dot(ndarray2)).to be_a(NDArray) }
      end

      describe "returns the correct result" do
        it { expect(ndarray1.dot(ndarray2).to_a).to eq([[19.0, 22.0], [43.0, 50.0]]) }
      end
    end
  end
end
