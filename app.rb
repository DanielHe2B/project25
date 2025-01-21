require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

get('/') do
    
    return slim(:start)
end

get('/login') do

    return slim(:login)
end