# frozen_string_literal: true

require 'trello'
require 'lita-exclusive-route'
module Lita
  module Handlers
    # handler for lita-slack that talks to a team trello board,
    # finding interrupt pair at any given time
    class Interrupt < Handler
      config :trello_developer_public_key, required: true, type: String
      config :trello_member_token, required: true, type: String
      config :board_name, required: true, type: String
      config :admins, required: true, type: Array
      attr_reader :admins, :team_roster, :interrupt_card

      route(/^add (.+) to the (.*) team.*$/, :handle_add_to_team, command: true)
      route(/^part$/, :handle_part, command: true)
      route(/^team$/, :handle_list_team, command: true)
      route(/^(.*)$/, :handle_interrupt_command, command: true, exclusive: true)
      route(
        /^(.*)@(\S+)\s*(.*)$/,
        :handle_interrupt_mention,
        command: false,
        exclusive: true
      )

      def initialize(robot)
        super

        configure_trello
        @admins = admins_array
        @team_roster = team_roster_hash
        @interrupt_card = team_interrupt_card if @team_roster
      end

      def handle_part(response)
        robot.part(response.room)
      end

      def handle_list_team(response)
        return unless @team_roster ||= team_roster_hash
        reply = +'The team roster is '
        @team_roster.each do |key, val|
          reply << "<@#{val}> => #{key}, "
        end
        response.reply(reply.gsub(/, $/, ''))
      end

      def handle_interrupt_mention(response)
        matches = response.matches[0]
        handle_interrupt_command(response) if matches[1] == robot.name
      end

      def handle_interrupt_command(response)
        return unless @interrupt_card ||= team_interrupt_card
        interrupt_ids = interrupt_pair
        answer = +"<@#{interrupt_ids[0]}>"
        if interrupt_ids.length > 1
          interrupt_ids[1..-1].each { |name| answer << " <@#{name}>" }
        end
        answer << ": you have an interrupt from <@#{response.user.id}> ^^"
        response.reply(answer)
      end

      def handle_add_to_team(response)
        trello_username = response.match_data[1].to_s
        unless (new_member = Trello::Member.find(trello_username))
          response.reply(
            %(Did not find the trello username "#{trello_username}")
          )
          return
        end
        @team_roster[trello_username] = response.user.id
        redis.set(:roster_hash, @team_roster.to_json)
        response.reply(
          %(I have linked trello user "#{new_member.username}" )\
          "with <@#{response.user.id}>!"
        )
      end

      Lita.register_handler(self)

      private

      def configure_trello
        Trello.configure do |c|
          c.developer_public_key = config.trello_developer_public_key
          c.member_token = config.trello_member_token
        end
      end

      def admins_array
        unless config.admins
          raise 'The admins array must be set in lita_config.rb. '\
            'A restart with "ROBOT_ADMINS" set is required.'
        end
        config.admins
      end

      def team_roster_hash
        team_roster = redis.get(:roster_hash)
        unless team_roster
          notify_admins(
            'You must add some users to the team roster. '\
            "You will need each member's slack handle and trello user name."
          )
          return nil
        end
        JSON.parse(team_roster)
      end

      def notify_admins(msg)
        @admins.each { |admin| robot.send_messages(admin, msg) }
      end

      def team_trello_lists
        team_board = nil
        @team_roster.each do |trello_username, _|
          member = Trello::Member.find(trello_username)
          break if (team_board = member.boards.find do |board|
            board.name == config.board_name
          end)
        end
        unless team_board
          notify_admins %(Trello team board "#{config.board_name}" not found! )\
          'Set "TRELLO_BOARD_NAME" and restart me, please.'
          return nil
        end
        team_board.lists
      end

      def validate_interrupt_cards(interrupt_cards)
        if interrupt_cards.empty?
          notify_admins(
            'Interrupt card not found! Your team '\
            'trello board needs a list with a card titled "Interrupt".'
          )
          return nil
        elsif interrupt_cards.length > 1
          notify_admins(
            'Multiple interrupt cards found! Using first one.'
          )
        end
        interrupt_cards[0]
      end

      def team_interrupt_card
        return nil unless (team_lists = team_trello_lists)
        interrupt_cards = []
        team_lists.each do |list|
          Trello::List.find(list.id).cards.each do |card|
            card.name == 'Interrupt' && interrupt_cards << card
          end
        end
        validate_interrupt_cards(interrupt_cards)
      end

      def interrupt_pair
        interrupt_ids = []
        interrupt_list = Trello::Card.find(@interrupt_card.id).list
        interrupt_list.cards.each do |card|
          card.member_ids.each do |member|
            username = Trello::Member.find(member).username
            interrupt_ids << @team_roster[username]
          end
        end
        if interrupt_ids.empty?
          @team_roster.map { |_, val| val }
        else
          interrupt_ids
        end
      end
    end
  end
end
