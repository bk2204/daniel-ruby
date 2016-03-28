#!/usr/bin/ruby
# encoding: UTF-8

# Ruby 1.8 doesn't have require_relative.
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Daniel::PasswordGenerator do
  def known_failure(code)
    ::RUBY_ENGINE == 'opal' && code == 'la-france'
  end

  [
    ['foo', 'bar', '3*Re7n*qcDDl9N6y', '8244c50a1000bar'],
    ['foo', 'baz', 'Dp4iWIX26UwV55N(', '8244c50a1000baz'],
    # Test Unicode.
    ['La République française', 'la-france', 'w^O)Vl7V0O&eEa^H',
     '55b1d40a1000la-france']
  ].each do |items|
    master, code, result, reminder = items

    it "gives the expected password for #{master}, #{code}" do
      pending 'Opal encoding issues' if known_failure(code)

      gen = Daniel::PasswordGenerator.new master
      expect(gen.generate(code, Daniel::Parameters.new(10))).to eq(result)
    end

    it "gives the expected reminder for #{master}, #{code}" do
      pending 'Opal encoding issues' if known_failure(code)

      gen = Daniel::PasswordGenerator.new master
      expect(gen.reminder(code, Daniel::Parameters.new(10))).to eq(reminder)
    end

    it "gives the expected password for #{master}, #{code} reminder" do
      pending 'Opal encoding issues' if known_failure(code)

      gen = Daniel::PasswordGenerator.new master
      expect(gen.generate_from_reminder(reminder)).to eq(result)
    end

    it "gives the expected password for #{master}, #{code} all-null reminder" do
      pending 'Opal encoding issues' if known_failure(code)

      gen = Daniel::PasswordGenerator.new master
      reminder.sub!(/^[0-9a-f]{6}/, '000000')
      expect(gen.generate_from_reminder(reminder)).to eq(result)
    end
  end

  it 'accepts reminder objects in generate_from_reminder' do
    gen = Daniel::PasswordGenerator.new 'foo'
    rem = Daniel::Reminder.parse('8244c50a1000bar')
    result = nil
    expect { result = gen.generate_from_reminder(rem) }.not_to raise_error
    expect(result).to eq('3*Re7n*qcDDl9N6y')
  end

  [
    'XJjdn !@DHdWnaG4mDx="rrhKP0o3/:VrRs=YkT[',
    '`+iNJmlUtFA-h$ArK}XdQx$RGzF`X>gz!g\dNolZ',
    'Xlw/9er22su(#73Mgh>scUcSfPi&0s3~ahLvEhkO',
    'wetRnhIZBjp.~K|x:Ok)or/Qfb@t_(doeFCuC)GN',
    'U\N_fdt[8C9\',{.<FB/m?:`rD8i~1UhVV<=YKR21',
    'lEq:;I?b[aIMB\'p,R`Z|f~p-.h|<wH,nVuzpE_b~',
    'CP]>+II3\'wLl1YT,<q3ADP-ZfFgb4yT_IxLxH|E\\',
    'b\'zzmsh\'x;pB<n`\'ucd]OHLX/|Ioh~~o-.ZxTcHX',
    'RUSlDRyrbpbT@$S0D4P&e4#T&FDxiS%tUVGFQa#f',
    '^Et#dhR^MDrZxrw!A(#MwPzH &BZNAY(nrH^tHDc',
    'Y1dZ#rBVLoNh2(03ZF(99J$nq*^RyeJ6^PlX$B!z',
    'MIZGCa%VLwcyAKxFREJtj*&uozV^qA$&DqFzM$of',
    'GrrtFfpbTpc p9iG2MZaS8bkiD2OgBZ5PCop0QDs',
    'GZFWWxveZiCtgKvfBcdcSYlXisqNZcWMSEuQeBLr',
    '4jTFoiTnc96mpzSu1mbf6lL3bsObjveu8Pln8KRI',
    'UTofBHTUVODoLjIBoKUrsWKRvpjVohhCNfsbCPdL',
    '673/".:_]6^"3`)?=$&_6(}:0 ]\.=6%{[&-1>=\'',
    '^-&%&_&?/?&;#(@{%]\\\'=:*/(<$+|-_.|>)+@\')~',
    ',=\'1:^,<8?\{*868[3)`2$">0-)<.6|8>[,1\"<%',
    '-?\="$#:\}--(^\'$&\'/<\}\'~>_==\'^`$%[.\'/:?(',
    '`6{[? 4{_|_}>6/.,{821_5]32]0=9 /}<[1<_,,',
    '|{-+{\',?/=;;;`\';.\'<_+<>}."+\'?]` ; \'|,"  ',
    '[+\+.\59<|96];|{+-.<5_62,,8|>0+\3+/{\'8+[',
    '_]\'`<,+;_}.:>-<}-`\}=|]=>-`+\'-~|{:+?{]+|',
    ' 63@1$9@36&)@26&8%69&%#54^% 7!284# 5$*7#',
    '  )@*^*&&%$% (#*%!&#)%* ^&@*&&$ &%##%*))',
    '3(4*%4^49*0!1@8*$71&%2*%4%22$(5)86&8737%',
    '#)@(%%(%*^&)#@!*@@#(*#!!$($#@%@^$(!!$$*#',
    '265759709105 33264918869 8648005 1401773',
    '                                        ',
    '2155580046452370263680868874450290219761'
  ].each_with_index do |result, i|
    it "gives the expected password for length 40 flags set to #{i}" do
      gen = Daniel::PasswordGenerator.new 'master-password'
      params = Daniel::Parameters.new i, 40
      expect(gen.generate('code', params)).to eq(result)
    end
  end
end
