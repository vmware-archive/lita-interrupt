require 'trello'
class TrelloDebug
  attr_reader :interrupt_list, :team_members, :team_board, :interrupt_card
  def initialize
    configure_trello
    set_team_member_hash
    get_interrupt_list
  end

  def interrupt_pair
    interrupt_ids = []
    @interrupt_list.cards.each do |card|
      card.member_ids.each do |member|
        username = Trello::Member.find(member).username
        interrupt_ids << @team_members[username]
      end
    end
    interrupt_ids.empty? ? @team_members.map { |_, val| val } : interrupt_ids
  end

  private

  def configure_trello
    Trello.configure do |c|
      c.developer_public_key = ENV['TRELLO_DEVELOPER_PUBLIC_KEY']
      c.member_token = ENV['TRELLO_MEMBER_TOKEN']
    end
  end

  def set_team_member_hash
    @team_members = {}
    ENV['TEAM_MEMBERS_HASH'].split(',').each do |pair|
      names = pair.split(':')
      @team_members[names[0]] = names[1]
    end
  end

  def get_interrupt_list
    @interrupt_list = nil
    board_name = ENV['TRELLO_BOARD_NAME']
    @team_board = nil
    @team_members.each do |trello_username, _|
      member = Trello::Member.find(trello_username)
      break if @team_board = member.boards.find do |board|
        board.name == board_name
      end
    end

    @team_board.lists.each do |list|
      break_flag = false
      Trello::List.find(list.id).cards.each do |card|
        if card.name == 'Interrupt'
          @interrupt_list = list
          @interrupt_card = card
          break_flag = true
          break
        end
        break if break_flag
      end
    end
  end
end
