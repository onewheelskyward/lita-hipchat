require "lita/adapters/hipchat/callback"

require "xmpp4r"
require "xmpp4r/roster/helper/roster"
require "xmpp4r/muc/helper/simplemucclient"
require "xmpp4r/muc/helper/mucbrowser"

module Lita
  module Adapters
    class HipChat < Adapter
      class Connector
        attr_reader :robot, :client, :roster

        def initialize(robot, jid, password, debug: false)
          @robot = robot
          @jid = normalized_jid(jid, "chat.hipchat.com", "bot")
          @password = password
          @client = Jabber::Client.new(@jid)
          Jabber.debug = true if debug
        end

        def jid
          @jid.to_s
        end

        def connect
          client_connect
          load_roster
          register_message_callback
        end

        def join_rooms(muc_domain, rooms)
          rooms.each do |room_name|
            muc = Jabber::MUC::SimpleMUCClient.new(client)
            room_jid = normalized_jid(room_name, muc_domain, robot.name)
            mucs[room_jid.bare.to_s] = muc
            register_muc_message_callback(muc)
            muc.join(room_jid)
          end
        end

        def list_rooms(muc_domain)
          browser = Jabber::MUC::MUCBrowser.new(client)
          browser.muc_rooms(muc_domain).map { |jid, name| jid.to_s }
        end

        def message_jid(user_jid, strings)
          strings.each do |s|
            message = Jabber::Message.new(user_jid, s)
            message.type = :chat
            client.send(message)
          end
        end

        def message_muc(room_jid, strings)
          muc = mucs[room_jid]
          strings.each { |s| muc.say(s) } if muc
        end

        def mucs
          @mucs ||= {}
        end

        def set_topic(room_jid, topic)
          muc = mucs[room_jid]
          muc.subject = topic if muc
        end

        def shut_down
          client.close
        end

        private

        def client_connect
          client.connect
          client.auth(@password)
          client.send(Jabber::Presence.new(:chat))
        end

        def register_message_callback
          Callback.new(robot, roster).private_message(client)
        end

        def register_muc_message_callback(muc)
          muc.on_message do |time, nick, text|
          end
        end

        def load_roster
          @roster = Jabber::Roster::Helper.new(client)
          roster.wait_for_roster
        end

        def normalized_jid(jid, domain, resource)
          jid = Jabber::JID.new(jid)
          jid.resource = resource
          unless jid.node
            jid.node = jid.domain
            jid.domain = domain
          end
          jid
        end
      end
    end
  end
end
