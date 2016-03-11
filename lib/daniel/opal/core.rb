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
          while val != 0
            t = Daniel::Util.to_chr((val & 0x7f) | 0x80) + t
            val >>= 7
          end
          s += t
        end
      end
      s
    else
      fail "Don't know how to pack '#{template}'"
    end
  end
end

# Base64 polyfill.
#
# Opal 0.9.2 has a bug with base64 that causes it to encode an extra NUL byte.
module Base64
  def self.encode64(s)
    len = s.length % 3
    chars = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a + %w(+ /)
    res = ''
    loop do
      chunk = s[0, 3].bytes + [0, 0]
      s = s[3..-1]
      enc = (chunk[0] << 16) | (chunk[1] << 8) | chunk[2]
      rres =''
      4.times do
        rres += chars[enc & 0x3f]
        enc >>= 6
      end
      res += rres.reverse
      break if s.nil? || s.empty?
    end
    return res if len == 0
    len == 1 ? res[0..-3] + '==' : res[0..-2] + '='
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
          # Intermediate variable required due to Opal bug #599
          x = (v & 0x7f)
          val |= x
          val <<= 7
        end
      end
      a
    else
      fail "Don't know how to unpack '#{template}'"
    end
  end
end
