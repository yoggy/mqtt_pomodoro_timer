#!/usr/bin/ruby
#
# mqtt_pomodoro_timer.rb - publish the local time using the MQTT.
#
#   $ sudo gem install mqtt
#   $ sudo gem install pit
#
require 'rubygems'
require 'mqtt'
require 'pit'
require 'json'

Thread.abort_on_exception = true

$config = Pit.get("mqtt_pomodoro_timer", :require => {
  "remote_host"     => "mqtt.example.com",
  "remote_port"     => 1883,
  "use_auth"        => false,
  "username"        => "username",
  "password"        => "password",
  "subscribe_topic" => "hvcc_face0",       # for node-omron-hvc-c-test
  "check_key"       => "detect_face_num",
  "publish_topic"   => "7seg0001",         # for nodemcu_mqtt_sub.lua & serial_sseg.ino
})

$conn_opts = {
  remote_host: $config["remote_host"],
  remote_port: $config["remote_port"].to_i,
}
if $config["use_auth"] == true
  $conn_opts["username"] = $config["username"]
  $conn_opts["password"] = $config["password"]
end

$conn = nil

def publish(msg)
  msg = "    " if msg.nil?
  str = "segd" + msg   # for serial_sseg.ino protocol
  puts "publish : topic=" + $config["publish_topic"] + ", message=" + str
  $conn.publish($config["publish_topic"], str)
end

$last_received_t = 0
$last_received_1 = 0
$start_t = 0

def diff(t)
  Time.now.to_i - t
end

def format_t(t)
  h = t / 60 / 60
  m = (t / 60) % 60
  s = t % 60
  sprintf("%02d.%02d", h, m)
end

def check
  if diff($last_received_t) > 30
    msg = "DOWN"
    $start_t = 0
  else
    if diff($last_received_1) < 10
      $start_t = Time.now.to_i if $start_t == 0

      t = diff($start_t)
      
      if t < 25 * 60
        msg = format_t(t)
      else
        # blink
        puts t % 2
        if t % 2 == 1
          msg = format_t(t)
        else
	      msg = "  .  "
        end
      end
    else
      msg = "    "
      $start_t = 0
    end
  end
  publish(msg)
end

loop do
  begin
    MQTT::Client.connect($conn_opts) do |c|
       puts "connected!"
    
       $conn = c
    
       Thread.start do
         loop do
           check
           sleep 1
         end
       end
    
       puts "subscribe : topic=" + $config['subscribe_topic']
       c.get($config['subscribe_topic']) do |t, msg|
         hvcc = JSON.parse(msg)
         $last_received_t = Time.now.to_i
         if hvcc[$config['check_key']].to_i > 0
           $last_received_1 = Time.now.to_i
         end
       end
    end
  rescue Exception => e
    puts e
  end
  puts "reconnecting..."
  sleep 3
end
