require "dont/version"
require "dry-container"
require "dry-initializer"

# Defines a `dont_use` method which can be used to deprecate methods.  Whenever
# the deprecated method is used the specified handler will get triggered.
#
# @example
#
#     # Register a deprecation handler.
#     # Anything that responds to `.call(deprecation)` will work.
#     LOGGER = Logger.new
#     Dont.register_handler(:logger, ->(deprecation) { LOGGER.warn(deprecation.message) })
#     class Shouter
#       include Dont.new(:logger)
#
#       def shout(msg)
#         msg.upcase
#       end
#
#       def scream(msg)
#         shout(msg)
#       end
#       dont_use :scream, use: :shout
#     end
#
#     # Logs "DEPRECATED: Don't use Shouter#scream. It's deprecated in favor of
#     # shout.", before executing the method.
#     Shouter.new.scream("hello")
#
#
#     # The :exception deprecation handler is provided by default.
#     # It raises an exception whenever the method is called, which is handy in
#     # test or development mode.
#     class Person
#       include Dont.new(:exception)
#
#       attr_accessor :firstname
#       attr_accessor :first_name
#
#       dont_use :firstname, use: :first_name
#     end
#     Person.new.firstname # => fails with Dont::DeprecationError
#
class Dont < Module
  Error = Class.new(StandardError)
  DeprecationError = Class.new(Error)
  MissingHandlerError = Class.new(Error)

  def initialize(key)
    handler = Dont.fetch_handler(key)
    @implementation = ->(old_method, use: nil) {
      # The moment `dont_use` is called in ActiveRecord is before AR defines
      # the attributes in the model. So you get an error when calling
      # instance_method with the regular implementation.
      #
      # This hack determines if it's an ActiveRecord attribute or not, and
      # adapts the code.
      is_ar_attribute = defined?(ActiveRecord::Base) &&
        ancestors.include?(ActiveRecord::Base) &&
        !method_defined?(old_method)

      original = instance_method(old_method) unless is_ar_attribute
      define_method(old_method) do |*args|
        deprecation = Deprecation.new(
          subject: self,
          new_method: use,
          old_method: old_method,
        )
        handler.call(deprecation)
        if is_ar_attribute
          if old_method =~ /=\z/
            attr = old_method.to_s.sub(/=\z/, '')
            public_send(:[]=, attr, *args)
          else
            self[old_method.to_s.sub(/\?\z/, '')]
          end
        else
          original.bind(self).call(*args)
        end
      end
    }
  end

  def included(base)
    base.instance_exec(@implementation) do |impl|
      define_singleton_method(:dont_use, &impl)
    end
  end

  class << self
    def register_handler(key, callable)
      handlers.register(key, callable)
    end

    def fetch_handler(key)
      handlers.resolve(key)
    rescue Dry::Container::Error => e
      fail MissingHandlerError, e.message
    end

    protected

    def handlers
      @handlers ||= Dry::Container.new
    end
  end

  # Contains info about the deprecated method being called
  class Deprecation
    extend Dry::Initializer::Mixin

    option :subject
    option :new_method
    option :old_method, optional: true

    # A message saying that the old_method is deprecated. It also mentions the
    # new_method if provided.
    #
    # @return [String]
    def message
      klass = subject.class.name
      if new_method && !new_method.empty?
        "DEPRECATED: Don't use #{klass}##{old_method}. It's deprecated in favor of #{new_method}."
      else
        "DEPRECATED: Don't use #{klass}##{old_method}. It's deprecated."
      end
    end
  end

  register_handler(:exception, -> (deprecation) {
    fail Dont::DeprecationError, deprecation.message
  })
end
