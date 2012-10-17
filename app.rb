require 'sinatra'
set :protection, except: :json_csrf

require './eol/api'
require './eol/fav'
