require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

#enable :sessions

@loggedin = true

get('/') do
    
    return slim(:start)
end

get('/showlogin') do

    return slim(:login)
end

get('/register') do

    return slim(:register)
end

post('/login') do
    username=params[:username]
    password=params[:password]
    db=SQLite3::Database.new('db/slutprojekt.db')
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    passwordDigest = result["passwordDigest"]
    id = result["id"]
  
    if BCrypt::Password.new(passwordDigest) == password
      session[:id] = id
      redirect('/')
    else
      "Fel lösenord"
    end
end