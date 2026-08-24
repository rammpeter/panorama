# Be sure to restart your server when you modify this file.
#
# Rails 8 hat form_with_generates_remote_forms von ActionView::Base nach
# ActionView::Helpers::FormHelper verschoben. Die ActionView-Railtie schiebt in einer
# generischen on_load(:action_view)-Schleife alle verbliebenen config.action_view-Keys
# per send auf ActionView::Base. Unter JRuby wird dieser Hash gelegentlich iteriert,
# waehrend der Key noch nicht entfernt ist -> ActionView::Base.form_with_generates_remote_forms=
# existiert dort nicht mehr:
#   NoMethodError: undefined method 'form_with_generates_remote_forms=' for class ActionView::Base
#
# Panorama verwendet jquery_ujs-Remote-Forms (form_tag remote: true), kein form_with,
# daher ist der Wert hier bedeutungslos. Verirrte Zuweisung mit No-op-Setter neutralisieren.
# Der echte Setter auf ActionView::Helpers::FormHelper bleibt davon unberuehrt.
#
# Das gleiche Problem betrifft form_with_generates_ids: Auch dieser Schalter liegt in Rails 8
# als mattr_accessor auf ActionView::Helpers::FormHelper und nicht mehr auf ActionView::Base.
# config.load_defaults 8.0 setzt config.action_view.form_with_generates_ids = true; wird dieser
# Key von der generischen on_load(:action_view)-Schleife erreicht, bevor die Railtie ihn per
# delete entfernt hat, landet die Zuweisung faelschlich auf ActionView::Base:
#   NoMethodError: undefined method 'form_with_generates_ids=' for class ActionView::Base
# Daher hier ebenfalls mit einem No-op-Setter neutralisieren.
#
# Ebenso default_enforce_utf8: liegt in Rails 8 als mattr_accessor auf
# ActionView::Helpers::FormTagHelper und nicht mehr auf ActionView::Base.
# config.load_defaults 8.0 setzt config.action_view.default_enforce_utf8 = false; wird dieser
# Key von der generischen on_load(:action_view)-Schleife erreicht, bevor die Railtie ihn per
# delete entfernt hat, landet die Zuweisung faelschlich auf ActionView::Base:
#   NoMethodError: undefined method 'default_enforce_utf8=' for class ActionView::Base
# Daher hier ebenfalls mit einem No-op-Setter neutralisieren.
#
# Ebenso preload_links_header: liegt in Rails 8 als mattr_accessor auf
# ActionView::Helpers::AssetTagHelper und nicht mehr auf ActionView::Base.
# config.load_defaults 8.0 setzt config.action_view.preload_links_header = false; wird dieser
# Key von der generischen on_load(:action_view)-Schleife erreicht, bevor die Railtie ihn per
# delete entfernt hat, landet die Zuweisung faelschlich auf ActionView::Base:
#   NoMethodError: undefined method 'preload_links_header=' for class ActionView::Base
# Daher hier ebenfalls mit einem No-op-Setter neutralisieren.
ActiveSupport.on_load(:action_view) do
  unless ActionView::Base.respond_to?(:form_with_generates_remote_forms=)
    ActionView::Base.define_singleton_method(:form_with_generates_remote_forms=) { |_value| }
  end
  unless ActionView::Base.respond_to?(:form_with_generates_ids=)
    ActionView::Base.define_singleton_method(:form_with_generates_ids=) { |_value| }
  end
  unless ActionView::Base.respond_to?(:default_enforce_utf8=)
    ActionView::Base.define_singleton_method(:default_enforce_utf8=) { |_value| }
  end
  unless ActionView::Base.respond_to?(:preload_links_header=)
    ActionView::Base.define_singleton_method(:preload_links_header=) { |_value| }
  end
end
