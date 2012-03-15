module Omnibus
module Vagrant
class Config < ::Vagrant::Config::Base

  attr_accessor :path

  def validate(env, errors)
    errors.add("Omnibus path must be set") if !path
  end

end # Config
end # Vagrant
end # Omnibus
