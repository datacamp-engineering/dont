require "dont/version"
require "dry-container"

# Defines a `dont_use` method which can be used to deprecate methods.  Whenever
# the deprecated method is used the specified handler will get triggered.
#
# @example
#
#     class Person
#       include Dont.new(:exception)
#
#       attr_accessor :firstname
#       attr_accessor :first_name
#
#       dont_use :firstname
#     end
#
#     Person.new.firstname # => Dont::DeprecationError
#
#     # Register custom handlers
#     Dont.register_handler(:logger, ->(object, method) {
#       class_name = object.class.name
#       logger.warn("Don't use `#{class_name}##{method}`. It's deprecated.")
#     })
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
#       dont_use :scream
#     end
#
#     # This will log "Don't use `Shouter#scream`. It's deprecated.", and then
#     # execute the method.
#     Shouter.new.scream("hello")
#     # => HELLO
#
#
class Dont < Module
  Error = Class.new(StandardError)
  DeprecationError = Class.new(Error)
  MissingHandlerError = Class.new(Error)
  WrongArityError = Class.new(Error)

  def initialize(key)
    handler = Dont.fetch_handler(key)
    @implementation = ->(method) {
      # The moment `dont_use` is called in ActiveRecord is before AR defines
      # the attributes in the model. So you get an error when calling
      # instance_method with the regular implementation.
      #
      # This hack determines if it's an ActiveRecord attribute or not, and
      # adapts the code.
      is_ar_attribute = defined?(ActiveRecord::Base) &&
        ancestors.include?(ActiveRecord::Base) &&
        !method_defined?(method)

      old_method = instance_method(method) unless is_ar_attribute
      define_method(method) do |*args|
        handler.call(self, method)
        if is_ar_attribute
          if method =~ /=$/
            self[method.to_s.gsub(/=$/, '')] = args.first
          else
            self[method.to_s.gsub(/\?$/, '')]
          end
        else
          old_method.bind(self).call(*args)
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
    def handlers
      @handlers ||= Dry::Container.new
    end

    def register_handler(key, callable)
      handlers.register(key, callable)
    end

    def fetch_handler(key)
      self.handlers.resolve(key)
    rescue Dry::Container::Error => e
      fail MissingHandlerError, e.message
    end
  end

  register_handler(:exception, -> (object, method) {
    class_name = object.class.name
    fail Dont::DeprecationError, "Don't use `#{class_name}##{method}`. It's deprecated."
  })
end
