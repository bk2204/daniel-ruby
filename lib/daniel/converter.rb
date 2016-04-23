require 'daniel'

# A password generation tool.
module Daniel
  # Converts passwords from one master password to another.
  class Converter
    def initialize(oldpass, newpass)
      @oldgen = Daniel::PasswordGenerator.new(oldpass)
      @newgen = Daniel::PasswordGenerator.new(newpass)
    end

    # Generate a reminder for the new master password.
    #
    # @param oldrem [String] reminder for the old master password
    # @return [String] reminder for the new master password
    def convert(oldrem)
      rem = @oldgen.parse_reminder(oldrem)
      pass = @oldgen.generate_from_reminder(rem)
      rem.params.flags = Daniel::Flags::REPLICATE_EXISTING
      rem.mask = @newgen.generate_mask(rem.code, rem.params, pass)
      rem.checksum = Util.to_hex(@newgen.checksum)
      rem.to_s
    end
  end
end
