# Copyright (c) 2015 Sho Kusano
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'json'
require 'net/http'
require 'ruboty/adapters/base'
require 'faraday'

module Ruboty
  module Adapters
    class TypeTalk < Base
      env :TYPETALK_CLIENT_ID, 'ClientID. get one on https://developer.nulab-inc.com/ja/docs/typetalk/'
      env :TYPETALK_CLIENT_SECRET, 'client secret key'

      def run
        init
        bind
        connect
      end

      def say(message)
        channel = resolve_topic_id(message[:to])
        return unless channel

        m = {
          message: message[:code] ? "```\n#{message[:body]}\n```" : message[:body]
        }
        client.post("/api/v1/topics/#{channel}", m)
      end

      private

      def resolve_topic_id(name)
        channel_info.find { |c| c[:name] == name }[:id]
      end

      def channel_info
        @_channel_info ||= begin
                             body = client.get("api/v1/topics")
                             body['topics'].map do |t|
                               { id: t['topic']['id'], name: t['topic']['name'] }
                             end
                           end
      end

      def init; end

      def bind
        realtime.on_text do |data|
          method_name = "on_#{data['type'].downcase}".to_sym
          send(method_name, data['data']) if respond_to?(method_name, true)
        end
      end

      def connect
        Thread.start do
          loop do
            sleep 5
            set_active
          end
        end

        loop do
          begin
            realtime.main_loop
          rescue StandardError
            nil
          end
          @realtime = nil
        end
      end


      def realtime
        @realtime ||= ::Ruboty::TypeTalk::Client.new(websocket_url: 'https://typetalk.com/api/v1/streaming')
      end

      # event handlers

      def on_postmessage(data)
        message_info = {
          from: data['topic']['name'],
          from_name: data['post']['account']['name'],
          time: Time.at(data['post']['createdAt'].to_f)
        }

        body = data['post']['message']
        mention_to = begin
                       data['post']['mention'].map { |m| m['name'] }
                     rescue StandardError
                       []
                     end
        robot.receive(message_info.merge(body: body, mention_to: mention_to))
      end
    end
  end
end
