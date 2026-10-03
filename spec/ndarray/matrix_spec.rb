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

  describe "#[]" do
    let(:matrix) { described_class[[1, 2, 3], [4, 5, 6]] }

    it "returns the element at row i, column j" do
      expect(matrix[0, 0]).to eq(1)
      expect(matrix[1, 2]).to eq(6)
    end

    it "counts negative indices from the end" do
      expect(matrix[-1, -1]).to eq(6)
      expect(matrix[-2, 0]).to eq(1)
    end

    it "returns nil when out of range" do
      expect(matrix[2, 0]).to be_nil
      expect(matrix[0, 3]).to be_nil
      expect(matrix[-3, 0]).to be_nil
      expect(described_class.empty(2, 0)[0, 0]).to be_nil
    end

    it "returns elements with their original class" do
      expect(described_class[[1.5]][0, 0]).to eql(1.5)
      expect(described_class[[Rational(1, 2), 1]][0, 0]).to eql(Rational(1, 2))
      expect(described_class[[Rational(1, 2), 1]][0, 1]).to eql(1)
    end

    it "is aliased as #element and #component" do
      expect(matrix.element(1, 1)).to eq(5)
      expect(matrix.component(1, 1)).to eq(5)
    end
  end

  describe "#==" do
    let(:matrix) { described_class[[1, 2], [3, 4]] }

    it "is true for matrices with the same elements" do
      expect(matrix).to eq(described_class[[1, 2], [3, 4]])
    end

    it "is false when an element differs" do
      expect(matrix).not_to eq(described_class[[1, 2], [3, 5]])
    end

    it "compares elements numerically across storages" do
      expect(matrix).to eq(described_class[[1.0, 2.0], [3.0, 4.0]])
      expect(described_class[[1.0, 2.0], [3.0, 4.0]]).to eq(matrix)
      expect(described_class[[Rational(1, 2)]]).to eq(described_class[[0.5]])
    end

    it "compares large integers and floats exactly" do
      expect(described_class[[2**53]]).to eq(described_class[[2.0**53]])
      expect(described_class[[2**53 + 1]]).not_to eq(described_class[[2.0**53]])
    end

    it "is false for different shapes, including empty ones" do
      expect(described_class[[1, 2]]).not_to eq(described_class[[1], [2]])
      expect(described_class.empty(0, 3)).not_to eq(described_class.empty(0, 2))
      expect(described_class.empty(2, 0)).to eq(described_class[[], []])
    end

    it "is false for objects that are not matrices" do
      expect(matrix).not_to eq([[1, 2], [3, 4]])
      expect(matrix).not_to eq(nil)
    end
  end

  describe "#clone and #dup" do
    [
      [[1, 2], [3, 4]],
      [[1.5, 2.5], [3.5, 4.5]],
      [[Rational(1, 2), Complex(0, 1)], [1, 2.0]]
    ].each do |rows|
      it "copy a matrix with elements #{rows.flatten.map(&:class).uniq.join(", ")}" do
        matrix = described_class[*rows]

        [matrix.clone, matrix.dup].each do |copy|
          expect(copy).to be_a(described_class)
          expect(copy).not_to equal(matrix)
          expect(copy.to_a).to eq(rows)
        end
      end
    end

    it "copies empty matrices keeping their shape" do
      copy = described_class.empty(0, 3).clone

      expect([copy.row_count, copy.column_count]).to eq([0, 3])
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
