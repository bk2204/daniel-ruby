require 'opal'
require 'opal-jquery'
require 'daniel'

class Element
  alias_native :select
end

def to_id(id)
  id = id.gsub('_', '-')
  id = '#' + id unless id[0] == '#'
end

def element(id)
  Element.find to_id(id)
end

def unhide(id)
  element(id).remove_class(:hidden)
end

def enable(id)
  element(id).prop(:disabled, false)
end

def main
  pwobj = nil

  password_box = element(:generated_password)

  element(:master_password_button).on :click do
    pass = element(:master_password).value
    pwobj = Daniel::PasswordGenerator.new pass
    element(:checksum).text = Daniel::Util.to_hex(pwobj.checksum)

    [:reminder, :reminder_button].each { |id| enable(id) }
    unhide(:checksum_text)
  end

  element(:reminder_button).on :click do
    reminder = element(:reminder).value
    pass = pwobj.generate_from_reminder(reminder)
    password_box.value = pass
    unhide(:password_helper)
  end

  clipboard_area = element(:clipboard_area)

  show_button = element(:show_hide_password_button)
  show_button.on :click do
    # Are we going to make it visible?
    visible = element(:clipboard_area).has_class? :invisible
    text = visible ? 'Hide Password' : 'Show Password'
    clipboard_area.toggle_class :invisible
    show_button.attr(:value, text)
  end
end

Document.ready? do
  main
end
