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
      config :team_members_hash, required: true, type: String
      config :admins, required: true, type: Array
      attr_reader :team_members_hash, :interrupt_card

      route(/add (.*) to BAM/, :add_to_team, command: true)
      # route(/part/, :leave_room, command: true)
      route(/^(.*)$/, :handle_interrupt, command: true, exclusive: true)
      route(
        /^(.*)@(\S+)\s*(.*)$/,
        :handle_mention,
        command: false,
        exclusive: true
      )

      def initialize(robot)
        super

        configure_trello
        @admins = admins
        @team_members = team_member_hash
        @interrupt_card = fetch_interrupt_card
      end

      def handle_mention(response)
        matches = response.matches[0]
        handle_interrupt(response) if matches[1] == robot.name
      end

      def handle_interrupt(response)
        return unless @interrupt_card ||= fetch_interrupt_card
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

      def admins
        unless config.admins
          raise 'The admins array must be set in lita_config.rb. '\
          'A restart with "ROBOT_ADMINS" set is required.'
        end
        config.admins
      end

      def team_member_hash
        team_members = {}
        # TEAM_MEMBER_HASH should look like "trello_name1:slack_handle1,trello_name2:slack_handle2"
        # TODO make this go in a DB and allow members to add/remove themselves by talking to bot in slack
        config.team_members_hash.split(',').each do |pair|
          names = pair.split(':')
          team_members[names[0]] = names[1]
        end
        unless team_members
          notify_admins(
            '"TEAM_MEMBERS_HASH" must be set correctly, then restart me.'
          )
        end
        team_members
      end

      def notify_admins(msg)
        @admins.each { |admin| robot.send_messages(admin, msg) }
      end

      def fetch_interrupt_card
        board_name = config.board_name
        interrupt_card = nil
        team_board = nil
        @team_members.each do |trello_username, _|
          member = Trello::Member.find(trello_username)
          break if (team_board = member.boards.find do |board|
            board.name == board_name
          end)
        end
        unless team_board
          notify_admins 'Trello team board "#{board_name}" not found! '\
          'Set "TRELLO_BOARD_NAME" and restart me, please.'
        end

        team_board.lists.each do |list|
          break_flag = false
          Trello::List.find(list.id).cards.each do |card|
            if card.name == 'Interrupt'
              interrupt_card = card
              break_flag = true
              break
            end
            break if break_flag
          end
        end
        unless interrupt_card
          notify_admins(
            'Interrupt card not found! Your team '\
            'trello board needs a list with a card titled "Interrupt".'
          )
        end
        interrupt_card
      end

      def interrupt_pair
        interrupt_ids = []
        interrupt_list = Trello::Card.find(@interrupt_card.id).list
        interrupt_list.cards.each do |card|
          card.member_ids.each do |member|
            username = Trello::Member.find(member).username
            interrupt_ids << @team_members[username]
          end
        end
        if interrupt_ids.empty?
          @team_members.map { |_, val| val }
        else
          interrupt_ids
        end
      end
    end
  end
end
