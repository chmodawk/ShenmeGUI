module ShenmeGUI

  class << self
    attr_accessor :elements, :socket
    attr_reader :this

    %w{body stack flow button radio checkbox image select textline textarea label progress}.each do |x|
      define_method x do |params={}, &block|
        el = const_get(x.capitalize).new(params)
        @temp_stack.last.children << el unless @temp_stack.empty?
        el.parent = @temp_stack.last unless @temp_stack.empty?
        @temp_stack << el
        instance_eval &block unless block.nil?
        @temp_stack.pop
        el
      end
      private x.to_sym
    end

    def handle(msg)
      match_data = msg.match(/(.+?):(\d+)(?:->)?({.+?})?/)
      command = match_data[1].to_sym
      id = match_data[2].to_i
      data = JSON.parse(match_data[3]) unless match_data[3].nil?
      target = elements[id]
      case command
        when :sync
          target.properties.update(data)
        else
          event_lambda = elements[id].events[command]
          @this = elements[id]
          result = ShenmeGUI.instance_exec(&event_lambda) if event_lambda
          @this = nil
          result

      end
      target
    end

    def app(params={}, &block)
      instance_eval(&block)
      File.open('index.html', 'w'){ |f| f.write elements[0].render }
      nil
    end

  end

  @elements = []
  @temp_stack = []

  def self.start!
    ws_thread = Thread.new do
      EM.run do
        EM::WebSocket.run(:host => "0.0.0.0", :port => 80) do |ws|
          ws.onopen do
            puts "WebSocket connection open"
            elements.each { |e| e.add_events }
          end

          ws.onclose { puts "Connection closed" }

          ws.onmessage do |msg|
            puts "Recieved message: #{msg}"
            handle msg
          end
          
          @socket = ws
        end
      end
    end

    index_path = "#{Dir.pwd}/index.html"
    `start file:///#{index_path}`

    ws_thread.join
  rescue Interrupt
    puts 'bye~'
  end

end