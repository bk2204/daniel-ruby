require 'opal'
require 'opal-jquery'
require 'daniel'

# The built-in jQuery element selector.
class Element
  alias_native :select
end

# The built-in jQuery Event class.
class Event
  def originalEvent # rubocop:disable Style/MethodName
    Native(`#{@native}.originalEvent`)
  end
end

def to_id(id)
  id = id.tr('_', '-')
  id = '#' + id unless id[0] == '#'
  id
end

def element(id)
  Element.find to_id(id)
end

def hide(id)
  element(id).add_class(:hidden)
end

def unhide(id)
  element(id).remove_class(:hidden)
end

def show(id)
  element(id).remove_class(:invisible)
end

def enable(id)
  element(id).prop(:disabled, false)
end

def flags
  value = 0
  names = Daniel::Flags.flag_names
  names.each_with_index do |name, i|
    next unless name.start_with? 'no-'
    name = name.gsub(/^no-/, 'flags-')
    # Intermediate variable required due to Opal bug #599
    flagval = 1 << i
    value |= flagval if element(name).is ':checked'
  end
  value ^ Daniel::Flags::SYMBOL_MASK_NEGATED
end

def handle_type_change
  all_blocks = [:reminder, :new, :list]
  blocks = {
    :new => [:reminder, :new],
    :reminder => [:reminder],
    :list => [:list]
  }
  val = Element.find('input[name=type]:checked').value
  on, off = all_blocks.partition { |b| blocks[val].include? b }
  on.each { |b| unhide(block_name(b)) }
  off.each { |b| hide(block_name(b)) }
end

def block_name(b)
  b.to_s + '-block'
end

def generate_from_reminder(pwobj, reminder)
  pass = pwobj.generate_from_reminder(reminder)
  element(:generated_password).value = pass
  unhide(:password_helper)
end

# Logic for main dispatch.
class MainProgram
  def initialize
    @pwobj = nil
    @reminders = {}
    @pwbox = element(:generated_password)
    @clipboard_area = element(:clipboard_area)
  end

  def master_password_button
    pass = element(:master_password).value
    @pwobj = Daniel::PasswordGenerator.new pass
    element(:checksum).text = Daniel::Util.to_hex(@pwobj.checksum)

    [:reminder, :reminder_button, :code, :code_button].each { |id| enable(id) }
    show(:checksum_text)
  end

  def reminder_button
    generate_from_reminder(@pwobj, element(:reminder).value)
  end

  def remlist_button
    generate_from_reminder(@pwobj, @reminders[element(:remlist).value])
  end

  def code_button
    params = Daniel::Parameters.new(flags)
    code = element(:code).value
    pass = @pwobj.generate(code, params)
    @pwbox.value = pass
    element(:reminder).value = @pwobj.reminder(code, params)
    unhide(:password_helper)
  end

  def source_button
    HTTP.get(element(:source).value) do |response|
      if response.ok?
        element(:remlist_contents).children.remove
        @reminders = {}
        entries = response.body.each_line.map do |rem|
          rem = rem.chomp
          next if /^\s*(?:#|$)/.match(rem)
          code = Daniel::Reminder.parse(rem).code
          [code, rem]
        end
        entries = entries.reject(&:nil?).sort_by { |e| e[0] }
        entries.each do |(code, rem)|
          @reminders[code] = rem
          elem = Element.new(:option)
          elem.prop(:value, code)
          element(:remlist_contents).append(elem)
        end
        unhide(:remlist_block)
      end
    end
  end

  def show_hide_password_button
    # Are we going to make it visible?
    visible = @clipboard_area.has_class? :invisible
    text = visible ? 'Hide Password' : 'Show Password'
    @clipboard_area.toggle_class :invisible
    element(:show_hide_password_button).attr(:value, text)
  end

  def copy(e)
    pass = element(:generated_password).value
    return unless pass && !pass.empty?
    cd = e.originalEvent.clipboardData
    cd.setData('text/plain', pass)
    e.prevent
  end
end

def main
  prog = MainProgram.new

  Element.find('input[name=type]').on(:change) { handle_type_change }

  [
    :master_password_button,
    :reminder_button,
    :remlist_button,
    :code_button,
    :source_button,
    :show_hide_password_button
  ].each do |button|
    element(button).on :click do
      prog.send(button)
    end
  end

  Document.on :copy do |e|
    prog.copy(e)
  end
end

Document.ready? do
  main
end
