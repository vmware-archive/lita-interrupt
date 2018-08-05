# frozen_string_literal: true

require 'trello'
require 'lita-exclusive-route'
module Lita
  module Handlers
    class Interrupt < Handler
      on :connected, :get_interrupt_list
      route(%r{add (.*) to BAM}, :add_to_team, command: true)
      route(%r{^(.+)$}, :handle_interrupt, command: true, exclusive: true)

      Trello.configure do |c|
        c.developer_public_key = ENV['TRELLO_DEVELOPER_PUBLIC_KEY'] or raise 'TRELLO_DEVELOPER_PUBLIC_KEY must be set'
        c.member_token = ENV['TRELLO_MEMBER_TOKEN'] or raise 'TRELLO_MEMBER_TOKEN must be set'
      end

      @@team_members = {}
      # TEAM_MEMBER_HASH should look like "trello_name1:slack_handle1,trello_name2:slack_handle2"
      # TODO make this go in a DB and allow members to add/remove themselves by talking to bot in slack
      ENV['TEAM_MEMBERS_HASH'].split(',').each do |pair|
        names = pair.split(':')
        @@team_members[names[0]] = names[1]
      end
      raise 'TEAM_MEMBERS_HASH must be set.' if @@team_members.empty?

      def get_interrupt_list(payload)
        board_name = ENV['TRELLO_BOARD_NAME'] or raise 'TRELLO_BOARD_NAME must be set.'
        team_board = nil
        @@team_members.each do |trello_username, _|
          member = Trello::Member.find(trello_username)
          break if team_board = member.boards.find do |board|
            board.name == board_name
          end
        end
        raise 'Team board not found!' unless team_board

        @@interrupt_list = nil
        team_board.lists.each do |list|
          break_flag = false
          Trello::List.find(list.id).cards.each do |card|
            if card.name == 'Interrupt'
              @@interrupt_list = list
              break_flag = true
              break
            end
            break if break_flag
          end
        end
        raise %q(
              Interrupt list not found!
              Your team trello board needs a list with a card titled 'Interrupt'!
        ) unless @@interrupt_list
      end

      def interrupt_pair
        interrupt_ids = []
        @@interrupt_list.cards.each do |card|
          card.member_ids.each do |member|
            username = Trello::Member.find(member).username
            interrupt_ids << @@team_members[username]
          end
        end
        interrupt_ids.empty? ? @@team_members.map { |_, val| val } : interrupt_ids
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
        # TODO: update @@team_members and persist it somehow
        response.reply(%Q(I have linked trello user '#{new_member.username}' with <@#{response.user.id}>!))
      end

      Lita.register_handler(self)
    end
  end
end
