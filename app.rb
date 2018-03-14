require 'redis'
require 'pusher'
require 'sinatra'

configure do
  $redis = Redis.new(url: ENV['REDISTOGO_URL'])
  Pusher.app_id = ENV['PUSHER_APP_ID']
  Pusher.key = ENV['PUSHER_KEY']
  Pusher.secret = ENV['PUSHER_SECRET']
end

get '/' do
  # Ordered keys dropping the request_count
  @keys = $redis.keys.sort_by(&:to_i).drop(1).reverse!
  erb :index
end

post '/' do
  content_type 'application/json'

  # Delete records once 50 postbacks are stored
  $redis.flushall if $redis.get('request_count').to_i >= 50

  payload = request.body.read
  counter = $redis.incr('request_count')

  # Store the record on Redis
  $redis.set(counter, payload)

  # Trigger a new event on Pusher for real-time update on view
  Pusher.trigger('transactions', 'log', { id: counter, payload: payload })

  status 200
end

post '/reset' do
  $redis.flushall
  redirect '/'
end

helpers do
  def prettify(string)
    JSON.pretty_generate(JSON.parse(string))
  rescue
    # Possibly not a valid JSON
    string
  end
end
