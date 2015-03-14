# Array polyfill.
class Array
  def pack(template)
    if template == 'C*'
      s = Daniel::Util.to_binary('')
      each { |n| s += n.chr }
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
        s += ((m[p[0]] << 4) + m[p[1]]).chr
        p = []
      end
      s
    elsif template.start_with? 'w'
      s = Daniel::Util.to_binary('')
      each do |item|
        if item <= 0x7f
          s += item.chr
        else
          val = item
          t = Daniel::Util.to_binary((val & 0x7f).chr)
          val >>= 7
          while val != 0
            t = ((val & 0x7f) | 0x80).chr + t
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

# String polyfill.
class String
  def bytes
    Daniel::Util.to_binary(self).each_char.to_a.map(&:ord)
  end

  def bytesize
    bytes.size
  end

  def each_byte
    bytes.each
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
