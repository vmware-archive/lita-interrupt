module Lita
  module Handlers
    class Cf < Handler
      # insert handler code here

      Lita.register_handler(self)

      route(/^echo\s+(.+)/, command: true, help: {"echo TEXT" => "Replies back with TEXT."}) do |response|
        response.reply("#{response.match_data[1]}")
      end

      # route(/^cf\s+(\bhelp\b|\bh\b|\bapps\b|\bservices\b|\bspaces\b|\borgs\b|\bo\b|\broutes\b|\br\b|\bmarketplace\b|\bdomains\b|\bspace-users\b|\borg-users\b)/, command: true) do |response|
      route(/^cf\s+(.+)/, command: true) do |response|
        apps = `/Users/pivotal/workspace/lita/lita-cf/lib/lita/scripts/cf_apps.sh #{response.args[0..-1].join(' ')}`
        response.reply("```#{apps}```")
      end
    end
  end
end

