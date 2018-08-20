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
      attr_reader :admins, :team_roster, :interrupt_card

      route(
        /^\s*add\s+(me)\s+(\S+)\s*$/,
        :add_to_team,
        command: true,
        help: { t('help.add_key') => t('help.add_value') }
      )
      route(
        /^\s*add\s+(@\S+)\s+(\S+)\s*$/,
        :add_to_team,
        command: true,
        restrict_to: :team
      )
      route(
        /^\s*remove\s+(me)\s*$/,
        :remove_from_team,
        command: true,
        help: { t('help.remove_key') => t('help.remove_value') }
      )
      route(
        /^\s*remove\s+(@\S+)\s*$/,
        :remove_from_team,
        command: true,
        restrict_to: :team
      )
      route(/^part$/, :part, command: true, restrict_to: :team)
      route(
        /^team$/,
        :list_team,
        command: true,
        help: { t('help.team_key') => t('help.team_value') }
      )
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
        slack_handle = determine_slack_handle(response)
        trello_username = remove(slack_handle)
        response.reply(t('user_removed', t: trello_username, s: slack_handle))
      end

      def add_to_team(response)
        slack_handle = determine_slack_handle(response)
        trello_username = response.match_data[2].to_s
        unless lookup_trello_user(trello_username)
          response.reply(t('user_not_found', t: trello_username))
          return
        end
        add(trello_username, slack_handle)
        response.reply(t('user_added', t: trello_username, s: slack_handle))
      end

      Lita.register_handler(self)

      private

      def configure_trello
        Trello.configure do |c|
          c.developer_public_key = config.trello_developer_public_key
          c.member_token = config.trello_member_token
        end
      end

      def create_lita_source_from_id(id)
        user = Lita::User.create(id)
        Lita::Source.new(user: user)
      end

      def admin_lita_sources
        robot.registry.config.robot.admins.map do |admin|
          create_lita_source_from_id(admin)
        end
      end

      def team_roster_hash
        team_roster = redis.get(:roster_hash)
        unless team_roster
          notify_admins(t('add_users_to_roster'))
          return nil
        end
        JSON.parse(team_roster)
      end

      def notify_admins(msg)
        @admins.each { |admin| robot.send_messages(admin, msg) }
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
          notify_admins(t('board_not_found', b: config.board_name))
          return nil
        end
        team_board.lists
      end

      def validate_interrupt_cards(interrupt_cards)
        if interrupt_cards.empty?
          notify_admins(t('interrupt_card_not_found'))
          return nil
        elsif interrupt_cards.length > 1
          notify_admins(t('multiple_interrupt_cards'))
        end
        interrupt_cards[0]
      end

      def team_interrupt_card
        return nil unless (team_lists = team_trello_lists)
        interrupt_cards = []
        team_lists.each do |list|
          Trello::List.find(list.id).cards.each do |card|
            card.name == t('interrupt_card') && interrupt_cards << card
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
        answer << t('interrupt_suffix', u: user)
      end

      def determine_slack_handle(response)
        match = response.match_data[1].to_s
        return match.to_s.gsub(/^@/, '') unless match == 'me'
        response.user.id
      end

      def lookup_trello_user(trello_username)
        Trello::Member.find(trello_username)
        true
      rescue Trello::Error
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
