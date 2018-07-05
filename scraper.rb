#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  # Not linked in the party table at the top
  EXTRA_PARTIES = [
    { id: 'Q6467393', name: 'Labour Co-operative' },
    { id: 'Q841045', name: 'Official Unionist' },
  ].freeze

  field :members do
    member_rows.map do |row|
      data = fragment(row => MemberRow).to_h
      data[:party_id] = parties.find { |p| p[:name].include? data[:party] }[:id] rescue binding.pry
      data
    end
  end

  private

  def parties
    @parties ||= party_rows.map { |row| fragment(row => PartyRow).to_h } + EXTRA_PARTIES
  end

  def party_rows
    party_table.xpath('.//tr[td[3]]')
  end

  def party_table
    noko.xpath('//table[.//td[contains(.,"Affiliation")]]')
  end

  def member_table
    noko.xpath('//table[.//th[contains(.,"Constituency")]]')
  end

  def member_rows
    member_table.xpath('.//tr[td[2]]')
  end
end

class MemberRow < Scraped::HTML
  field :id do
    tds[1].css('a/@wikidata').map(&:text).first rescue binding.pry
  end

  field :name do
    tds[1].css('a').map(&:text).map(&:tidy).first
  end

  field :party do
    tds[2].text.tidy
  end

  private

  def tds
    noko.css('td')
  end
end

class PartyRow < Scraped::HTML
  field :id do
    tds[1].css('a/@wikidata').map(&:text).first rescue binding.pry
  end

  field :name do
    tds[1].css('a').map(&:text).map(&:tidy).first
  end

  private

  def tds
    noko.css('td')
  end
end

url = 'https://en.wikipedia.org/wiki/List_of_MPs_elected_in_the_United_Kingdom_general_election,_1987'
Scraped::Scraper.new(url => MembersPage).store(:members)
