require 'spec_helper'

describe Daniel::Util do
  it 'converts hex to binary as expected' do
    expected = "\x00A7\x80"
    if Daniel::Version.smart_implementation?
      expected = expected.force_encoding('BINARY')
    end
    expect(Daniel::Util.from_hex('00413780')).to eq expected
  end

  it 'converts hex to binary as expected' do
    expect(Daniel::Util.to_hex("\x00A7\x80")).to eq '00413780'
  end

  it 'converts data to base64 as expected' do
    expect(Daniel::Util.to_base64('abcdefg')).to eq 'YWJjZGVmZw=='
    expect(Daniel::Util.to_base64('hij')).to eq 'aGlq'
    expect(Daniel::Util.to_base64("klmn\n")).to eq 'a2xtbgo='
    expect(Daniel::Util.to_base64('aa?')).to eq 'YWE/'
    expect(Daniel::Util.to_base64('bc>')).to eq 'YmM+'
    expect(Daniel::Util.to_base64('')).to eq ''
  end

  it 'converts data from base64 as expected' do
    expect(Daniel::Util.from_base64('YWJjZGVmZw==')).to eq 'abcdefg'
    expect(Daniel::Util.from_base64('aGlq')).to eq 'hij'
    expect(Daniel::Util.from_base64('a2xtbgo=')).to eq "klmn\n"
    expect(Daniel::Util.from_base64('YWE/')).to eq 'aa?'
    expect(Daniel::Util.from_base64('YmM+')).to eq 'bc>'
    expect(Daniel::Util.from_base64('')).to eq ''
  end

  it 'converts data to url64 as expected' do
    expect(Daniel::Util.to_url64('abcdefg')).to eq 'YWJjZGVmZw'
    expect(Daniel::Util.to_url64('hij')).to eq 'aGlq'
    expect(Daniel::Util.to_url64("klmn\n")).to eq 'a2xtbgo'
    expect(Daniel::Util.to_url64('aa?')).to eq 'YWE_'
    expect(Daniel::Util.to_url64('bc>')).to eq 'YmM-'
    expect(Daniel::Util.to_url64('')).to eq ''
  end

  it 'converts data from url64 as expected' do
    expect(Daniel::Util.from_url64('YWJjZGVmZw')).to eq 'abcdefg'
    expect(Daniel::Util.from_url64('aGlq')).to eq 'hij'
    expect(Daniel::Util.from_url64('a2xtbgo')).to eq "klmn\n"
    expect(Daniel::Util.from_url64('YWE_')).to eq 'aa?'
    expect(Daniel::Util.from_url64('YmM-')).to eq 'bc>'
    expect(Daniel::Util.from_url64('')).to eq ''
  end
end
