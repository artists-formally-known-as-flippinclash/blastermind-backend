require "aasm"
require "sequel/model"
require "blastermind/match_name_generator"
require "blastermind/models/round"

module Blastermind
  module Models
    class Match < Sequel::Model
      MAX_PLAYERS = 4
      ROUNDS_COUNT = 1

      EVENTS = [
        MATCH_STARTED = "match-started".freeze,
        MATCH_PROGRESS = "match-progress".freeze,
        MATCH_ENDED = "match-ended".freeze,
      ].freeze

      STATES = [
        MATCH_MAKING = :match_making,
        IN_PROGRESS = :in_progress,
        FINISHED = :finished,
      ].freeze

      def self.create_to_play(name: MatchNameGenerator.generate, &on_create)
        on_create ||= lambda{|*|}
        create(state: MATCH_MAKING.to_s, name: name).tap do |match|
          ROUNDS_COUNT.times { Round.generate(match).save }
          on_create.call(match)
        end
      end

      def self.find_or_create_to_play(&on_create)
        playable || create_to_play(&on_create)
      end

      def self.playable
        where(state: MATCH_MAKING.to_s).find do |match|
          match.players.count < MAX_PLAYERS
        end
      end

      include AASM

      aasm column: :state do
        state MATCH_MAKING
        state IN_PROGRESS
        state FINISHED

        event :start do
          transitions from: MATCH_MAKING, to: IN_PROGRESS

          after do
            trigger(MATCH_STARTED)
          end
        end

        event :finish do
          transitions from: IN_PROGRESS, to: FINISHED

          after do
            trigger(MATCH_ENDED)
          end
        end
      end

      attr_accessor :you

      one_to_many :players
      one_to_many :rounds

      def channel
        "match-#{id}"
      end

      def current_round
        rounds.find { |r| !r.finished? }
      end

      def progress
        trigger(MATCH_PROGRESS)
      end

      def winner
        winners = rounds.map(&:winner).compact

        unless winners.empty?
          winners
            .each_with_object(Hash.new(0)) { |winner, counts| counts[winner] += 1 }
            .sort_by(&:last)
            .last
            .first
        end
      end

      private

      def trigger(event)
        # It seems ROAR representers are single-use. I tried to extend the
        # original instance and reuse it hear, but to_json didn't behave
        # as expected after to_hash was called ಠ_ಠ
        pusher_data = extend(Representers::IndividualMatch)
        Pusher[channel].trigger(event, pusher_data.to_hash)
      end
    end
  end
end
