require 'base64'

# Array polyfill.
class Array
  def pack(template)
    if template == 'C*'
      s = Daniel::Util.to_binary('')
      each { |n| s += Daniel::Util.to_chr(n) }
      s
    elsif template == 'N'
      a = []
      (0..3).reverse_each { |shift| a.push((self[0] >> (shift * 8)) & 0xff) }
      s = a.pack('C*')
      s
    elsif template == 'H*'
      m = {}
      (0..9).each { |n| m[n.to_s] = n }
      ('a'..'f').each { |l| m[l.to_s] = l.ord - 0x61 + 10 }
      ('A'..'F').each { |l| m[l.to_s] = l.ord - 0x41 + 10 }
      s = Daniel::Util.to_binary('')
      p = []
      self[0].each_char do |item|
        p << item
        next unless p.size == 2
        s += Daniel::Util.to_chr((m[p[0]] << 4) + m[p[1]])
        p = []
      end
      s
    elsif template.start_with? 'w'
      s = Daniel::Util.to_binary('')
      each do |item|
        if item <= 0x7f
          s += Daniel::Util.to_chr(item)
        else
          val = item
          t = Daniel::Util.to_chr(val & 0x7f)
          val >>= 7
          while val.nonzero?
            t = Daniel::Util.to_chr((val & 0x7f) | 0x80) + t
            val >>= 7
          end
          s += t
        end
      end
      s
    else
      raise "Don't know how to pack '#{template}'"
    end
  end
end

module JSON
  def self.generate(obj, options = {})
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
