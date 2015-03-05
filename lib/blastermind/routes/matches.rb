require "json"
require "blastermind/models/match"
require "blastermind/pusher"
require "blastermind/representers/individual_match"
require "blastermind/representers/matches"

module Blastermind
  module Routes
    class Matches < Sinatra::Application
      get "/matches" do
        content_type :json

        Models::Match
          .all
          .extend(Representers::Matches)
          .to_json
      end

      post "/matches" do
        content_type :json

        match = Models::Match.find_or_create_to_play
        Models::Player.create(name: player_params[:name], match: match)

        # It seems ROAR representers are single-use. I tried to extend the
        # original instance and reuse it hear, but to_json didn't behave
        # as expected after to_hash was called ಠ_ಠ
        pusher_data = match.extend(Representers::IndividualMatch)
        Pusher[match.channel]
          .trigger(Models::Match::MATCH_STARTED, pusher_data.to_hash)

        status 201
        response['Access-Control-Allow-Origin'] = "*"
        match
          .extend(Representers::IndividualMatch)
          .to_json
      end

      private

      def player_params
        params.fetch("player") { Hash.new }
      end
    end
  end
end
