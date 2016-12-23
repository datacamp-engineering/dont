require 'spec_helper'

describe Dont::WithWarn do
  it "logs a warning via Kernal#warn" do
    klass = Class.new do
      include Dont::WithWarn

      def stuff; end
      dont_use :stuff
    end

    expect_any_instance_of(Kernel).to receive(:warn)
      .with(/^DEPRECATED:.+/)
    klass.new.stuff
  end
end
