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

      def initialize(websocket_url:, token:)
        @queue = Queue.new
        @client = create_client(websocket_url.to_s, token)
      end

      def send_message(data)
        data[:id] = (Time.now.to_i * 10 + rand(10)) % (1 << 31)
        @queue.enq(data.to_json)
      end

      def on_text
        @client.on(:message) do |message|
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
          @client.send(message)
        end
      end

      private

      def create_client(url, token)
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
            @client.send('', type: 'ping')
          end
        end
      end
    end
  end
end