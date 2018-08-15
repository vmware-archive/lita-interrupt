# frozen_string_literal: true

require 'lita-interrupt'
require 'lita/rspec'

# A compatibility mode is provided for older plugins upgrading from Lita 3.
# Since this plugin was generated with Lita 4, the compatibility mode
# should be left disabled.
Lita.version_3_compatibility_mode = false

RSpec.configure do |config|
  config.before do
    registry.register_hook(:validate_route, Lita::Extensions::ExclusiveRoute)
  end
end

def jon_details
  {
    'id'         => 'abcde1f23457689021346578',
    'fullName'   => 'Jon Snow',
    'username'   => 'jonsnow',
    'intials'    => 'JS',
    'avatarHash' => 'abcdef1234567890abcdef1234567890',
    'bio'        => 'a rather famous user',
    'url'        => 'https://trello.com/jonsnow',
    'email'      => 'jonsnow@thewall.com'
  }
end

def sam_details
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

def new_sam_details
  {
    'id'         => 'badce1f24357680913246578',
    'fullName'   => 'Samwell Tarley',
    'username'   => 'samwelltarley2',
    'intials'    => 'ST',
    'avatarHash' => 'abcdef1234567890abcdef1234567890',
    'bio'        => 'a rather famous user with a new username',
    'url'        => 'https://trello.com/samwelltarley',
    'email'      => 'samwelltarley@thewall.com'
  }
end

def jaime_details
  {
    'id'         => 'abdcfe132465879012346587',
    'fullName'   => 'Jaime Lannister',
    'username'   => 'jaimelannister',
    'intials'    => 'JL',
    'avatarHash' => 'abcdef1234567890abcdef1234567890',
    'bio'        => 'a rather famous user',
    'url'        => 'https://trello.com/jaimelannister',
    'email'      => 'jaimelannister@golden.com'
  }
end

def tyrion_details
  {
    'id'         => 'abcedf132465798021354687',
    'fullName'   => 'Tyrion Lannister',
    'username'   => 'tyrionlannister',
    'intials'    => 'TL',
    'avatarHash' => 'abcdef1234567890abcdef1234567890',
    'bio'        => 'a rather famous user',
    'url'        => 'https://trello.com/tyrionlannister',
    'email'      => 'tyrionlannister@golden.com'
  }
end

def list_details
  {
    'id' => 'abcdef123456789123456789',
    source_list_id: 'abcdef123456789123456780'
  }
end

def interrupt_list_details
  {
    'id' => 'abecfd215364782931458697',
    source_list_id: 'badcfe214365871932547608'
  }
end

def board_details
  {
    'id' => 'abcdef123456789123456789',
    organization_id: 'abcdef123456789123456789'
  }
end

def interrupt_card_details
  {
    name:                   'Interrupt',
    list_id:                'abcdef123456789123456789',
    desc:                   'This is the interrupt card',
    member_ids:             [],
    card_labels: %w[abcdef123456789123456789 dbcdef123456789123456789],
    due:                    Date.today,
    pos:                    12,
    source_card_id:         'abcdef1234567891234567890',
    source_card_properties: 'checklist,members'
  }
end

def tyrion_card_details
  {
    name:                   'Tyrion Lannister',
    list_id:                'abcdef123456789123456789',
    desc:                   'Tyrion Lannister personal card.',
    member_ids:             ['tyrionlannister'],
    card_labels: %w[abcdef123456789123456789 dbcdef123456789123456789],
    due:                    Date.today,
    pos:                    12,
    source_card_id:         'abcdef1234567891234567890',
    source_card_properties: 'checklist,members'
  }
end

def jaime_card_details
  {
    name:                   'Jaime Lannister',
    list_id:                'abcdef123456789123456789',
    desc:                   'Jaime Lannister personal card.',
    member_ids:             ['jaimelannister'],
    card_labels: %w[abcdef123456789123456789 dbcdef123456789123456789],
    due:                    Date.today,
    pos:                    12,
    source_card_id:         'abcdef1234567891234567890',
    source_card_properties: 'checklist,members'
  }
end

def team_details
  {
    'jonsnow' => 'U1BSCLVQ1',
    'samwelltarley' => 'U93MFAV9V',
    'tyrionlannister' => 'U5062MBLE',
    'jaimelannister' => 'U8FE4C6Z7'
  }
end

def augmented_team_details
  {
    'jonsnow' => 'U1BSCLVQ1',
    'samwelltarley' => 'U93MFAV9V',
    'tyrionlannister' => 'U5062MBLE',
    'jaimelannister' => 'U8FE4C6Z7',
    'samwelltarley2' => 'U93MFAV9V'
  }
end

def diminished_team_details
  {
    'jonsnow' => 'U1BSCLVQ1',
    'tyrionlannister' => 'U5062MBLE',
    'jaimelannister' => 'U8FE4C6Z7',
  }
end
