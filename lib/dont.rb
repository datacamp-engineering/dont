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

  HANDLERS = {
    exception: -> (object, method) {
      class_name = object.class.name
      fail DeprecationError, "Don't use `#{class_name}##{method}`. It's deprecated."
    },
    airbrake: -> (object, method) {
      class_name = object.class.name
      err = DeprecationError.new("Don't use `#{class_name}##{method}`. It's deprecated.")
      Airbrake.notify(err)
    },
  }

  def initialize(key)
    handler = Dont.fetch_handler(key)
    @implementation = ->(method) {
      old_method = instance_method(method)
      define_method(method) do |*args|
        handler.call(self, method)
        old_method.bind(self).call(*args)
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
