require "request_helper"
require "json"
require "blastermind/models/code_peg"
require "blastermind/models/match"

describe "/matches/{match_id}/players/{player_id}/guesses" do
  let(:json_response) { JSON.parse(last_response.body) }
  let(:response_data) { json_response.fetch("data") }

  describe "POST create" do
    let(:match) { Blastermind::Models::Match.create(state: Blastermind::Models::Match::IN_PROGRESS) }
    let!(:round) { Blastermind::Models::Round.generate(match, solution).save }
    let(:player) { Blastermind::Models::Player.create(name: "J", match: match) }
    let(:solution) { Blastermind::Models::CodePeg::STATES.first(solution_size) }
    let(:solution_size) { 4 }

    context "correct guess" do
      it "responds with 'correct' outcome" do
        guess_params = {
          guess: { code_pegs: round.solution }
        }

        post "/matches/#{match.id}/players/#{player.id}/guesses", guess_params.to_json, "CONTENT_TYPE" => "application/json"

        expect(last_response.status).to be(201)
        expect(response_data.fetch("outcome")).to eq(Blastermind::Models::Guess::CORRECT.to_s)
      end
    end

    context "incorrect guess" do
      let(:guess_params) do
        { guess: { code_pegs: solution.rotate } }
      end

      it "responds with 'incorrect' outcome" do
        post "/matches/#{match.id}/players/#{player.id}/guesses", guess_params.to_json, "CONTENT_TYPE" => "application/json"

        expect(response_data.fetch("outcome")).to eq(Blastermind::Models::Guess::INCORRECT.to_s)
      end

      it "includes feedback" do
        post "/matches/#{match.id}/players/#{player.id}/guesses", guess_params.to_json, "CONTENT_TYPE" => "application/json"

        feedback = response_data.fetch("feedback")
        expect(feedback.fetch("peg_count")).to eq(solution_size)
        expect(feedback.fetch("position_count")).to eq(0)
      end
    end
  end
end
