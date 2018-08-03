require 'spec_helper'

describe Lita::Handlers::Cf, lita_handler: true do
  describe '#run' do
    it { is_expected.to route_command('hey').to(:handle_interrupt) }

    describe 'when nobody is interrupt' do
      before do
        allow(Trello::List).to receive(:find).with('samwelltarley').and_return(trello_sam)
      end
      it 'pings the whole team' do
        send_command('hello hello hello')
        expect(replies.last).to eq('')
      end
    end

    def user_details
      {
        'id'         => 'abcdef123456789012345678',
        'fullName'   => 'Samwell Tarley',
        'username'   => 'samwelltarley',
        'intials'    => 'ST',
        'avatarHash' => 'abcdef1234567890abcdef1234567890',
        'bio'        => 'a rather famous user',
        'url'        => 'https://trello.com/samwelltarley',
        'email'      => 'samwelltarley@thewall.com'
      }
    end
    describe 'someone requests to be added to team_members' do
      let!(:trello_sam) do
        Trello::Member.new(user_details)
      end
      let!(:sam) { Lita::User.create('U9Z2QJL1F', name: 'sam') }

      before do
        allow(Trello::Member).to receive(:find).with('samwelltarley').and_return(trello_sam)
      end

      it 'adds them' do
        send_command('add samwelltarley to BAM', as: sam)

        expect(replies.last).to eq(%Q(I have linked trello user 'samwelltarley' with <@#{sam.id}>!))
      end
    end
  end
end
