class TrackingNumber

  UPS_REGEX     = Regexp.new(/\b1Z\w{16}\b/)
  ONTRAC_REGEX  = Regexp.new(/\bC\d{14}\b/)
  FEDEX_REGEX   = Regexp.new(/\b(9\d{10,21}|\d{15})\b/)
  USPS_REGEX    = Regexp.new(/\b(9\d{10,21}|\w\w\d{9}US)\b/)
  REGEXEN       = [UPS_REGEX, ONTRAC_REGEX, FEDEX_REGEX, USPS_REGEX]

  attr_reader :carriers, :string

  def self.extract_identifier_from(txt)
    REGEXEN.map{ |regex| txt.upcase.scan(regex) }.flatten.uniq
  end

  def initialize(str)
    @string = str.to_s.upcase.gsub(/[^A-Z0-9]/, '')
    @carriers = []
    pick_carriers
  end

  def pick_carriers
    @carriers << :ups       if ups?
    @carriers << :usps      if usps?
    @carriers << :fedex     if fedex?
    @carriers << :ontrac    if ontrac?
    @carriers << :dhl       if dhl?
    @carriers << :airborne  if airborne?
  end

  def ups_modified_mod_ten(str)
    str.chars.each_with_index.map{ |char, idx|
      (idx.even? ? 1 : 2) * char.to_i
    }.inject(0) { |sum, x| sum + x }
  end

  def next_multiple_of_ten(num)
    num.to_i + 10 - num.to_s.chars.last.to_i
  end



  module OntracTrackingNumber
    def ontrac_core_portion
      @string.chop
    end

    def ontrac_mapping(chr)
      if pos = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".index(chr)
        "23456789012345678901234567"[pos]
      else
        chr
      end
    end

    def ontrac_core_portion_mapped_to_numbers
      ontrac_core_portion.chars.map{ |c| ontrac_mapping(c) }.join
    end

    def ontrac_checksum_digit
      @string.chars.last.to_i
    end

    def ontrac_core_portion_checksum
      ups_modified_mod_ten(ontrac_core_portion_mapped_to_numbers)
    end

    def ontrac_core_portion_checksum_remainder
      remainder = next_multiple_of_ten(ontrac_core_portion_checksum) - ontrac_core_portion_checksum
      remainder == 10 ? 0 : remainder
    end

    def ontrac_checksum_ok?
      ontrac_core_portion_checksum_remainder == ontrac_checksum_digit
    end

    def ontrac?
      return false unless @string =~ ONTRAC_REGEX
      ontrac_checksum_ok?
    end
  end
  include OntracTrackingNumber



  module UPSTrackingNumber
    def ups_core_portion
      # portion between '1Z' and last character
      @string[2..@string.length-2]
    end

    def ups_mapping(chr)
      if pos = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".index(chr)
        "23456789012345678901234567"[pos]
      else
        chr
      end
    end

    def ups_core_portion_mapped_to_numbers
      ups_core_portion.chars.map{ |c| ups_mapping(c) }.join
    end

    def ups_checksum_digit
      @string.chars.last.to_i
    end

    def ups_core_portion_checksum
      ups_modified_mod_ten(ups_core_portion_mapped_to_numbers)
    end

    def ups_core_portion_checksum_remainder
      remainder = next_multiple_of_ten(ups_core_portion_checksum) - ups_core_portion_checksum
      remainder == 10 ? 0 : remainder
    end

    def ups_checksum_ok?
      ups_core_portion_checksum_remainder == ups_checksum_digit
    end

    def ups?
      return false unless @string =~ UPS_REGEX
      ups_checksum_ok?
    end
  end
  include UPSTrackingNumber



  module FedExTrackingNumber
    def fedex?
      !!(@string =~ FEDEX_REGEX)
    end
  end
  include FedExTrackingNumber



  module USPSTrackingNumber
    def usps?
      !!(@string =~ USPS_REGEX)
    end
  end
  include USPSTrackingNumber



  module AirborneTrackingNumber
    def airborne?
      false
    end
  end
  include AirborneTrackingNumber



  module DHLTrackingNumber
    def dhl?
      false
    end
  end
  include DHLTrackingNumber

end