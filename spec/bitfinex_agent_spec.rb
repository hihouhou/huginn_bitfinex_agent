require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::BitfinexAgent do
  before(:each) do
    @valid_options = Agents::BitfinexAgent.new.default_options
    @checker = Agents::BitfinexAgent.new(:name => "BitfinexAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
