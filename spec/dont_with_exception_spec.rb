require 'spec_helper'

describe Dont::WithException do
  it "raises a Dont::DeprecationError" do
    klass = Class.new do
      include Dont::WithException

      def stuff; end
      dont_use :stuff
    end

    expect {
      klass.new.stuff
    }.to raise_error(
      Dont::DeprecationError,
      /DEPRECATED: Don't use #stuff/
    )
  end
end
