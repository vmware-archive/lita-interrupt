require 'spec_helper'

describe Lita::Handlers::Interrupt, lita_handler: true do
  describe '#run' do
    let(:maester) { Lita::User.create('U9298ANLQ', name: 'maester_luwin') }
    let(:sam) { Lita::User.create('U93MFAV9V', name: 'sam') }
    let(:jon) { Lita::User.create('U1BSCLVQ1', name: 'jon') }
    let(:tyrion) { Lita::User.create('U5062MBLE', name: 'tyrion') }
    let(:jaime) { Lita::User.create('U8FE4C6Z7', name: 'jaime') }
    let(:list) { Trello::List.new(list_details) }
    before do
      allow(Trello::Member).to receive(:find).with('jonsnow').and_return(Trello::Member.new(jon_details))
      allow(Trello::Member).to receive(:find).with('samwelltarley').and_return(Trello::Member.new(sam_details))
      allow(Trello::Member).to receive(:find).with('jaimelannister').and_return(Trello::Member.new(jaime_details))
      allow(Trello::Member).to receive(:find).with('tyrionlannister').and_return(Trello::Member.new(tyrion_details))
      allow_any_instance_of(Trello::Member).to receive(:boards).and_return([Trello::Board.new(name: 'Game of Boards')])
      allow_any_instance_of(Trello::Board).to receive(:lists).and_return([list])
      allow(Trello::List).to receive(:find).with(list.id).and_return(list)
      allow(list)
        .to receive(:cards)
        .and_return([
      Trello::Card.new(card_details_array[0]),
      Trello::Card.new(card_details_array[1]),
      Trello::Card.new(card_details_array[2])
      ])
    end

    it 'routes the command' do
      is_expected.to route_command('hey').to(:handle_interrupt)
    end

    describe 'when tyrion & jaime are the interrupt pair' do
      before do
        robot.trigger(:connected)
      end
      it 'pings the interrupt pair only' do
        send_command('hello hello hello', as: maester)
        expect(replies.last).to eq("<@#{tyrion.id}> <@#{jaime.id}>: you have an interrupt from <@#{maester.id}> ^^")
      end
    end

    describe 'when there is no interrupt list' do
      before do
        allow(list)
          .to receive(:cards)
          .and_return([
        Trello::Card.new(card_details_array[1]),
        Trello::Card.new(card_details_array[2])
        ])
      end
      it 'raises an error' do
        expect { robot.trigger(:connected) }.to raise_error(%q(
              Interrupt list not found!
              Your team trello board needs a list with a card titled 'Interrupt'!
                                                            ))
      end
    end

    describe 'when there is no interrupt list' do
      before do
        allow(list)
          .to receive(:cards)
          .and_return([
        Trello::Card.new(card_details_array[0])
        ])
        robot.trigger(:connected)
      end
      it 'pings the whole team' do
        send_command('hello hello hello', as: maester)
        expect(replies.last).to eq("<@#{jon.id}> <@#{sam.id}> <@#{tyrion.id}> <@#{jaime.id}>: you have an interrupt from <@#{maester.id}> ^^")
      end
    end

    describe 'someone requests to be added to team_members' do
      it 'adds them' do
        send_command('add samwelltarley to BAM', as: sam)
        expect(replies.last).to eq(%Q(I have linked trello user 'samwelltarley' with <@#{sam.id}>!))
      end
    end
  end
end
