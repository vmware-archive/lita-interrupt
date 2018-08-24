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

      on :loaded, :setup

      def setup(_payload)
        define_routes(robot.registry.config.robot.name)
        configure_trello
        check_team_roster
      end

      def list_team(response)
        response.reply(generate_roster_response)
      end

      def interrupt(response)
        return unless check_team_roster
        return unless (interrupt_card = team_interrupt_card)
        answer = generate_interrupt_response(response.user.id, interrupt_card)
        response.reply(answer)
      end

      def remove_from_team(response)
        slack_handle = determine_slack_handle(response)
        unless (trello_username = remove(slack_handle))
          response.reply t('team_roster_is') + t('empty')
          return
        end
        response.reply t('user_removed', t: trello_username, s: slack_handle)
      end

      def add_to_team(response)
        slack_handle = determine_slack_handle(response)
        trello_username = response.match_data[2].to_s
        unless lookup_trello_user(trello_username)
          response.reply t('user_not_found', t: trello_username)
          return
        end
        add(trello_username, slack_handle)
        response.reply t('user_added', t: trello_username, s: slack_handle)
      end

      private

      def check_team_roster
        unless team_roster
          notify_admins t('add_users_to_roster')
          return false
        end
        true
      end

      def define_routes(robot_name)
        define_add_routes
        define_remove_routes
        define_list_team_route
        define_interrupt_routes(robot_name)
      end

      def define_add_routes
        self.class.route(
          /^\s*add\s+(me)\s+(\S+)\s*$/,
          :add_to_team,
          command: true,
          help: { t('help.add_key') => t('help.add_value') }
        )
        self.class.route(
          /^\s*add\s+(@\S+)\s+(\S+)\s*$/,
          :add_to_team,
          command: true,
          restrict_to: :team
        )
      end

      def define_remove_routes
        self.class.route(
          /^\s*remove\s+(me)\s*$/,
          :remove_from_team,
          command: true,
          help: { t('help.remove_key') => t('help.remove_value') }
        )
        self.class.route(
          /^\s*remove\s+(@\S+)\s*$/,
          :remove_from_team,
          command: true,
          restrict_to: :team
        )
      end

      def define_list_team_route
        self.class.route(
          /^team$/,
          :list_team,
          command: true,
          help: { t('help.team_key') => t('help.team_value') }
        )
      end

      def define_interrupt_routes(robot_name)
        self.class.route(/^(.*)$/, :interrupt, command: true, exclusive: true)
        self.class.route(
          /^(.*)@(#{robot_name})\s*(.*)$/,
          :interrupt,
          command: false,
          exclusive: true
        )
      end

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

      def notify_admins(msg)
        robot.registry.config.robot.admins.each do |admin|
          admin = create_lita_source_from_id(admin)
          robot.send_messages(admin, msg)
        end
      end

      def team_roster
        roster = redis.get(:roster_hash)
        roster_json = roster.nil? ? {} : JSON.parse(roster)
        return nil if roster_json.empty?
        roster_json
      end

      def team_trello_lists
        team_board = nil
        return unless (roster = team_roster)
        roster.each do |_, trello_username|
          member = Trello::Member.find(trello_username)
          team_board = member.boards.find do |board|
            board.name == config.board_name
          end
          break if team_board
        end
        unless team_board
          notify_admins t('board_not_found', b: config.board_name)
          return nil
        end
        team_board.lists
      end

      def validate_interrupt_cards(interrupt_cards)
        if interrupt_cards.empty?
          notify_admins t('interrupt_card_not_found')
          return nil
        elsif interrupt_cards.length > 1
          notify_admins t('multiple_interrupt_cards')
        end
        interrupt_cards[0]
      end

      def team_interrupt_card
        return nil unless (team_lists = team_trello_lists)
        if (interrupt_card = redis.get(:interrupt_card))
          return interrupt_card
        end
        interrupt_cards = []
        team_lists.each do |list|
          Trello::List.find(list.id).cards.each do |card|
            card.name == t('interrupt_card') && interrupt_cards << card.id
          end
        end
        validate_interrupt_cards(interrupt_cards)
      end

      def interrupt_pair(interrupt_card)
        interrupt_ids = []
        roster = team_roster
        cards = Trello::Card.find(interrupt_card).list.cards
        cards.each do |card|
          card.member_ids.each do |member|
            trello_username = Trello::Member.find(member).username
            interrupt_ids << roster.key(trello_username)
          end
        end
        interrupt_ids.empty? ? roster.keys : interrupt_ids
      end

      def generate_roster_response
        reply = t('team_roster_is')
        unless (roster = team_roster)
          return reply << t('empty')
        end
        roster.each do |key, val|
          reply << "<@#{key}> => #{val}, "
        end
        reply.gsub(/, $/, '')
      end

      def generate_interrupt_response(user, interrupt_card)
        interrupt_ids = interrupt_pair(interrupt_card)
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
        unless (roster = team_roster)
          roster = {}
          redis.set(:roster_hash, roster.to_json)
        end
        roster[slack_handle] = trello_username
        redis.set(:roster_hash, roster.to_json)
      end

      def remove(slack_handle)
        return nil unless (roster = team_roster)
        trello_username = roster[slack_handle]
        roster.delete(slack_handle)
        redis.set(:roster_hash, roster.to_json)
        trello_username
      end

      Lita.register_handler(Interrupt)
    end
  end
end
