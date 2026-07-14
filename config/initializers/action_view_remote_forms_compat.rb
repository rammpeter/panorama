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
ActiveSupport.on_load(:action_view) do
  unless ActionView::Base.respond_to?(:form_with_generates_remote_forms=)
    ActionView::Base.define_singleton_method(:form_with_generates_remote_forms=) { |_value| }
  end
end
