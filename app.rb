require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

#enable :sessions

@loggedin = 1

get('/') do
    
    return slim(:start)
end

get('/showlogin') do

    return slim(:login)
end

get('/register') do

    return slim(:register)
end

def connect_to_db(path)
  db=SQLite3::Database.new(path)
  db.results_as_hash = true
  return db
end


post('/login') do
    username=params[:username]
    password=params[:password]
    db= connect_to_db('db/slutprojekt.db')
    result = db.execute("SELECT * FROM users WHERE username = ?", username).first
    passwordDigest = result["passwordDigest"]
    id = result["id"]
  
    if BCrypt::Password.new(passwordDigest) == password
      session[:id] = id
      @loggedin=2
      @username= db.execute("SELECT username, WHERE id = ?", id)
      p "plaster"
      redirect('/')
    else
      "Fel lösenord"
    end
end

post('/users/new') do
  username=params[:username]
  password=params[:password]
  password_confirm=params[:password_confirm]

  if (password==password_confirm)
    password_digest = BCrypt::Password.create(password)
    dbn= connect_to_db('db/slutprojekt.db')
    db.execute("INSERT INTO users (username, passwordDigest) VALUES (?,?)", [username, password_digest])
    redirect('/')


  else


  end
end