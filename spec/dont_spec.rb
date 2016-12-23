require "spec_helper"
require "logger"
require "sqlite3"
require "active_record"

describe Dont do

  before :all do
    @method_calls = []
    Dont.register_handler(:method_logger, -> (depr) {
      @method_calls << "#{depr.subject.class.name}##{depr.old_method}"
    })
  end

  it "has a version number" do
    expect(Dont::VERSION).not_to be nil
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

  describe ".register_handler" do
    it "can be used for a custom handler" do
      logger = instance_double(Logger)
      Dont.register_handler(:log_deprecated_call, -> (depr) {
        logger.warn(depr.message)
      })

      klass = Class.new do
        include Dont.new(:log_deprecated_call)

        def shout(msg)
          scream(msg)
        end
        dont_use :shout

        def yell(msg)
          scream(msg)
        end
        dont_use :yell, use: :scream

        def scream(msg)
          msg.upcase
        end
      end

      expect(logger).to receive(:warn)
        .with("DEPRECATED: Don't use #shout. It's deprecated.")
      expect(logger).to receive(:warn)
        .with("DEPRECATED: Don't use #yell. It's deprecated in favor of scream.")
      shouter = klass.new
      expect(shouter.shout("Welcome!")).to eq("WELCOME!")
      expect(shouter.yell("Welcome!")).to eq("WELCOME!")
    end
  end

  describe "ActiveRecord::Base" do
    before(:all) do
      # Define model before schema is defined. The attributes don't exist at
      # this point, but dont_use should still work
      #
      class Item < ActiveRecord::Base
        include Dont.new(:method_logger)
        dont_use :usable
        dont_use :usable?
        dont_use :usable=

        def old_name
          name
        end
        dont_use :old_name
      end

      ActiveRecord::Migration.verbose = false
      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: ":memory:"
      )
      ActiveRecord::Schema.define(version: 1) do
        create_table :items do |t|
          t.text :name
          t.boolean :usable
        end
      end
    end

    it "still executes the original method correctly" do
      Item.create!(name: "Usable item", usable: true)
      expect(@method_calls).to include("Item#usable=")
      @method_calls.clear
      item = Item.last
      expect(item.usable).to eq(true)
      expect(item.usable?).to eq(true)
      expect(@method_calls).to eq(["Item#usable", "Item#usable?"])

      item.usable = false
      item.save!
      item.reload
      expect(item.usable).to eq(false)
      expect(item.usable?).to eq(false)

      item.usable = nil
      item.save!
      item.reload
      expect(item.usable).to eq(nil)
      expect(item.usable?).to eq(nil)

      @method_calls.clear
      expect(item.old_name).to eq("Usable item")
      expect(@method_calls).to eq(["Item#old_name"])
    end
  end

  describe Dont::Deprecation do
    it "generates a deprecation message" do
      [
        [
          Hash.new, "to_h", :to_h_v2,
          "DEPRECATED: Don't use Hash#to_h. It's deprecated in favor of to_h_v2."
        ],
        [
          Array.new, "old_method", nil,
          "DEPRECATED: Don't use Array#old_method. It's deprecated."
        ],
        [
          Array.new, "old_method", "",
          "DEPRECATED: Don't use Array#old_method. It's deprecated."
        ],
      ].each do |(obj, old, use, msg)|
        depr = described_class.new(subject: obj, old_method: old, new_method: use)
        expect(depr.message).to eq(msg)
      end
    end
  end
end
