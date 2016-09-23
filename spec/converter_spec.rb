require 'spec_helper'

if ::RUBY_ENGINE != 'opal'
  describe Daniel::Converter do
    it 'properly converts from one master password to another' do
      c = Daniel::Converter.new('foo', 'foobar')
      reminder = c.convert('8244c50a1000bar')
      expect(reminder).to eq '72eb362010005120687ae64c642fdfc988448ced0d19bar'
    end
  end
end
