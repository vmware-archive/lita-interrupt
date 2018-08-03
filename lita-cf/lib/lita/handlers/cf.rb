# frozen_string_literal: true

require 'trello'
require 'lita-exclusive-route'
module Lita
  module Handlers
    # a handler
    class Cf < Handler
      @@team_members = {}
      # TEAM_MEMBER_HASH should look like "trello_name1:slack_handle1,trello_name2:slack_handle2"
      # temporary workaround since this cannot be read as a hash
      # TODO make this go in a DB
      ENV['TEAM_MEMBERS_HASH'].split(',').each do |pair|
          names = pair.split(':')
          @@team_members[names[0]] = names[1]
      end

      Lita.register_handler(self)
      Trello.configure do |c|
        c.developer_public_key = ENV['TRELLO_DEVELOPER_PUBLIC_KEY']
        c.member_token = ENV['TRELLO_MEMBER_TOKEN']
      end

      board_id = ENV['TRELLO_BAM_BOARD_ID']

      # if board_id.nil?

      @@interrupt_list = nil
      Trello::Board.find(board_id).lists.each do |list|
        break_flag = false
        Trello::List.find(list.id).cards.each do |card|
          if card.name == 'Interrupt'
            @@interrupt_list = list.id
            break_flag = true
            break
          end
          break if break_flag
        end
      end

      route(/^echo\s+(.+)/,
            command: true,
            help: { 'echo TEXT' => 'Replies back with TEXT.' }) do |response|
        response.reply(response.match_data[1].to_s)
      end

      # route(/^cf\s+(\bhelp\b|\bh\b|\bapps\b|\bservices\b|\bspaces\b|\borgs\b|\bo\b|\broutes\b|\br\b|\bmarketplace\b|\bdomains\b|\bspace-users\b|\borg-users\b)/, command: true) do |response|
      route(/^cf\s+(.+)/, command: true) do |response|
        cf_script = '/Users/pivotal/workspace/lita/lita-cf/lib/lita/scripts/cf_apps.sh'
        apps = `#{cf_script} #{response.args[0..-1].join(' ')}`
        response.reply("```#{apps}```")
      end

      route(/^blahblah$/, command: false) do |response|
        response.reply('hey, blah blah to you')
      end

      route(%r{^.*salesforce.com\/.*$}, command: false) do
        p 'someone just said salesforce'
      end

      # target = Source.new(room: response.room)
      # robot.set_topic(target, 'hey there')

      def interrupt_pair
        interrupt_ids = []
        Trello::List.find(@@interrupt_list).cards.each do |card|
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
        response.reply(%Q(I have linked trello user '#{new_member.username}' with <@#{response.user.id}>!))
      end

      route(%r{add (.*) to BAM}, :add_to_team, command: true)
      route(%r{^(.+)$}, :handle_interrupt, command: true, exclusive: true)
    end
  end
end
