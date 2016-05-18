require 'tracking_number'

describe TrackingNumber do

  context "regular expressions used for matching tracking numbers" do
    describe "constants" do
      it "should have the correct names" do
        TrackingNumber::UPS_REGEX.class.to_s.should    eq('Regexp')
        TrackingNumber::ONTRAC_REGEX.class.to_s.should eq('Regexp')
        TrackingNumber::FEDEX_REGEX.class.to_s.should  eq('Regexp')
        TrackingNumber::USPS_REGEX.class.to_s.should   eq('Regexp')
      end

      it "should know of an array of regular expression constants" do
        TrackingNumber::REGEXEN.class.to_s.should eq('Array')
      end
    end
  end

  context "Extracting tracking-number-like things from a bit of text" do
    describe ".extract_identifier_from(text)" do
      it "should find a (FedEx freight) number in a URL" do
        txt = "https://www.fedex.com/insight/findit/nrp.jsp?tracknumbers=076884980006374&opco=FDEG&language=en&clienttype=ivother"
        ret = TrackingNumber.extract_identifier_from(txt)
        ret.should include('076884980006374')
      end

      it "should find a UPS tracking number within a block of text" do
        txt = "this number 1z0T3731P292258842 is my number"
        ret = TrackingNumber.extract_identifier_from(txt)
        ret.should include('1Z0T3731P292258842')
      end

      it "should find multiple UPS tracking numbers within a block of text" do
        txt = "this number, 1Z0T3731P292258842, and this number, 1Z5FX0076803466397, are my numbers"
        ret = TrackingNumber.extract_identifier_from(txt)
        ret.should =~ %w(1Z0T3731P292258842  1Z5FX0076803466397)
      end

      it "should find multiple UPS tracking numbers within a block of text, and filter duplicates" do
        txt = "this number, 1Z0T3731P292258842, and this number, 1Z5FX0076803466397, are my numbers.  And did I mention 1z5FX0076803466397?"
        ret = TrackingNumber.extract_identifier_from(txt)
        ret.should =~ %w(1Z0T3731P292258842  1Z5FX0076803466397)
      end

      it "should find multiple tracking numbers for various carriers within a block of text" do
        txt = "this number, 1Z0T3731P292258842, and this number, C10999911320231, are my numbers.  And did I mention 9102901000462189604217?"
        ret = TrackingNumber.extract_identifier_from(txt)
        ret.should =~ %w(1Z0T3731P292258842  9102901000462189604217  C10999911320231)
      end
    end
  end


  describe "new instance" do
    it "should require a string" do
      expect { TrackingNumber.new() }.to raise_error(ArgumentError)
    end

    it "should upcase the provided tracking number" do
      t = TrackingNumber.new('1z01w1010101010100')
      t.string.should eq('1Z01W1010101010100')
    end

    it "should collapse the provided tracking number" do
      t = TrackingNumber.new('1Z 010 101010 101010 0')
      t.string.should eq('1Z0101010101010100')
    end

    it "should provide an array of carriers" do
      t = TrackingNumber.new('1Z0101010101010100')
      t.carriers.should be_an Array
    end
  end


  context "instance methods" do
    describe "#next_multiple_of_ten" do
      it "should return 160 for 159" do
        t = TrackingNumber.new('')
        t.next_multiple_of_ten(159).should eq(160)
      end

      it "should return 170 for 160" do
        t = TrackingNumber.new('')
        t.next_multiple_of_ten(160).should eq(170)
      end

      it "should return 170 for 161" do
        t = TrackingNumber.new('')
        t.next_multiple_of_ten(161).should eq(170)
      end
    end

    describe "#ups_modified_mod_ten" do
      it "should sum the values of the odd-position characters" do
        t = TrackingNumber.new('')
        t.ups_modified_mod_ten('101010101010101').should eq(8 * 1)
      end

      it "should double the sum of values the even-position characters" do
        t = TrackingNumber.new('')
        t.ups_modified_mod_ten('010101010101010').should eq(7 * 1 * 2)
      end
    end
  end


  context "ONTRAC checksum functions" do
    describe "#ontrac_mapping" do
      it "should map an alpha character A to a numeric character 2" do
        TrackingNumber.new('').ontrac_mapping('A').should eq('2')
      end

      it "should map an alpha character M to a numeric character 4" do
        TrackingNumber.new('').ontrac_mapping('M').should eq('4')
      end

      it "should not change a numeric character" do
        TrackingNumber.new('').ontrac_mapping('3').should eq('3')
      end
    end

    describe "#ontrac_checksum_digit" do
      it "should return the last digit from a string, as an integer" do
        TrackingNumber.new('1234').ontrac_checksum_digit.should eq(4)
      end
    end

    describe "#ontrac_core_portion_checksum" do
      it "should return the value derived from the sum of odd-position characters and double the sum of even-position characters" do
        # remember this will be a 1-based array examination, i.e. first character is an odd position
        TrackingNumber.new('C10101010101010').ontrac_core_portion_checksum.should eq(4 + 7 * 2)
      end
    end

    describe "#ontrac_checksum_ok?" do
      it "should return true when the checksum digit matches the checksum remainder of the core portion" do
        t = TrackingNumber.new('')
        t.stub(:ontrac_checksum_digit) { 4 }
        t.stub(:ontrac_core_portion_checksum_remainder) { 4 }
        t.ontrac_checksum_ok?.should eq true
      end

      it "should return false when the checksum digit does NOT match the checksum remainder of the core portion" do
        t = TrackingNumber.new('')
        t.stub(:ontrac_checksum_digit) { 4 }
        t.stub(:ontrac_core_portion_checksum_remainder) { 5 }
        t.ontrac_checksum_ok?.should eq false
      end
    end

    describe "#ontrac_core_portion_checksum" do
      it "should call #ups_modified_mod_ten with the core portion" do
        t = TrackingNumber.new('C12345678901234')
        t.should_receive(:ups_modified_mod_ten).with('41234567890123')
        t.ontrac_core_portion_checksum
      end
    end

    describe "#ontrac_core_portion_checksum_remainder" do
      it "should return 0 when 10" do
        t = TrackingNumber.new('')
        t.stub(:ontrac_core_portion_checksum).and_return(10)
        t.ontrac_core_portion_checksum_remainder.should eq(0)
      end

      it "should return 6 (20 minus 14) when checksum is 14" do
        t = TrackingNumber.new('')
        t.stub(:ontrac_core_portion_checksum).and_return(14)
        t.ontrac_core_portion_checksum_remainder.should eq(20-14)
      end
    end

    describe "#ontrac?" do
      %w(C10999911320231  C10999606576777  C11001105367744  C11000411158855).each do |number|
        it "should return true for #{number}" do
          TrackingNumber.new(number).ontrac?.should eq true
        end
      end
      it "should return false" do
        TrackingNumber.new('C22222222222222').ontrac?.should eq false
      end
    end
  end  # of ONTRAC


  context "UPS checksum functions" do
    describe "#ups_mapping" do
      it "should map an alpha character A to a numeric character 2" do
        TrackingNumber.new('').ups_mapping('A').should eq('2')
      end

      it "should map an alpha character M to a numeric character 4" do
        TrackingNumber.new('').ups_mapping('M').should eq('4')
      end

      it "should not change a numeric character" do
        TrackingNumber.new('').ups_mapping('3').should eq('3')
      end
    end

    describe "#ups_checksum_digit" do
      it "should return the last digit from a string, as an integer" do
        TrackingNumber.new('1234').ups_checksum_digit.should eq(4)
      end
    end

    describe "#ups_core_portion" do
      it "should return the section between the 1Z and the check digit" do
        TrackingNumber.new('1Z0101010101010109').ups_core_portion.should eq('010101010101010')
      end
    end

    describe "#ups_core_portion_checksum" do
      it "should call #ups_modified_mod_ten with the core portion" do
        t = TrackingNumber.new('1Z 010101010101010 0')
        t.should_receive(:ups_modified_mod_ten).with('010101010101010')
        t.ups_core_portion_checksum
      end
    end

    describe "#ups_checksum_ok?" do
      it "should return true when the checksum digit matches the checksum remainder of the core portion" do
        t = TrackingNumber.new('')
        t.stub(:ups_checksum_digit) { 4 }
        t.stub(:ups_core_portion_checksum_remainder) { 4 }
        t.ups_checksum_ok?.should eq true
      end

      it "should return false when the checksum digit does NOT match the checksum remainder of the core portion" do
        t = TrackingNumber.new('')
        t.stub(:ups_checksum_digit) { 4 }
        t.stub(:ups_core_portion_checksum_remainder) { 5 }
        t.ups_checksum_ok?.should eq false
      end
    end

    describe "#ups_core_portion_checksum_remainder" do
      it "should return 0 when 10" do
        t = TrackingNumber.new('')
        t.stub(:ups_core_portion_checksum).and_return(10)
        t.ups_core_portion_checksum_remainder.should eq(0)
      end

      it "should return 6 (20 minus 14) when checksum is 14" do
        t = TrackingNumber.new('')
        t.stub(:ups_core_portion_checksum).and_return(14)
        t.ups_core_portion_checksum_remainder.should eq(20-14)
      end
    end

    describe "#ups_core_portion_mapped_to_numbers" do
      it "should convert alpha characters to digits" do
        t = TrackingNumber.new('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
        t.ups_core_portion_mapped_to_numbers.should eq('45678901234567890123456')
      end

      it "should not alter numeric characters" do
        t = TrackingNumber.new('01234567890')
        t.ups_core_portion_mapped_to_numbers.should eq('23456789')
      end
    end

    describe "#ups?" do
      %w( 1Z0T3731P292258842  1Z5FX0076803466397  1ZW0X5110319778880 ).each do |number|
        it "should return true for #{number}" do
          TrackingNumber.new(number).ups?.should eq true
        end
      end
      %w( 9102901000462189604217  bad  1Z0T3731P2922588  1Zinvalid  1Z9999999992804405  1Z  1ZW0X5110319778880678890678342 ).each do |bad_number|
        it "should return false for #{bad_number}" do
          TrackingNumber.new(bad_number).ups?.should eq false
        end
      end
    end
  end  # of UPS


  describe "#airborne?" do
    # it "should return true for a valid number", pending: true do
    #   TrackingNumber.new('valid airborne').airborne?.should eq true
    # end
    it "should return false for an invalid number" do
      TrackingNumber.new('airborne').airborne?.should eq false
    end
  end  # of Airborne



  describe "#dhl?" do
    # it "should return true for a valid number", pending: true do
    #   TrackingNumber.new('valid dhl').dhl?.should eq true
    # end
    it "should return false for an invalid number" do
      TrackingNumber.new('dhl').dhl?.should eq false
    end
  end  # of DHL


  describe "#usps?" do
    %w( EI457881382US  9102901000462189604217 ).each do |number|
      it "should return true for #{number}" do
        TrackingNumber.new(number).usps?.should eq true
      end
    end

    it "should return false for a bad number" do
      TrackingNumber.new('8675309').usps?.should eq false
    end
  end


  describe "#fedex?" do
    it "returns true" do
      expect(TrackingNumber.new('9102901000462189604217').fedex?).to eq true
    end

    it "should return false" do
      expect(TrackingNumber.new('8675309').fedex?).to eq false
    end
  end


  describe "UPS tracking numbers" do
    it "should return UPS as a carrier when given a UPS tracking number" do
      TrackingNumber.new('1Z0T3731P292258842').carriers.should include(:ups)
    end
  end


  describe 'USPS tracking numbers' do
    it "should return USPS as a carrier when given a USPS tracking number" do
      TrackingNumber.new('9102901000462189604217').carriers.should include(:usps)
    end
  end


  describe "FedEx" do
    it "should return FedEx as a carrier when given a FedEx tracking number" do
      TrackingNumber.new('9102927010180027375941').carriers.should include(:fedex)
    end
  end


  describe "FedEx" do
    it "should return FedEx as a carrier when given a FedEx freight tracking number" do
      TrackingNumber.new('076884980006374').carriers.should include(:fedex)
    end
  end


  describe "FedEx Smartpost" do
    it "should return both FedEx and USPS when given a smartpost number" do
      TrackingNumber.new('9102927010180027375941').carriers.should =~ [:fedex, :usps]
    end
  end

end