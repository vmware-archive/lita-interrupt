# frozen_string_literal: true

require 'trello'
require 'lita-exclusive-route'
module Lita
  module Handlers
    class Interrupt < Handler
      config :trello_developer_public_key, required: true, type: String
      config :trello_member_token, required: true, type: String
      config :board_name, required: true, type: String
      config :team_members_hash, required: true, type: String

      route(%r{add (.*) to BAM}, :add_to_team, command: true)
      # route(%r{part}, :leave_room, command: true)
      route(%r{^(.*)$}, :handle_interrupt, command: true, exclusive: true)
      route(%r{^(.*)@(\S+)\s*(.*)$}, :handle_mention, command: false, exclusive: true)

      def initialize(robot)
        super

        configure_trello
        set_team_member_hash
        get_interrupt_list
      end

      def configure_trello
        Trello.configure do |c|
          c.developer_public_key = config.trello_developer_public_key
          c.member_token = config.trello_member_token
        end
      end

      def set_team_member_hash
        @team_members = {}
        # TEAM_MEMBER_HASH should look like "trello_name1:slack_handle1,trello_name2:slack_handle2"
        # TODO make this go in a DB and allow members to add/remove themselves by talking to bot in slack
        config.team_members_hash.split(',').each do |pair|
          names = pair.split(':')
          @team_members[names[0]] = names[1]
        end
        raise 'TEAM_MEMBERS_HASH must be set correctly.' if @team_members.empty?
      end

      def get_interrupt_list
        board_name = config.board_name
        team_board = nil
        @team_members.each do |trello_username, _|
          member = Trello::Member.find(trello_username)
          break if team_board = member.boards.find do |board|
            board.name == board_name
          end
        end
        raise 'Team board not found!' unless team_board

        @interrupt_list = nil
        team_board.lists.each do |list|
          break_flag = false
          Trello::List.find(list.id).cards.each do |card|
            if card.name == 'Interrupt'
              @interrupt_list = list
              break_flag = true
              break
            end
            break if break_flag
          end
        end
        raise %q(
              Interrupt list not found!
              Your team trello board needs a list with a card titled 'Interrupt'!
        ) unless @interrupt_list
      end

      def interrupt_pair
        get_interrupt_list unless @interrupt_list.cards.find { |card| card.name == 'Interrupt' }
        interrupt_ids = []
        @interrupt_list.cards.each do |card|
          card.member_ids.each do |member|
            username = Trello::Member.find(member).username
            interrupt_ids << @team_members[username]
          end
        end
        interrupt_ids.empty? ? @team_members.map { |_, val| val } : interrupt_ids
      end

      def handle_mention(response)
        matches = response.matches[0]
        handle_interrupt(response) if matches[1] == robot.name
      end

      def handle_interrupt(response)
        interrupt_ids = interrupt_pair
        answer = +"<@#{interrupt_ids[0]}>"
        if interrupt_ids.length > 1
          interrupt_ids[1..-1].each { |name| answer << " <@#{name}>" }
        end
        answer << ": you have an interrupt from <@#{response.user.id}> ^^"
        response.reply(answer)
      end

      def add_to_team(response)
        new_member = Trello::Member.find(response.match_data[1].to_s)
        # TODO: update @team_members and persist it somehow
        response.reply(%Q(I have linked trello user '#{new_member.username}' with <@#{response.user.id}>!))
      end

      Lita.register_handler(self)
    end
  end
end
