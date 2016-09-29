require 'base64'

# Array polyfill.
class Array
  def pack(template)
    if template == 'C*'
      pack_c
    elsif template == 'N'
      pack_n
    elsif template == 'H*'
      pack_h
    elsif template.start_with? 'w'
      pack_w
    else
      raise "Don't know how to pack '#{template}'"
    end
  end

  private

  def pack_c
    s = Daniel::Util.to_binary('')
    each { |n| s += Daniel::Util.to_chr(n) }
    s
  end

  def pack_n
    a = []
    (0..3).reverse_each { |shift| a.push((self[0] >> (shift * 8)) & 0xff) }
    a.pack('C*')
  end

  def pack_h
    m = { '0' => 0, '1' => 1, '2' => 2, '3' => 3, '4' => 4,
          '5' => 5, '6' => 6, '7' => 7, '8' => 8, '9' => 9,
          'a' => 10, 'b' => 11, 'c' => 12, 'd' => 13, 'e' => 14, 'f' => 15,
          'A' => 10, 'B' => 11, 'C' => 12, 'D' => 13, 'E' => 14, 'F' => 15 }
    a = []
    self[0].each_char.each_slice(2) do |p|
      a << ((m[p[0]] << 4) + m[p[1]])
    end
    a.pack('C*')
  end

  def pack_w
    a = []
    each do |item|
      val = item
      t = [val & 0x7f]
      val >>= 7
      while val.nonzero?
        t << ((val & 0x7f) | 0x80)
        val >>= 7
      end
      a += t.reverse
    end
    a.pack('C*')
  end
end

# JSON polyfill.
module JSON
  def self.generate(obj, _options = {})
    obj.to_json
  end
end

# String polyfill.
class String
  def bytesize
    bytes.size
  end

  def unpack(template)
    if template == 'H*'
      s = ''
      m = %w(0 1 2 3 4 5 6 7 8 9 a b c d e f)
      bytes.each do |v|
        s += m[v >> 4] + m[v & 0xf]
      end
      [s]
    elsif template.start_with? 'w'
      a = []
      val = 0
      bytes.each do |v|
        if v <= 0x7f
          a << (val | v)
          val = 0
        else
          val |= (v & 0x7f)
          val <<= 7
        end
      end
      a
    else
      raise "Don't know how to unpack '#{template}'"
    end
  end
end

# CGI utility polyfill.
class CGI
  def self.unescape(s)
    s.gsub(/%([0-9a-fA-F]{2})/) do
      Daniel::Util.to_chr(Regexp.last_match[1].to_i(16))
    end
  end
end
