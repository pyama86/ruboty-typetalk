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
require 'websocket-client-simple'

module Ruboty
  module TypeTalk
    class Client
      CONNECTION_CLOSED = Object.new

      def initialize(websocket_url:)
        @queue = Queue.new
        @stream_client ||= build_stream_client(websocket_url.to_s)
      end

      def send_message(data)
        data[:id] = (Time.now.to_i * 10 + rand(10)) % (1 << 31)
        @queue.enq(data.to_json)
      end

      def on_text
        @stream_client.on(:message) do |message|
          case message.type
          when :ping
            Ruboty.logger.debug("#{Client.name}: Received ping message")
            send('', type: 'pong')
          when :pong
            Ruboty.logger.debug("#{Client.name}: Received pong message")
          when :text
            yield(JSON.parse(message.data))
          else
            Ruboty.logger.warn("#{Client.name}: Received unknown message type=#{message.type}: #{message.data}")
          end
        end
      end

      def main_loop
        keep_connection

        loop do
          message = @queue.deq
          break if message.equal?(CONNECTION_CLOSED)
          @stream_client.send(message)
        end
      end

      def post(path, params)
        res = conn.post(path) do |req|
          req.body = params.to_json
          req.headers['Content-Type'] = 'application/json'
          req.headers['Authorization'] = "Bearer #{token}"
        end

        JSON.parse(res.body)
      end

      def get(path, params = {})
        res = conn.get(path) do |req|
          req.body = params.to_json
          req.headers['Content-Type'] = 'application/json'
          req.headers['Authorization'] = "Bearer #{token}"
        end

        JSON.parse(res.body)
      end

      private

      def conn
        @_conn = Faraday.new(url: 'https://typetalk.com') do |faraday|
          faraday.request  :url_encoded
          faraday.adapter  Faraday.default_adapter
        end
      end

      def token
        if !@_token || @_token.expired?
          @_token = Token.new(conn)
        end
        @_token.value
      end

      def build_stream_client(url)
        WebSocket::Client::Simple.connect(url, verify_mode: OpenSSL::SSL::VERIFY_PEER, headers: { Authorization: "Bearer #{token}" }).tap do |client|
          client.on(:error) do |err|
            Ruboty.logger.error("#{err.class}: #{err.message}\n#{err.backtrace.join("\n")}")
          end
          queue = @queue
          client.on(:close) do
            Ruboty.logger.info('Disconnected')
            queue.enq(CONNECTION_CLOSED)
          end
        end
      end

      def keep_connection
        Thread.start do
          loop do
            sleep(30)
            @stream_client.send('', type: 'ping')
          end
        end
      end
    end

    class Token
      def initialize(conn)
        response = conn.post('/oauth2/access_token', client_id: ENV['TYPETALK_CLIENT_ID'],
                                                     client_secret: ENV['TYPETALK_CLIENT_SECRET'],
                                                     grant_type: 'client_credentials',
                                                     scope: 'my,topic.read,topic.post')
        body = JSON.parse(response.body)
        @_token = { token: body['access_token'], expired_at: Time.now + body['expires_in'] }
      end

      def expired?
        @_token[:expired_at] < Time.now
      end

      def value
        @_token[:token]
      end
    end
  end
end
