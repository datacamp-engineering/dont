# Dont

[![Build Status](https://travis-ci.org/datacamp/dont.svg?branch=master)](https://travis-ci.org/datacamp/dont) [![Gem Version](https://badge.fury.io/rb/dont.svg)](https://badge.fury.io/rb/dont) 

Easily deprecate methods.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dont'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install dont

## Usage

```ruby
# Register a deprecation handler.
# Anything that responds to `.call(deprecation)` will work.
LOGGER = Logger.new
Dont.register_handler(:logger, ->(deprecation) { LOGGER.warn(deprecation.message) })
class Shouter
  include Dont.new(:logger)

  def shout(msg)
    msg.upcase
  end

  def scream(msg)
    shout(msg)
  end
  dont_use :scream, use: :shout
end

# Logs "DEPRECATED: Don't use Shouter#scream. It's deprecated in favor of
# shout.", before executing the method.
Shouter.new.scream("hello")


# The :exception deprecation handler is provided by default.
# It raises an exception whenever the method is called, which is handy in
# test or development mode.
class Person
  include Dont.new(:exception)

  attr_accessor :firstname
  attr_accessor :first_name

  dont_use :firstname, use: :first_name
end
Person.new.firstname # => fails with Dont::DeprecationError
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/datacamp/dont. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

