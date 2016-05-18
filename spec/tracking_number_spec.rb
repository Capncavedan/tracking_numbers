require 'tracking_number'

describe TrackingNumber do

  context "Extracting tracking-number-like things from a bit of text" do
    describe ".extract_identifier_from(text)" do
      it "finds a (FedEx freight) number in a URL" do
        txt = "https://www.fedex.com/insight/findit/nrp.jsp?tracknumbers=076884980006374&opco=FDEG&language=en&clienttype=ivother"
        ret = TrackingNumber.extract_identifier_from(txt)
        expect(ret).to include('076884980006374')
      end

      it "finds a UPS tracking number within a block of text" do
        txt = "this number 1z0T3731P292258842 is my number"
        ret = TrackingNumber.extract_identifier_from(txt)
        expect(ret).to include('1Z0T3731P292258842')
      end

      it "finds multiple UPS tracking numbers within a block of text" do
        txt = "this number, 1Z0T3731P292258842, and this number, 1Z5FX0076803466397, are my numbers"
        ret = TrackingNumber.extract_identifier_from(txt)
        expect(ret).to match_array %w(1Z0T3731P292258842 1Z5FX0076803466397)
      end

      it "finds multiple UPS tracking numbers within a block of text, and filter duplicates" do
        txt = "this number, 1Z0T3731P292258842, and this number, 1Z5FX0076803466397, are my numbers.  And did I mention 1z5FX0076803466397?"
        ret = TrackingNumber.extract_identifier_from(txt)
        expect(ret).to match_array %w(1Z0T3731P292258842 1Z5FX0076803466397)
      end

      it "finds multiple tracking numbers for various carriers within a block of text" do
        txt = "this number, 1Z0T3731P292258842, and this number, C10999911320231, are my numbers.  And did I mention 9102901000462189604217?"
        ret = TrackingNumber.extract_identifier_from(txt)
        expect(ret).to match_array %w(1Z0T3731P292258842  9102901000462189604217  C10999911320231)
      end
    end
  end


  describe "new instance" do
    it "requires a string" do
      expect {
          TrackingNumber.new
        }.to raise_error(ArgumentError)
    end

    it "upcases the provided tracking number" do
      t = TrackingNumber.new '1z01w1010101010100'
      expect(t.string).to eq '1Z01W1010101010100'
    end

    it "collapses the provided tracking number" do
      t = TrackingNumber.new '1Z 010 101010 101010 0'
      expect(t.string).to eq '1Z0101010101010100'
    end

    it "provides an array of carriers" do
      t = TrackingNumber.new '1Z0101010101010100'
      expect(t.carriers).to be_an Array
    end
  end


  context "instance methods" do
    describe "#next_multiple_of_ten" do
      it "returns 160 for 159" do
        t = TrackingNumber.new ''
        expect(t.next_multiple_of_ten 159).to eq 160
      end

      it "returns 170 for 160" do
        t = TrackingNumber.new ''
        expect(t.next_multiple_of_ten 160).to eq 170
      end

      it "returns 170 for 161" do
        t = TrackingNumber.new ''
        expect(t.next_multiple_of_ten 161).to eq 170
      end
    end

    describe "#ups_modified_mod_ten" do
      it "sums the values of the odd-position characters" do
        t = TrackingNumber.new ''
        expect(t.ups_modified_mod_ten '101010101010101').to eq 8
      end

      it "doubles the sum of the values of the even-position characters" do
        t = TrackingNumber.new ''
        expect(t.ups_modified_mod_ten '010101010101010').to eq 14
      end
    end
  end


  context "ONTRAC checksum functions" do
    describe "#ontrac_mapping" do
      it "maps an alpha character A to a numeric character 2" do
        expect(TrackingNumber.new('').ontrac_mapping('A')).to eq '2'
      end

      it "maps an alpha character M to a numeric character 4" do
        expect(TrackingNumber.new('').ontrac_mapping('M')).to eq '4'
      end

      it "does not change a numeric character" do
        expect(TrackingNumber.new('').ontrac_mapping('3')).to eq '3'
      end
    end

    describe "#ontrac_checksum_digit" do
      it "returns the last digit from a string, as an integer" do
        expect(TrackingNumber.new('1234').ontrac_checksum_digit).to eq 4
      end
    end

    describe "#ontrac_core_portion_checksum" do
      it "returns the value derived from the sum of odd-position characters and double the sum of even-position characters" do
        # remember this will be a 1-based array examination, i.e. first character is an odd position
        expect(TrackingNumber.new('C10101010101010').ontrac_core_portion_checksum).to eq 18
      end
    end

    describe "#ontrac_checksum_ok?" do
      it "returns true when the checksum digit matches the checksum remainder of the core portion" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ontrac_checksum_digit).and_return 4
        allow(t).to receive(:ontrac_core_portion_checksum_remainder).and_return 4
        expect(t.ontrac_checksum_ok?).to eq true
      end

      it "returns false when the checksum digit does NOT match the checksum remainder of the core portion" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ontrac_checksum_digit).and_return 4
        allow(t).to receive(:ontrac_core_portion_checksum_remainder).and_return 5
        expect(t.ontrac_checksum_ok?).to eq false
      end
    end

    describe "#ontrac_core_portion_checksum" do
      it "calls #ups_modified_mod_ten with the core portion" do
        t = TrackingNumber.new 'C12345678901234'
        expect(t).to receive(:ups_modified_mod_ten).with '41234567890123'
        t.ontrac_core_portion_checksum
      end
    end

    describe "#ontrac_core_portion_checksum_remainder" do
      it "returns 0 when 10" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ontrac_core_portion_checksum).and_return 10
        expect(t.ontrac_core_portion_checksum_remainder).to eq 0
      end

      it "returns 6 (20 minus 14) when checksum is 14" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ontrac_core_portion_checksum).and_return 14
        expect(t.ontrac_core_portion_checksum_remainder).to eq 6
      end
    end

    describe "#ontrac?" do
      %w(C10999911320231  C10999606576777  C11001105367744  C11000411158855).each do |number|
        it "returns true for #{number}" do
          expect(TrackingNumber.new(number).ontrac?).to eq true
        end
      end

      it "returns false" do
        expect(TrackingNumber.new('C22222222222222').ontrac?).to eq false
      end
    end
  end  # of ONTRAC


  context "UPS checksum functions" do
    describe "#ups_mapping" do
      it "maps an alpha character A to a numeric character 2" do
        expect(TrackingNumber.new('').ups_mapping('A')).to eq '2'
      end

      it "maps an alpha character M to a numeric character 4" do
        expect(TrackingNumber.new('').ups_mapping('M')).to eq '4'
      end

      it "does not change a numeric character" do
        expect(TrackingNumber.new('').ups_mapping('3')).to eq '3'
      end
    end

    describe "#ups_checksum_digit" do
      it "returns the last digit from a string, as an integer" do
        expect(TrackingNumber.new('1234').ups_checksum_digit).to eq 4
      end
    end

    describe "#ups_core_portion" do
      it "return the section between the 1Z and the check digit" do
        expect(TrackingNumber.new('1Z0101010101010109').ups_core_portion).to eq '010101010101010'
      end
    end

    describe "#ups_core_portion_checksum" do
      it "calls #ups_modified_mod_ten with the core portion" do
        t = TrackingNumber.new '1Z 010101010101010 0'
        expect(t).to receive(:ups_modified_mod_ten).with '010101010101010'
        t.ups_core_portion_checksum
      end
    end

    describe "#ups_checksum_ok?" do
      it "returns true when the checksum digit matches the checksum remainder of the core portion" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ups_checksum_digit).and_return 4
        allow(t).to receive(:ups_core_portion_checksum_remainder).and_return 4
        expect(t.ups_checksum_ok?).to eq true
      end

      it "returns false when the checksum digit does NOT match the checksum remainder of the core portion" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ups_checksum_digit).and_return 4
        allow(t).to receive(:ups_core_portion_checksum_remainder).and_return 5
        expect(t.ups_checksum_ok?).to eq false
      end
    end

    describe "#ups_core_portion_checksum_remainder" do
      it "returns 0 when 10" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ups_core_portion_checksum).and_return 10
        expect(t.ups_core_portion_checksum_remainder).to eq 0
      end

      it "return 6 (20 minus 14) when checksum is 14" do
        t = TrackingNumber.new ''
        allow(t).to receive(:ups_core_portion_checksum).and_return 14
        expect(t.ups_core_portion_checksum_remainder).to eq 6
      end
    end

    describe "#ups_core_portion_mapped_to_numbers" do
      it "converts alpha characters to digits" do
        t = TrackingNumber.new 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        expect(t.ups_core_portion_mapped_to_numbers).to eq '45678901234567890123456'
      end

      it "does not alter numeric characters" do
        t = TrackingNumber.new '01234567890'
        expect(t.ups_core_portion_mapped_to_numbers).to eq '23456789'
      end
    end

    describe "#ups?" do
      %w( 1Z0T3731P292258842  1Z5FX0076803466397  1ZW0X5110319778880 ).each do |number|
        it "returns true for #{number}" do
          expect(TrackingNumber.new(number).ups?).to eq true
        end
      end

      %w( 9102901000462189604217  bad  1Z0T3731P2922588  1Zinvalid  1Z9999999992804405  1Z  1ZW0X5110319778880678890678342 ).each do |bad_number|
        it "returns false for #{bad_number}" do
          expect(TrackingNumber.new(bad_number).ups?).to eq false
        end
      end
    end
  end  # of UPS


  describe "#airborne?" do
    # it "returns true for a valid number", pending: true do
    #   expect(TrackingNumber.new('valid airborne').airborne?).to eq true
    # end
    it "returns false for an invalid number" do
      expect(TrackingNumber.new('airborne').airborne?).to eq false
    end
  end  # of Airborne



  describe "#dhl?" do
    # it "returns true for a valid number", pending: true do
    #   expect(TrackingNumber.new('valid dhl').dhl?).to eq true
    # end
    it "returns false for an invalid number" do
      expect(TrackingNumber.new('dhl').dhl?).to eq false
    end
  end  # of DHL


  describe "#usps?" do
    %w( EI457881382US  9102901000462189604217 ).each do |number|
      it "returns true for #{number}" do
        expect(TrackingNumber.new(number).usps?).to eq true
      end
    end

    it "returns false for a bad number" do
      expect(TrackingNumber.new('8675309').usps?).to eq false
    end
  end


  describe "#fedex?" do
    it "returns true" do
      expect(TrackingNumber.new('9102901000462189604217').fedex?).to eq true
    end

    it "returns false" do
      expect(TrackingNumber.new('8675309').fedex?).to eq false
    end
  end


  describe "UPS tracking numbers" do
    it "returns UPS as a carrier when given a UPS tracking number" do
      expect(TrackingNumber.new('1Z0T3731P292258842').carriers).to include(:ups)
    end
  end


  describe 'USPS tracking numbers' do
    it "returns USPS as a carrier when given a USPS tracking number" do
      expect(TrackingNumber.new('9102901000462189604217').carriers).to include(:usps)
    end
  end


  describe "FedEx" do
    it "returns FedEx as a carrier when given a FedEx tracking number" do
      expect(TrackingNumber.new('9102927010180027375941').carriers).to include(:fedex)
    end
  end


  describe "FedEx" do
    it "returns FedEx as a carrier when given a FedEx freight tracking number" do
      expect(TrackingNumber.new('076884980006374').carriers).to include(:fedex)
    end
  end


  describe "FedEx Smartpost" do
    it "returns both FedEx and USPS when given a smartpost number" do
      expect(TrackingNumber.new('9102927010180027375941').carriers).to match_array [:fedex, :usps]
    end
  end

end