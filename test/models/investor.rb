class Investor < ActiveRecord::Base
  has_many :companies
  has_many :locations, :through => :companies
end