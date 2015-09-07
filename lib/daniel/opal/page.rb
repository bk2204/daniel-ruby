require 'opal'
require 'opal-jquery'
require 'daniel'

# The built-in jQuery element selector.
class Element
  alias_native :select
end

class Event
  def originalEvent
    Native(`#{@native}.originalEvent`)
  end
end

def to_id(id)
  id = id.gsub('_', '-')
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
  all_blocks = [:reminder, :new]
  blocks = {
    :new => [:reminder, :new],
    :reminder => [:reminder]
  }
  val = Element.find('input[name=type]:checked').value
  wanted = blocks[val]
  on, off = all_blocks.partition { |b| wanted.include? b }
  on.map { |b| b.to_s + '-block' }.each { |b| unhide(b) }
  off.map { |b| b.to_s + '-block' }.each { |b| hide(b) }
end

def main
  pwobj = nil

  password_box = element(:generated_password)

  element(:master_password_button).on :click do
    pass = element(:master_password).value
    pwobj = Daniel::PasswordGenerator.new pass
    element(:checksum).text = Daniel::Util.to_hex(pwobj.checksum)

    [:reminder, :reminder_button, :code, :code_button].each { |id| enable(id) }
    show(:checksum_text)
  end

  element(:reminder_button).on :click do
    reminder = element(:reminder).value
    pass = pwobj.generate_from_reminder(reminder)
    password_box.value = pass
    unhide(:password_helper)
  end

  element(:code_button).on :click do
    params = Daniel::Parameters.new(flags)
    code = element(:code).value
    pass = pwobj.generate(code, params)
    password_box.value = pass
    element(:reminder).value = pwobj.reminder(code, params)
    unhide(:password_helper)
  end

  Element.find('input[name=type]').on(:change) { handle_type_change }

  clipboard_area = element(:clipboard_area)

  show_button = element(:show_hide_password_button)
  show_button.on :click do
    # Are we going to make it visible?
    visible = element(:clipboard_area).has_class? :invisible
    text = visible ? 'Hide Password' : 'Show Password'
    clipboard_area.toggle_class :invisible
    show_button.attr(:value, text)
  end

  Document.on :copy do |e|
    pass = element(:generated_password).value
    if pass && !pass.empty?
      cd = e.originalEvent.clipboardData
      cd.setData('text/plain', pass)
      e.prevent
    end
  end
end

Document.ready? do
  main
end
