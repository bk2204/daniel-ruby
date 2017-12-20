require 'spec_helper'

FC = Daniel::Flags

describe Daniel::Flags do
  it "returns an identical mask if it's a number" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(x)).to eq x
    end
  end

  it "returns the correct mask if it's an octal string" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(format('0%o', x))).to eq x
    end
  end

  it "returns the correct mask if it's a lowercase hex string" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(format('0x%x', x))).to eq x
    end
  end

  it "returns the correct mask if it's an uppercase hex string" do
    (0x00..0x7f).each do |x|
      expect(Daniel::Flags.mask_from_characters(format('0X%X', x))).to eq x
    end
  end

  [
    ['-', 0x17, FC::NO_NUMBERS | FC::NO_SPACES | FC::NO_SYMBOLS_TOP |
      FC::NO_LETTERS],
    ['as', 0x0d, FC::NO_NUMBERS | FC::NO_SYMBOLS_TOP | FC::NO_SYMBOLS_OTHER],
    ['A ', 0x0d, FC::NO_NUMBERS | FC::NO_SYMBOLS_TOP | FC::NO_SYMBOLS_OTHER],
    ['!:', 0x13, FC::NO_NUMBERS | FC::NO_SPACES | FC::NO_LETTERS],
    ['0as!+', 0x00, 0],
    ['A -', 0x05, FC::NO_NUMBERS | FC::NO_SYMBOLS_TOP],
    ['A0-', 0x06, FC::NO_SPACES | FC::NO_SYMBOLS_TOP]
  ].each do |(mask, value, fvalue)|
    it "returns the correct mask for '#{mask}'" do
      computed = Daniel::Flags.mask_from_characters(mask)
      expect(computed).to eq value
      expect(computed).to eq fvalue
    end
  end

  [
    [0x00, []],
    [0x1f, %w[no-numbers no-spaces no-symbols-top no-symbols-other no-letters]],
    [0x20, %w[replicate-existing]],
    [0x13, %w[no-numbers no-spaces no-letters]],
    [0x07, %w[no-numbers no-spaces no-symbols-top]],
    [0x80, %w[arbitrary-bytes]]
  ].each do |(flags, array)|
    it "returns the correct explanation for '#{flags}'" do
      expect(Daniel::Flags.explain(flags)).to eq array
    end
  end

  it 'throws an exception for invalid flags' do
    expect do
      Daniel::Flags.explain(0x100)
    end.to raise_error(Daniel::InvalidParametersError, /invalid/i)
  end
end
