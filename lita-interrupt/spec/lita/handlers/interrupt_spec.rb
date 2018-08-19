# frozen_string_literal: true

require 'spec_helper'

describe Lita::Handlers::Interrupt, lita_handler: true do
  describe '#run' do
    let(:maester) { Lita::User.create('U9298ANLQ', name: 'maester_luwin') }
    let(:sam) { Lita::User.create('U93MFAV9V', name: 'sam') }
    let(:arya) { Lita::User.create('U93FMA9VV', name: 'arya') }
    let(:jon) { Lita::User.create('U1BSCLVQ1', name: 'jon') }
    let(:tyrion) { Lita::User.create('U5062MBLE', name: 'tyrion') }
    let(:jaime) { Lita::User.create('U8FE4C6Z7', name: 'jaime') }
    let(:list) { Trello::List.new(list_details) }
    let(:interrupt_list) { Trello::List.new(interrupt_list_details) }
    let(:interrupt_card) { Trello::Card.new(interrupt_card_details) }
    let(:jaime_card) { Trello::Card.new(jaime_card_details) }
    let(:tyrion_card) { Trello::Card.new(tyrion_card_details) }
    let(:board_name) { 'Game of Boards' }
    let(:redis_team_roster_hash) do
      JSON.parse(subject.redis.get(:roster_hash))
    end

    before do
      registry.configure do |config|
        config.robot.admins = [maester.id]
        config.handlers.interrupt.trello_developer_public_key = ''
        config.handlers.interrupt.trello_member_token = ''
        config.handlers.interrupt.board_name = board_name
      end
      allow(Trello::Member)
        .to receive(:find)
        .with('jonsnow')
        .and_return(Trello::Member.new(jon_details))
      allow(Trello::Member)
        .to receive(:find)
        .with('samwelltarley')
        .and_return(Trello::Member.new(sam_details))
      allow(Trello::Member)
        .to receive(:find)
        .with('jaimelannister')
        .and_return(Trello::Member.new(jaime_details))
      allow(Trello::Member)
        .to receive(:find)
        .with('tyrionlannister')
        .and_return(Trello::Member.new(tyrion_details))
      allow_any_instance_of(Trello::Member)
        .to receive(:boards)
        .and_return([Trello::Board.new(name: 'Game of Boards')])
      allow_any_instance_of(Trello::Board)
        .to receive(:lists)
        .and_return([list, interrupt_list])
      allow(Trello::List).to receive(:find).with(list.id).and_return(list)
      allow(Trello::List)
        .to receive(:find)
        .with(interrupt_list.id)
        .and_return(interrupt_list)
      allow(Trello::Card)
        .to receive(:find)
        .with(interrupt_card.id)
        .and_return(interrupt_card)
      allow(Trello::Card)
        .to receive(:find)
        .with(jaime_card.id)
        .and_return(jaime_card)
      allow(Trello::Card)
        .to receive(:find)
        .with(tyrion_card.id)
        .and_return(tyrion_card)
      allow(tyrion_card).to receive(:list).and_return(interrupt_list)
      allow(jaime_card).to receive(:list).and_return(interrupt_list)
      allow(interrupt_card).to receive(:list).and_return(interrupt_list)
      allow(list).to receive(:cards).and_return([tyrion_card, jaime_card])
      allow(interrupt_list)
        .to receive(:cards)
        .and_return([interrupt_card, tyrion_card, jaime_card])
      subject.redis.set(:roster_hash, team_details.to_json)
    end

    it { is_expected.to route_command('hey').to(:interrupt_command) }

    it { is_expected.to route(+"hi @#{robot.name} hey").to(:interrupt_mention) }

    it { is_expected.to route_command(+'remove  me').to(:remove_from_team) }

    it { is_expected.to route_command(+'team').to(:list_team) }

    it do
      is_expected.not_to route_command(+'remove @someone').to(:remove_from_team)
    end

    it do
      is_expected
        .to route_command(+'remove @someone')
        .with_authorization_for(:team)
        .to(:remove_from_team)
    end

    it do
      is_expected
        .to route_command(+'add me my_trello_name ')
        .to(:add_to_team)
    end

    it do
      is_expected
        .not_to route_command(+'add @someone some_trello_user ')
        .to(:add_to_team)
    end

    it do
      is_expected
        .to route_command(+'add @someone some_trello_user ')
        .with_authorization_for(:team)
        .to(:add_to_team)
    end

    it { is_expected.not_to route_command(+'part').to(:part) }

    it do
      is_expected
        .to route_command(+'part')
        .with_authorization_for(:team)
        .to(:part)
    end

    describe 'when there are multiple interrupt cards' do
      before do
        allow(list)
          .to receive(:cards)
          .and_return([interrupt_card, tyrion_card, jaime_card])
      end
      it 'alerts the admins and pings the interrupt pair' do
        send_command('hello hello hello', as: maester)
        expect(replies.last)
          .to eq(
            "<@#{tyrion.id}> <@#{jaime.id}>: "\
            "you have an interrupt from <@#{maester.id}> ^^"
          )
        expect(replies[-2])
          .to eq('Multiple interrupt cards found! Using first one.')
      end
    end

    describe 'when tyrion & jaime are the interrupt pair' do
      it 'looks up the interrupt list from the current interrupt card' do
        expect(Trello::Card)
          .to receive(:find)
          .with(interrupt_card.id)
          .and_return(interrupt_card)
        expect(interrupt_card)
          .to receive(:list)
          .and_return(interrupt_list)
        send_command('hey', as: maester)
      end

      describe 'and the interrupt list contains the interrupt card' do
        it 'pings the interrupt pair only' do
          send_command('hello hello hello', as: maester)
          expect(replies.last)
            .to eq(
              "<@#{tyrion.id}> <@#{jaime.id}>: "\
              "you have an interrupt from <@#{maester.id}> ^^"
            )
        end
      end
    end

    describe 'when there is no interrupt list' do
      before do
        allow_any_instance_of(Trello::List)
          .to receive(:cards).and_return([tyrion_card])
      end
      it "privately messages the robot's admins" do
        send_command('hello hello hello', as: maester)
        expect(replies.last).to eq(
          'Interrupt card not found! Your team '\
          'trello board needs a list with a card titled "Interrupt".'
        )
      end
    end

    describe 'when there is nobody on the interrupt list' do
      before do
        allow(interrupt_list).to receive(:cards).and_return([interrupt_card])
      end
      it 'pings the whole team' do
        send_command('hello hello hello', as: maester)
        expect(replies.last)
          .to eq(
            "<@#{jon.id}> <@#{sam.id}> <@#{tyrion.id}> <@#{jaime.id}>: "\
            "you have an interrupt from <@#{maester.id}> ^^"
          )
      end
    end

    describe 'when the bot is mentioned but not commanded' do
      it 'pings the interrupt pair' do
        send_message(+"hey hey hey @#{robot.name} hello", as: maester)
        expect(replies.last)
          .to eq(
            "<@#{tyrion.id}> <@#{jaime.id}>: "\
            "you have an interrupt from <@#{maester.id}> ^^"
          )
      end
    end

    describe 'when the team board does not exist for any roster member' do
      before do
        allow_any_instance_of(Trello::Member)
          .to receive(:boards)
          .and_return([Trello::Board.new(name: 'Game of Bards')])
      end
      it 'alerts the admins' do
        send_message(+"hey hey hey @#{robot.name} hello", as: maester)
        expect(replies.last)
          .to eq(
            %(Trello team board "#{board_name}" not found! )\
            'Set "TRELLO_BOARD_NAME" and restart me, please.'
          )
      end
    end

    describe 'when asked to leave a room by a teammate' do
      before do
        robot.auth.add_user_to_group!(user, :team)
      end

      it 'leaves the room' do
        room = Lita::Room.create_or_update('#this_example_room')
        expect(robot).to receive(:part).with(room)
        send_command('part', from: room, as: user)
      end
    end

    describe 'when someone asks to get a list of the team roster' do
      it 'lists the team member slack handles and trello user names' do
        send_command('team', as: maester)
        expect(replies.last).to eq(
          'The team roster is <@U1BSCLVQ1> => jonsnow, '\
            '<@U93MFAV9V> => samwelltarley, '\
            '<@U5062MBLE> => tyrionlannister, '\
            '<@U8FE4C6Z7> => jaimelannister'
        )
      end
    end

    describe 'when the redis store has no team roster' do
      before { subject.redis.del(:roster_hash) }

      describe 'when someone asks for the team roster' do
        it 'lets the admins know that there is no roster' do
          send_command('team', as: maester)
          expect(replies.last).to eq(
            'You must add some users to the team roster. '\
            "You will need each member's slack handle and trello user name."
          )
        end
      end

      describe 'when someone triggers the interrupt' do
        it 'lets the admins know that there is no roster' do
          send_command('hey', as: jon)
          expect(replies.last).to eq(
            'You must add some users to the team roster. '\
            "You will need each member's slack handle and trello user name."
          )
        end
      end
    end

    describe 'when someone requests that they be removed from team roster' do
      it 'removes them' do
        send_command('remove  me', as: sam)
        expect(replies.last)
          .to eq(
            %(Trello user "samwelltarley" (<@#{sam.id}>) removed!)
          )
        expect(redis_team_roster_hash).to eq(diminished_team_details)
      end
    end

    describe 'when someone requests that they be added to team roster' do
      before do
        allow(Trello::Member)
          .to receive(:find)
          .with('aryastark')
          .and_return(Trello::Member.new(arya_details))
      end
      it 'adds them' do
        send_command('add me aryastark ', as: arya)
        expect(replies.last)
          .to eq(
            %(Trello user "aryastark" (<@#{arya.id}>) added!)
          )
        expect(redis_team_roster_hash).to eq(augmented_team_details)
      end
    end

    describe 'when a teammate requests to remove someone from roster' do
      it 'removes them' do
        robot.auth.add_user_to_group!(maester, :team)
        send_command("remove @#{sam.id} ", as: maester)
        expect(replies.last)
          .to eq(
            %(Trello user "samwelltarley" (<@#{sam.id}>) removed!)
          )
        expect(redis_team_roster_hash).to eq(diminished_team_details)
      end
    end

    describe 'when a non-teammate requests to remove someone from roster' do
      it 'does not remove them' do
        send_command("remove @#{sam.id} ", as: jaime)
        expect(replies.last)
          .to_not eq(
            %(Trello user "samwelltarley" (<@#{sam.id}>) removed!)
          )
        expect(redis_team_roster_hash).to eq(team_details)
      end
    end

    describe 'when a teammate requests to add someone to the team roster' do
      before do
        robot.auth.add_user_to_group!(maester, :team)
        allow(Trello::Member)
          .to receive(:find)
          .with('aryastark')
          .and_return(Trello::Member.new(arya_details))
      end
      it 'adds them' do
        send_command("add @#{arya.id} aryastark", as: maester)
        expect(replies.last)
          .to eq(
            %(Trello user "aryastark" (<@#{arya.id}>) added!)
          )
        expect(redis_team_roster_hash).to eq(augmented_team_details)
      end
    end

    describe 'when a non-teammate requests to add someone to the roster' do
      before do
        allow(Trello::Member)
          .to receive(:find)
          .with('aryastark')
          .and_return(Trello::Member.new(arya_details))
      end
      it 'does not add them' do
        send_command("add @#{arya.id} aryastark", as: jaime)
        expect(replies.last)
          .to_not eq(
            %(Trello user "aryastark" (<@#{arya.id}>) added!)
          )
        expect(redis_team_roster_hash).to eq(team_details)
      end
    end

    describe 'when someone asks for the team roster' do
      it 'lists the team member slack handles and trello user names' do
        send_command('team', as: maester)
        expect(replies.last).to eq(
          'The team roster is <@U1BSCLVQ1> => jonsnow, '\
            '<@U93MFAV9V> => samwelltarley, '\
            '<@U5062MBLE> => tyrionlannister, '\
            '<@U8FE4C6Z7> => jaimelannister'
        )
      end
    end
  end
end
