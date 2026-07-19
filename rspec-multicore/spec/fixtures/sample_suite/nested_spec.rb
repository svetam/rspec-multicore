# frozen_string_literal: true

RSpec.describe "Nested structure" do
  describe "level 1" do
    it "passes at level 1" do
      expect(1).to eq(1)
    end

    describe "level 2" do
      it "passes at level 2" do
        expect(2).to eq(2)
      end

      context "when in context" do
        it "passes in context" do
          expect(3).to eq(3)
        end

        describe "level 3" do
          it "passes at level 3" do
            expect(4).to eq(4)
          end
        end
      end
    end
  end

  describe "another branch" do
    it "passes in another branch" do
      expect(5).to eq(5)
    end
  end
end
