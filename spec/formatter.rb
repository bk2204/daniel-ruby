#!/usr/bin/ruby
# encoding: UTF-8

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'daniel'

describe Daniel::Formatter do
  [
    ['', 'xexax'],
    ['1234567890', 'xesef-disof-gytuf-katof-movif-baxux'],
    ['Pineapple', 'xigak-nyryk-humil-bosek-sonax']
  ].each do |(plain, bubblebabble)|
    it "performs no transformation for plain '#{plain}'" do
      res = Daniel::Formatter.plain(plain)
      expect(res).to eq(plain)
    end

    it "gives the expected result for bubblebabble '#{plain}'" do
      res = Daniel::Formatter.bubblebabble(plain)
      expect(res).to eq(bubblebabble)
    end
  end
end
