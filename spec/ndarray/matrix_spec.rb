# frozen_string_literal: true

RSpec.describe NDArray::Matrix do
  describe ".[]" do
    it "keeps Integer elements as Integer" do
      matrix = described_class[[1, 2, 3], [4, 5, 6]]

      expect(matrix.to_a).to eq([[1, 2, 3], [4, 5, 6]])
      expect(matrix.to_a.flatten).to all(be_an(Integer))
    end

    it "keeps Float elements as Float" do
      matrix = described_class[[1.0, 2.5], [3.0, 4.5]]

      expect(matrix.to_a).to eq([[1.0, 2.5], [3.0, 4.5]])
      expect(matrix.to_a.flatten).to all(be_a(Float))
    end

    it "keeps other numeric elements as Ruby objects" do
      rows = [[Rational(1, 2), Complex(1, 2)], [2**64, 1.5]]

      expect(described_class[*rows].to_a).to eq(rows)
    end

    it "preserves each element's type in mixed matrices" do
      expect(described_class[[1, 2.0]].to_a.flatten.map(&:class)).to eq([Integer, Float])
    end

    it "keeps object elements alive across garbage collection" do
      build_rows = -> { Array.new(10) { |i| Array.new(10) { |j| "#{i},#{j}" } } }
      matrix = described_class[*build_rows.call]

      GC.start
      GC.compact if GC.respond_to?(:compact)

      expect(matrix.to_a).to eq(build_rows.call)
    end

    it "accepts objects convertible with #to_ary" do
      row = Object.new
      def row.to_ary = [1, 2, 3]

      expect(described_class[row, [4, 5, 6]].to_a).to eq([[1, 2, 3], [4, 5, 6]])
    end

    it "raises TypeError for rows that are not arrays" do
      expect { described_class[Object.new] }.to raise_error(TypeError)
    end

    it "rejects rows of different sizes" do
      expect { described_class[[1, 2], [3]] }.to raise_error(ArgumentError)
    end

    it "builds empty matrices" do
      expect(described_class[].to_a).to eq([])
      expect(described_class[[]].to_a).to eq([[]])
    end
  end

  describe ".empty" do
    it "builds a 0x0 matrix by default" do
      expect(described_class.empty.to_a).to eq([])
    end

    it "builds matrices with one zero dimension" do
      expect(described_class.empty(2, 0).to_a).to eq([[], []])
      expect(described_class.empty(0, 3).column_count).to eq(3)
      expect(described_class.empty(0, 3).to_a).to eq([])
    end

    it "requires one size to be 0" do
      expect { described_class.empty(2, 3) }.to raise_error(ArgumentError, "One size must be 0")
    end

    it "rejects negative sizes" do
      expect { described_class.empty(-1, 0) }.to raise_error(ArgumentError, "Negative size")
    end
  end

  describe "#row_count and #column_count" do
    let(:matrix) { described_class[[1, 2, 3], [4, 5, 6]] }

    it { expect(matrix.row_count).to eq(2) }
    it { expect(matrix.column_count).to eq(3) }
    it { expect(matrix.row_size).to eq(2) }
    it { expect(matrix.column_size).to eq(3) }

    it "knows the shape of empty matrices" do
      expect([described_class[].row_count, described_class[].column_count]).to eq([0, 0])
      expect([described_class[[]].row_count, described_class[[]].column_count]).to eq([1, 0])
    end
  end
end
