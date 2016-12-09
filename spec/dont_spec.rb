require "spec_helper"
require "logger"

describe Dont do
  it "has a version number" do
    expect(Dont::VERSION).not_to be nil
  end

  Car = Class.new do
    include Dont.new(:exception)

    def drive_autopilot
    end

    def drive_manually
    end
    dont_use :drive_manually
  end


  describe ".new(...)" do
    it "fails when used with an unknown handler" do
      expect {
        Class.new { include Dont.new(:deal_with_it) }
      }.to raise_error(
        Dont::MissingHandlerError,
        "Nothing registered with the key :deal_with_it"
      )
    end
  end

  describe "deprecation handling" do
    context "with :exception" do
      it "triggers an exception if the old method is used" do
        expect {
          Car.new.drive_manually
        }.to raise_error(
          Dont::DeprecationError,
          "Don't use `Car#drive_manually`. It's deprecated."
        )
      end
    end
  end

  describe ".register_handler" do
    it "can be used for a custom handler" do
      logger = instance_double(Logger)
      Dont.register_handler(:log_deprecated_call, -> (object, method) {
        logger.warn("Don't use '#{method.to_s}'.")
      })

      klass = Class.new do
        include Dont.new(:log_deprecated_call)

        def shout(msg)
          msg.upcase
        end
        dont_use :shout
      end

      expect(logger).to receive(:warn).with("Don't use 'shout'.")
      result = klass.new.shout("Welcome!")
      expect(result).to eq("WELCOME!")
    end
  end
end
