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

      route(/^add\s+(\S+)(\s+\(?@\S+\)?)?\s*$/, :add_to_team, command: true)
      route(/^remove\s+(me|@\S+)\s*$/, :remove_from_team, command: true)
      route(/^part$/, :part, command: true, restrict_to: :team)
      route(/^team$/, :list_team, command: true)
      route(/^(.*)$/, :interrupt_command, command: true, exclusive: true)
      route(
        /^(.*)@(\S+)\s*(.*)$/,
        :interrupt_mention,
        command: false,
        exclusive: true
      )

      def initialize(robot)
        super

        configure_trello
        @admins = admin_lita_sources
        @team_roster = team_roster_hash
        @interrupt_card = team_interrupt_card if @team_roster
      end

      def part(response)
        robot.part(response.room)
      end

      def list_team(response)
        return unless @team_roster ||= team_roster_hash
        response.reply(generate_roster_response)
      end

      def interrupt_mention(response)
        matches = response.matches[0]
        interrupt_command(response) if matches[1] == robot.name
      end

      def interrupt_command(response)
        return unless @interrupt_card ||= team_interrupt_card
        answer = generate_interrupt_response(response.user.id)
        response.reply(answer)
      end

      def remove_from_team(response)
        match = response.match_data[1].to_s
        unless (slack_handle = slack_handle_to_remove(match, response.user.id))
          return
        end
        trello_username = remove(slack_handle)
        response.reply(
          %(Trello user "#{trello_username}" (<@#{slack_handle}>) removed!)
        )
      end

      def add_to_team(response)
        trello_username = response.match_data[1].to_s
        unless lookup_trello_user(trello_username)
          response.reply(
            %(Did not find the trello username "#{trello_username}")
          )
          return
        end
        match = response.match_data[2]
        slack_handle = slack_handle_to_add(match, response.user.id)
        return unless slack_handle
        add(trello_username, slack_handle)
        response.reply(
          %(Trello user "#{trello_username}" (<@#{slack_handle}>) added!)
        )
      end

      Lita.register_handler(self)

      private

      def admin_lita_sources
        config.admins.map do |admin|
          admin_user = Lita::User.create(admin)
          Lita::Source.new(user: admin_user)
        end
      end

      def admin?(user_id)
        @admins.find { |admin| user_id == admin.user.id }
      end

      def configure_trello
        Trello.configure do |c|
          c.developer_public_key = config.trello_developer_public_key
          c.member_token = config.trello_member_token
        end
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
        @admins.each do |admin|
          robot.send_messages(admin, msg)
        end
      end

      def team_trello_lists
        team_board = nil
        return unless @team_roster
        @team_roster.each do |_, trello_username|
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
        cards = Trello::Card.find(@interrupt_card.id).list.cards
        cards.each do |card|
          card.member_ids.each do |member|
            trello_username = Trello::Member.find(member).username
            interrupt_ids << @team_roster.key(trello_username)
          end
        end
        interrupt_ids.empty? ? @team_roster.keys : interrupt_ids
      end

      def generate_roster_response
        reply = +'The team roster is '
        @team_roster.each do |key, val|
          reply << "<@#{key}> => #{val}, "
        end
        reply.gsub(/, $/, '')
      end

      def generate_interrupt_response(user)
        interrupt_ids = interrupt_pair
        answer = +"<@#{interrupt_ids[0]}>"
        if interrupt_ids.length > 1
          interrupt_ids[1..-1].each { |name| answer << " <@#{name}>" }
        end
        answer << ": you have an interrupt from <@#{user}> ^^"
      end

      def slack_handle_to_remove(match, requester_id)
        return requester_id if match == 'me'
        return match.gsub(/^@/, '') if admin?(requester_id)
        nil
      end

      def slack_handle_to_add(match, requester_id)
        if match
          return nil unless admin?(requester_id)
          return match.to_s.gsub(/^ *\(?@/, '').gsub(/\)$/, '')
        end
        requester_id
      end

      def lookup_trello_user(trello_username)
        return true if Trello::Member.find(trello_username)
        false
      end

      def add(trello_username, slack_handle)
        @team_roster ||= {}
        @team_roster[slack_handle] = trello_username
        redis.set(:roster_hash, @team_roster.to_json)
      end

      def remove(slack_handle)
        trello_username = @team_roster[slack_handle]
        @team_roster.delete(slack_handle)
        redis.set(:roster_hash, @team_roster.to_json)
        trello_username
      end
    end
  end
end
